#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11,<3.13"
# dependencies = [
#   "numpy",
#   "requests",
# ]
# ///
"""Verify track ordering within a show by audio junction continuity.

Tracks on phish.in are cut from one continuous source recording, so at a
correct junction the audio flows across the cut with no seam: crowd noise,
room tone, and loudness all continue. This script scores every within-set
junction of a show for continuity, flags suspicious ones, and searches for
the best placement of "floater" tracks (banter etc. whose position is
unknown). Set/encore boundaries are expected discontinuities and are skipped.

Continuity signals per junction (tail of A joined to head of B):
  - spectral ratio: mel-spectrum distance across the joint, normalized by the
    natural block-to-block variation within each side (1.0 = joint looks like
    any other moment; >>1 = seam)
  - rms step: loudness jump across the joint in dB
  - seam z-score: spectral flux spike at the joint relative to surrounding
    frames of the spliced audio

Output: proposed.json (machine-readable order + evidence), review.html with
listenable splice clips for suspect junctions and floater candidates.

Usage:
  uv run scripts/audio_junction_analysis.py --show 1991-03-17
  uv run scripts/audio_junction_analysis.py --show 1991-03-17 --floaters banter,banter-2
  uv run scripts/audio_junction_analysis.py --show 1990-12-08 --floaters 15286  # ground-truth check
"""

import argparse
import hashlib
import html
import itertools
import json
import re
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import requests

API_BASE = "https://phish.in/api/v2"
SITE_BASE = "https://phish.in"
REPO_ROOT = Path(__file__).resolve().parent.parent
STORAGE_CANDIDATES = [
    REPO_ROOT / "tmp" / "attachments",
    Path("/content/active_storage"),
]
CACHE_DIR = REPO_ROOT / "tmp" / "audio_cache"

SAMPLE_RATE = 16000
EDGE_WINDOW_S = 8.0  # audio decoded from each end of each track
BLOCK_S = 1.0  # feature block size for spectral comparison
RMS_WIN_S = 0.4  # window on each side of the joint for the RMS step
SEAM_S = 1.5  # audio on each side of the joint for the flux seam check
CLIP_S = 4.0  # audio on each side of the joint in rendered review clips

# Combined score weights and classification thresholds. Calibrated against
# shows with known-correct order (see --show 1990-12-08 in the repo history).
W_SPECTRAL = 0.5
W_RMS = 0.25
W_SEAM = 0.25
RMS_NORM_DB = 6.0
SEAM_NORM_Z = 5.0
SUSPECT_AT = 1.6
BROKEN_AT = 2.6
MARGIN = 0.35  # required gap between best and runner-up floater slot


def run(cmd, **kw):
    return subprocess.run(cmd, check=True, capture_output=True, **kw)


def decode_segment(path, start_s, dur_s):
    """Decode a segment to 16kHz mono float32 via ffmpeg."""
    out = run([
        "ffmpeg", "-v", "error", "-ss", f"{max(start_s, 0):.3f}", "-t", f"{dur_s:.3f}",
        "-i", str(path), "-ac", "1", "-ar", str(SAMPLE_RATE), "-f", "f32le", "-",
    ])
    return np.frombuffer(out.stdout, dtype=np.float32)


def local_blob_path(url, storage_dirs):
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


def probe_duration(path):
    out = run([
        "ffprobe", "-v", "error", "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1:nokey=1", str(path),
    ])
    return float(out.stdout.decode().strip())


# ---------------------------------------------------------------------------
# Features


