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
import base64
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
# Whisper hallucinates caption-style sound descriptions on crowd noise
# ("CHEERING", "[Music]"); a segment that is exactly one of these, once
# lowercased and stripped of punctuation, is not banter.
HALLUCINATED_CAPTIONS = {
    "music", "music playing", "instrumental", "singing", "whistling",
    "cheering", "cheers", "applause", "clapping", "laughter", "laughing",
    "shouting", "screaming", "crowd", "crowd noise", "crowd cheering",
    "crowd chatter", "audience", "audience cheering",
}
SILENCE_RMS_DB = -48.0
MIN_CUT_S = 5.0  # default for --min-cut: skip trims that would remove less than this
CLIP_LEAD_S = 5.0  # audio kept before the fade starts in review clips
LEAD_CLIP_MUSIC_S = 10.0  # music kept after the boundary in leading review clips
MUSIC_SUSTAIN_S = 4.0  # music must hold above threshold this long to end a non-music run
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
    waveform_url: str = ""  # full-track waveform png, for the in-page player


def run(cmd, **kw):
    return subprocess.run(cmd, check=True, capture_output=True, **kw)


def probe_duration(path):
    out = run([
        "ffprobe", "-v", "error", "-show_entries", "format=duration",
        "-of", "csv=p=0", str(path),
    ])
    return float(out.stdout.decode().strip())


def probe_bitrate(path, timeout=None):
    """Source bitrate, so a trim re-encodes at the quality it came in at.

    timeout bounds the call for callers reading over http, where a stalled
    connection would otherwise hang here indefinitely. Left unset for local
    files and the scan path, which have nothing to stall on."""
    out = run([
        "ffprobe", "-v", "error", "-show_entries", "format=bit_rate",
        "-of", "csv=p=0", str(path),
    ], timeout=timeout)
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


def fmt_tenths(seconds):
    """Seconds as m:ss.s, the editable form on the review page (e.g. 1:03.2)."""
    # Round before splitting: 59.99 must render 1:00.0, not 0:60.0 (which the
    # page's own parser would then reject).
    tenths = max(0, round(float(seconds) * 10))
    m, s = divmod(tenths, 600)
    return f"{m}:{s / 10:04.1f}"


def display_label(label):
    """Label for human-facing pages: drops the tNN position token and separates
    date, set and song with dashes (1999-07-21 - Set 1 - AC/DC Bag)."""
    m = re.match(r"^(\d{4}-\d{2}-\d{2}) (.*?) t\d+ (.*)$", label)
    if m:
        return f"{m.group(1)} - {m.group(2)} - {m.group(3)}"
    return re.sub(r"^(\d{4}-\d{2}-\d{2} .*?) t\d+ ", r"\1 ", label)


def effective_boundary(result, gap_s):
    """Music boundary pushed outward past adjacent on-mic banter.

    Banter segments are chained: each one within gap_s of the current boundary
    extends it, so a thank-you 20s after the last note is still kept. A segment
    is only chained if it fits within MAX_CHAIN_S of the raw boundary."""
    boundary = result.music_boundary_s
    # Leading edges ignore banter: what precedes a set opener is crowd noise and
    # tuning, not speech worth keeping, and pulling the cut earlier to preserve
    # it just leaves more junk in. Trailing edges still chain it, where a
    # thank-you after the last note is the whole point.
    if result.edge != "trailing":
        return boundary
    limit = boundary + MAX_CHAIN_S
    for seg in sorted(result.banter, key=lambda s: s["start"]):
        if seg["start"] <= boundary + gap_s and seg["end"] <= limit:
            boundary = max(boundary, seg["end"])
    return boundary


def trim_filters(start, end, fade_in, fade_out):
    """Build the ffmpeg -af chain for a trim. Single source of truth for the
    filter chain: the scan renderer, the preview server, and the Ruby
    AudioEdgeTrimService must all produce this exact string for the same inputs
    (see spec/services/audio_edge_trim_service_parity_spec.rb)."""
    filters = [f"atrim=start={start:.2f}:end={end:.2f}", "asetpts=PTS-STARTPTS"]
    if start > 0 and fade_in > 0:
        filters.append(f"afade=t=in:st=0:d={fade_in:.2f}")
    # NOTE: a leading edge whose boundary is under --keep-lead clamps to
    # start=0.0, where there is no splice to smooth. Ruby has always skipped
    # the fade there (trim_start.positive?); this now matches. See
    # spec/services/audio_edge_trim_service_parity_spec.rb.
    if fade_out > 0:
        fade = min(fade_out, end - start)
        filters.append(f"afade=t=out:st={end - start - fade:.2f}:d={fade:.2f}")
    return filters


def trim_command(src, out_path, start, end, fade_in, fade_out, bitrate=None,
                 seek_input=False, probe_timeout=None):
    """Full ffmpeg argv for rendering a trim. Shared by the scan and the
    preview server so a preview is byte-identical to what gets applied.

    seek_input adds an input-side -ss so ffmpeg jumps to the trim instead of
    decoding (and, over http, downloading) everything before it. A 20-minute
    track trimmed at 0:35 otherwise costs a minute of pointless decoding. The
    filter chain is rebased onto the seek so the output is the same audio; it
    is off by default because the apply path renders from a local file where
    the saving is small and exactness is pinned by the parity spec."""
    src = str(src)
    # Reading straight from http avoids downloading a whole track to trim a few
    # seconds; reconnect so a dropped connection retries instead of failing.
    reconnect = ([
        "-reconnect", "1", "-reconnect_streamed", "1",
        "-reconnect_delay_max", "5",
    ] if src.startswith(("http://", "https://")) else [])
    pre = []
    if seek_input and start > 0:
        # Seek slightly early and let atrim do the exact cut: -ss on a
        # compressed stream lands on a frame boundary, not a sample.
        seek = max(0.0, start - 1.0)
        pre = ["-ss", f"{seek:.2f}"]
        start, end = start - seek, end - seek
    return [
        "ffmpeg", "-y", "-v", "error", *reconnect, *pre, "-i", src,
        "-af", ",".join(trim_filters(start, end, fade_in, fade_out)),
        "-map_metadata", "0", "-id3v2_version", "3",
        "-b:a", bitrate or probe_bitrate(src, timeout=probe_timeout), str(out_path),
    ]


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
    if "leading" in flagged:
        start = max(0.0, effective_boundary(flagged["leading"], args.banter_gap) - args.keep_lead)
    if "trailing" in flagged:
        boundary = effective_boundary(flagged["trailing"], args.banter_gap)
        end = min(duration_s, boundary + args.fade_delay + args.fade_out)
    # Fades only apply on edges that were actually flagged for trimming.
    fade_in = args.fade_in if "leading" in flagged else 0.0
    fade_out = args.fade_out if "trailing" in flagged else 0.0
    filters = trim_filters(start, end, fade_in, fade_out)

    cut_s = duration_s - (end - start)
    if cut_s < args.min_cut:
        # Nothing meaningful to remove (e.g. banter runs to the end of the
        # track); re-encoding would only add a fade over kept content.
        print(f"  skipping {display_label(label)}: only {cut_s:.1f}s would be cut", file=sys.stderr)
        return {"cut_s": round(cut_s, 1), "skipped": True}

    args.trim_dir.mkdir(parents=True, exist_ok=True)
    safe_label = re.sub(r"[^\w.-]+", "_", label)
    out_path = args.trim_dir / f"{safe_label}_trimmed.mp3"
    run(trim_command(path, out_path, start, end, fade_in, fade_out))
    print(f"  trimmed {display_label(label)}: kept {start:.1f}s to {end:.1f}s "
          f"(cut {duration_s - (end - start):.1f}s of {duration_s:.1f}s) -> {out_path}",
          file=sys.stderr)

    info = {"trimmed": out_path, "start": start, "end": end,
            "cut_s": round(duration_s - (end - start), 1)}
    if "leading" in flagged:
        # Audition clip from the start of the trimmed file: fade-in, any kept
        # banter/crowd, then past the music boundary — with kept banter the
        # boundary can be well beyond the trim point, and hearing the music
        # arrive is what the review is for.
        clip_dir = args.trim_dir / "clips"
        clip_dir.mkdir(exist_ok=True)
        clip_len = (flagged["leading"].music_boundary_s - start) + LEAD_CLIP_MUSIC_S
        clip = clip_dir / f"{safe_label}_lead_audition.mp3"
        if render_clip(["ffmpeg", "-y", "-v", "error", "-i", str(out_path),
                        "-t", f"{clip_len:.2f}", "-c", "copy", str(clip)], label):
            info["audition_lead"] = clip
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


FONT_DIR = REPO_ROOT / "node_modules" / "@fontsource" / "open-sans-condensed" / "files"


