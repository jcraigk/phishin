#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11,<3.13"
# dependencies = [
#   "requests",
#   "rarfile",
#   "numpy",
# ]
# ///
"""Verification report for split-scan repairs.

The split scan finds tracks that end in digital silence where a split lost the
audio. Repairing one means rebuilding it from the original source, and that is
only safe if the source is actually the same master - a different transfer of
the same show correlates around 0.82 and is 25% off in level, which would put
an audible step in any seam.

So this pairs each flagged track with the source audio that would replace it and
serves them side by side to be listened to before anything is written.

The pairing is post-combination: phish.in merges sandwiches (HYHU, TMWSIY, YEM)
into a single track, so the source side is merged the same way before it is
compared. What you hear on the right is what would go into the slot on the left,
not a fragment of it.

    uv run scripts/split_verify.py --report split_report.json \
        --sources ~/Desktop/sources --out tmp/split_verify
    uv run scripts/split_verify.py --serve --out tmp/split_verify --port 8774
"""

import argparse
import html
import json
import re
import struct
import subprocess
import sys
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

RENDER_TIMEOUT_S = 180
# Same abbreviations audio_sandwich_analysis.py uses, so a phish.in title like
# "HYHU > Jennifer Dances > HYHU" can be expanded back into the source tracks it
# was merged from.
ABBREVIATIONS = {
    "HYHU": "hold your head up",
    "TMWSIY": "the man who stepped into yesterday",
    "YEM": "you enjoy myself",
}
SEGUE_RE = re.compile(r"\s*-?>\s*")
# A re-encode of identical audio correlates at 0.9999, so anything near that is
# the same master. A different transfer of the same show measures around 0.82.
SAME_MASTER = 0.99
LIKELY_SAME = 0.95
# Below this the two files do not hold the same passage at all. Source files are
# paired to a track by filename, and a show whose songs were split at different
# points will pair "Mound" with a Mound that starts somewhere else - the length
# difference then looks like restored audio when it is nothing of the kind, so
# no length verdict is offered until the audio is known to match.
SAME_PERFORMANCE = 0.5
# Whole shows in some sources end every track on a two second pad. That is the
# master's own convention rather than a split dropping audio, so it is reported
# separately instead of filling the repair queue with 660 false leads.
PAD_MIN_S = 1.90
PAD_MAX_S = 2.10


def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, timeout=RENDER_TIMEOUT_S, **kw)


def probe(path, entry, stream=False):
    sel = ["-select_streams", "a:0", "-show_entries", f"stream={entry}"] if stream \
        else ["-show_entries", f"format={entry}"]
    out = run(["ffprobe", "-v", "error", *sel, "-of", "csv=p=0", str(path)]).stdout
    text = out.decode(errors="replace").strip()
    return text.split("\n")[0].split(",")[0] if text else ""


def duration_s(path):
    try:
        return float(probe(path, "duration"))
    except ValueError:
        return 0.0


