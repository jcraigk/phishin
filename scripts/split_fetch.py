#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11,<3.13"
# dependencies = [
#   "requests",
#   "rarfile",
# ]
# ///
"""Fetch the sources the split repair queue needs.

Reads the show links captured from the Phish Spreadsheet and downloads one
archive per show into a directory split_verify.py can read, unpacking archives
so the individual songs are visible.

Downloads are skipped when a show already has audio, so this can be re-run to
pick up where it stopped. Nothing here decides anything about the audio - that
is split_verify.py's job.

    uv run scripts/split_fetch.py --links sheet_links.json \
        --report split_report.json --out ~/Desktop/sources --limit 5
"""

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

PAD_MIN_S = 1.90
PAD_MAX_S = 2.10
AUDIO_EXT = {".mp3", ".flac", ".wav", ".m4a", ".shn"}
ARCHIVE_EXT = {".rar", ".zip", ".7z", ".tar", ".gz"}
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"


def queue_dates(report_path):
    """Shows in the repair queue, worst first.

    The two second pad shows are left out for the same reason split_verify.py
    leaves them out: their silence is a mastering habit, and downloading 45
    shows of sources to confirm that would be wasted bandwidth.
    """
    rows = json.loads(Path(report_path).read_text())["tracks"]
    mid = [r for r in rows if r["followed_in_set"]]
    by_show = {}
    for row in mid:
        by_show.setdefault(row["date"], []).append(row)
    queue = {}
    for date, items in by_show.items():
        padded = sum(1 for r in items if PAD_MIN_S <= r["trailing_zeros_s"] <= PAD_MAX_S)
        if padded >= max(2, len(items) * 0.5):
            continue
        queue[date] = items
    return sorted(queue, key=lambda d: (
        -max(r["trailing_zeros_s"] for r in queue[d]), -len(queue[d])))


def has_audio(directory):
    return any(p.suffix.lower() in AUDIO_EXT for p in directory.rglob("*"))


def download(url, dest):
    import requests
    with requests.get(url, timeout=600, stream=True,
                      allow_redirects=True, headers={"User-Agent": UA}) as resp:
        resp.raise_for_status()
        with dest.open("wb") as handle:
            for chunk in resp.iter_content(1 << 20):
                handle.write(chunk)
    return dest


def unpack(archive, target):
    if shutil.which("unar") is None:
        return False, "unar is not installed (brew install unar)"
    proc = subprocess.run(["unar", "-q", "-f", "-o", str(target), str(archive)],
                          capture_output=True, timeout=900)
    if proc.returncode != 0:
        return False, proc.stderr.decode(errors="replace")[:120]
    # unar makes a folder per archive; lift the audio up so every show directory
    # has the same shape whatever the archive happened to contain.
    for path in list(target.rglob("*")):
        if path.suffix.lower() in AUDIO_EXT and path.parent != target:
            dest = target / path.name
            if not dest.exists():
                path.rename(dest)
    for path in sorted(target.glob("*"), reverse=True):
        if path.is_dir() and not any(path.iterdir()):
            path.rmdir()
    return True, ""


def fetch_show(date, link, out_root):
    target = out_root / date
    target.mkdir(parents=True, exist_ok=True)
    if has_audio(target):
        return "have", ""
    url = link["url"]
    name = url.split("/")[-1].split("?")[0] or f"{date}.bin"
    suffix = Path(name).suffix.lower()
    archive = target / name
    try:
        download(url, archive)
    except Exception as exc:  # noqa: BLE001 - one bad link must not stop the run
        return "failed", f"{type(exc).__name__}: {exc}"[:120]
    if suffix in ARCHIVE_EXT:
        ok, err = unpack(archive, target)
        if not ok:
            return "failed", err
        archive.unlink(missing_ok=True)
    elif suffix not in AUDIO_EXT:
        return "failed", f"not audio or an archive: {name}"
    return ("ok", "") if has_audio(target) else ("failed", "no audio in the archive")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--links", required=True)
    ap.add_argument("--report", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--dates", help="comma separated, instead of the queue order")
    args = ap.parse_args()

    links = json.loads(Path(args.links).read_text())
    dates = (args.dates.split(",") if args.dates else queue_dates(args.report))
    if args.limit:
        dates = dates[:args.limit]
    out_root = Path(args.out).expanduser()
    out_root.mkdir(parents=True, exist_ok=True)

    counts = {"ok": 0, "have": 0, "failed": 0, "nolink": 0}
    for i, date in enumerate(dates, 1):
        link = links.get(date)
        if not link:
            counts["nolink"] += 1
            print(f"[{i}/{len(dates)}] {date}  no source listed")
            continue
        status, detail = fetch_show(date, link, out_root)
        counts[status] += 1
        note = f"  {detail}" if detail else ""
        print(f"[{i}/{len(dates)}] {date}  {status}{note}", flush=True)

    print(f"\ndownloaded {counts['ok']}, already had {counts['have']}, "
          f"failed {counts['failed']}, no link {counts['nolink']}")
    print(f"-> {out_root}")


if __name__ == "__main__":
    main()
