#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11,<3.13"
# dependencies = [
#   "numpy",     # imported at module scope by audio_edge_analysis
#   "requests",
# ]
# ///
"""Preview server for the lead-scan review page.

Serves a scan output dir (review.html, plots, clips) over http and renders
on-demand trim previews so a reviewer can adjust the fade start and hear the
exact audio that `rake lead_scan:apply` would produce.

The filter chain is not reimplemented here: trim_command() is imported from
audio_edge_analysis.py, which spec/services/audio_edge_trim_service_parity_spec.rb
pins against AudioEdgeTrimService. Preview == scan == applied.

Usage (normally via `rake lead_scan:serve[2025]`):
  uv run scripts/lead_scan_server.py --dir data/lead_scan/2025 --port 8770

Requires ffmpeg/ffprobe on PATH.
"""

import argparse
import hashlib
import math
import importlib.util
import json
import re
import struct
import subprocess
import sys
import threading

import requests
import time
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SCAN_SCRIPT = REPO_ROOT / "scripts" / "audio_edge_analysis.py"
PREVIEW_DIR = REPO_ROOT / "tmp" / "lead_scan_previews"
# Previews audition the splice at the start, not the whole performance.
PREVIEW_HEAD_S = 30.0
# Hard ceiling on one preview render. A cold source is read over http, and those
# reads occasionally stall outright - ffmpeg's -reconnect retries forever and
# ffprobe has no timeout of its own, so without this the request never answers
# and the page sits on "rendering..." until its own watchdog gives up. Well
# above a normal cold render (a few seconds; ~86s has been seen on a bad read).
RENDER_TIMEOUT_S = 100
# Dropped from the end of the first track at a joint, but only when that track
# ends in a burst of encoder flush at full scale that the LAME header does not
# cover: inaudible at the end of a track, a loud click once another follows it.
# Mirrors TrackMergeService::TAIL_TRIM_S and TAIL_BURST_LEVEL so a preview
# matches the applied merge.
TAIL_TRIM_S = 0.001
TAIL_BURST_LEVEL = 20000
# Decoded from the end to reach the last millisecond.
TAIL_PROBE_S = 0.5


def load_scan_module():
    """Import audio_edge_analysis.py for its renderer. Heavy analysis deps
    (tensorflow, whisper) are only imported inside the functions that use them,
    so this stays cheap."""
    spec = importlib.util.spec_from_file_location("audio_edge_analysis", SCAN_SCRIPT)
    module = importlib.util.module_from_spec(spec)
    sys.modules["audio_edge_analysis"] = module
    spec.loader.exec_module(module)
    return module


aea = load_scan_module()
# Previews are short (PREVIEW_HEAD_S) and dominated by network reads, not CPU,
# so a tight limit just makes edits queue behind each other. Cap generously -
# enough to keep a burst from thrashing, loose enough that no edit waits.
_render_sem = threading.Semaphore(8)
_warming = set()   # urls with a cache fetch already in flight


def _warm_cache(mp3_url, dest):
    """Fetch a track into the cache once, in the background.

    Streaming from http keeps the first render fast, but every later edit to
    the same track re-reads over the network, and those reads occasionally
    stall for over a minute. One background fetch makes every render after it
    local and predictable."""
    tmp = dest.with_suffix(".part")
    try:
        dest.parent.mkdir(parents=True, exist_ok=True)
        resp = requests.get(mp3_url, timeout=180)
        resp.raise_for_status()
        tmp.write_bytes(resp.content)
        tmp.replace(dest)          # atomic: readers never see a partial file
    except Exception as e:         # noqa: BLE001 - caching is best effort
        tmp.unlink(missing_ok=True)
        print(f"  cache warm failed for {mp3_url}: {e}", file=sys.stderr)
    finally:
        _warming.discard(mp3_url)


def source_for(mp3_url, storage_dirs):
    """Local Active Storage blob, an already-cached download, or the url itself.

    Downloading a whole 15MB track before the first render would make it slow,
    so the first read streams from http and a background fetch warms the cache
    for everything after it."""
    local = aea.local_blob_path(mp3_url, storage_dirs)
    if local:
        return local
    key = Path(mp3_url.split("?")[0]).stem
    cached = aea.CACHE_DIR / f"{key}.mp3"
    if cached.exists():
        return cached
    if mp3_url not in _warming:
        _warming.add(mp3_url)
        threading.Thread(target=_warm_cache, args=(mp3_url, cached),
                         daemon=True).start()
    return mp3_url