def mono_pcm(path, start=0.0, seconds=None, rate=8000):
    """Mono at a low rate: enough to align and correlate, cheap to compute."""
    pre = ["-ss", f"{start:.3f}"] if start else []
    post = ["-t", f"{seconds:.3f}"] if seconds else []
    out = run(["ffmpeg", "-v", "error", *pre, "-i", str(path), *post,
               "-ac", "1", "-ar", str(rate),
               "-f", "s16le", "-acodec", "pcm_s16le", "-"]).stdout
    return struct.unpack(f"<{len(out) // 2}h", out[: len(out) // 2 * 2])


def fft_alignment(needle, haystack):
    """Where the excerpt sits in the source, and how well it matches there.

    A direct scan is about a minute for a track of this length; correlating
    through an fft is a second, which is what makes searching the whole source
    affordable rather than guessing at a window.
    """
    import numpy as np
    a = np.asarray(needle, dtype=np.float64)
    b = np.asarray(haystack, dtype=np.float64)
    if len(b) <= len(a):
        return 0.0, 0
    size = 1 << (len(b) + len(a)).bit_length()
    spectrum = np.fft.rfft(b, size) * np.conj(np.fft.rfft(a, size))
    cc = np.fft.irfft(spectrum, size)[: len(b) - len(a) + 1]
    # Each position is scored against the energy actually under the window, so
    # a loud passage cannot outrank a well matching quiet one.
    cumulative = np.concatenate([[0.0], np.cumsum(b * b)])
    energy = np.sqrt(np.maximum(
        cumulative[len(a):len(a) + len(cc)] - cumulative[:len(cc)], 1.0))
    scores = cc / (energy * max(np.linalg.norm(a), 1.0))
    index = int(np.argmax(scores))
    # The fft answer is checked against a plain dot product at the offset it
    # picked. They agree when the maths is right, and a silent disagreement here
    # would put a wrong verdict on every card.
    window = b[index:index + len(a)]
    exact = float(np.dot(window, a) /
                  max(np.linalg.norm(window) * np.linalg.norm(a), 1.0))
    return exact, index


def level_ratio(a, b):
    """How much louder one is than the other, as a plain ratio."""
    pa = sum(abs(v) for v in a) / max(len(a), 1)
    pb = sum(abs(v) for v in b) / max(len(b), 1)
    return pa / pb if pb else 0.0


def title_parts(title):
    """The songs a merged title was built from, lowercased.

    "HYHU > Jennifer Dances > HYHU" is three source tracks; a plain title is one.
    """
    parts = []
    for piece in SEGUE_RE.split(title):
        piece = piece.strip()
        if not piece:
            continue
        parts.append(ABBREVIATIONS.get(piece, piece).lower())
    return parts


def normalize(name):
    """Loose key for matching a source filename to a song title."""
    name = re.sub(r"\.[a-z0-9]+$", "", name, flags=re.I)
    name = re.sub(r"^[IVXe\-]+\s*\d+\s*", "", name)
    name = re.sub(r"^\(check\)\s*", "", name, flags=re.I)
    name = re.sub(r"[^a-z0-9 ]+", " ", name.lower())
    return re.sub(r"\s+", " ", name).strip()


def source_files(directory):
    exts = {".mp3", ".flac", ".wav", ".m4a", ".shn"}
    return sorted(p for p in Path(directory).rglob("*") if p.suffix.lower() in exts)


def match_parts(parts, files):
    """Source files for each song of a merged title, in order.

    Returns None when any part has no match: a partial rebuild would drop audio,
    and a report that quietly showed one would be worse than showing nothing.
    """
    by_key = {}
    for path in files:
        by_key.setdefault(normalize(path.name), []).append(path)
    picked, used = [], set()
    for part in parts:
        options = by_key.get(part) or []
        options = [p for p in options if p not in used]
        if not options:
            hits = [k for k in by_key if part in k or k in part]
            options = [p for k in hits for p in by_key[k] if p not in used]
        if not options:
            return None
        picked.append(options[0])
        used.add(options[0])
    return picked


def build_source_audio(paths, out_path):
    """Concatenate the source parts into one file, as phish.in's merge does."""
    out_path.parent.mkdir(parents=True, exist_ok=True)
    if out_path.exists():
        return out_path
    args = ["ffmpeg", "-y", "-v", "error"]
    for path in paths:
        args += ["-i", str(path)]
    chain = "".join(f"[{i}:a]aresample=44100[a{i}];" for i in range(len(paths)))
    chain += "".join(f"[a{i}]" for i in range(len(paths)))
    chain += f"concat=n={len(paths)}:v=0:a=1[out]"
    args += ["-filter_complex", chain, "-map", "[out]",
             "-c:a", "pcm_s16le", str(out_path)]
    proc = run(args)
    if proc.returncode != 0:
        out_path.unlink(missing_ok=True)
        return None
    return out_path


def fetch_track(url, dest):
    import requests
    if dest.exists() and dest.stat().st_size:
        return dest
    dest.parent.mkdir(parents=True, exist_ok=True)
    with requests.get(url, timeout=180, stream=True,
                      headers={"User-Agent": "Mozilla/5.0"}) as resp:
        resp.raise_for_status()
        with dest.open("wb") as handle:
            for chunk in resp.iter_content(1 << 20):
                handle.write(chunk)
    return dest


# Deciding whether two files are the same master takes a few seconds of audio,
# not the whole track. mp3 frames are self contained, so a byte range out of the
# middle decodes on its own - a 1MB read instead of 15MB, which is the
# difference between a queue that takes an afternoon and one that takes minutes.
EXCERPT_BYTES = 1 << 20
EXCERPT_AT = 0.25


def fetch_excerpt(url, dest):
    import requests
    if dest.exists() and dest.stat().st_size:
        return dest
    dest.parent.mkdir(parents=True, exist_ok=True)
    head = requests.head(url, timeout=60, headers={"User-Agent": "Mozilla/5.0"})
    size = int(head.headers.get("content-length", 0))
    if not size:
        return None
    start = max(0, int(size * EXCERPT_AT))
    end = min(size - 1, start + EXCERPT_BYTES - 1)
    resp = requests.get(url, timeout=120, headers={
        "User-Agent": "Mozilla/5.0", "Range": f"bytes={start}-{end}"})
    resp.raise_for_status()
    raw = dest.with_suffix(".raw.mp3")
    raw.write_bytes(resp.content)
    # The slice starts mid frame, so decode it once and keep the pcm: reading
    # the raw slice again later would re-run the decoder's guess at where the
    # first whole frame begins, and that guess is what the comparison rides on.
    proc = run(["ffmpeg", "-y", "-v", "error", "-i", str(raw),
                "-ac", "1", "-ar", "8000",
                "-f", "wav", "-acodec", "pcm_s16le", str(dest)])
    raw.unlink(missing_ok=True)
    if proc.returncode != 0:
        dest.unlink(missing_ok=True)
        return None
    return dest


def remote_duration_s(url):
    """Duration without downloading: ffprobe reads the header over http."""
    out = run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
               "-of", "csv=p=0", url]).stdout.decode(errors="replace").strip()
    try:
        return float(out.split("\n")[0])
    except (ValueError, IndexError):
        return 0.0


