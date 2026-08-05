#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11,<3.13"
# dependencies = [
#   "numpy",
#   "requests",
#   "tensorflow>=2.16",
#   "tensorflow-hub>=0.16",
#   "setuptools<81",  # tensorflow-hub imports pkg_resources, removed in newer setuptools
#   "faster-whisper",
#   "matplotlib",
# ]
# ///
"""Detect non-music (crowd noise / silence) at the edges of tracks.

Stage 1 of https://github.com/jcraigk/phishin/issues/166: analyze set-boundary
tracks and report contiguous non-music runs anchored at the start or end of the
file. Detection combines YAMNet (music vs applause/crowd/speech classification
per ~0.5s frame) with an RMS loudness curve. Nothing is modified; output is a
report (and optional plots) for human review.

Audio is resolved locally when possible (Active Storage disk paths), otherwise
downloaded from the track's mp3_url into a cache dir.

Usage:
  uv run scripts/audio_edge_analysis.py --show 1997-11-22
  uv run scripts/audio_edge_analysis.py --show 1997-11-22 --json tmp/report.json --plot-dir tmp/plots
  uv run scripts/audio_edge_analysis.py path/or/url.mp3 --edges both --plot-dir tmp/plots
  uv run scripts/audio_edge_analysis.py url.mp3 --edges trailing --trim-dir tmp/trimmed

Production-style first pass (set/encore enders only, with review page):
  uv run scripts/audio_edge_analysis.py --show 1996-11-02 --edges trailing \\
    --trim-dir tmp/trimmed --plot-dir tmp/plots --json tmp/report.json --html tmp/review.html

Full catalog, one self-contained review bundle per year:
  for y in $(seq 1983 2025); do
    uv run scripts/audio_edge_analysis.py --year $y --edges trailing --stream \\
      --trim-dir out/$y/trimmed --plot-dir out/$y/plots \\
      --json out/$y/report.json --html out/$y/review.html
  done

Requires ffmpeg/ffprobe on PATH.
"""

import argparse
import csv
import hashlib
import html as html_escape
import json
import os
import re
import shutil
import subprocess
import sys
from dataclasses import asdict, dataclass, field
from pathlib import Path

import numpy as np
import requests

API_BASE = "https://phish.in/api/v2"
SITE_BASE = "https://phish.in"
SAMPLE_RATE = 16000
FRAME_HOP_S = 0.48  # YAMNet score hop
FRAME_WIN_S = 0.96  # YAMNet score window
CROWD_CLASSES = ["Applause", "Cheering", "Crowd", "Clapping", "Chatter"]
SPEECH_CLASSES = ["Speech"]
SILENCE_RMS_DB = -48.0
MIN_CUT_S = 5.0  # skip trims that would remove less than this
CLIP_LEAD_S = 5.0  # audio kept before the fade starts in review clips
LOUD_TAIL_DROP_DB = 6.0  # badge candidates whose cut side stays within this of the music level
MAX_CHAIN_S = 60.0  # furthest banter chaining may extend past the raw music boundary
# A cappella repertoire: YAMNet scores quiet unaccompanied singing as speech,
# so the music boundary lands mid-performance and any proposed trim would cut
# the song itself. Tracks with these song slugs are still scanned, but never
# auto-trimmed; flagged ones get their own manual-review section in review.html.
A_CAPPELLA_SLUGS = {
    "amazing-grace",
    "carolina",
    "free-bird",
    "grind",
    "hello-my-baby",
    "memories",
    "sweet-adeline",
    "the-star-spangled-banner",
}

REPO_ROOT = Path(__file__).resolve().parent.parent
STORAGE_CANDIDATES = [
    REPO_ROOT / "tmp" / "attachments",
    Path("/content/active_storage"),
]
CACHE_DIR = REPO_ROOT / "tmp" / "audio_cache"
IGNORE_FILE = REPO_ROOT / "data" / "edge_scan" / "ignore.txt"


def load_ignore_urls(path):
    """Share URLs of tracks to leave alone, one per line, # comments allowed."""
    if not path.exists():
        return set()
    return {
        line.strip().rstrip("/")
        for line in path.read_text().splitlines()
        if line.strip() and not line.strip().startswith("#")
    }


@dataclass
class EdgeResult:
    label: str
    edge: str  # "leading" or "trailing"
    track_duration_s: float
    nonmusic_run_s: float  # contiguous non-music anchored at the edge
    music_boundary_s: float  # track time where music starts (leading) / ends (trailing)
    region: list  # [start_s, end_s] of the run in track time
    character: dict  # fraction of run frames: silence / crowd / speech / other
    mean_music_score: float
    mean_crowd_score: float
    mean_rms_db: float
    flagged: bool = False  # internal screening state; recomputed on load, kept out of report.json
    banter: list = field(default_factory=list)  # [{start, end, text}] on-mic speech in the region
    songs: list = field(default_factory=list)
    mp3_url: str = ""
    share_url: str = ""  # e.g. https://phish.in/1996-11-02/sweet-adeline
    boundary_rms_drop_db: float | None = None  # music-side minus cut-side loudness at the boundary


def run(cmd, **kw):
    return subprocess.run(cmd, check=True, capture_output=True, **kw)


def probe_duration(path):
    out = run([
        "ffprobe", "-v", "error", "-show_entries", "format=duration",
        "-of", "csv=p=0", str(path),
    ])
    return float(out.stdout.decode().strip())