def mel_filterbank(n_mels=40, n_fft=1024, sr=SAMPLE_RATE, fmin=50.0, fmax=7600.0):
    def hz_to_mel(f):
        return 2595.0 * np.log10(1.0 + f / 700.0)

    def mel_to_hz(m):
        return 700.0 * (10.0 ** (m / 2595.0) - 1.0)

    mel_pts = np.linspace(hz_to_mel(fmin), hz_to_mel(fmax), n_mels + 2)
    hz_pts = mel_to_hz(mel_pts)
    bins = np.floor((n_fft + 1) * hz_pts / sr).astype(int)
    fb = np.zeros((n_mels, n_fft // 2 + 1))
    for i in range(n_mels):
        lo, mid, hi = bins[i], bins[i + 1], bins[i + 2]
        if mid > lo:
            fb[i, lo:mid] = (np.arange(lo, mid) - lo) / (mid - lo)
        if hi > mid:
            fb[i, mid:hi] = (hi - np.arange(mid, hi)) / (hi - mid)
    return fb


MEL_FB = mel_filterbank()
N_FFT = 1024
HOP = 256


def log_mel_frames(wave):
    """Log-mel spectrogram frames, shape (n_frames, n_mels)."""
    if len(wave) < N_FFT:
        return np.zeros((0, MEL_FB.shape[0]))
    n = 1 + (len(wave) - N_FFT) // HOP
    idx = np.arange(N_FFT)[None, :] + HOP * np.arange(n)[:, None]
    frames = wave[idx] * np.hanning(N_FFT)[None, :]
    spec = np.abs(np.fft.rfft(frames, axis=1)) ** 2
    mel = spec @ MEL_FB.T
    return np.log10(mel + 1e-10)


def block_features(wave, block_s=BLOCK_S):
    """Mean log-mel per consecutive block, shape (n_blocks, n_mels)."""
    step = int(block_s * SAMPLE_RATE)
    blocks = []
    for i in range(0, len(wave) - step + 1, step):
        frames = log_mel_frames(wave[i:i + step])
        if len(frames):
            blocks.append(frames.mean(axis=0))
    return np.array(blocks)


def rms_db(wave):
    if len(wave) == 0:
        return -120.0
    return float(20 * np.log10(np.sqrt(np.mean(wave ** 2)) + 1e-10))


def spectral_flux(wave):
    frames = log_mel_frames(wave)
    if len(frames) < 2:
        return np.zeros(0)
    return np.sqrt(((np.diff(frames, axis=0)) ** 2).sum(axis=1))


# ---------------------------------------------------------------------------
# Junction scoring


@dataclass
class Junction:
    score: float
    spectral_ratio: float
    rms_step_db: float
    seam_z: float

    def parts(self):
        return (f"spectral {self.spectral_ratio:.2f}x, "
                f"rms step {self.rms_step_db:+.1f}dB, seam z {self.seam_z:.1f}")


def internal_variation(feats):
    """Median distance between consecutive feature blocks within one edge."""
    if len(feats) < 2:
        return None
    d = np.sqrt(((np.diff(feats, axis=0)) ** 2).sum(axis=1))
    return float(np.median(d))


def score_junction(tail, head):
    """Continuity of tail-of-A spliced to head-of-B. Lower = more continuous."""
    tail_feats = block_features(tail)
    head_feats = block_features(head)
    if len(tail_feats) == 0 or len(head_feats) == 0:
        return Junction(float(BROKEN_AT), 0.0, 0.0, 0.0)

    joint = float(np.sqrt(((tail_feats[-1] - head_feats[0]) ** 2).sum()))
    baselines = [v for v in (internal_variation(tail_feats), internal_variation(head_feats))
                 if v is not None]
    baseline = float(np.median(baselines)) if baselines else 1.0
    spectral_ratio = joint / max(baseline, 1e-3)

    n_rms = int(RMS_WIN_S * SAMPLE_RATE)
    rms_step = abs(rms_db(tail[-n_rms:]) - rms_db(head[:n_rms]))

    n_seam = int(SEAM_S * SAMPLE_RATE)
    spliced = np.concatenate([tail[-n_seam:], head[:n_seam]])
    flux = spectral_flux(spliced)
    if len(flux) > 8:
        center = len(flux) // 2
        window = flux[center - 2:center + 3]
        med = np.median(flux)
        mad = np.median(np.abs(flux - med)) + 1e-6
        seam_z = float((window.max() - med) / (1.4826 * mad))
    else:
        seam_z = 0.0

    score = (W_SPECTRAL * spectral_ratio
             + W_RMS * rms_step / RMS_NORM_DB
             + W_SEAM * max(seam_z, 0.0) / SEAM_NORM_Z)
    return Junction(score, spectral_ratio, rms_step, seam_z)


def classify(score):
    if score is None:
        return "NO_AUDIO"
    if score < SUSPECT_AT:
        return "CONTINUOUS"
    if score < BROKEN_AT:
        return "SUSPECT"
    return "BROKEN"


# ---------------------------------------------------------------------------
# Show model


@dataclass(eq=False)
class Track:
    id: int
    position: int
    set_name: str
    title: str
    slug: str
    mp3_url: str | None
    duration_ms: int
    path: Path | None = None
    head: np.ndarray | None = None
    tail: np.ndarray | None = None
    floater: bool = False

    @property
    def has_audio(self):
        return self.head is not None and self.tail is not None

    def label(self):
        return f"{self.title} ({self.duration_ms // 60000}:{self.duration_ms % 60000 // 1000:02d})"


def fetch_show(date):
    resp = requests.get(f"{API_BASE}/shows/{date}", timeout=30)
    resp.raise_for_status()
    data = resp.json()
    tracks = [
        Track(
            id=t["id"], position=t["position"], set_name=t["set_name"],
            title=t["title"], slug=t.get("slug") or "", mp3_url=t.get("mp3_url"),
            duration_ms=t.get("duration") or 0,
        )
        for t in sorted(data["tracks"], key=lambda t: t["position"])
    ]
    return tracks


def load_edges(track, storage_dirs):
    if not track.mp3_url:
        return
    path = local_blob_path(track.mp3_url, storage_dirs) or download_audio(track.mp3_url)
    duration = probe_duration(path)
    window = min(EDGE_WINDOW_S, duration)
    track.path = path
    track.head = decode_segment(path, 0, window)
    track.tail = decode_segment(path, max(duration - window, 0), window)


# ---------------------------------------------------------------------------
# Analysis passes


def in_set_sequences(tracks):
    """Consecutive runs of tracks sharing a set_name, in position order."""
    seqs = []
    for t in tracks:
        if seqs and seqs[-1][0].set_name == t.set_name:
            seqs[-1].append(t)
        else:
            seqs.append([t])
    return seqs


def verify_pass(sequences):
    junctions = []
    for seq in sequences:
        for a, b in zip(seq, seq[1:]):
            j = score_junction(a.tail, b.head) if a.has_audio and b.has_audio else None
            junctions.append({"a": a, "b": b, "junction": j,
                              "verdict": classify(j.score if j else None)})
    return junctions


def placement_slots(tracks, floater):
    """Insertion slots for floater among the non-floater tracks of its set
    (grouped by set_name, not current adjacency, since a misplaced track may
    sit far from its set). (prev, next) of None marks the set edge."""
    anchors = [t for t in tracks if t.set_name == floater.set_name and not t.floater]
    slots = []
    for i in range(len(anchors) + 1):
        prev = anchors[i - 1] if i > 0 else None
        nxt = anchors[i] if i < len(anchors) else None
        slots.append((i, prev, nxt))
    return slots


def score_slot(prev, floater, nxt):
    """Two-sided continuity of floater inserted between prev and next.
    Set-edge sides (None) are unscored; require at least one scored side."""
    sides = []
    if prev is not None and prev.has_audio:
        sides.append(score_junction(prev.tail, floater.head))
    if nxt is not None and nxt.has_audio:
        sides.append(score_junction(floater.tail, nxt.head))
    if not sides:
        return None, []
    return float(np.mean([s.score for s in sides])), sides


def placement_pass(tracks, floaters):
    placements = []
    for floater in floaters:
        ranked = []
        for i, prev, nxt in placement_slots(tracks, floater):
            combined, sides = score_slot(prev, floater, nxt)
            if combined is None:
                continue
            ranked.append({"slot": i, "prev": prev, "next": nxt,
                           "score": combined, "sides": sides})
        ranked.sort(key=lambda r: r["score"])
        placements.append({"floater": floater, "ranked": ranked})
    return placements


def junction_cached(cache, a, b):
    key = (a.id, b.id)
    if key not in cache:
        cache[key] = score_junction(a.tail, b.head)
    return cache[key]


def arrangement_cost(groups, cache):
    """Mean junction score of an arrangement. Floaters sharing a slot form an
    ordered chain, scored with their inter-floater junctions (best ordering)."""
    total, njunc, layout = 0.0, 0, {}
    for (prev, nxt), members in groups.items():
        if len(members) == 1:
            f, r = members[0]
            total += sum(s.score for s in r["sides"])
            njunc += len(r["sides"])
            layout[f] = (prev, nxt, [f])
        else:
            floats = [f for f, _ in members]
            best = None
            for perm in itertools.permutations(floats):
                s, n = 0.0, 0
                if prev is not None and prev.has_audio:
                    s += junction_cached(cache, prev, perm[0]).score
                    n += 1
                for x, y in zip(perm, perm[1:]):
                    s += junction_cached(cache, x, y).score
                    n += 1
                if nxt is not None and nxt.has_audio:
                    s += junction_cached(cache, perm[-1], nxt).score
                    n += 1
                if n and (best is None or s / n < best[0] / best[1]):
                    best = (s, n, perm)
            if best is None:
                return None
            total += best[0]
            njunc += best[1]
            for f in best[2]:
                layout[f] = (prev, nxt, list(best[2]))
    if njunc == 0:
        return None
    return total / njunc, njunc, layout


def resolve_placements(placements, cache, pins=None):
    """Jointly assign floaters to slots so no two claim the same junction
    independently. Enumerates combinations of each floater's top candidate
    slots; floaters choosing the same slot are scored as an ordered chain.
    A pinned floater (pins = {floater: 1-based candidate rank}) is locked to
    that candidate and never marked ambiguous - the human has decided.
    Returns {floater: {prev, next, chain, margin, ambiguous, pinned}}."""
    pins = pins or {}
    live = [p for p in placements if p["ranked"]]
    if not live:
        return {}

    def options(p):
        rank = pins.get(p["floater"])
        if rank is None:
            return p["ranked"][:5]
        if rank > len(p["ranked"]):
            sys.exit(f"pin rank {rank} out of range for {p['floater'].title} "
                     f"({len(p['ranked'])} candidates)")
        return [p["ranked"][rank - 1]]

    scored = []
    for choice in itertools.product(*(options(p) for p in live)):
        groups = {}
        for p, r in zip(live, choice):
            groups.setdefault((r["prev"], r["next"]), []).append((p["floater"], r))
        res = arrangement_cost(groups, cache)
        if res is not None:
            scored.append(res)
    if not scored:
        return {}
    scored.sort(key=lambda x: x[0])
    best_mean, best_njunc, best_layout = scored[0]

    final = {}
    for p in live:
        f = p["floater"]
        placement_of = lambda layout: (layout[f][0], layout[f][1], layout[f][2].index(f))
        alt = next((mean for mean, _, layout in scored[1:]
                    if placement_of(layout) != placement_of(best_layout)), None)
        # Scale the arrangement-mean difference back to a per-floater score
        # difference (a floater owns ~2 junctions) so MARGIN stays comparable
        # to the single-floater case.
        margin = float("inf") if alt is None else (alt - best_mean) * best_njunc / 2
        prev, nxt, chain = best_layout[f]
        pinned = f in pins
        final[f] = {"prev": prev, "next": nxt, "chain": chain, "margin": margin,
                    "ambiguous": not pinned and margin < MARGIN, "pinned": pinned}
    return final


def proposed_order(tracks, final, include_ambiguous=False):
    """Full track-ID order with floaters moved to their resolved slot
    (ambiguous ones only when include_ambiguous). Anchors are non-floater
    tracks, so this works even when a floater currently sits far from the
    rest of its set. Chained floaters are inserted together in chain order."""
    moves = {f: d for f, d in final.items() if include_ambiguous or not d["ambiguous"]}
    placed = [t for t in tracks if t not in moves]
    done = set()
    for f, d in moves.items():
        if f in done:
            continue
        chain = [x for x in d["chain"] if x in moves]
        if d["prev"] is not None:
            idx = placed.index(d["prev"]) + 1
        elif d["next"] is not None:
            idx = placed.index(d["next"])
        else:
            idx = len(placed)
        for offset, x in enumerate(chain):
            placed.insert(idx + offset, x)
            done.add(x)
    return [t.id for t in placed]


# ---------------------------------------------------------------------------
# Output


def render_clip(a, b, out_path):
    """Encode tail-of-A + head-of-B as one listenable mp3."""
    n = int(CLIP_S * SAMPLE_RATE)
    tail = a.tail[-n:] if a is not None and a.has_audio else np.zeros(0, dtype=np.float32)
    head = b.head[:n] if b is not None and b.has_audio else np.zeros(0, dtype=np.float32)
    spliced = np.concatenate([tail, head]).astype(np.float32)
    with tempfile.NamedTemporaryFile(suffix=".f32") as tmp:
        tmp.write(spliced.tobytes())
        tmp.flush()
        run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SAMPLE_RATE),
             "-ac", "1", "-i", tmp.name, "-b:a", "128k", str(out_path)])