def is_show_pad(row):
    return PAD_MIN_S <= row.get("trailing_zeros_s", 0) <= PAD_MAX_S


def compare(excerpt, rebuilt, site_s, rebuilt_s, excerpt_at_s):
    """How closely the source matches the site's audio, from an excerpt.

    The excerpt came out of the middle of the site's file as a byte range, and
    a byte offset is not a time offset in a variable bitrate file, so where it
    landed is only known to within a wide margin. It is searched for across the
    whole source by cross correlation rather than guessed at - a direct scan at
    this length would cost more than the fetch it replaced.
    """
    a = mono_pcm(excerpt, start=1.0, seconds=12.0)
    hay = mono_pcm(rebuilt)
    if not a or not hay or len(hay) <= len(a):
        return None
    score, off = fft_alignment(a, hay)
    b = hay[off:off + len(a)]
    return {
        "correlation": round(score, 4),
        "offset_s": round(off / 8000.0, 3),
        "level_ratio": round(level_ratio(a, b), 3),
        "existing_s": round(site_s, 2),
        "rebuilt_s": round(rebuilt_s, 2),
    }


def verdict(cmp):
    if cmp is None:
        return "unknown", "could not compare"
    c = cmp["correlation"]
    if c >= SAME_MASTER:
        return "same", "same master - safe to rebuild"
    if c >= LIKELY_SAME:
        return "close", "close, but check by ear before replacing"
    if c >= SAME_PERFORMANCE:
        return "different", "different transfer - level and tone will not match"
    return "different", "not the same passage - wrong file, or split elsewhere"


# The whole point of the repair is to put back audio a split dropped, so the
# rebuilt track has to be longer than what the site serves. Shorter means the
# source is missing something of its own and replacing would lose more than it
# restores; roughly equal means there was nothing to recover.
def length_verdict(cmp):
    if cmp is None:
        return "unknown", "no measurement"
    if cmp["correlation"] < SAME_PERFORMANCE:
        return "unknown", "different passage - length says nothing"
    delta = cmp["rebuilt_s"] - cmp["existing_s"]
    if delta > 0.05:
        return "same", f"+{delta:.2f}s restored"
    if delta < -0.05:
        return "different", f"{delta:.2f}s SHORTER - would lose audio"
    return "close", f"{delta:+.2f}s - nothing gained"