def probe_bitrate(path):
    out = run([
        "ffprobe", "-v", "error", "-show_entries", "format=bit_rate",
        "-of", "csv=p=0", str(path),
    ])
    raw = out.stdout.decode().strip()
    return f"{round(int(raw) / 1000)}k" if raw.isdigit() else "192k"


def report_json(results):
    """Serialize results for report.json. `flagged` is internal screening state
    (run length vs --min-duration) and stays out of the report."""
    return json.dumps(
        [{k: v for k, v in asdict(r).items() if k != "flagged"} for r in results],
        indent=2)


def track_slug(share_url):
    return share_url.rstrip("/").rsplit("/", 1)[-1]


def fmt_ts(seconds):
    """Seconds as m:ss (or h:mm:ss), matching what audio players display."""
    seconds = int(round(float(seconds)))
    m, s = divmod(seconds, 60)
    h, m = divmod(m, 60)
    return f"{h}:{m:02d}:{s:02d}" if h else f"{m}:{s:02d}"


def display_label(label):
    """Label without the tNN position token, for human-facing pages."""
    return re.sub(r"^(\d{4}-\d{2}-\d{2} .*?) t\d+ ", r"\1 ", label)


def effective_boundary(result, gap_s):
    """Music boundary pushed outward past adjacent on-mic banter.

    Banter segments are chained: each one within gap_s of the current boundary
    extends it, so a thank-you 20s after the last note is still kept. A segment
    is only chained if it fits within MAX_CHAIN_S of the raw boundary."""
    boundary = result.music_boundary_s
    if result.edge == "trailing":
        limit = boundary + MAX_CHAIN_S
        for seg in sorted(result.banter, key=lambda s: s["start"]):
            if seg["start"] <= boundary + gap_s and seg["end"] <= limit:
                boundary = max(boundary, seg["end"])
    else:
        limit = boundary - MAX_CHAIN_S
        for seg in sorted(result.banter, key=lambda s: s["end"], reverse=True):
            if seg["end"] >= boundary - gap_s and seg["start"] >= limit:
                boundary = min(boundary, seg["start"])
    return boundary


def trim_track(path, duration_s, edge_results, args, label):
    """Render a trimmed mp3 for flagged edges: cut at the music boundary plus a
    few seconds of kept crowd noise, with fades. Writes to --trim-dir; the
    original file is never modified."""
    flagged = {r.edge: r for r in edge_results if r.flagged}
    if not flagged:
        return
    if track_slug(edge_results[0].share_url) in A_CAPPELLA_SLUGS:
        print(f"  skipping {display_label(label)}: a cappella, listed for manual review", file=sys.stderr)
        return
    start = 0.0
    end = duration_s
    filters = [None, "asetpts=PTS-STARTPTS"]
    if "leading" in flagged:
        start = max(0.0, effective_boundary(flagged["leading"], args.banter_gap) - args.keep_lead)
        if args.fade_in > 0:
            filters.append(f"afade=t=in:st=0:d={args.fade_in:.2f}")
    if "trailing" in flagged:
        boundary = effective_boundary(flagged["trailing"], args.banter_gap)
        end = min(duration_s, boundary + args.fade_delay + args.fade_out)
        if args.fade_out > 0:
            fade = min(args.fade_out, end - start)
            filters.append(f"afade=t=out:st={end - start - fade:.2f}:d={fade:.2f}")
    filters[0] = f"atrim=start={start:.2f}:end={end:.2f}"

    cut_s = duration_s - (end - start)
    if cut_s < MIN_CUT_S:
        # Nothing meaningful to remove (e.g. banter runs to the end of the
        # track); re-encoding would only add a fade over kept content.
        print(f"  skipping {display_label(label)}: only {cut_s:.1f}s would be cut", file=sys.stderr)
        return {"cut_s": round(cut_s, 1), "skipped": True}

    args.trim_dir.mkdir(parents=True, exist_ok=True)
    safe_label = re.sub(r"[^\w.-]+", "_", label)
    out_path = args.trim_dir / f"{safe_label}_trimmed.mp3"
    run([
        "ffmpeg", "-y", "-v", "error", "-i", str(path),
        "-af", ",".join(filters), "-map_metadata", "0", "-id3v2_version", "3",
        "-b:a", probe_bitrate(path), str(out_path),
    ])
    print(f"  trimmed {display_label(label)}: kept {start:.1f}s to {end:.1f}s "
          f"(cut {duration_s - (end - start):.1f}s of {duration_s:.1f}s) -> {out_path}",
          file=sys.stderr)

    info = {"trimmed": out_path, "start": start, "end": end,
            "cut_s": round(duration_s - (end - start), 1)}
    if "trailing" in flagged:
        # Audition clip: the last seconds before the fade, then the full fade-out.
        # Anchored to the fade, not the music boundary — with trailing banter the
        # two can be a minute apart, and the fade is what needs reviewing.
        clip_dir = args.trim_dir / "clips"
        clip_dir.mkdir(exist_ok=True)
        fade_start = end - min(args.fade_out, end - start)
        clip_start = max(0.0, fade_start - CLIP_LEAD_S - start)
        clip = clip_dir / f"{safe_label}_audition.mp3"
        if render_clip(["ffmpeg", "-y", "-v", "error", "-ss", f"{clip_start:.2f}",
                        "-i", str(out_path), "-c", "copy", str(clip)], label):
            info["audition"] = clip
    return info