def wav_trim_command(src, out_path, start, end, fade_in, fade_out):
    """Same trim as aea.trim_command, rendered to PCM. An mp3 carries encoder
    delay and padding, which a browser plays as a short fade at the tail; a wav
    is sample exact, so an audition ends exactly where the cut does. Previews
    are ephemeral, so the size costs nothing."""
    src = str(src)
    reconnect = ([
        "-reconnect", "1", "-reconnect_streamed", "1",
        "-reconnect_delay_max", "5",
    ] if src.startswith(("http://", "https://")) else [])
    pre = []
    if start > 0:
        seek = max(0.0, start - 1.0)
        pre = ["-ss", f"{seek:.2f}"]
        start, end = start - seek, end - seek
    return [
        "ffmpeg", "-y", "-v", "error", *reconnect, *pre, "-i", src,
        "-af", ",".join(aea.trim_filters(start, end, fade_in, fade_out)),
        "-map_metadata", "-1", "-c:a", "pcm_s16le", str(out_path),
    ]


def tail_burst(src, duration_s):
    """True when the last millisecond reaches a level real music does not.

    Seeks from the end: an -ss seek lands on a frame boundary and decodes past
    the burst. Mirrors TrackMergeService#tail_burst?; see TAIL_BURST_LEVEL."""
    cmd = [
        "ffmpeg", "-v", "error", "-sseof", f"-{TAIL_PROBE_S:.2f}",
        "-i", str(src), "-f", "s16le", "-acodec", "pcm_s16le",
        "-ac", "1", "-ar", "44100", "-",
    ]
    try:
        proc = subprocess.run(cmd, capture_output=True, timeout=RENDER_TIMEOUT_S)
    except subprocess.TimeoutExpired:
        return False
    if proc.returncode != 0 or len(proc.stdout) < 2:
        return False
    n = len(proc.stdout) // 2
    samples = struct.unpack("<%dh" % n, proc.stdout[:n * 2])
    tail = samples[-math.ceil(TAIL_TRIM_S * 44100):]
    return bool(tail) and max(abs(v) for v in tail) >= TAIL_BURST_LEVEL


def render_joint(first_url, second_url, first_duration_s, seconds, storage_dirs):
    """Tail of the first track + head of the second, butt joined.

    Rendered as one wav so the splice is heard exactly where it falls, with no
    encoder padding between the halves to mask or invent a glitch. Where the
    first track ends in an encoder flush burst its last millisecond is dropped,
    matching TrackMergeService so the preview is what the merge produces.

    The cache key carries a version so previews rendered under earlier trim
    rules are not served for the current one."""
    stamp = hashlib.sha1(
        f"v2|{first_url}|{second_url}|{first_duration_s:.2f}|{seconds:.2f}".encode()
    ).hexdigest()[:16]
    out_path = PREVIEW_DIR / f"{stamp}.wav"
    if out_path.exists():
        return out_path

    tail_start = max(0.0, first_duration_s - seconds)
    first_src = source_for(first_url, storage_dirs)
    second_src = source_for(second_url, storage_dirs)
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)

    def seg_args(src, start, end):
        reconnect = ([
            "-reconnect", "1", "-reconnect_streamed", "1",
            "-reconnect_delay_max", "5",
        ] if str(src).startswith(("http://", "https://")) else [])
        pre = ["-ss", f"{max(0.0, start - 1.0):.2f}"] if start > 0 else []
        return reconnect + pre + ["-i", str(src)]

    lead = max(0.0, tail_start - 1.0)
    trim = TAIL_TRIM_S if tail_burst(first_src, first_duration_s) else 0.0
    cmd = [
        "ffmpeg", "-y", "-v", "error",
        *seg_args(first_src, tail_start, first_duration_s),
        *seg_args(second_src, 0.0, seconds),
        "-filter_complex",
        f"[0:a]atrim=start={tail_start - lead:.2f}:"
        f"end={first_duration_s - lead - trim:.4f},"
        f"asetpts=PTS-STARTPTS,aresample=44100[a];"
        f"[1:a]atrim=start=0:end={seconds:.2f},asetpts=PTS-STARTPTS,"
        f"aresample=44100[b];"
        f"[a][b]concat=n=2:v=0:a=1[out]",
        "-map", "[out]", "-c:a", "pcm_s16le", str(out_path),
    ]
    with _render_sem:
        try:
            proc = subprocess.run(cmd, capture_output=True, timeout=RENDER_TIMEOUT_S)
        except subprocess.TimeoutExpired:
            out_path.unlink(missing_ok=True)
            raise RuntimeError(
                f"joint render timed out after {RENDER_TIMEOUT_S}s") from None
    if proc.returncode != 0:
        out_path.unlink(missing_ok=True)
        raise RuntimeError(
            f"ffmpeg failed: {proc.stderr.decode('utf-8', 'replace')[:300]}")
    return out_path