CSS = """
:root { --bg:#fff; --fg:#1c1c1e; --muted:#6b6b70; --line:#d8d8dd;
        --ok:#1a7f37; --warn:#a15c00; --bad:#c0392b; --link:#2f6fd0; }
@media (prefers-color-scheme: dark) {
  :root { --bg:#1b1f27; --fg:#e6e9ef; --muted:#8b95a7; --line:#3a4356;
          --ok:#4ac26b; --warn:#d29922; --bad:#e5534b; --link:#7fb3f0; } }
* { box-sizing:border-box; }
body { margin:0; padding:1.5rem; background:var(--bg); color:var(--fg);
       font:14px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
h1 { font-size:1.3rem; margin:0 0 .25rem; }
.meta { color:var(--muted); font-size:12px; margin-bottom:1.25rem; }
a { color:var(--link); }
.row { border:1px solid var(--line); border-radius:10px; padding:.85rem 1rem;
       margin-bottom:.85rem; max-width:1000px; }
.row h3 { margin:0 0 .15rem; font-size:14px; font-weight:600; }
.sub { color:var(--muted); font-size:12px; margin-bottom:.6rem; }
.pair { display:flex; gap:1.5rem; flex-wrap:wrap; align-items:center; }
.side { display:flex; align-items:center; gap:.5rem; }
.tag { font-size:11px; text-transform:uppercase; letter-spacing:.04em;
       padding:.1rem .4rem; border-radius:4px; border:1px solid var(--line); }
.v-same { color:var(--ok); border-color:var(--ok); }
.v-close { color:var(--warn); border-color:var(--warn); }
.v-different, .v-unknown { color:var(--bad); border-color:var(--bad); }
audio { height:32px; }
table { border-collapse:collapse; width:100%; max-width:1000px; }
th, td { text-align:left; padding:.4rem .6rem; border-bottom:1px solid var(--line); }
th { font-size:12px; text-transform:uppercase; letter-spacing:.04em;
     color:var(--muted); font-weight:600; }
code { font-size:12px; color:var(--muted); }
"""


def page(title, body):
    return (f"<!doctype html>\n<meta charset=utf-8>\n"
            f"<meta name=viewport content='width=device-width,initial-scale=1'>\n"
            f"<title>{html.escape(title)}</title>\n<style>{CSS}</style>\n{body}\n")


def build(report_path, sources_dir, out_dir, limit, include_pads=False):
    rows = json.loads(Path(report_path).read_text())["tracks"]
    rows = [r for r in rows if r.get("followed_in_set")]
    padded = [] if include_pads else [r for r in rows if is_show_pad(r)]
    rows = [r for r in rows if include_pads or not is_show_pad(r)]
    if padded:
        shows = len({r["date"] for r in padded})
        print(f"Skipping {len(padded)} track(s) across {shows} show(s) padded to "
              f"~2s throughout - a master convention, not lost audio "
              f"(--include-pads to review them anyway)\n")
    out = Path(out_dir)
    (out / "audio").mkdir(parents=True, exist_ok=True)

    by_date = {}
    for row in rows:
        by_date.setdefault(row["date"], []).append(row)

    cards, done = [], 0
    for date in sorted(by_date):
        show_dir = Path(sources_dir) / date
        if not show_dir.is_dir():
            continue
        files = source_files(show_dir)
        for row in sorted(by_date[date], key=lambda r: r["position"]):
            if limit and done >= limit:
                break
            parts = title_parts(row["title"])
            picked = match_parts(parts, files)
            if not picked:
                cards.append(unmatched_card(row, parts))
                continue
            stem = f"{date}_t{row['position']}"
            rebuilt = build_source_audio(picked, out / "audio" / f"{stem}_source.wav")
            if rebuilt is None:
                cards.append(unmatched_card(row, parts))
                continue
            excerpt = fetch_excerpt(row["mp3_url"], out / "audio" / f"{stem}_probe.wav")
            site_s = row.get("duration_s") or remote_duration_s(row["mp3_url"])
            cmp = None
            if excerpt:
                cmp = compare(excerpt, rebuilt, site_s, duration_s(rebuilt),
                              site_s * EXCERPT_AT)
            # Only worth pulling the whole track once it is going on the page.
            existing = fetch_track(row["mp3_url"], out / "audio" / f"{stem}_site.mp3")
            cards.append((cmp, card(row, parts, picked, existing, rebuilt, cmp)))
            done += 1
            delta = (cmp["rebuilt_s"] - cmp["existing_s"]) if cmp else 0
            print(f"  {date} t{row['position']} {row['title'][:36]}"
                  f"  corr={cmp['correlation'] if cmp else '?'}  {delta:+.2f}s")

    # Anything that would lose audio or come from the wrong master first: those
    # are the ones that must not be applied, and they are easy to miss at the
    # bottom of a long page.
    def rank(entry):
        cmp = entry[0]
        if cmp is None or cmp["correlation"] < SAME_PERFORMANCE:
            return (0, 0)
        delta = cmp["rebuilt_s"] - cmp["existing_s"]
        return (1 if delta > 0.05 else 0, cmp["correlation"])

    ordered = [c for _, c in sorted((e for e in cards if isinstance(e, tuple)),
                                    key=rank)]
    ordered += [c for c in cards if not isinstance(c, tuple)]
    body = (f"<h1>Split repair verification</h1>"
            f'<div class="meta">{len(ordered)} track(s), problems first. Left is '
            f"what the site serves now; right is the source rebuilt to the same "
            f"shape, sandwiches merged. They should sound like the same "
            f"recording, and the source should be <em>longer</em> - that is the "
            f"audio being restored.</div>"
            + "".join(ordered))
    (out / "index.html").write_text(page("Split repair verification", body))
    print(f"\n{len(cards)} card(s) -> {out / 'index.html'}")