def render_clip(cmd, label):
    """Render an audition clip, retrying once; clips are conveniences, so a
    failure (e.g. transient HTTP error on a streamed source) only warns."""
    for attempt in (1, 2):
        try:
            run(cmd)
            return True
        except subprocess.CalledProcessError as e:
            if attempt == 2:
                print(f"  WARNING clip render failed for {label}: {e}", file=sys.stderr)
    return False


def write_outputs(results, trim_info, args):
    """Write report.json and review.html for the results so far, ordered by
    run length. Called after every track so a running scan can be reviewed."""
    ordered = sorted(results, key=lambda r: r.nonmusic_run_s, reverse=True)
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(report_json(ordered))
    if args.html:
        write_review_html(args.html, ordered, trim_info, args, quiet=True)


def write_review_html(html_path, results, trim_info, args, quiet=False):
    """Static review page: audition clip, plot, transcript, and
    an approve checkbox per candidate. Export writes approved.json for the
    apply step. Open locally; audio/img paths are relative to this file."""
    def rel(p):
        return os.path.relpath(p, html_path.parent)

    rows = []
    skipped = []
    acappella = []
    for r in results:
        if not r.flagged:
            continue
        info = trim_info.get(r.label, {})
        esc = html_escape.escape
        shown = display_label(r.label)
        link = (f'<a href="{esc(r.share_url, quote=True)}" target="_blank">{esc(shown)}</a>'
                if r.share_url else esc(shown))
        cut_at = info.get("end") if r.edge == "trailing" else info.get("start")
        segs = []
        for s in r.banter:
            if cut_at is None:
                kept = True
            elif r.edge == "trailing":
                kept = s["end"] <= cut_at
            else:
                kept = s["start"] >= cut_at
            segs.append(
                f'<span class="seg {"kept" if kept else "cut"}" '
                f'title="{fmt_ts(s["start"])}&ndash;{fmt_ts(s["end"])}">'
                f'{fmt_ts(s["start"])} &ldquo;{esc(s["text"])}&rdquo;</span>')
        banter = f'<div class="banter">{"".join(segs)}</div>' if segs else ""
        char = ", ".join(f"{k} {v:.0%}" for k, v in r.character.items() if v > 0)
        plot = ""
        if args.plot_dir:
            p = args.plot_dir / (re.sub(r"[^\w.-]+", "_", f"{r.label}_{r.edge}") + ".png")
            if p.exists():
                plot = f'<img src="{rel(p)}" loading="lazy">'
        if track_slug(r.share_url) in A_CAPPELLA_SLUGS:
            # Never auto-trimmed: the music detector misreads unaccompanied
            # singing. Listed without an approve checkbox for manual review.
            acappella.append(f'<div class="meta">{link} &middot; '
                             f'run {fmt_ts(r.nonmusic_run_s)} &middot; {char}</div>')
            continue
        if info.get("end") is None:
            # Flagged but nothing actionable (cut below minimum, usually
            # banter running to the end of the track). Footnote only.
            cut = fmt_ts(info["cut_s"]) if info.get("cut_s") is not None else "?"
            skipped.append(f'<div class="meta">{link} &middot; run {fmt_ts(r.nonmusic_run_s)}, '
                           f'cut {cut} &mdash; left untouched</div>')
            continue
        audio = ""
        if info.get("audition"):
            audio += f'<audio controls preload="none" src="{rel(info["audition"])}"></audio>'
        payload = esc(json.dumps({
            "label": r.label, "edge": r.edge, "mp3_url": r.mp3_url,
            "share_url": r.share_url, "music_boundary_s": r.music_boundary_s,
            "trim_start": info.get("start"), "trim_end": info.get("end"),
        }), quote=True)
        warn = ""
        if r.boundary_rms_drop_db is not None and r.boundary_rms_drop_db < LOUD_TAIL_DROP_DB:
            warn = '<span class="warn">&#9888;&#xFE0F; Loud past boundary</span>'
        rows.append(f"""
<div class="row">
  <div class="head">
    <input type="checkbox" data-payload="{payload}">
    <strong>{link}</strong>
    <span class="meta">{fmt_ts(r.track_duration_s)} / {fmt_ts(info["cut_s"])}</span>
    {warn}
  </div>
  {banter}
  <div class="audio">{audio}</div>
  {plot}
</div>""")

    html_path.parent.mkdir(parents=True, exist_ok=True)
    html_path.write_text(f"""<!doctype html>
<meta charset="utf-8">
<title>Track edge trim review</title>
<link rel="icon" href='data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><text y=".9em" font-size="90">&#x2702;&#xFE0F;</text></svg>'>
<style>
  body {{ font: 14px/1.5 -apple-system, sans-serif; margin: 2rem auto; max-width: 1100px; }}
  .row {{ border-bottom: 1px solid #ccc; padding: 1rem 0; }}
  .head {{ display: flex; gap: .6rem; align-items: baseline; flex-wrap: wrap; }}
  .meta {{ color: #666; }}
  .banter {{ display: flex; flex-wrap: wrap; gap: .3rem .4rem; margin: .4rem 0 .4rem 1.6rem; }}
  .banter .seg {{ padding: .05rem .45rem; border-radius: 3px; font-size: 13px; }}
  .banter .seg.kept {{ background: #dcefe1; color: #1a6b2f; }}
  .banter .seg.cut {{ background: #f3dada; color: #a02020; text-decoration: line-through; }}
  .warn {{ color: #b00020; font-weight: 600; }}
  .audio {{ display: flex; gap: 1rem; align-items: center; margin: .4rem 0; flex-wrap: wrap; }}
  input[type="checkbox"] {{ width: 1.3rem; height: 1.3rem; }}
  img {{ max-width: 100%; }}
  #export {{ position: fixed; top: 1rem; right: 1rem; padding: .5rem 1rem; }}
</style>
<button id="export">Export approved.json</button>
<h1>Track edge trim review ({len(rows)} candidates)</h1>
{"".join(rows)}
{f'<h2>A cappella ({len(acappella)}) &mdash; not auto-trimmed, review manually</h2>{"".join(acappella)}' if acappella else ""}
{f'<h2>Not trimmed ({len(skipped)})</h2>{"".join(skipped)}' if skipped else ""}
<script>
document.getElementById("export").onclick = () => {{
  const approved = [...document.querySelectorAll("input:checked")]
    .map(cb => JSON.parse(cb.dataset.payload));
  const blob = new Blob([JSON.stringify(approved, null, 2)], {{type: "application/json"}});
  const a = Object.assign(document.createElement("a"),
    {{href: URL.createObjectURL(blob), download: "approved.json"}});
  a.click();
}};
</script>
""")
    if not quiet:
        print(f"Review page written to {html_path}", file=sys.stderr)