def embedded_fonts():
    """@font-face rules with the font inlined as data URIs.

    phish.in's own body font, but the review page has to work over file:// with
    no network, so the bytes go in the html rather than a link. Silently yields
    nothing if node_modules is absent - the stack falls back to system sans."""
    faces = []
    for weight in (300, 700):
        path = FONT_DIR / f"open-sans-condensed-latin-{weight}-normal.woff2"
        if not path.exists():
            return ""
        b64 = base64.b64encode(path.read_bytes()).decode()
        # Literal CSS: this is interpolated into the f-string template, so the
        # braces must NOT be doubled the way they are inside the template.
        src = f"url(data:font/woff2;base64,{b64}) format(\"woff2\")"
        faces.append(
            '@font-face { font-family: "Open Sans Condensed"; font-style: normal; '
            f'font-weight: {weight}; font-display: swap; src: {src}; ' + "}")
    return "\n  ".join(faces)


def write_review_html(html_path, results, trim_info, args, quiet=False):
    """Static review page: audition clip, plot, transcript, and
    an approve checkbox per candidate. Export writes approved.json for the
    apply step. Open locally; audio/img paths are relative to this file."""
    def rel(p):
        return os.path.relpath(p, html_path.parent)

    def seconds_cut(r):
        """The page displays the cut, so order by it; rows without a rendered
        trim (a cappella, skipped) fall back to the non-music run length."""
        cut = trim_info.get(r.label, {}).get("cut_s")
        return cut if cut is not None else r.nonmusic_run_s

    rows = []
    skipped = []
    acappella = []
    for r in sorted(results, key=seconds_cut, reverse=True):
        if not r.flagged:
            continue
        info = trim_info.get(r.label, {})
        esc = html_escape.escape
        shown = display_label(r.label)
        link = (f'<a href="{esc(r.share_url, quote=True)}" target="_blank">{esc(shown)}</a>'
                if r.share_url else esc(shown))
        cut_at = info.get("end") if r.edge == "trailing" else info.get("start")
        segs = []
        # Transcripts only earn their space on trailing edges, where the words
        # decide where the cut lands. Before a set opener it is crowd noise.
        for s in (r.banter if r.edge == "trailing" else []):
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
        # Charts earn their place on trailing edges, where the fade-out shape
        # matters. On leading edges the typed start plus the preview tell you
        # everything, and 100+ plots per page is a lot of weight for nothing.
        plot = ""
        if args.plot_dir and r.edge != "leading":
            p = args.plot_dir / (re.sub(r"[^\w.-]+", "_", f"{r.label}_{r.edge}") + ".png")
            if p.exists():
                plot = f'<img src="{rel(p)}" loading="lazy">'
        # On leading-edge reports every flagged track is reviewable: the start
        # time is typed and previewed by hand, so the reasons to sideline a
        # track (a cappella misdetection, a computed cut below the screening
        # minimum) no longer apply - they just need a human to pick the time.
        leading_review = r.edge == "leading"
        if track_slug(r.share_url) in A_CAPPELLA_SLUGS and not leading_review:
            # Never auto-trimmed: the music detector misreads unaccompanied
            # singing. Listed without an approve checkbox for manual review.
            acappella.append(f'<div class="meta">{link} &middot; '
                             f'run {fmt_ts(r.nonmusic_run_s)} &middot; {char}</div>')
            continue
        if info.get("end") is None:
            if not leading_review:
                # Flagged but nothing actionable (cut below minimum, usually
                # banter running to the end of the track). Footnote only.
                cut = fmt_ts(info["cut_s"]) if info.get("cut_s") is not None else "?"
                skipped.append(f'<div class="meta">{link} &middot; run {fmt_ts(r.nonmusic_run_s)}, '
                               f'cut {cut} &mdash; left untouched</div>')
                continue
            # Seed the field from the detected boundary the same way the normal
            # path does, so there is a sensible starting point to adjust from.
            info = dict(info)
            info.setdefault(
                "start", max(0.0, effective_boundary(r, args.banter_gap) - args.keep_lead))
            info.setdefault("end", r.track_duration_s)
            info["cut_s"] = round(
                r.track_duration_s - (info["end"] - info["start"]), 1)
        # Leading edges get an empty player: the scan-time audition clips were
        # cut with whatever boundary logic was current when the scan ran, so
        # they go stale as soon as the trim math or the start time changes. The
        # preview server renders the real thing in about a second, and the page
        # asks for it on load. Trailing reports still ship their clips.
        audio = ""
        if r.edge != "leading":
            for key in ("audition_lead", "audition"):
                if info.get(key):
                    audio += f'<audio controls preload="none" src="{rel(info[key])}"></audio>'
        payload = esc(json.dumps({
            "label": r.label, "edge": r.edge, "mp3_url": r.mp3_url,
            "share_url": r.share_url, "music_boundary_s": r.music_boundary_s,
            "trim_start": info.get("start"), "trim_end": info.get("end"),
            "fade_in": args.fade_in if r.edge == "leading" else 0.0,
            "fade_out": args.fade_out if r.edge == "trailing" else 0.0,
        }), quote=True)
        # A loud cut side matters on a trailing edge, where it means the fade
        # may clip the end of the music. Before a set opener it is just a noisy
        # room, which is the normal case and not worth flagging.
        warn = ""
        if (r.edge == "trailing" and r.boundary_rms_drop_db is not None
                and r.boundary_rms_drop_db < LOUD_TAIL_DROP_DB):
            warn = '<span class="warn">&#9888;&#xFE0F; Loud past boundary</span>'
        # Full-track player: the waveform spans the whole track, so clicking it
        # seeks the original audio. Saves opening the track on phish.in just to
        # hear context around the cut.
        track_player = ""
        if r.waveform_url:
            track_player = (
                f'<div class="track" data-src="{esc(r.mp3_url, quote=True)}" '
                f'data-duration="{r.track_duration_s}">'
                f'<div class="tctl">'
                f'<button class="tplay" title="play the full track">&#9654;</button>'
                f'<button class="tt" title="use this position as the trim start">0:00</button>'
                f'</div>'
                f'<div class="wave"><img src="{esc(r.waveform_url, quote=True)}" loading="lazy">'
                f'<span class="cut"></span><span class="pos"></span></div></div>')
        rows.append(f"""
<div class="row">
  <div class="head">
    <input type="checkbox" class="approve" data-payload="{payload}"
      title="approve this trim (w)">
    <input type="checkbox" class="skip" title="no changes needed (x or k)">
    <strong>{link}</strong>
    <span class="dur">{fmt_ts(r.track_duration_s)}</span>
    <span class="chosen"></span>
    {warn}
    <span class="status"></span>
  </div>
  {banter}
  <div class="body">
    <div class="controls">
      <div class="tune">
        <button class="replay" title="restart the preview clip (r)">&#x21ba;</button>
        <input class="start" type="text" value="{fmt_tenths(info["start"])}"
          size="8" spellcheck="false" title="trim start">
        <button class="nudge" data-step="-1" title="1 second earlier (a)">&minus;1</button>
        <button class="nudge" data-step="-0.3" title="0.3 seconds earlier (s)">&minus;.3</button>
        <button class="nudge" data-step="-0.1" title="0.1 seconds earlier (d or [)">&minus;.1</button>
        <button class="nudge" data-step="0.1" title="0.1 seconds later (f or ])">+.1</button>
        <button class="nudge" data-step="0.3" title="0.3 seconds later (g)">+.3</button>
        <button class="nudge" data-step="1" title="1 second later (h)">+1</button>
      </div>
      <div class="audio">{audio}</div>
    </div>
    {track_player}
  </div>
  {plot}
</div>""")

    html_path.parent.mkdir(parents=True, exist_ok=True)
    html_path.write_text(f"""<!doctype html>
<meta charset="utf-8">
<title>Track edge trim review</title>
<link rel="icon" href='data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><text y=".9em" font-size="90">&#x2702;&#xFE0F;</text></svg>'>
<style>
  {embedded_fonts()}
  :root {{
    --bg: #ffffff; --header: #f4f4f6; --fg: #1c1c1e; --muted: #6b6b70;
    --line: #e3e3e7; --card: #fafafa; --sel: #eef2f8; --sel-line: #b9cbe6;
    --accent: #b8860b; --ok: #1a6b2f; --err: #b00020;
    --btn: #f2f2f4; --btn-line: #d8d8dd; --link: #2f6fd0;
    --wave-filter: sepia(.45) saturate(2.2) hue-rotate(165deg) brightness(.95) opacity(.88);
    --btn-hover: #e8e8ec;
  }}
  @media (prefers-color-scheme: dark) {{
    :root {{
      /* Cool slate rather than neutral grey: enough hue to feel considered,
         not enough to distract from the waveforms. */
      --bg: #1b1f27; --header: #12151b; --fg: #e6e9ef; --muted: #8b95a7;
      --line: #2f3542; --card: #232833; --sel: #26313f; --sel-line: #3a5578;
      --accent: #e0a92e; --ok: #5fce85; --err: #ff6b81;
      --btn: #2e3644; --btn-line: #4a5568; --link: #7fb3f0;
      --wave-filter: sepia(.5) saturate(1.9) hue-rotate(168deg) brightness(.82) opacity(.86);
      --btn-hover: #3a4354;
    }}
  }}
  * {{ box-sizing: border-box; }}
  body {{ font: 14px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
          margin: 0 auto 2rem; max-width: 1300px; padding: 4.8rem 1.5rem 0;
          background: var(--bg); color: var(--fg);
          -webkit-font-smoothing: antialiased; }}
  h1 {{ font-family: "Open Sans Condensed", -apple-system, sans-serif;
        font-size: 30px; font-weight: 700; letter-spacing: .01em; margin: 0 0 1.2rem; }}
  h2 {{ font-family: "Open Sans Condensed", -apple-system, sans-serif;
        font-size: 21px; font-weight: 700; color: var(--muted); margin-top: 2rem; }}
  a {{ color: var(--link); text-decoration-color: color-mix(in srgb, var(--link) 45%, transparent);
       text-underline-offset: 2px; }}
  a:hover {{ text-decoration-color: currentColor; }}
  .row {{ border: 1px solid transparent; border-bottom-color: var(--line);
          border-radius: 10px; padding: .85rem 1rem; transition: background .12s ease; }}
  .row:hover {{ background: var(--card); }}
  /* Approved rows collapse to just the title line: the work is done, and a
     long page of finished rows should stay scannable. Selecting one expands it
     again without unapproving it, so a finished row can be revisited; it
     re-collapses on its own as soon as the selection moves away. */
  .row.done:not(.sel) .body {{ display: none; }}
  .row.done:not(.sel) .head {{ margin-bottom: 0; }}
  /* Track length: always visible, muted so it never competes with the title. */
  .dur {{ color: var(--muted); font-variant-numeric: tabular-nums; font-size: 14px; }}
  .chosen {{ display: none; font-variant-numeric: tabular-nums; font-weight: 600;
             color: var(--ok); font-size: 15px; }}
  /* The summary time stands in for the collapsed controls, so it goes away
     when those controls are back on screen. */
  .row.done:not(.sel) .chosen {{ display: inline; }}
  /* Skipped rows collapse the same way but read dimmer than approved ones:
     they are settled work with no edit behind them, so they should recede
     further than a row that produced a trim. The struck-through title says
     "left alone" on its own, so no summary text is needed beside it. */
  .row.skipped:not(.sel) {{ opacity: .55; }}
  /* The title is a link, and links here carry a translucent underline colour.
     Pin the strike to currentColor or it inherits that wash and barely shows. */
  .row.skipped:not(.sel) .head strong,
  .row.skipped:not(.sel) .head strong a {{ text-decoration: line-through;
                                           text-decoration-color: currentColor;
                                           text-decoration-thickness: 1px; }}
  .skip {{ accent-color: var(--muted); }}
  /* Center, not baseline: the checkbox is a fixed-size box and baseline
     alignment leaves it sitting above the text. */
  .head {{ display: flex; gap: .6rem; align-items: center; flex-wrap: wrap;
           margin-bottom: .5rem; }}
  .head strong {{ font-family: "Open Sans Condensed", -apple-system, sans-serif;
                  font-size: 21px; font-weight: 700; letter-spacing: .01em; }}
  .meta {{ color: var(--muted); }}
  /* One button treatment everywhere: nudge, restart, waveform play. */
  .tune .nudge, .tune .replay, .track .tplay, .track .tt, #export {{
    background: var(--btn); color: var(--fg); border: 1px solid var(--btn-line);
    border-radius: 7px; transition: background .12s ease, border-color .12s ease;
  }}
  .tune .nudge:hover, .tune .replay:hover, .track .tplay:hover, .track .tt:hover,
  #export:hover {{ background: var(--btn-hover); border-color: var(--muted); }}
  .tune .nudge:active, .tune .replay:active, .track .tplay:active,
  .track .tt:active {{ transform: translateY(1px); }}
  .banter {{ display: flex; flex-wrap: wrap; gap: .3rem .4rem; margin: .4rem 0 .4rem 1.6rem; }}
  .banter .seg {{ padding: .05rem .45rem; border-radius: 3px; font-size: 13px; }}
  .banter .seg.kept {{ background: #dcefe1; color: #1a6b2f; }}
  .banter .seg.cut {{ background: #f3dada; color: #a02020; text-decoration: line-through; }}
  .warn {{ color: var(--err); font-weight: 600; }}
  .audio {{ display: flex; gap: 1rem; align-items: center; margin: .4rem 0; flex-wrap: wrap; }}
  input[type="checkbox"] {{ width: 1.15rem; height: 1.15rem; cursor: pointer;
                            accent-color: var(--link); }}
  img {{ max-width: 100%; }}
  #export {{ padding: .4rem 1rem; font: inherit; font-weight: 600;
             cursor: pointer; flex: 0 0 auto; }}
  /* Fixed header: title, progress and export in one bar, with the progress
     bar spanning the full width underneath. Replaces a floating legend that
     overlapped the title on narrow windows. */
  #topbar {{ position: fixed; top: 0; left: 0; right: 0; z-index: 10;
             background: var(--header); border-bottom: 1px solid var(--line);
             padding: .55rem 1.5rem .35rem; }}
  #topbar .row1 {{ display: flex; align-items: center; gap: 1rem;
                   max-width: 1300px; margin: 0 auto; }}
  #topbar h1 {{ font-size: 21px; margin: 0; flex: 1 1 auto; min-width: 0;
                white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }}
  #topbar h1 .count {{ color: var(--muted); font-weight: 400; font-size: 15px; }}
  #legend {{ display: flex; align-items: baseline; gap: .9rem; flex: 0 0 auto;
             font-size: 13px; font-variant-numeric: tabular-nums; }}
  #legend .pct {{ font-size: 20px; font-weight: 700;
                  font-family: "Open Sans Condensed", -apple-system, sans-serif; }}
  #legend .k {{ color: var(--muted); margin-right: .3rem; }}
  #legend .v {{ font-weight: 600; }}
  #topbar .bar {{ height: 4px; border-radius: 2px; background: var(--line);
                  margin: .45rem auto 0; max-width: 1300px;
                  overflow: hidden; font-size: 0; }}
  /* Inline-block, not flex: a flex item's basis is its content, and these are
     empty, so flex sized them from nothing and ignored the exact percentage
     widths set on them - the bar never reached the end. */
  #topbar .bar i {{ display: inline-block; height: 100%; vertical-align: top; }}
  #topbar .bar .fill-ok {{ background: var(--ok); }}
  /* Skipped must not read as unfilled track: grey-on-grey made a full bar look
     three-quarters done. Tint it toward the accent so both segments clearly
     count as progress. */
  #topbar .bar .fill-skip {{ background: var(--accent); opacity: .55; }}
  /* Narrow windows: the per-stat labels go first, then the counts. */
  @media (max-width: 860px) {{ #legend .k {{ display: none; }} }}
  @media (max-width: 640px) {{ #legend .stat {{ display: none; }} }}
  /* Six nudge buttons now, so the row is tighter than it was with four: the
     gap and the button padding both give up a little rather than letting the
     controls run wide and crowd the waveform beside them. */
  .tune {{ display: flex; gap: .35rem; align-items: center; margin: .4rem 0 .4rem 1.6rem; }}
  /* The nudges are one control, not six: closing them into a strip makes the
     step sequence read as a single scale. The .tune gap still separates that
     strip from the replay button and the time field on either side. */
  .tune .nudge + .nudge {{ margin-left: -.28rem; }}
  .tune input {{ font: inherit; font-size: 17px; font-variant-numeric: tabular-nums;
                 padding: .18rem .3rem; width: 5.2rem; text-align: center;
                 background: var(--bg); color: var(--fg);
                 border: 1px solid var(--btn-line); border-radius: 7px; }}
  .tune input:focus {{ outline: none; border-color: var(--accent);
                       box-shadow: 0 0 0 3px color-mix(in srgb, var(--accent) 25%, transparent); }}
  .tune input.invalid {{ border-color: var(--err); }}
  .tune .nudge {{ font: inherit; font-size: 13px; padding: .1rem .38rem;
                  cursor: pointer; }}
  /* Status lives in the header row, which spans the full width: its text
     changes length constantly and must never push the waveform column. */
  .head .status {{ color: var(--muted); font-size: 13px; }}
  .head .status.err {{ color: var(--err); }}
  /* In-progress reads as a pill so it is obvious at a glance which rows are
     still rendering; success says nothing at all. */
  .head .status.busy {{ background: color-mix(in srgb, var(--accent) 22%, transparent);
                        color: var(--accent); font-weight: 600;
                        border: 1px solid color-mix(in srgb, var(--accent) 40%, transparent);
                        padding: .12rem .65rem; border-radius: 999px;
                        font-size: 12px; letter-spacing: .01em; }}
  .offline {{ background: #fff4d6; border: 1px solid #d9ad4a; color: #6b4e00;
             padding: .6rem .8rem; margin-bottom: 1rem; border-radius: 4px; }}
  .tune .replay {{ font: inherit; font-size: 15px; line-height: 1; cursor: pointer;
                   padding: .15rem .35rem; }}
  /* Controls left, full-height waveform filling the right. */
  .body {{ display: flex; gap: .5rem; align-items: stretch; }}
  .controls audio {{ width: 100%; height: 34px; }}
  @media (prefers-color-scheme: dark) {{
    .controls audio {{ color-scheme: dark; }}
  }}
  /* Fixed width so the waveform column starts at the same x on every row,
     sized to the widest control (the audio element) and no wider. */
  .controls {{ flex: 0 0 22rem; min-width: 0; }}
  /* The waveform needs room to breathe from the transport controls beside it -
     at a tight gap the play button reads as sitting on the waveform. */
  .track {{ display: flex; align-items: center; gap: 1rem; flex: 1 1 auto; min-width: 280px; }}
  /* Play stacked above the position readout, left of the waveform. */
  .track .tctl {{ display: flex; flex-direction: column; align-items: stretch;
                  justify-content: center; gap: .25rem; flex: 0 0 auto; }}
  .track .tplay {{ font: inherit; padding: .1rem .55rem; cursor: pointer; }}
  .track .wave {{ position: relative; flex: 1; cursor: pointer; line-height: 0;
                  display: flex; align-items: stretch; border-radius: 8px;
                  overflow: hidden; background: var(--card); height: 96px; }}
  /* The waveform png is grey; hue-rotate tints it toward the accent without
     needing a recoloured image. */
  /* Width is set inline per row so the visible window fills the strip; .wave
     already has overflow:hidden, which clips the rest of the track. */
  .track .wave img {{ width: 100%; height: 96px; display: block;
                      object-fit: fill; filter: var(--wave-filter);
                      flex: 0 0 auto; max-width: none; }}
  /* Cut marker: where the trim starts, in whole-track time. */
  /* Hairline markers, translucent so the waveform reads through them. */
  .track .cut {{ position: absolute; top: 0; bottom: 0; width: 1px;
                 background: color-mix(in srgb, var(--accent) 65%, transparent);
                 pointer-events: none; }}
  .track .pos {{ position: absolute; top: 0; bottom: 0; width: 1px;
                 background: color-mix(in srgb, var(--ok) 65%, transparent);
                 pointer-events: none; display: none; }}
  .track .tt {{ font: inherit; font-size: 17px; font-variant-numeric: tabular-nums;
                min-width: 4rem; cursor: pointer; padding: .15rem .4rem; }}
  /* Buffering the streamed mp3: the glyph is replaced by a dotted ring that
     spins, so a slow start reads as loading rather than as a dead button. The
     ring is a pseudo-element so only it rotates - spinning the button itself
     would drag its border round with it and fight the :active nudge. Fixed
     size, so nothing shifts on a 100-row page. */
  .track .tplay.loading {{ color: transparent; position: relative; }}
  .track .tplay.loading::after {{ content: ""; position: absolute;
    top: 50%; left: 50%; width: .82em; height: .82em; margin: -.41em 0 0 -.41em;
    border: 2px solid color-mix(in srgb, var(--muted) 35%, transparent);
    border-top-color: var(--muted); border-radius: 50%;
    animation: tspin .7s linear infinite; }}
  @keyframes tspin {{ to {{ transform: rotate(360deg); }} }}
  @media (prefers-reduced-motion: reduce) {{
    .track .tplay.loading::after {{ animation-duration: 2.4s; }}
  }}
  .row.edited .tune input {{ border-color: var(--accent); }}
  /* Selected row: subtle, and set with a box-shadow so it does not shift
     anything. Up/down moves the selection; space plays, c adopts the time. */
  .row.sel {{ background: var(--sel); border-color: var(--sel-line);
              box-shadow: inset 3px 0 0 var(--link); }}
</style>
<header id="topbar">
  <div class="row1">
    <h1>Track edge trim review <span class="count">{len(rows)} candidates</span></h1>
    <div id="legend">
      <span class="pct">0%</span>
      <span class="stat"><span class="k">Approved</span><span class="v" id="n-approved">0</span></span>
      <span class="stat"><span class="k">Skipped</span><span class="v" id="n-skipped">0</span></span>
      <span class="stat"><span class="k">Total</span><span class="v" id="n-total">0</span></span>
    </div>
    <button id="export">Export JSON</button>
  </div>
  <div class="bar"><i class="fill-ok"></i><i class="fill-skip"></i></div>
</header>
{"".join(rows)}
{f'<h2>A cappella ({len(acappella)}) &mdash; not auto-trimmed, review manually</h2>{"".join(acappella)}' if acappella else ""}
{f'<h2>Not trimmed ({len(skipped)})</h2>{"".join(skipped)}' if skipped else ""}
<script>
// Seconds of the track shown in the waveform strip (2.5 minutes).
const WAVE_WINDOW_S = 150;
const YEAR = {json.dumps(html_path.resolve().parent.name)};

// Accepts "1:03.2", "63.2", "1:03". Returns null on anything else so a typo
// is rejected visibly rather than silently trimming at the wrong place.
function parseTime(raw) {{
  const s = raw.trim();
  if (!s) return null;
  // With a colon the seconds field is clock-style and capped at 59; bare input
  // is a plain seconds count, so "63.2" and "1:03.2" both mean 63.2s.
  const clock = s.match(/^(\\d+):([0-5]?\\d(?:\\.\\d+)?)$/);
  if (clock) {{
    return Math.round((parseInt(clock[1], 10) * 60 + parseFloat(clock[2])) * 10) / 10;
  }}
  const plain = s.match(/^\\d+(?:\\.\\d+)?$/);
  return plain ? Math.round(parseFloat(s) * 10) / 10 : null;
}}

function fmtTime(sec) {{
  const m = Math.floor(sec / 60);
  return m + ":" + (sec - m * 60).toFixed(1).padStart(4, "0");
}}

// Stop whichever full-track player is playing. Called when a preview starts so
// the two audio sources never overlap.
function stopFullTrack() {{
  const cur = window._playing;
  if (!cur || cur.audio.paused) return;
  cur.audio.pause();
  if (cur.playBtn) {{ cur.playBtn.classList.remove("loading"); cur.playBtn.textContent = "\\u25B6"; }}
}}

// Only one waveform at a time: starting one stops any other row's.
function stopOtherFullTracks(keep) {{
  const cur = window._playing;
  if (!cur || cur.audio === keep || cur.audio.paused) return;
  cur.audio.pause();
  if (cur.playBtn) {{ cur.playBtn.classList.remove("loading"); cur.playBtn.textContent = "\\u25B6"; }}
}}

// Mirror of stopFullTrack: starting a waveform silences every preview clip on
// the page. Both are hung off the "play" event so clicking a control and
// pressing a shortcut behave identically.
function stopPreviewClips() {{
  document.querySelectorAll(".audio audio").forEach(a => {{
    if (!a.paused) a.pause();
  }});
}}

// Whole seconds, for the full-track player readout.
function fmtClock(sec) {{
  const m = Math.floor(sec / 60);
  return m + ":" + String(Math.floor(sec - m * 60)).padStart(2, "0");
}}

// Previews render server-side with the same ffmpeg chain as the real trim, so
// what you hear is what lead_scan:apply writes. Without the server (opened over
// file://) the field still edits the export; only the preview is unavailable.
async function renderPreview(row) {{
  const cb = row.querySelector("input.approve");
  const input = row.querySelector("input.start");
  const status = row.querySelector(".status");
  const payload = JSON.parse(cb.dataset.payload);
  const secs = parseTime(input.value);
  if (secs === null) return;

  status.textContent = "rendering...";
  status.classList.remove("err");
  status.classList.add("busy");
  if (row._armWatchdog) row._armWatchdog();
  // Without a timeout a dropped request leaves the row on "rendering..."
  // forever, with no way to tell a slow render from a dead one.
  const ctl = new AbortController();
  // Drop any render this row already had in flight: it is for a start time the
  // reviewer has moved past, and it would hold a server slot.
  if (row._inflight) row._inflight.abort();
  row._inflight = ctl;
  row._pending = (row._pending || 0) + 1;
  // The field stays editable during a render: the debounce already prevents
  // pile-up, and locking it would swallow clicks mid-render.
  try {{
    // Must fire inside the watchdog deadline, or the watchdog silently clears
    // the pill while the request is still live and the reviewer never learns
    // the render died - it just looks like nothing happened.
    const timeout = setTimeout(() => ctl.abort(), 90000);
    let resp;
    try {{
      resp = await fetch("/preview", {{
        method: "POST",
        signal: ctl.signal,
        headers: {{"Content-Type": "application/json"}},
        body: JSON.stringify({{
          mp3_url: payload.mp3_url, trim_start: secs, trim_end: payload.trim_end,
          fade_in: payload.fade_in, fade_out: payload.fade_out
        }})
      }});
    }} finally {{
      clearTimeout(timeout);
    }}
    const data = await resp.json();
    if (!resp.ok) throw new Error(data.error || resp.statusText);
    // A newer render is already in flight: let it own the player and status.
    // Note we do NOT bail merely because the field text moved on - if nothing
    // superseded this request, dropping it here would strand the row on
    // "rendering..." forever (type a value, correct it before the first render
    // lands, and no successor ever arrives).
    if (row._inflight !== ctl) {{
      // Same guard as the abort path: only hand the pill over if another
      // render is genuinely still running. Discount this one, which has not
      // hit its finally block yet.
      if (Math.max(0, (row._pending || 1) - 1) === 0) {{
        status.textContent = "";
        status.classList.remove("busy");
      }}
      return;
    }}
    // One player per row: the preview supersedes the scan-time audition clips,
    // which were rendered at the original start and would only be confusing to
    // leave alongside it.
    const box = row.querySelector(".audio");
    let audio = box.querySelector("audio.preview");
    if (!audio) {{
      // Drop the scan-time audition clips, but keep the full-track waveform
      // player: it is a permanent control, not a clip.
      const keep = [...box.children].filter(el => el.classList.contains("track"));
      box.replaceChildren();
      audio = Object.assign(document.createElement("audio"),
        {{controls: true, className: "preview"}});
      // Never two sources at once: starting a preview stops the full track,
      // whether it was autoplay, restart, or the player's own controls.
      audio.addEventListener("play", stopFullTrack);
      box.append(audio);
      keep.forEach(el => box.append(el));
    }}
    audio.src = data.url + "?t=" + Date.now();
    // Autoplay only in the highlighted row: a render that finishes after the
    // reviewer has moved on must not start talking from off-screen. Browsers
    // may still block it without prior interaction; ignore that.
    if (window._sel === row) audio.play().catch(() => {{}});
    // Nothing to say on success: the audio is there and the field shows the
    // time. Only the in-progress and error states need words.
    status.textContent = "";
    status.classList.remove("busy");
  }} catch (e) {{
    // A TypeError from fetch means nothing answered: almost always the page
    // was opened over file:// instead of through `rake lead_scan:serve`.
    // Superseded by a newer edit: that render owns the status now. Hand the
    // pill over only if a successor is genuinely running - otherwise this abort
    // would leave "rendering..." on screen with nothing left to clear it.
    if (e.name === "AbortError" && row._inflight !== ctl) {{
      // Discount this request: what matters is whether any OTHER render is
      // still running to take ownership of the pill.
      if (Math.max(0, (row._pending || 1) - 1) > 0) return;
      status.textContent = "";
      status.classList.remove("busy");
      return;
    }}
    status.textContent =
      e.name === "AbortError" ? "render timed out \\u2014 retry, or check the server"
      : (e instanceof TypeError || location.protocol === "file:")
        ? "no preview server \\u2014 run: rake lead_scan:serve[" + (YEAR || "YYYY") + "]"
        : "preview failed: " + e.message;
    status.classList.remove("busy");
    status.classList.add("err");
  }} finally {{
    row._pending = Math.max(0, (row._pending || 1) - 1);
    // Last request out turns the light off. Ownership games between
    // superseded and superseding renders are what kept stranding the pill:
    // whoever finishes last is unambiguously the one that should clear it.
    if (row._pending === 0) {{
      clearTimeout(row._watchdog);
      const st = row.querySelector(".status");
      if (st.classList.contains("busy")) {{
        st.textContent = "";
        st.classList.remove("busy");
      }}
    }}
  }}
}}

// Audio only ever plays in the highlighted row, so moving the highlight
// silences whatever the old row was playing - both its preview clip and its
// waveform. Without this you can walk away from a row and still hear it.
function stopRowAudio(row) {{
  if (!row) return;
  row.querySelectorAll(".audio audio").forEach(a => {{ if (!a.paused) a.pause(); }});
  const cur = window._playing;
  if (cur && cur.row === row && !cur.audio.paused) {{
    cur.audio.pause();
    cur.playBtn.classList.remove("loading");
    cur.playBtn.textContent = "\\u25B6";
  }}
}}

function selectRow(row) {{
  if (window._sel === row) return;
  if (window._sel) {{
    stopRowAudio(window._sel);
    window._sel.classList.remove("sel");
  }}
  window._sel = row;
  if (!row) return;
  row.classList.add("sel");
  // Arriving at a row starts its waveform: the review loop is listen, adjust,
  // approve, and this removes a keypress from every single pass. Approved rows
  // expand on arrival so they can be re-checked, but stay silent - they are
  // already dealt with, and arrowing back over finished work should be quiet.
  // Space still plays one on demand.
  if (row._startTrack && !row.classList.contains("done")) row._startTrack();
  // Deliberately no auto-render on arrival: it would seize playback from the
  // waveform every time the selection moved. A preview is rendered only when
  // asked for - "c", or an edit to the start time.
}}

function moveSelection(delta) {{
  const rows = [...document.querySelectorAll(".row")];
  if (!rows.length) return;
  const i = window._sel ? rows.indexOf(window._sel) : -1;
  const next = rows[Math.min(rows.length - 1, Math.max(0, i < 0 ? 0 : i + delta))];
  selectRow(next);
  // selectRow no-ops when the row is already selected, so start playback here
  // too: landing on a row must always play it, however we arrived.
  if (next._startTrack && !next.classList.contains("done")) next._startTrack();
  if (next.scrollIntoView) next.scrollIntoView({{block: "nearest"}});
}}

// Keyboard: up/down moves the row selection, space plays the selected row's
// full track, c adopts its playhead as the trim start, left/right scrub
// whatever is playing. All ignored while typing so the time field is normal.
document.addEventListener("keydown", e => {{
  // Never intercept browser shortcuts: cmd-F, ctrl-R, cmd-A and friends must
  // keep working. Every shortcut here is an unmodified keypress.
  if (e.metaKey || e.ctrlKey || e.altKey) return;
  const t = e.target && e.target.tagName;
  // Up/down always move between rows, even from inside the time field: they
  // are navigation, and a text input has nothing vertical to do with them.
  // Leaving the field commits whatever was typed.
  if (e.key === "ArrowDown" || e.key === "ArrowUp") {{
    e.preventDefault();
    if (e.target && e.target.blur) e.target.blur();
    return moveSelection(e.key === "ArrowDown" ? 1 : -1);
  }}

  // Every other key: only *text* entry keeps it. A checkbox is an INPUT too,
  // but it is not typing - and a focused checkbox or <audio> would otherwise
  // swallow the arrows (the browser scrolls instead), so navigation would stop
  // working after clicking a control or pressing "w".
  const typing = (t === "INPUT" && e.target.type !== "checkbox")
    || t === "TEXTAREA" || (e.target && e.target.isContentEditable);
  // The only text field on the page is the m:ss.s start time, so the only
  // characters it can ever need are digits, ":" and ".". Every other printable
  // key is a shortcut even with the field focused - ";" approves rather than
  // typing a semicolon - while the editing keys (arrows, backspace, tab...)
  // are multi-character names and still reach the field normally.
  const isTimeChar = e.key.length === 1 && /[0-9.:]/.test(e.key);
  const isShortcutChar = e.key.length === 1 && !isTimeChar;
  if (typing && !(t === "INPUT" && isShortcutChar)) return;
  // A shortcut character reaching this point is not text. Swallow it up front:
  // the branches below only preventDefault once they know they can act, and an
  // unhandled key ("q", or ";" with no row) would otherwise still be typed
  // into the field we are about to leave.
  if (typing && isShortcutChar) e.preventDefault();
  if (e.target && e.target.blur && (t === "AUDIO" || t === "INPUT" || t === "BUTTON")) {{
    e.target.blur();
  }}
  if (e.key === " " || e.key === "Spacebar") {{
    // Always swallow space: letting it through scrolls the page, which is
    // never what is wanted here. With no row selected it simply does nothing.
    e.preventDefault();
    if (!window._sel || !window._sel._toggle) return;
    return window._sel._toggle();
  }}
  // Right-hand aliases so the whole loop is reachable without moving hands:
  // / = c (adopt), ; = w (approve), ' = k (skip). The nudge pair , and . keep
  // meaning -.3 and +.3 - they alias the steps, not the letters, because the
  // letter for +.3 moved when a s d f g h took the whole button row.
  const RIGHT_HAND = {{"/": "c", ",": "s", ".": "g", ";": "w", "'": "k"}};
  const key = RIGHT_HAND[e.key] || e.key;

  if (key === "c" || key === "C") {{
    if (!window._sel || !window._sel._adopt) return;
    e.preventDefault();
    return window._sel._adopt();
  }}
  if (key === "r" || key === "R") {{
    if (!window._sel || !window._sel._restart) return;
    e.preventDefault();
    return window._sel._restart();
  }}
  // a s d f g h map straight onto the six nudge buttons left to right, so the
  // home row is the button row. [ and ] stay as right-hand aliases for the
  // fine pair, which is the step used most while dialling a cut in.
  const nudgeKeys = {{
    a: -1, s: -0.3, d: -0.1, f: 0.1, g: 0.3, h: 1,
    "[": -0.1, "]": 0.1,
  }};
  const nudgeStep = nudgeKeys[key.toLowerCase()];
  if (nudgeStep !== undefined) {{
    if (!window._sel || !window._sel._nudge) return;
    e.preventDefault();
    window._sel._nudge(nudgeStep);
    return;
  }}
  // "w" approves the selected row; "x" or "k" marks it as needing no changes.
  // Both are the commit step of the review loop, not toggles: answer and move
  // on. Reversing an answer is still available via the checkbox itself.
  const answerKeys = {{w: "approve", x: "skip", k: "skip"}};
  const answer = answerKeys[key.toLowerCase()];
  if (answer) {{
    if (!window._sel) return;
    const box = window._sel.querySelector("input." + answer);
    if (!box) return;
    e.preventDefault();
    // The two answers are exclusive, and setting .checked in script fires no
    // "change" - so clear the other box and collapse by hand.
    const other = window._sel.querySelector(
      "input." + (answer === "approve" ? "skip" : "approve"));
    if (other) other.checked = false;
    box.checked = true;
    if (window._sel._syncDone) window._sel._syncDone();
    return moveSelection(1);
  }}
  // "e" toggles the preview clip - the left-hand player. Arrows stay entirely
  // on the waveform so scrubbing never fights with clip playback.
  if (e.key === "e" || e.key === "E") {{
    if (!window._sel) return;
    const clip = window._sel.querySelector(".audio audio");
    if (!clip || !clip.src) return;
    e.preventDefault();
    if (clip.paused) clip.play().catch(() => {{}});
    else clip.pause();
    return;
  }}
  if (e.key !== "ArrowLeft" && e.key !== "ArrowRight") return;

  const cur = window._playing;
  // Right starts the selected row's waveform when nothing is playing yet,
  // rather than doing nothing.
  if ((!cur || cur.audio.paused) && e.key === "ArrowRight"
      && window._sel && window._sel._toggle) {{
    e.preventDefault();
    return window._sel._toggle();
  }}
  if (!cur) return;
  e.preventDefault();
  const step = (e.shiftKey ? 5 : 1) * (e.key === "ArrowRight" ? 1 : -1);
  const d = cur.audio.duration || cur.duration || 0;
  const next = Math.min(d || Infinity, Math.max(0, cur.audio.currentTime + step));
  cur.audio.currentTime = next;
  if (cur.mark) cur.mark(next);
  cur.label.textContent = fmtClock(next);
}});

if (location.protocol === "file:") {{
  const b = document.createElement("div");
  b.className = "offline";
  b.textContent = "Opened as a file \\u2014 previews need the server. "
    + "Run: rake lead_scan:serve[" + YEAR + "] and open the http:// URL. "
    + "Editing start times still works and still exports.";
  document.body.prepend(b);
}}

// Progress legend. Approved and skipped are both "answered": the percentage is
// how much of this year's review is behind you, which is the number you want
// when deciding whether to keep going.
function updateLegend() {{
  const rows = [...document.querySelectorAll(".row")];
  const total = rows.length;
  const approved = rows.filter(r => {{
    const b = r.querySelector("input.approve");
    return b && b.checked;
  }}).length;
  const skipped = rows.filter(r => {{
    const b = r.querySelector("input.skip");
    return b && b.checked;
  }}).length;
  const pct = total ? Math.round(((approved + skipped) / total) * 100) : 0;
  const set = (id, v) => {{
    const el = document.getElementById(id);
    if (el) el.textContent = v;
  }};
  set("n-approved", approved);
  set("n-skipped", skipped);
  set("n-total", total);
  const pctEl = document.querySelector("#legend .pct");
  if (pctEl) pctEl.textContent = pct + "%";
  // Two segments in one bar: approved and skipped stack to the same total the
  // percentage reports, so the bar and the number can never disagree.
  const ok = document.querySelector("#topbar .fill-ok");
  const sk = document.querySelector("#topbar .fill-skip");
  if (ok) ok.style.width = (total ? (approved / total) * 100 : 0) + "%";
  if (sk) sk.style.width = (total ? (skipped / total) * 100 : 0) + "%";
  saveProgress();
}}

// Progress survives a reload: a year is a long pass and losing it to a stray
// cmd-R is brutal. Keyed by share url so it follows the track even if the page
// is rebuilt and the rows reorder. Skips are page-only - they never reach
// approved.json - so this is the only place they persist.
const STORE_KEY = "leadscan:progress:" + YEAR;
function rowKey(row) {{
  const b = row.querySelector("input.approve");
  if (!b) return null;
  try {{ return JSON.parse(b.dataset.payload).share_url || null; }}
  catch (e) {{ return null; }}
}}
function saveProgress() {{
  const state = {{}};
  document.querySelectorAll(".row").forEach(row => {{
    const key = rowKey(row);
    if (!key) return;
    const a = row.querySelector("input.approve");
    const s = row.querySelector("input.skip");
    // Only answered rows are stored, so the blob stays small and a cleared
    // answer actually disappears instead of lingering as false.
    if (a && a.checked) state[key] = "a";
    else if (s && s.checked) state[key] = "s";
  }});
  try {{ localStorage.setItem(STORE_KEY, JSON.stringify(state)); }}
  catch (e) {{ /* private mode or full quota: progress just stops persisting */ }}
}}
function restoreProgress() {{
  let state = null;
  try {{ state = JSON.parse(localStorage.getItem(STORE_KEY) || "null"); }}
  catch (e) {{ return; }}
  if (!state) return;
  document.querySelectorAll(".row").forEach(row => {{
    const mark = state[rowKey(row)];
    if (!mark) return;
    const box = row.querySelector(mark === "a" ? "input.approve" : "input.skip");
    if (!box) return;
    box.checked = true;
    // Setting .checked in script fires no "change", so collapse by hand.
    if (row._syncDone) row._syncDone();
  }});
}}

document.querySelectorAll(".row").forEach(row => {{
  const cb = row.querySelector("input.approve");
  const input = row.querySelector("input.start");
  if (!cb || !input) return;
  const original = JSON.parse(cb.dataset.payload).trim_start;
  const payloadEnd = JSON.parse(cb.dataset.payload).trim_end;

  // The export payload updates on every commit, but rendering waits for a
  // pause so a burst of +1s clicks costs one ffmpeg run, not one per click.
  let renderTimer = null;
  // Watchdog: the busy pill has several exit paths (success, superseded
  // success, abort, no-op commit, a request that never leaves the browser) and
  // any one of them going wrong strands "rendering..." on screen forever.
  // Rather than guard each path, guarantee the pill cannot outlive the work:
  // whenever it is shown, arm a timer that clears it if nothing else has.
  const armWatchdog = () => {{
    clearTimeout(row._watchdog);
    // Real renders are ~1.5s but a cold network read has been seen at 86s,
    // so the deadline has to clear genuine hangs without cutting off slow
    // work. Source tracks are cached after first use, making these rare.
    row._deadline = Date.now() + 120000;
    row._watchdog = setTimeout(function tick() {{
      const st = row.querySelector(".status");
      if (!st.classList.contains("busy")) return;
      // Re-arm while work is genuinely in flight, but never past the deadline:
      // a request that hangs keeps _pending above zero forever, and deferring
      // to it is what let "rendering..." stick around indefinitely.
      if (row._pending > 0 && Date.now() < row._deadline) {{
        row._watchdog = setTimeout(tick, 4000);
        return;
      }}
      st.textContent = "";
      st.classList.remove("busy");
      row._pending = 0;
    }}, 8000);
  }};

  const scheduleRender = () => {{
    clearTimeout(renderTimer);
    armWatchdog();
    row.querySelector(".status").textContent = "waiting...";
    row.querySelector(".status").classList.remove("err");
    row.querySelector(".status").classList.add("busy");
    renderTimer = setTimeout(() => renderPreview(row), 450);
  }};

  const commit = () => {{
    const secs = parseTime(input.value);
    input.classList.toggle("invalid", secs === null);
    if (secs === null) {{
      clearTimeout(renderTimer);
      row.querySelector(".status").textContent = "use m:ss.s (e.g. 1:03.2)";
      row.querySelector(".status").classList.remove("busy");
      row.querySelector(".status").classList.add("err");
      return;
    }}
    // The checkbox payload is the single source of truth for the export.
    const payload = JSON.parse(cb.dataset.payload);
    if (payload.trim_start === secs) {{
      // Nothing to render, but a pill may be showing from an earlier edit that
      // this one just cancelled - clear it rather than strand it.
      if (!row._pending) {{
        clearTimeout(renderTimer);
        const st = row.querySelector(".status");
        if (!st.classList.contains("err")) {{
          st.textContent = "";
          st.classList.remove("busy");
        }}
      }}
      return;
    }}
    payload.trim_start = secs;
    cb.dataset.payload = JSON.stringify(payload);
    // Highlight the control only. The plot is a static scan-time PNG and is
    // never redrawn, so nothing about it should look active.
    row.classList.toggle("edited", Math.abs(secs - original) > 0.05);
    if (row._markCut) row._markCut(secs);
    if (row._syncDone) row._syncDone();
    scheduleRender();
  }};

  input.addEventListener("change", commit);
  input.addEventListener("keydown", e => {{ if (e.key === "Enter") {{ e.preventDefault(); commit(); }} }});

  // Full-track player. Streams the original mp3 straight from phish.in and
  // scrubs on the waveform, so context around a cut can be checked without
  // leaving the page. Separate from the preview clip, which is the short
  // render used to judge the splice itself.
  const track = row.querySelector(".track");
  if (track) {{
    const wave = track.querySelector(".wave");
    const posEl = track.querySelector(".pos");
    const cutEl = track.querySelector(".cut");
    const label = track.querySelector(".tt");
    const playBtn = track.querySelector(".tplay");
    const duration = parseFloat(track.dataset.duration) || 0;
    let full = null;

    // Only the opening WAVE_WINDOW_S are shown, stretched across the full
    // width. The trim is always within the first few seconds, so rendering
    // twenty minutes of waveform wastes almost all of the space. The png still
    // covers the whole track, so it is scaled up and clipped by .wave.
    const shown = Math.min(duration || WAVE_WINDOW_S, WAVE_WINDOW_S);
    if (duration > shown) {{
      const img = track.querySelector("img");
      if (img) img.style.width = (duration / shown * 100) + "%";
    }}
    // Fraction of the visible width for a time in track seconds.
    const frac = secs => (shown > 0 ? Math.min(1, Math.max(0, secs / shown)) : 0);

    const markCut = secs => {{
      cutEl.style.left = (frac(secs) * 100) + "%";
      cutEl.style.display = secs > shown ? "none" : "block";
    }};
    markCut(original);
    row._markCut = markCut;
    // Exact playhead, since the label is rounded to whole seconds.
    let atSecs = 0;

    // Clicking the readout adopts that position as the trim start.
    const adopt = () => {{
      const was = JSON.parse(cb.dataset.payload).trim_start;
      input.value = fmtTime(Math.round(atSecs * 10) / 10);
      input.classList.remove("invalid");
      commit();
      // Adopting is an explicit request to hear it, so render even when the
      // value did not actually change (commit no-ops in that case).
      if (JSON.parse(cb.dataset.payload).trim_start === was) scheduleRender();
      // The point has been made once a few seconds of the kept audio have
      // played: adopting picks the cut, and letting the whole rest of the track
      // run on from there just has to be stopped by hand. The preview clip that
      // the render produces is the thing to listen to next.
      if (full && !full.paused) {{
        clearTimeout(row._adoptStop);
        const from = full.currentTime;
        row._adoptStop = setTimeout(() => {{
          if (!full || full.paused) return;
          // Only stop the run this adopt started. If the reviewer seeked or
          // restarted meanwhile the playhead will not be where simply playing
          // on from `from` would have left it, and that is their playback to
          // keep - so leave it running.
          const expected = from + 3;
          if (Math.abs(full.currentTime - expected) > 1) return;
          full.pause();
          if (row._paintBtn) row._paintBtn();
        }}, 3000);
      }}
    }};
    label.addEventListener("click", adopt);
    // Exposed for the keyboard shortcuts on the selected row.
    row._adopt = adopt;

    // The mp3 streams from phish.in, so there is a real wait between asking for
    // playback and hearing it. One place decides what the button shows, so the
    // spinner cannot be left behind by whichever path started the audio.
    const paintBtn = () => {{
      playBtn.textContent = (full && !full.paused) ? "\\u23F8" : "\\u25B6";
    }};
    // The spinner is drawn by CSS over a transparent glyph, so the button keeps
    // its width and the underlying play/pause state stays correct underneath.
    const setLoading = on => {{
      playBtn.classList.toggle("loading", on);
      paintBtn();
    }};
    row._paintBtn = paintBtn;

    // Created on first use so a page of 100 rows opens no connections.
    const ensure = () => {{
      if (full) return full;
      full = new Audio(track.dataset.src);
      full.preload = "none";
      // Buffering is the whole reason for the indicator: "waiting" fires when
      // playback stalls for data, and it can happen mid-track too, not just on
      // the first press.
      full.addEventListener("waiting", () => setLoading(true));
      full.addEventListener("stalled", () => setLoading(true));
      // Any of these means we have audio again. "playing" is the one that fires
      // when sound actually starts, which is what the spinner was waiting for.
      ["playing", "canplay", "error", "pause", "ended"].forEach(
        ev => full.addEventListener(ev, () => setLoading(false)));
      // Arrow-key scrubbing acts on whichever track is playing.
      full.addEventListener("play", () => {{
        stopOtherFullTracks(full);
        window._playing = {{audio: full, label, posEl, duration, playBtn, row,
          mark: t => {{
            posEl.style.display = t > shown ? "none" : "block";
            posEl.style.left = (frac(t) * 100) + "%";
          }}}};
        stopPreviewClips();
      }});
      full.addEventListener("timeupdate", () => {{
        const d = full.duration || duration;
        if (!d) return;
        posEl.style.display = full.currentTime > shown ? "none" : "block";
        posEl.style.left = (frac(full.currentTime) * 100) + "%";
        atSecs = full.currentTime;
        label.textContent = fmtClock(full.currentTime);
      }});
      full.addEventListener("ended", () => {{ paintBtn(); }});
      return full;
    }};

    // Starting playback always goes through here, so the spinner appears on the
    // press rather than waiting for a "waiting" event that may never fire if the
    // browser buffers silently. It clears on "playing" - or on "error", so a
    // dead url does not spin forever.
    const start = a => {{
      if (a.readyState < 3) setLoading(true);  // < HAVE_FUTURE_DATA
      a.play().then(() => setLoading(false)).catch(() => setLoading(false));
    }};

    const togglePlay = () => {{
      const a = ensure();
      if (a.paused) {{
        start(a);
      }} else {{
        a.pause();
        setLoading(false);
      }}
    }};
    playBtn.addEventListener("click", togglePlay);
    row._toggle = togglePlay;
    // Play-only, for arriving at a row: never pauses something already going.
    row._startTrack = () => {{
      const a = ensure();
      if (!a.paused) return;
      start(a);
    }};

    wave.addEventListener("click", e => {{
      const a = ensure();
      const rect = wave.getBoundingClientRect();
      const at = Math.min(1, Math.max(0, (e.clientX - rect.left) / rect.width)) * shown;
      a.currentTime = at;
      atSecs = at;
      label.textContent = fmtClock(at);
      if (a.paused) start(a);
    }});
  }}

  // Clicking anywhere in a row selects it, so the keyboard shortcuts have an
  // obvious target. Buttons and inputs still do their own thing.
  row.addEventListener("mousedown", () => selectRow(row));

  // Approving marks the row done - it collapses to its title plus the chosen
  // time once the selection leaves it; unchecking restores the full controls.
  // Anything playing in it stops on approval. Skipping is the same motion for
  // the other answer: this track needs no trim at all.
  const chosen = row.querySelector(".chosen");
  const skipBox = row.querySelector("input.skip");
  const syncDone = () => {{
    const skipped = skipBox && skipBox.checked;
    const on = cb.checked || skipped;
    // One collapse class for both answers: "done" means settled, either way.
    row.classList.toggle("done", on);
    row.classList.toggle("skipped", !!skipped);
    // A skipped row has no chosen time to show, and the struck-through title
    // already says so - anything here would just be a stale timestamp for a cut
    // that is never going to happen.
    if (chosen) chosen.textContent = (on && !skipped) ? input.value : "";
    if (on) {{
      stopRowAudio(row);
      // Answering settles the row, so any render still claiming to be in flight
      // is moot - drop it rather than leave a "rendering..." pill on a finished
      // row with nothing left to clear it.
      if (row._inflight) row._inflight.abort();
      clearTimeout(row._watchdog);
      row._pending = 0;
      const st = row.querySelector(".status");
      if (st && st.classList.contains("busy")) {{
        st.textContent = "";
        st.classList.remove("busy");
      }}
    }}
    updateLegend();
  }};
  // The two answers are mutually exclusive: a track is either getting a trim or
  // being left alone, never both. Checking one clears the other.
  const settle = (box, other) => box.addEventListener("change", () => {{
    if (box.checked && other) other.checked = false;
    syncDone();
    // Answering is the commit step, same as "w": collapse and move on.
    if (box.checked) return moveSelection(1);
    // Unanswered and expanded again: treat it like arriving at the row.
    selectRow(row);
    if (row._startTrack) row._startTrack();
  }});
  settle(cb, skipBox);
  if (skipBox) settle(skipBox, cb);
  row._syncDone = syncDone;
  row._skipBox = skipBox;

  // Scan-audition clips are in the markup, so they need the same guard the
  // preview element gets when it is created.
  row.querySelectorAll(".audio audio").forEach(
    el => el.addEventListener("play", stopFullTrack));

  // Restart replays whichever clip the row currently shows - the scan audition
  // before a preview exists, the preview after.
  const restart = () => {{
    const audio = row.querySelector(".audio audio");
    if (!audio) return;
    audio.currentTime = 0;
    audio.play().catch(() => {{}});
  }};
  const replay = row.querySelector("button.replay");
  if (replay) replay.addEventListener("click", restart);
  // Exposed so "r" can restart the selected row's clip.
  row._restart = restart;

  // Nudge from whatever is currently in the field so repeated clicks compound;
  // an unparseable field falls back to the committed value rather than 0.
  const nudgeBy = amount => {{
    const base = parseTime(input.value) ?? JSON.parse(cb.dataset.payload).trim_start;
    const next = Math.max(0, Math.round((base + amount) * 10) / 10);
    if (next > payloadEnd - 0.1) return;  // never past the trim end
    input.value = fmtTime(next);
    input.classList.remove("invalid");
    commit();
  }};
  row.querySelectorAll("button.nudge").forEach(btn => {{
    btn.addEventListener("click", () => nudgeBy(Number(btn.dataset.step)));
  }});
  // Exposed so a s d f can drive the same steps from the keyboard.
  row._nudge = nudgeBy;
  row._armWatchdog = armWatchdog;
}});

// Rows are wired up by now, so restoring can reuse their own collapse logic.
restoreProgress();
updateLegend();

document.getElementById("export").onclick = () => {{
  const approved = [...document.querySelectorAll("input.approve:checked")]
    .map(cb => JSON.parse(cb.dataset.payload));
  const blob = new Blob([JSON.stringify(approved, null, 2)], {{type: "application/json"}});
  const a = Object.assign(document.createElement("a"),
    {{href: URL.createObjectURL(blob), download: "approved.json"}});
  a.click();
}};
</script>
""")
    html_path.with_name("summary.json").write_text(json.dumps(
        {"trims": len(rows), "a_cappella": len(acappella), "not_trimmed": len(skipped)}))
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
            # Hallucinated punctuation/symbols ("." / "∂∂") on crowd noise pass
            # the probability filters; only transcriptions with letters count.
            if not re.search(r"[A-Za-z]", text):
                continue
            if re.sub(r"[^a-z ]", "", text.lower()).strip() in HALLUCINATED_CAPTIONS:
                continue
            if s.no_speech_prob < 0.6 and s.avg_logprob > -1.5:
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

    # Walk inward from the edge; median smoothing has already removed short
    # blips. A surviving blip (a few music-ish seconds of crowd noise) must not
    # end the run either, so a music frame only terminates it when the score
    # holds up over the next MUSIC_SUSTAIN_S of audio.
    look = max(1, int(round(MUSIC_SUSTAIN_S / FRAME_HOP_S)))

    def sustained(i):
        w = music_sm[i:i + look] if edge == "leading" else music_sm[max(0, i - look + 1):i + 1]
        return float(np.median(w)) >= args.music_threshold

    order = range(n) if edge == "leading" else range(n - 1, -1, -1)
    run_frames = []
    for i in order:
        if not nonmusic[i] and sustained(i):
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

    # A banter track has no music to bound the lead-in, so the run swallows
    # the whole file and the trim would delete it. With --speech-onset the
    # first on-mic words are the boundary instead: what precedes them is the
    # crowd noise a lead trim is meant to remove.
    if args.speech_onset and edge == "leading" and banter:
        onset = min(seg["start"] for seg in banter)
        if onset < boundary:
            boundary = onset
            region = [offset_s, onset]
            run_s = onset - offset_s

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
    """Fill in share_url and waveform_url on results from older reports by
    refetching show data. Both come from the same API call, so reports written
    before a field existed pick it up on a plain rebuild - no re-scan."""
    todo = [r for r in results if not (r.share_url and r.waveform_url)]
    if not todo:
        return
    dates_needed = len({m.group(1) for r in todo
                        if (m := re.match(r"(\d{4}-\d{2}-\d{2}) ", r.label))})
    print(f"  backfilling {len(todo)} result(s) from {dates_needed} show(s)...", file=sys.stderr)
    track_maps = {}
    for r in todo:
        m = re.match(r"(\d{4}-\d{2}-\d{2}) .+? t(\d+) ", r.label)
        if not m:
            continue
        date, position = m.group(1), int(m.group(2))
        if date not in track_maps:
            resp = requests.get(f"{API_BASE}/shows/{date}", timeout=30)
            resp.raise_for_status()
            track_maps[date] = {t["position"]: t for t in resp.json()["tracks"]}
            if len(track_maps) % 25 == 0:
                print(f"    {len(track_maps)}/{dates_needed} shows", file=sys.stderr)
        track = track_maps[date].get(position) or {}
        if not r.share_url and track.get("slug"):
            r.share_url = f"{SITE_BASE}/{date}/{track['slug']}"
        if not r.waveform_url:
            r.waveform_url = track.get("waveform_image_url") or ""


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
        if cut_s < args.min_cut:
            trim_info[label] = {"cut_s": round(cut_s, 1), "skipped": True}
            continue
        info = {"start": start, "end": end, "cut_s": round(cut_s, 1)}
        safe = re.sub(r"[^\w.-]+", "_", label)
        for key, path in [("trimmed", args.trim_dir / f"{safe}_trimmed.mp3"),
                          ("audition", args.trim_dir / "clips" / f"{safe}_audition.mp3"),
                          ("audition_lead", args.trim_dir / "clips" / f"{safe}_lead_audition.mp3")]:
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
                      args.trim_dir / "clips" / f"{safe}_audition.mp3",
                      args.trim_dir / "clips" / f"{safe}_lead_audition.mp3"]:
                p.unlink(missing_ok=True)
    if drop:
        results = [r for r in results if r.label not in drop]
        for label in drop:
            safe = re.sub(r"[^\w.-]+", "_", label)
            for p in [args.trim_dir / f"{safe}_trimmed.mp3",
                      args.trim_dir / "clips" / f"{safe}_audition.mp3",
                      args.trim_dir / "clips" / f"{safe}_lead_audition.mp3",
                      args.plot_dir / f"{safe}_leading.png",
                      args.plot_dir / f"{safe}_trailing.png"]:
                p.unlink(missing_ok=True)

    backfill_share_urls(results)
    trim_info = reconstruct_trim_info(results, args)
    # report.json always keeps every result; only the review page is narrowed.
    report_path.write_text(report_json(results))
    page_results = results
    if args.only_unreviewed:
        # A rendered trim file means this candidate was reviewable before, so it
        # has already been through a review pass. Keep the rest.
        def already_reviewed(result):
            safe = re.sub(r"[^\w.-]+", "_", result.label)
            return (args.trim_dir / f"{safe}_trimmed.mp3").exists()

        page_results = [r for r in results if not already_reviewed(r)]
        print(f"  only-unreviewed: {len(page_results)} of {len(results)} candidates",
              file=sys.stderr)
    write_review_html(dir_path / "review.html", page_results, trim_info, args)


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
    p.add_argument("--min-cut", type=float, default=MIN_CUT_S,
                   help="Skip trims that would remove less than this many seconds "
                        f"(default: {MIN_CUT_S})")
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
    p.add_argument("--speech-onset", action="store_true",
                   help="on an all-speech track (banter), bound the lead-in at the first "
                        "transcribed words instead of at music that never comes")
    p.add_argument("--no-transcribe", action="store_true",
                   help="Skip Whisper banter detection on flagged regions")
    p.add_argument("--banter-gap", type=float, default=25,
                   help="Chain banter segments within this many seconds of the music boundary "
                        "when extending the trim point (default: 25)")
    p.add_argument("--rebuild", type=Path, action="append", default=[], metavar="DIR",
                   help="Regenerate review.html from DIR/report.json (backfills share urls; "
                        "no audio analyzed). Repeatable.")
    p.add_argument("--only-unreviewed", action="store_true",
                   help="On rebuild, keep only candidates with no rendered trim file: the ones "
                        "newly promoted into review, skipping any you already worked through.")
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
    waveforms = {}  # share url -> waveform png, for tracks given as urls
    for inp in args.inputs:
        edges = ["leading", "trailing"] if args.edges == "both" else [args.edges]
        # A phish.in track page stands in for its mp3, with the same label,
        # songs and share url a --show job gets, so its row applies like one.
        m = re.match(rf"{re.escape(SITE_BASE)}/(\d{{4}}-\d{{2}}-\d{{2}})/([^/?#]+)/?$", inp)
        if m:
            date, slug = m.groups()
            try:
                resp = requests.get(f"{API_BASE}/shows/{date}", timeout=30)
                resp.raise_for_status()
                track = next((t for t in resp.json()["tracks"] if t.get("slug") == slug), None)
            except Exception as e:  # noqa: BLE001 - reported with the other fetch failures
                track = None
                failures.append(f"{inp}: {e}")
            if not track or not track.get("mp3_url"):
                print(f"  skipping {inp} (no such track or no audio)", file=sys.stderr)
                continue
            label = f"{date} {track['set_name']} t{track['position']:02d} {track['title']}"
            waveforms[inp] = track.get("waveform_image_url") or ""
            jobs.append((label, track["mp3_url"], edges,
                         [s["title"] for s in track.get("songs", [])], inp))
            continue
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
            for r in track_results:
                r.waveform_url = r.waveform_url or waveforms.get(share, "")
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