def render_preview(mp3_url, trim_start, trim_end, fade_in, fade_out, storage_dirs,
                   head_s=PREVIEW_HEAD_S, fmt="mp3"):
    # What is being judged is the splice at the start, so render only the first
    # head_s of the kept audio. Encoding all 7 minutes of a track to audition a
    # 2-second edit is what made rapid edits queue up behind slow renders.
    if head_s and trim_end - trim_start > head_s:
        trim_end = trim_start + head_s
    stamp = hashlib.sha1(
        f"{mp3_url}|{trim_start:.2f}|{trim_end:.2f}|{fade_in:.2f}|{fade_out:.2f}"
        f"|{fmt}".encode()
    ).hexdigest()[:16]
    out_path = PREVIEW_DIR / f"{stamp}.{fmt}"
    # Check the cache before touching the source: a re-request of something
    # already rendered should never wait on a download or a lock.
    if out_path.exists():
        return out_path

    t0 = time.monotonic()
    src = source_for(mp3_url, storage_dirs)
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    # seek_input: previews are re-rendered constantly while a start time is
    # tuned, and decoding a 20-minute track from 0 each time is what makes the
    # page look stuck. Same audio out, it just skips to the region first.
    # trim_command probes the source for its bitrate, and that ffprobe is itself
    # a network read on a cold track - so it gets the same deadline as the
    # render rather than being allowed to hang before ffmpeg even starts.
    try:
        if fmt == "wav":
            cmd = wav_trim_command(src, out_path, trim_start, trim_end,
                                   fade_in, fade_out)
        else:
            cmd = aea.trim_command(src, out_path, trim_start, trim_end,
                                   fade_in, fade_out, seek_input=True,
                                   probe_timeout=RENDER_TIMEOUT_S)
    except subprocess.TimeoutExpired:
        raise RuntimeError(
            f"source probe timed out after {RENDER_TIMEOUT_S}s - the track is "
            "still downloading; retry in a moment") from None
    t_probe = time.monotonic()
    # ffmpeg is CPU-bound and previews are user-triggered; cap concurrency so a
    # burst of edits cannot thrash the box, but allow a few at once so one slow
    # render does not stall the whole page.
    with _render_sem:
        t_slot = time.monotonic()
        try:
            proc = subprocess.run(cmd, capture_output=True, timeout=RENDER_TIMEOUT_S)
        except subprocess.TimeoutExpired:
            # A half-written mp3 would be served as a valid preview, so drop it.
            out_path.unlink(missing_ok=True)
            raise RuntimeError(
                f"render timed out after {RENDER_TIMEOUT_S}s - the source read "
                "stalled; the track is caching now, so a retry should be fast"
            ) from None
    t_done = time.monotonic()
    print(f"  render {trim_start:.1f}s: probe={t_probe - t0:.2f}s "
          f"wait={t_slot - t_probe:.2f}s ffmpeg={t_done - t_slot:.2f}s", file=sys.stderr)
    if proc.returncode != 0:
        out_path.unlink(missing_ok=True)
        raise RuntimeError(proc.stderr.decode()[-400:] or "ffmpeg failed")
    return out_path