def decode_segment(path, start_s, dur_s):
    """Decode a segment to 16kHz mono float32 via ffmpeg."""
    out = run([
        "ffmpeg", "-v", "error", "-ss", f"{max(start_s, 0):.3f}", "-t", f"{dur_s:.3f}",
        "-i", str(path), "-ac", "1", "-ar", str(SAMPLE_RATE), "-f", "f32le", "-",
    ])
    return np.frombuffer(out.stdout, dtype=np.float32)


def local_blob_path(url, storage_dirs):
    """Find the Active Storage disk path for a blob URL, if present locally."""
    key = Path(url.split("?")[0]).stem
    if re.fullmatch(r"[a-z0-9]{20,}", key):
        for root in storage_dirs:
            candidate = root / key[0:2] / key[2:4] / key
            if candidate.exists():
                return candidate
    return None


def download_audio(url):
    key = Path(url.split("?")[0]).stem
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    name = key if re.fullmatch(r"[a-z0-9]{20,}", key) else hashlib.sha1(url.encode()).hexdigest()
    cached = CACHE_DIR / f"{name}.mp3"
    if not cached.exists():
        print(f"  downloading {url}", file=sys.stderr)
        resp = requests.get(url, timeout=120)
        resp.raise_for_status()
        cached.write_bytes(resp.content)
    return cached


class Yamnet:
    def __init__(self):
        print("Loading YAMNet model...", file=sys.stderr)
        import tensorflow_hub as hub
        self.model = hub.load("https://tfhub.dev/google/yamnet/1")
        class_map = self.model.class_map_path().numpy().decode()
        with open(class_map) as f:
            self.class_names = [row["display_name"] for row in csv.DictReader(f)]
        self.music_idx = self.class_names.index("Music")
        self.crowd_idx = [self.class_names.index(n) for n in CROWD_CLASSES]
        self.speech_idx = [self.class_names.index(n) for n in SPEECH_CLASSES]

    def scores(self, waveform):
        scores, _, _ = self.model(waveform)
        return scores.numpy()


class BanterFinder:
    """Transcribes non-music regions; intelligible speech = on-mic banter.

    Crowd voices near the mic don't survive ASR, so Whisper finding words is a
    reliable proxy for PA speech. Whisper's own VAD filter discards this faint,
    noisy audio entirely, so it stays off.
    """

    def __init__(self):
        print("Loading Whisper model...", file=sys.stderr)
        from faster_whisper import WhisperModel
        self.model = WhisperModel("small", device="cpu", compute_type="int8")

    def find(self, waveform, offset_s):
        segments, _ = self.model.transcribe(
            waveform, language="en", vad_filter=False, condition_on_previous_text=False,
            word_timestamps=True)
        banter = []
        for s in segments:
            text = s.text.strip()
            if text and s.no_speech_prob < 0.6 and s.avg_logprob > -1.5:
                # Word timings are far more accurate than segment bounds on
                # noisy crowd audio; use them for the region edges.
                start = s.words[0].start if s.words else s.start
                end = s.words[-1].end if s.words else s.end
                banter.append({
                    "start": round(offset_s + start, 1),
                    "end": round(offset_s + end, 1),
                    "text": text,
                })
        return banter


class LazyBanterFinder:
    """Defer loading Whisper until a flagged region actually needs it."""

    def __init__(self):
        self._inner = None

    def find(self, waveform, offset_s):
        if self._inner is None:
            self._inner = BanterFinder()
        return self._inner.find(waveform, offset_s)


def median_smooth(x, k=5):
    if len(x) < k:
        return x
    pad = k // 2
    padded = np.pad(x, pad, mode="edge")
    return np.median(np.lib.stride_tricks.sliding_window_view(padded, k), axis=1)