def esc(s):
    return html.escape(str(s))


def write_review(out_dir, date, junctions, placements, clip_specs):
    rows = []
    for jr in junctions:
        j = jr["junction"]
        detail = j.parts() if j else "no audio on one side"
        score = f"{j.score:.2f}" if j else "-"
        clip = clip_specs.get(("junction", jr["a"].id, jr["b"].id))
        audio = f'<audio controls preload="none" src="{clip}"></audio>' if clip else ""
        rows.append(
            f'<tr class="{jr["verdict"].lower()}"><td>{esc(jr["a"].label())}</td>'
            f'<td>{esc(jr["b"].label())}</td><td>{score}</td>'
            f'<td>{jr["verdict"]}</td><td>{esc(detail)}</td><td>{audio}</td></tr>'
        )

    floater_html = []
    for p in placements:
        f = p["floater"]
        d = p.get("final")
        status = ("PINNED" if d and d.get("pinned")
                  else "AMBIGUOUS" if p["ambiguous"] else "PLACED")
        if d:
            decision = (f"after {esc(d['prev'].label()) if d['prev'] else '(start of set)'}, "
                        f"before {esc(d['next'].label()) if d['next'] else '(end of set)'}")
            if len(d["chain"]) > 1:
                decision += " — chained: " + " &gt; ".join(esc(t.label()) for t in d["chain"])
            status += f": {decision}"
        items = []
        for rank, r in p["shown"]:
            prev_label = esc(r["prev"].label()) if r["prev"] else "(start of set)"
            next_label = esc(r["next"].label()) if r["next"] else "(end of set)"
            parts = "; ".join(s.parts() for s in r["sides"])
            clips = []
            if r["prev"] is not None:
                c = clip_specs.get(("splice", r["prev"].id, f.id))
                if c:
                    clips.append(f'<audio controls preload="none" src="{c}"></audio>')
            if r["next"] is not None:
                c = clip_specs.get(("splice", f.id, r["next"].id))
                if c:
                    clips.append(f'<audio controls preload="none" src="{c}"></audio>')
            payload = esc(json.dumps({
                "id": f.id, "title": f.title, "rank": rank,
                "after_id": r["prev"].id if r["prev"] else None,
                "before_id": r["next"].id if r["next"] else None,
            }))
            checked = " checked" if d and r["prev"] is d["prev"] and r["next"] is d["next"] else ""
            items.append(
                f'<li><label><input type="radio" name="floater-{f.id}" '
                f'data-payload="{payload}"{checked}> <b>#{rank}</b> score {r["score"]:.2f} — '
                f"after {prev_label}, before {next_label}</label>"
                f"<br><small>{esc(parts)}</small><br>{''.join(clips)}</li>"
            )
        items.append(
            f'<li><label><input type="radio" name="floater-{f.id}"> '
            "leave unplaced (decide later)</label></li>"
        )
        floater_html.append(
            f"<h3>{esc(f.label())} — {status} (margin {p['margin']:.2f})</h3>"
            f"<ol>{''.join(items)}</ol>"
        )

    out = out_dir / "review.html"
    out.write_text(f"""<!doctype html>
<meta charset="utf-8">
<title>Audio order review {esc(date)}</title>
<style>
  body {{ font: 14px/1.5 -apple-system, sans-serif; margin: 2rem auto; max-width: 1100px; }}
  table {{ border-collapse: collapse; width: 100%; }}
  td, th {{ border: 1px solid #ccc; padding: 4px 8px; text-align: left; }}
  tr.suspect {{ background: #fff3cd; }}
  tr.broken {{ background: #f8d7da; }}
  tr.no_audio {{ color: #999; }}
  audio {{ height: 28px; }}
  input[type="radio"] {{ width: 1.1rem; height: 1.1rem; }}
  #export {{ position: fixed; top: 1rem; right: 1rem; padding: .5rem 1rem; }}
</style>
<button id="export">Export selections.json</button>
<h1>{esc(date)} junction review</h1>
<h2>Junctions (current order, within sets)</h2>
<table>
<tr><th>Track A</th><th>Track B</th><th>Score</th><th>Verdict</th><th>Detail</th><th>Splice</th></tr>
{''.join(rows)}
</table>
<h2>Floater placements</h2>
<p>Pick one slot per floater (the analysis pick is pre-selected), then Export
and save the file as <code>selections.json</code> next to this page. Apply
with: <code>APPLY=true bin/rails "tracks:audio_order[{esc(date)}]"</code></p>
{''.join(floater_html) or '<p>None requested or flagged.</p>'}
<script>
document.getElementById("export").onclick = () => {{
  const selections = [...document.querySelectorAll("input[type=radio]:checked")]
    .filter(rb => rb.dataset.payload)
    .map(rb => JSON.parse(rb.dataset.payload));
  const blob = new Blob([JSON.stringify(selections, null, 2)], {{type: "application/json"}});
  const a = Object.assign(document.createElement("a"),
    {{href: URL.createObjectURL(blob), download: "selections.json"}});
  a.click();
}};
</script>
""")
    return out


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--show", required=True, metavar="YYYY-MM-DD")
    p.add_argument("--floaters", default="",
                   help="Comma-separated track slugs or numeric IDs to (re)place")
    p.add_argument("--pins", default="",
                   help="Lock floaters to a reviewed candidate: id-or-slug:rank,... "
                        "(rank as shown in review.html, e.g. 33244:2)")
    p.add_argument("--out-dir", type=Path, default=None,
                   help="Output dir (default: data/audio_order/<date>)")
    p.add_argument("--storage-dir", type=Path, action="append", default=[])
    args = p.parse_args()

    out_dir = args.out_dir or REPO_ROOT / "data" / "audio_order" / args.show
    out_dir.mkdir(parents=True, exist_ok=True)
    storage_dirs = args.storage_dir + STORAGE_CANDIDATES

    tracks = fetch_show(args.show)
    print(f"{args.show}: {len(tracks)} tracks", file=sys.stderr)
    for t in tracks:
        load_edges(t, storage_dirs)
        if not t.has_audio:
            print(f"  no audio, pinning in place: {t.title}", file=sys.stderr)

    wanted = {w.strip() for w in args.floaters.split(",") if w.strip()}
    floaters = [t for t in tracks if t.slug in wanted or str(t.id) in wanted]
    missing = wanted - {t.slug for t in floaters} - {str(t.id) for t in floaters}
    if missing:
        sys.exit(f"floaters not found in show: {', '.join(sorted(missing))}")
    no_audio = [t for t in floaters if not t.has_audio]
    if no_audio:
        sys.exit(f"floaters have no audio: {', '.join(t.title for t in no_audio)}")
    for t in floaters:
        t.floater = True

    sequences = in_set_sequences(tracks)
    junctions = verify_pass(sequences)

    # Auto-float: audio tracks broken on every scored junction (and not at a set edge)
    for jr in junctions:
        jr["a"].__dict__.setdefault("_verdicts", []).append(jr["verdict"])
        jr["b"].__dict__.setdefault("_verdicts", []).append(jr["verdict"])
    for t in tracks:
        verdicts = [v for v in getattr(t, "_verdicts", []) if v != "NO_AUDIO"]
        if (t.has_audio and not t.floater and len(verdicts) >= 2
                and all(v == "BROKEN" for v in verdicts)):
            print(f"  auto-floating (both junctions broken): {t.title}", file=sys.stderr)
            t.floater = True
            floaters.append(t)

    pins = {}
    for spec in (s.strip() for s in args.pins.split(",") if s.strip()):
        ident, _, rank = spec.partition(":")
        target = next((t for t in floaters if t.slug == ident or str(t.id) == ident), None)
        if target is None:
            sys.exit(f"pin target not in floaters: {ident}")
        if not rank.isdigit() or int(rank) < 1:
            sys.exit(f"bad pin rank in {spec!r} (want id-or-slug:rank)")
        pins[target] = int(rank)

    cache = {}
    placements = placement_pass(tracks, floaters)
    final = resolve_placements(placements, cache, pins)
    for p in placements:
        d = final.get(p["floater"])
        p["final"] = d
        p["margin"] = d["margin"] if d else float("inf")
        p["ambiguous"] = d["ambiguous"] if d else False
        # Candidates surfaced in the review page: top 3 plus the resolved slot
        # if joint resolution picked one further down the list.
        p["shown"] = list(enumerate(p["ranked"][:3], 1))
        if d:
            resolved = next(((i, r) for i, r in enumerate(p["ranked"], 1)
                             if r["prev"] is d["prev"] and r["next"] is d["next"]), None)
            if resolved and resolved not in p["shown"]:
                p["shown"].append(resolved)

    clip_dir = out_dir / "clips"
    clip_dir.mkdir(exist_ok=True)
    clip_specs = {}
    for jr in junctions:
        if jr["verdict"] in ("SUSPECT", "BROKEN"):
            name = f"junction_{jr['a'].id}_{jr['b'].id}.mp3"
            render_clip(jr["a"], jr["b"], clip_dir / name)
            clip_specs[("junction", jr["a"].id, jr["b"].id)] = f"clips/{name}"
    for pl in placements:
        f = pl["floater"]
        for _rank, r in pl["shown"]:
            for a, b in ((r["prev"], f), (f, r["next"])):
                if a is None or b is None or not (a.has_audio and b.has_audio):
                    continue
                key = ("splice", a.id, b.id)
                if key not in clip_specs:
                    name = f"splice_{a.id}_{b.id}.mp3"
                    render_clip(a, b, clip_dir / name)
                    clip_specs[key] = f"clips/{name}"
    for pl in placements:
        d = pl["final"]
        if not d or len(d["chain"]) < 2:
            continue
        seq = ([d["prev"]] if d["prev"] else []) + d["chain"] + ([d["next"]] if d["next"] else [])
        for a, b in zip(seq, seq[1:]):
            if not (a.has_audio and b.has_audio):
                continue
            key = ("splice", a.id, b.id)
            if key not in clip_specs:
                name = f"splice_{a.id}_{b.id}.mp3"
                render_clip(a, b, clip_dir / name)
                clip_specs[key] = f"clips/{name}"

    order = proposed_order(tracks, final)
    order_full = proposed_order(tracks, final, include_ambiguous=True)
    report = {
        "date": args.show,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "current_order": [t.id for t in tracks],
        "proposed_order": order,
        "proposed_order_full": order_full,
        "changed": order != [t.id for t in tracks],
        "ambiguous_floaters": [p["floater"].id for p in placements if p["ambiguous"]],
        "junctions": [
            {"a_id": jr["a"].id, "a": jr["a"].title, "b_id": jr["b"].id, "b": jr["b"].title,
             "verdict": jr["verdict"],
             **({"score": round(jr["junction"].score, 3),
                 "spectral_ratio": round(jr["junction"].spectral_ratio, 3),
                 "rms_step_db": round(jr["junction"].rms_step_db, 2),
                 "seam_z": round(jr["junction"].seam_z, 2)} if jr["junction"] else {})}
            for jr in junctions
        ],
        "placements": [
            {"id": p["floater"].id, "title": p["floater"].title,
             "ambiguous": p["ambiguous"],
             "pinned": bool(p["final"] and p["final"].get("pinned")),
             "margin": None if p["margin"] == float("inf") else round(p["margin"], 3),
             **({"placed_after_id": p["final"]["prev"].id if p["final"]["prev"] else None,
                 "placed_after": p["final"]["prev"].title if p["final"]["prev"] else None,
                 "placed_before_id": p["final"]["next"].id if p["final"]["next"] else None,
                 "placed_before": p["final"]["next"].title if p["final"]["next"] else None,
                 "chain": [t.id for t in p["final"]["chain"]]} if p["final"] else {}),
             "candidates": [
                 {"after_id": r["prev"].id if r["prev"] else None,
                  "after": r["prev"].title if r["prev"] else None,
                  "before_id": r["next"].id if r["next"] else None,
                  "before": r["next"].title if r["next"] else None,
                  "score": round(r["score"], 3)}
                 for r in p["ranked"][:5]
             ]}
            for p in placements
        ],
    }
    (out_dir / "proposed.json").write_text(json.dumps(report, indent=2))
    review = write_review(out_dir, args.show, junctions, placements, clip_specs)

    print(f"\nJunctions: " + ", ".join(
        f"{v}={sum(1 for j in junctions if j['verdict'] == v)}"
        for v in ("CONTINUOUS", "SUSPECT", "BROKEN", "NO_AUDIO")))
    for pl in placements:
        d = pl["final"]
        if d:
            where = (f"after {d['prev'].title if d['prev'] else '(start of set)'}, "
                     f"before {d['next'].title if d['next'] else '(end of set)'}")
            if len(d["chain"]) > 1:
                where += " (chained: " + " -> ".join(t.label() for t in d["chain"]) + ")"
        else:
            where = "no scorable slots"
        state = ("PINNED" if d and d.get("pinned")
                 else "AMBIGUOUS" if pl["ambiguous"] else "PLACED")
        print(f"Floater {pl['floater'].label()}: {state} {where} (margin {pl['margin']:.2f})")
    print(f"Proposed order {'CHANGED' if report['changed'] else 'unchanged'}")
    print(f"Report: {out_dir / 'proposed.json'}")
    print(f"Review: {review}")


if __name__ == "__main__":
    main()
