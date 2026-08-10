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
import importlib.util
import json
import re
import subprocess
import sys
import threading
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SCAN_SCRIPT = REPO_ROOT / "scripts" / "audio_edge_analysis.py"
PREVIEW_DIR = REPO_ROOT / "tmp" / "lead_scan_previews"


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
_render_lock = threading.Lock()


def source_for(mp3_url, storage_dirs):
    """Local Active Storage blob if we have one, else the cached download."""
    local = aea.local_blob_path(mp3_url, storage_dirs)
    return local or aea.download_audio(mp3_url)


def render_preview(mp3_url, trim_start, trim_end, fade_in, fade_out, storage_dirs):
    src = source_for(mp3_url, storage_dirs)
    stamp = hashlib.sha1(
        f"{mp3_url}|{trim_start:.2f}|{trim_end:.2f}|{fade_in:.2f}|{fade_out:.2f}".encode()
    ).hexdigest()[:16]
    out_path = PREVIEW_DIR / f"{stamp}.mp3"
    if out_path.exists():
        return out_path

    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    cmd = aea.trim_command(src, out_path, trim_start, trim_end, fade_in, fade_out)
    # ffmpeg is CPU-bound and previews are user-triggered; one at a time keeps a
    # burst of edits from thrashing the box.
    with _render_lock:
        proc = subprocess.run(cmd, capture_output=True)
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
        except (KeyError, TypeError, ValueError, json.JSONDecodeError) as e:
            return self._json(400, {"error": f"bad request: {e}"})

        if trim_end <= trim_start:
            return self._json(400, {"error": "trim_end must be after trim_start"})

        try:
            out_path = render_preview(
                mp3_url, trim_start, trim_end, fade_in, fade_out, self.storage_dirs)
        except Exception as e:  # noqa: BLE001 - surfaced to the reviewer verbatim
            return self._json(500, {"error": str(e)})

        self._json(200, {"url": f"/_preview/{out_path.name}"})

    def translate_path(self, path):
        clean = path.split("?", 1)[0].split("#", 1)[0]
        if clean.startswith("/_preview/"):
            name = Path(clean).name
            # Rendered names are hex digests; refuse anything else so this
            # cannot be walked out of the preview dir.
            if not re.fullmatch(r"[0-9a-f]{16}\.mp3", name):
                return str(PREVIEW_DIR / "missing")
            return str(PREVIEW_DIR / name)
        return super().translate_path(path)


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--dir", type=Path, required=True, help="scan output dir to serve")
    p.add_argument("--port", type=int, default=8770)
    p.add_argument("--storage-dir", type=Path, action="append", default=[],
                   help="extra Active Storage root to resolve blobs from")
    args = p.parse_args()

    if not (args.dir / "review.html").exists():
        sys.exit(f"No review.html in {args.dir}")

    Handler.storage_dirs = args.storage_dir + aea.STORAGE_CANDIDATES
    handler = partial(Handler, directory=str(args.dir))
    server = ThreadingHTTPServer(("127.0.0.1", args.port), handler)
    print(f"Review: http://127.0.0.1:{args.port}/review.html")
    print("Ctrl-C to stop.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")


if __name__ == "__main__":
    main()