def frame_rms_db(waveform, n_frames):
    win = int(FRAME_WIN_S * SAMPLE_RATE)
    hop = int(FRAME_HOP_S * SAMPLE_RATE)
    rms = np.empty(n_frames)
    for i in range(n_frames):
        seg = waveform[i * hop : i * hop + win]
        rms[i] = np.sqrt(np.mean(seg**2)) if len(seg) else 0.0
    return 20 * np.log10(rms + 1e-10)


def analyze_edge(yamnet, banter_finder, path, duration_s, edge, args, label, songs, url, share_url=""):
    window_s = min(args.window, duration_s)
    offset_s = 0.0 if edge == "leading" else duration_s - window_s
    waveform = decode_segment(path, offset_s, window_s)
    scores = yamnet.scores(waveform)
    n = len(scores)
    music = scores[:, yamnet.music_idx]
    crowd = scores[:, yamnet.crowd_idx].max(axis=1)
    speech = scores[:, yamnet.speech_idx].max(axis=1)
    rms_db = frame_rms_db(waveform, n)

    music_sm = median_smooth(music, k=5)
    nonmusic = music_sm < args.music_threshold

    # Walk inward from the edge; median smoothing has already removed short blips.
    order = range(n) if edge == "leading" else range(n - 1, -1, -1)
    run_frames = []
    for i in order:
        if not nonmusic[i]:
            break
        run_frames.append(i)

    run_s = len(run_frames) * FRAME_HOP_S
    if run_frames:
        lo, hi = min(run_frames), max(run_frames)
        region = [offset_s + lo * FRAME_HOP_S, offset_s + hi * FRAME_HOP_S + FRAME_WIN_S]
        idx = np.array(run_frames)
        silent = rms_db[idx] < SILENCE_RMS_DB
        crowdy = ~silent & (crowd[idx] >= speech[idx])
        speechy = ~silent & (speech[idx] > crowd[idx])
        character = {
            "silence": round(float(silent.mean()), 2),
            "crowd": round(float(crowdy.mean()), 2),
            "speech": round(float(speechy.mean()), 2),
        }
        stats = (float(music[idx].mean()), float(crowd[idx].mean()), float(rms_db[idx].mean()))
    else:
        region = []
        character = {}
        stats = (0.0, 0.0, 0.0)

    boundary = region[1] if edge == "leading" and region else (
        region[0] if region else (0.0 if edge == "leading" else duration_s))

    if run_frames:
        # Hysteresis for the cut point: frames just inside the run that still
        # score above ring_threshold are usually ring-out/sustain decay (YAMNet
        # is ~10-20% confident on decaying notes), not crowd. Walk the boundary
        # outward through consecutive ringing frames so fades never clip the end
        # of the music, stopping at the first quiet frame — an isolated blip of
        # music-ish crowd noise deep in the run must not drag the boundary out.
        for i in reversed(run_frames):  # run_frames ends at the music-side edge
            if music_sm[i] < args.ring_threshold:
                break
            if edge == "leading":
                boundary = min(boundary, offset_s + i * FRAME_HOP_S)
            else:
                boundary = max(boundary, offset_s + i * FRAME_HOP_S + FRAME_WIN_S)

    # Sanity signal for review: how much quieter the cut side of the boundary
    # is than the music side (median RMS over ~10s windows). A near-zero drop
    # means a fade would start while the audio is still at song level, e.g.
    # shouted vocals that YAMNet classifies as speech.
    b_idx = int(round((boundary - offset_s) / FRAME_HOP_S))
    w = max(1, int(round(10.0 / FRAME_HOP_S)))
    if edge == "trailing":
        music_win = rms_db[max(0, b_idx - w):b_idx]
        cut_win = rms_db[b_idx:b_idx + w]
    else:
        music_win = rms_db[b_idx:b_idx + w]
        cut_win = rms_db[max(0, b_idx - w):b_idx]
    rms_drop = None
    if len(music_win) and len(cut_win):
        rms_drop = round(float(np.median(music_win) - np.median(cut_win)), 1)

    banter = []
    if banter_finder and region and run_s >= args.min_duration:
        # Transcribe a bit past the region edges so speech straddling the music
        # boundary isn't clipped mid-sentence.
        t0 = max(0.0, region[0] - offset_s - 3.0)
        t1 = min(window_s, region[1] - offset_s + 3.0)
        banter = banter_finder.find(
            waveform[int(t0 * SAMPLE_RATE):int(t1 * SAMPLE_RATE)], offset_s + t0)

    result = EdgeResult(
        label=label,
        edge=edge,
        track_duration_s=round(duration_s, 1),
        nonmusic_run_s=round(run_s, 1),
        music_boundary_s=round(boundary, 1),
        region=[round(t, 1) for t in region],
        character=character,
        mean_music_score=round(stats[0], 3),
        mean_crowd_score=round(stats[1], 3),
        mean_rms_db=round(stats[2], 1),
        flagged=run_s >= args.min_duration,
        banter=banter,
        songs=songs,
        mp3_url=url,
        share_url=share_url,
        boundary_rms_drop_db=rms_drop,
    )

    if args.plot_dir:
        fade = None
        if result.flagged:
            # Same math as trim_track: fade placement relative to the
            # banter-extended boundary.
            eff = effective_boundary(result, args.banter_gap)
            if edge == "trailing":
                fade_end = min(duration_s, eff + args.fade_delay + args.fade_out)
                fade = (max(0.0, fade_end - args.fade_out), fade_end)
            else:
                fade_start = max(0.0, eff - args.keep_lead)
                fade = (fade_start, min(duration_s, fade_start + args.fade_in))
        plot_edge(args.plot_dir, result, offset_s, music_sm, crowd, rms_db, region, fade)
    return result