class Handler(SimpleHTTPRequestHandler):
    storage_dirs = []

    def log_message(self, fmt, *args):
        sys.stderr.write(f"  {fmt % args}\n")

    def _json(self, code, payload):
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        if self.path.rstrip("/") == "/joint":
            return self._joint()
        if self.path.rstrip("/") != "/preview":
            return self._json(404, {"error": "not found"})
        try:
            length = int(self.headers.get("Content-Length", 0))
            req = json.loads(self.rfile.read(length) or b"{}")
            mp3_url = req["mp3_url"]
            trim_start = float(req["trim_start"])
            trim_end = float(req["trim_end"])
            fade_in = float(req.get("fade_in", 0.0))
            fade_out = float(req.get("fade_out", 0.0))
            fmt = str(req.get("fmt", "mp3")).lower()
        except (KeyError, TypeError, ValueError, json.JSONDecodeError) as e:
            return self._json(400, {"error": f"bad request: {e}"})

        if fmt not in ("mp3", "wav"):
            return self._json(400, {"error": "fmt must be mp3 or wav"})

        if trim_end <= trim_start:
            return self._json(400, {"error": "trim_end must be after trim_start"})

        try:
            out_path = render_preview(
                mp3_url, trim_start, trim_end, fade_in, fade_out, self.storage_dirs,
                fmt=fmt)
        except Exception as e:  # noqa: BLE001 - surfaced to the reviewer verbatim
            return self._json(500, {"error": str(e)})

        truncated = trim_end - trim_start > PREVIEW_HEAD_S
        self._json(200, {
            "url": f"/_preview/{out_path.name}",
            "head_s": int(PREVIEW_HEAD_S) if truncated else None,
        })

    def _joint(self):
        """The seam between two tracks: the tail of one butted against the head
        of the next, concatenated exactly as a merge would join them."""
        try:
            length = int(self.headers.get("Content-Length", 0))
            req = json.loads(self.rfile.read(length) or b"{}")
            first_url = req["first_mp3_url"]
            second_url = req["second_mp3_url"]
            first_duration = float(req["first_duration_s"])
            seconds = float(req.get("seconds", 2.5))
        except (KeyError, TypeError, ValueError, json.JSONDecodeError) as e:
            return self._json(400, {"error": f"bad request: {e}"})
        if seconds <= 0 or first_duration <= 0:
            return self._json(400, {"error": "seconds and first_duration_s must be positive"})

        try:
            out_path = render_joint(first_url, second_url, first_duration,
                                    seconds, self.storage_dirs)
        except Exception as e:  # noqa: BLE001 - surfaced to the reviewer verbatim
            return self._json(500, {"error": str(e)})
        self._json(200, {"url": f"/_preview/{out_path.name}"})

    def translate_path(self, path):
        clean = path.split("?", 1)[0].split("#", 1)[0]
        if clean.startswith("/_preview/"):
            name = Path(clean).name
            # Rendered names are hex digests; refuse anything else so this
            # cannot be walked out of the preview dir.
            if not re.fullmatch(r"[0-9a-f]{16}\.(mp3|wav)", name):
                return str(PREVIEW_DIR / "missing")
            return str(PREVIEW_DIR / name)
        return super().translate_path(path)

    def do_GET(self):
        """SimpleHTTPRequestHandler ignores Range and answers 200 with the whole
        body. Audio elements ask for ranges; handing them a full body where they
        expect 206 makes them re-request, and a page with dozens of clips can
        exhaust the browser's connections to this host and hang. Serve real
        partial content instead."""
        rng = self.headers.get("Range")
        path = Path(self.translate_path(self.path))
        if not rng or not path.is_file():
            return super().do_GET()

        m = re.fullmatch(r"bytes=(\d*)-(\d*)", rng.strip())
        if not m:
            return super().do_GET()
        size = path.stat().st_size
        start_raw, end_raw = m.group(1), m.group(2)
        if start_raw:
            start = int(start_raw)
            end = int(end_raw) if end_raw else size - 1
        elif end_raw:  # suffix form: last N bytes
            start, end = max(0, size - int(end_raw)), size - 1
        else:
            return super().do_GET()
        if start >= size:
            self.send_response(416)
            self.send_header("Content-Range", f"bytes */{size}")
            self.end_headers()
            return
        end = min(end, size - 1)
        length = end - start + 1

        self.send_response(206)
        self.send_header("Content-Type", self.guess_type(str(path)))
        self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
        self.send_header("Content-Length", str(length))
        self.send_header("Accept-Ranges", "bytes")
        self.end_headers()
        with path.open("rb") as f:
            f.seek(start)
            remaining = length
            while remaining > 0:
                chunk = f.read(min(64 * 1024, remaining))
                if not chunk:
                    break
                self.wfile.write(chunk)
                remaining -= len(chunk)

    def send_response(self, code, message=None):
        super().send_response(code, message)
        # Advertise range support so media elements seek rather than refetch.
        # Sent after the status line, where headers belong.
        if self.command == "GET" and code == 200:
            self.send_header("Accept-Ranges", "bytes")


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--dir", type=Path, required=True, help="scan output dir to serve")
    p.add_argument("--port", type=int, default=8770)
    p.add_argument("--storage-dir", type=Path, action="append", default=[],
                   help="extra Active Storage root to resolve blobs from")
    args = p.parse_args()

    # A single server can root at the scan root and serve every year at
    # /<year>/review.html, so the index page's relative links just work and
    # there is no port to track per year.
    pages = sorted(args.dir.glob("*/review.html")) + \
        ([args.dir / "review.html"] if (args.dir / "review.html").exists() else [])
    if not pages:
        sys.exit(f"No review.html under {args.dir}")

    Handler.storage_dirs = args.storage_dir + aea.STORAGE_CANDIDATES
    handler = partial(Handler, directory=str(args.dir))
    server = ThreadingHTTPServer(("127.0.0.1", args.port), handler)
    base = f"http://127.0.0.1:{args.port}"
    if (args.dir / "index.html").exists():
        print(f"Index:  {base}/index.html")
    for page in pages:
        rel_path = page.relative_to(args.dir)
        print(f"Review: {base}/{rel_path}")
    print("Ctrl-C to stop.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")


if __name__ == "__main__":
    main()