def unmatched_card(row, parts):
    return (f'<div class="row"><h3>{html.escape(row["date"])} '
            f't{row["position"]} &middot; {html.escape(row["title"])}</h3>'
            f'<div class="sub"><span class="tag v-unknown">no source</span> '
            f"needs: {html.escape(', '.join(parts))}</div></div>")


def card(row, parts, picked, existing, rebuilt, cmp):
    klass, note = verdict(cmp)
    lklass, lnote = length_verdict(cmp)
    names = ", ".join(p.name for p in picked)
    detail = ""
    if cmp:
        detail = (f"correlation {cmp['correlation']} &middot; "
                  f"level &times;{cmp['level_ratio']} &middot; "
                  f"site {cmp['existing_s']}s &rarr; source {cmp['rebuilt_s']}s "
                  f"&middot; silence trailing the site copy "
                  f"{row['trailing_zeros_s'] * 1000:.0f}ms")
    return (
        f'<div class="row">'
        f'<h3>{html.escape(row["date"])} t{row["position"]} &middot; '
        f'{html.escape(row["title"])}</h3>'
        f'<div class="sub"><span class="tag v-{klass}">{html.escape(note)}</span> '
        f'<span class="tag v-{lklass}">{html.escape(lnote)}</span> '
        f"{detail}</div>"
        f'<div class="sub"><code>{html.escape(names)}</code></div>'
        f'<div class="pair">'
        f'<div class="side"><span class="tag">site</span>'
        f'<audio controls preload="none" src="audio/{existing.name}"></audio></div>'
        f'<div class="side"><span class="tag">source</span>'
        f'<audio controls preload="none" src="audio/{rebuilt.name}"></audio></div>'
        f"</div></div>")


def serve(out_dir, port):
    handler = partial(SimpleHTTPRequestHandler, directory=str(Path(out_dir).resolve()))
    server = ThreadingHTTPServer(("127.0.0.1", port), handler)
    print(f"http://127.0.0.1:{port}/index.html")
    server.serve_forever()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--report")
    ap.add_argument("--sources", help="dir holding one subdir per show date")
    ap.add_argument("--out", default="tmp/split_verify")
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--include-pads", action="store_true",
                    help="also review tracks padded to ~2s throughout a show")
    ap.add_argument("--serve", action="store_true")
    ap.add_argument("--port", type=int, default=8774)
    args = ap.parse_args()
    if args.serve:
        serve(args.out, args.port)
        return
    if not args.report or not args.sources:
        sys.exit("--report and --sources are required to build")
    build(args.report, args.sources, args.out, args.limit, args.include_pads)


if __name__ == "__main__":
    main()