def plot_edge(plot_dir, result, offset_s, music, crowd, rms_db, region, fade=None):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    plt.style.use("dark_background")

    t = offset_s + np.arange(len(music)) * FRAME_HOP_S
    fig, ax = plt.subplots(figsize=(14, 3.1))
    fig.set_facecolor("#222222")
    ax.set_facecolor("#222222")
    ax.plot(t, music, label="music score", color="tab:blue")
    ax.plot(t, crowd, label="crowd score", color="tab:orange", alpha=0.7)
    ax.set_ylim(0, 1)
    ax.set_xlabel("time")
    ax.set_ylabel("YAMNet score")
    ax.xaxis.set_major_formatter(plt.FuncFormatter(lambda x, _: fmt_ts(x)))
    ax2 = ax.twinx()
    ax2.plot(t, rms_db, label="RMS dB", color="tab:gray", alpha=0.4)
    ax2.set_ylabel("RMS (dB)")
    if region:
        ax.axvspan(region[0], region[1], color="red", alpha=0.15)
        ax.axvline(result.music_boundary_s, color="red", linestyle="--", alpha=0.7)
    if fade:
        ax.axvline(fade[0], color="tab:green", linestyle=":", alpha=0.9, label="fade start")
        ax.axvline(fade[1], color="tab:blue", linestyle=":", alpha=0.9, label="fade end")
    for k, seg in enumerate(result.banter):
        xs = np.arange(seg["start"], seg["end"] + 0.25, 0.5)
        ax.plot(xs, np.full(len(xs), 0.02), "o", color="tab:green", markersize=3,
                label="whisper speech" if k == 0 else None)
    handles, labels = ax.get_legend_handles_labels()
    h2, l2 = ax2.get_legend_handles_labels()
    ax.legend(handles + h2, labels + l2, loc="upper left", fontsize=7, ncol=2, framealpha=0.5)
    ax.set_title(f"{display_label(result.label)} [{result.edge}] run={fmt_ts(result.nonmusic_run_s)}")
    plot_dir.mkdir(parents=True, exist_ok=True)
    safe = re.sub(r"[^\w.-]+", "_", f"{result.label}_{result.edge}")
    fig.tight_layout()
    fig.savefig(plot_dir / f"{safe}.png", dpi=90)
    plt.close(fig)


def fetch_show_jobs(date, args):
    """Return (label, url, edges, songs) for set-boundary tracks of a show."""
    resp = requests.get(f"{API_BASE}/shows/{date}", timeout=30)
    resp.raise_for_status()
    tracks = sorted(resp.json()["tracks"], key=lambda t: t["position"])
    by_set = {}
    for t in tracks:
        by_set.setdefault(t["set_name"], []).append(t)

    jobs = []
    for set_name, set_tracks in by_set.items():
        if set_name == "Soundcheck":
            continue
        for t in set_tracks:
            allowed = {"leading", "trailing"} if args.edges == "both" else {args.edges}
            edges = []
            if "leading" in allowed and (args.all_edges or t is set_tracks[0]):
                edges.append("leading")
            if "trailing" in allowed and (args.all_edges or t is set_tracks[-1]):
                edges.append("trailing")
            if not edges:
                continue
            label = f"{date} {set_name} t{t['position']:02d} {t['title']}"
            if not t.get("mp3_url"):
                print(f"  skipping {display_label(label)} (no mp3_url)", file=sys.stderr)
                continue
            songs = [s["title"] for s in t.get("songs", [])]
            share = f"{SITE_BASE}/{date}/{t['slug']}" if t.get("slug") else ""
            if share and share in args.ignore_urls:
                print(f"  skipping {display_label(label)} (in ignore list)", file=sys.stderr)
                continue
            jobs.append((label, t["mp3_url"], edges, songs, share))
    return jobs


def backfill_share_urls(results):
    """Fill in share_url on results from older reports by refetching show data."""
    slug_maps = {}
    for r in results:
        if r.share_url:
            continue
        m = re.match(r"(\d{4}-\d{2}-\d{2}) .+? t(\d+) ", r.label)
        if not m:
            continue
        date, position = m.group(1), int(m.group(2))
        if date not in slug_maps:
            resp = requests.get(f"{API_BASE}/shows/{date}", timeout=30)
            resp.raise_for_status()
            slug_maps[date] = {t["position"]: t.get("slug") for t in resp.json()["tracks"]}
        slug = slug_maps[date].get(position)
        if slug:
            r.share_url = f"{SITE_BASE}/{date}/{slug}"


def reconstruct_trim_info(results, args):
    """Rebuild the trim_info dict from report data using the same math as
    trim_track, without rendering. Clip paths are included only if the files
    from the original run still exist."""
    by_label = {}
    for r in results:
        by_label.setdefault(r.label, []).append(r)

    trim_info = {}
    for label, group in by_label.items():
        flagged = {r.edge: r for r in group if r.flagged}
        if not flagged:
            continue
        if track_slug(group[0].share_url) in A_CAPPELLA_SLUGS:
            continue
        duration_s = group[0].track_duration_s
        start, end = 0.0, duration_s
        if "leading" in flagged:
            start = max(0.0, effective_boundary(flagged["leading"], args.banter_gap) - args.keep_lead)
        if "trailing" in flagged:
            boundary = effective_boundary(flagged["trailing"], args.banter_gap)
            end = min(duration_s, boundary + args.fade_delay + args.fade_out)
        cut_s = duration_s - (end - start)
        if cut_s < MIN_CUT_S:
            trim_info[label] = {"cut_s": round(cut_s, 1), "skipped": True}
            continue
        info = {"start": start, "end": end, "cut_s": round(cut_s, 1)}
        safe = re.sub(r"[^\w.-]+", "_", label)
        for key, path in [("trimmed", args.trim_dir / f"{safe}_trimmed.mp3"),
                          ("audition", args.trim_dir / "clips" / f"{safe}_audition.mp3")]:
            if path.exists():
                info[key] = path
        trim_info[label] = info
    return trim_info


def rebuild_dir(dir_path, args):
    """Regenerate review.html (and re-save report.json) from an existing
    report, backfilling share urls. No audio is analyzed or rendered."""
    report_path = dir_path / "report.json"
    if not report_path.exists():
        print(f"  no report.json in {dir_path}, skipping", file=sys.stderr)
        return
    results = []
    for entry in json.loads(report_path.read_text()):
        entry.pop("flagged", None)  # older reports carried it; recompute either way
        result = EdgeResult(**entry)
        result.flagged = result.nonmusic_run_s >= args.min_duration
        results.append(result)
    args.trim_dir = dir_path / "trimmed"
    args.plot_dir = dir_path / "plots"

    # Soundcheck sets and ignore-listed tracks are excluded from new scans;
    # scrub them from old reports along with any files rendered for them.
    drop = {r.label for r in results if re.search(r" Soundcheck t\d", r.label)}
    ignored = {r.label for r in results if r.share_url.rstrip("/") in args.ignore_urls}
    if ignored:
        print(f"  dropping {len(ignored)} ignore-listed track(s)", file=sys.stderr)
        drop |= ignored
    # A cappella tracks stay in the report (they get a manual-review section)
    # but are never auto-trimmed; clear any trim files rendered before that
    # policy.
    acappella = {r.label for r in results if track_slug(r.share_url) in A_CAPPELLA_SLUGS}
    if acappella:
        print(f"  clearing rendered trims for {len(acappella)} a cappella track(s)", file=sys.stderr)
        for label in acappella:
            safe = re.sub(r"[^\w.-]+", "_", label)
            for p in [args.trim_dir / f"{safe}_trimmed.mp3",
                      args.trim_dir / "clips" / f"{safe}_audition.mp3"]:
                p.unlink(missing_ok=True)
    if drop:
        results = [r for r in results if r.label not in drop]
        for label in drop:
            safe = re.sub(r"[^\w.-]+", "_", label)
            for p in [args.trim_dir / f"{safe}_trimmed.mp3",
                      args.trim_dir / "clips" / f"{safe}_audition.mp3",
                      args.plot_dir / f"{safe}_leading.png",
                      args.plot_dir / f"{safe}_trailing.png"]:
                p.unlink(missing_ok=True)

    backfill_share_urls(results)
    trim_info = reconstruct_trim_info(results, args)
    report_path.write_text(report_json(results))
    write_review_html(dir_path / "review.html", results, trim_info, args)


def fetch_year_dates(year):
    resp = requests.get(f"{API_BASE}/shows", params={"year": year, "per_page": 500}, timeout=30)
    resp.raise_for_status()
    shows = resp.json()["shows"]
    dates = sorted(s["date"] for s in shows if s["audio_status"] != "missing")
    print(f"{year}: {len(dates)} shows with audio", file=sys.stderr)
    return dates


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("inputs", nargs="*", help="Local mp3 paths or URLs")
    p.add_argument("--show", action="append", default=[], metavar="YYYY-MM-DD",
                   help="Analyze set-boundary tracks of a phish.in show (repeatable)")
    p.add_argument("--year", action="append", default=[], type=int,
                   help="Analyze every show with audio in this year (repeatable)")
    p.add_argument("--all-edges", action="store_true",
                   help="With --show, analyze both edges of every track instead of set boundaries only")
    p.add_argument("--edges", choices=["leading", "trailing", "both"], default="both",
                   help="Restrict which edges are analyzed, for all input modes. "
                        "'trailing' with --show means set closers / encore enders only (default: both)")
    p.add_argument("--window", type=float, default=300, help="Seconds to analyze at each edge (default: 300)")
    p.add_argument("--ignore-file", type=Path, default=IGNORE_FILE,
                   help="File of track share URLs to leave alone, one per line "
                        f"(default: {IGNORE_FILE})")
    p.add_argument("--ring-threshold", type=float, default=0.1,
                   help="Frames in the nonmusic run scoring above this are treated as "
                        "ring-out; the cut boundary moves past the last of them (default: 0.1)")
    p.add_argument("--music-threshold", type=float, default=0.2,
                   help="Music score below this = non-music frame (default: 0.2)")
    p.add_argument("--min-duration", type=float, default=20,
                   help="Flag edges with non-music runs at least this long (default: 20s)")
    p.add_argument("--storage-dir", type=Path, action="append", default=[],
                   help="Extra Active Storage root dir to check for local blobs")
    p.add_argument("--stream", action="store_true",
                   help="Let ffmpeg read remote URLs directly (range requests) instead of downloading")
    p.add_argument("--json", type=Path, help="Write full report to this JSON file")
    p.add_argument("--plot-dir", type=Path, help="Write a score/RMS plot per analyzed edge")
    p.add_argument("--html", type=Path,
                   help="Write a static review page (audition clips, plots, approve checkboxes)")
    p.add_argument("--trim-dir", type=Path,
                   help="Render a trimmed mp3 (originals untouched) for each track with a flagged edge")
    p.add_argument("--keep-lead", type=float, default=3,
                   help="Seconds of crowd noise to keep before music starts when trimming (default: 3)")
    p.add_argument("--fade-in", type=float, default=1.0,
                   help="Fade-in seconds on a trimmed leading edge (default: 1.0)")
    p.add_argument("--fade-delay", type=float, default=2.0,
                   help="Seconds of untouched crowd noise after the music/banter boundary "
                        "before the fade-out starts (default: 2.0)")
    p.add_argument("--fade-out", type=float, default=6.0,
                   help="Fade-out seconds on a trimmed trailing edge (default: 6.0)")
    p.add_argument("--no-transcribe", action="store_true",
                   help="Skip Whisper banter detection on flagged regions")
    p.add_argument("--banter-gap", type=float, default=25,
                   help="Chain banter segments within this many seconds of the music boundary "
                        "when extending the trim point (default: 25)")
    p.add_argument("--rebuild", type=Path, action="append", default=[], metavar="DIR",
                   help="Regenerate review.html from DIR/report.json (backfills share urls; "
                        "no audio analyzed). Repeatable.")
    args = p.parse_args()
    args.ignore_urls = load_ignore_urls(args.ignore_file)
    if args.ignore_urls:
        print(f"Ignore list: {len(args.ignore_urls)} track(s) from {args.ignore_file}", file=sys.stderr)

    if args.rebuild:
        for dir_path in args.rebuild:
            print(f"Rebuilding {dir_path}...", file=sys.stderr)
            rebuild_dir(dir_path, args)
        return

    if not args.inputs and not args.show and not args.year:
        p.error("provide mp3 paths/URLs, --show YYYY-MM-DD, or --year YYYY")

    for year in args.year:
        args.show.extend(fetch_year_dates(year))

    storage_dirs = args.storage_dir + STORAGE_CANDIDATES
    jobs = []
    failures = []
    for date in args.show:
        try:
            jobs.extend(fetch_show_jobs(date, args))
        except Exception as e:
            print(f"  ERROR fetching {date}: {e}", file=sys.stderr)
            failures.append(f"{date}: {e}")
    for inp in args.inputs:
        edges = ["leading", "trailing"] if args.edges == "both" else [args.edges]
        jobs.append((Path(inp).name, inp, edges, [], ""))

    if not jobs:
        print("No tracks to analyze; no report written.", file=sys.stderr)
        sys.exit(1 if failures else 0)

    # Start fresh: clear rendered trims/clips/plots from any previous run so
    # stale files don't linger (and inflate index counts) for tracks that are
    # no longer flagged.
    for d in (args.trim_dir, args.plot_dir):
        if d and d.exists():
            shutil.rmtree(d)

    yamnet = Yamnet()
    banter_finder = None if args.no_transcribe else LazyBanterFinder()
    results = []
    trim_info = {}
    for i, (label, src, edges, songs, share) in enumerate(jobs, 1):
        try:
            if re.match(r"https?://", src):
                path = local_blob_path(src, storage_dirs) or (src if args.stream else download_audio(src))
            else:
                path = Path(src)
            duration = probe_duration(path)
            track_results = []
            for edge in edges:
                print(f"[{i}/{len(jobs)}] {display_label(label)}...", file=sys.stderr)
                track_results.append(analyze_edge(yamnet, banter_finder, path, duration, edge, args,
                                                  label, songs, src if re.match(r"https?://", src) else "",
                                                  share))
            results.extend(track_results)
            if args.trim_dir:
                info = trim_track(path, duration, track_results, args, label)
                if info:
                    trim_info[label] = info
        except Exception as e:
            print(f"  ERROR on {display_label(label)}: {e}", file=sys.stderr)
            failures.append(f"{display_label(label)}: {e}")
        write_outputs(results, trim_info, args)

    results.sort(key=lambda r: r.nonmusic_run_s, reverse=True)
    print(f"\n{'RUN(s)':>7} {'EDGE':8} {'CHARACTER':28} {'BOUNDARY':>8}  TRACK")
    for r in results:
        segue = " [multi-song]" if len(r.songs) > 1 else ""
        char = ", ".join(f"{k}:{v:.0%}" for k, v in r.character.items() if v > 0) or "-"
        print(f"{r.nonmusic_run_s:7.1f} {r.edge:8} {char:28} {r.music_boundary_s:8.1f}  {display_label(r.label)}{segue}")
        for seg in r.banter:
            print(f"{'':7} {'':8}   banter {seg['start']:.1f}-{seg['end']:.1f}s: \"{seg['text']}\"")

    write_outputs(results, trim_info, args)
    if args.json:
        print(f"\nReport written to {args.json}", file=sys.stderr)
    if args.html:
        print(f"Review page written to {args.html}", file=sys.stderr)

    if failures:
        print(f"\n{len(failures)} failure(s) — rerun these after investigating:", file=sys.stderr)
        for f in failures:
            print(f"  {f}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
