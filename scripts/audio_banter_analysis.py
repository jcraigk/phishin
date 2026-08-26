#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11,<3.13"
# dependencies = [
#   "numpy",
#   "openpyxl",
#   "requests",
# ]
# ///
"""Find banter tracks a show is missing and prove where they go by audio.

The original import skipped many taper-labelled "banter" files. For each show
this script:

  1. finds the archive.org item the show was cut from, by matching the item's
     per-file lengths against phish.in's track durations (the catalog's tracks
     are exact butt-cuts of one transfer, so a real match is to the ms);
  2. lists the source files phish.in has no track for, and treats the ones the
     taper labelled banter/talking/etc. as candidates;
  3. downloads just those FLACs (verified against the item's .ffp/.md5), and
     scores the two joints each one would create - tail of the track before it
     spliced to its head, its tail spliced to the head of the track after -
     plus the "direct" joint phish.in currently has between those two tracks.
     If the banter belongs there, both new joints are continuous and the
     direct one is the seam.

Output: <out-dir>/report.json, review.html (listenable joints, approve
checkboxes, approved.json export) and <out-dir>/<date>/*.flac.

Usage (normally via the rake tasks):
  uv run scripts/audio_banter_analysis.py --out-dir data/banter_scan --from-notes
  uv run scripts/audio_banter_analysis.py --out-dir data/banter_scan --dates 1991-05-17,1992-11-20
  uv run scripts/audio_banter_analysis.py --out-dir data/banter_scan --rebuild
"""

import argparse
import hashlib
import html
import importlib.util
import json
import re
import sys
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict, dataclass, field
from pathlib import Path

import numpy as np
import requests

REPO_ROOT = Path(__file__).resolve().parent.parent
JUNCTION_SCRIPT = REPO_ROOT / "scripts" / "audio_junction_analysis.py"
API_BASE = "https://phish.in/api/v2"
SITE_BASE = "https://phish.in"
ARCHIVE = "https://archive.org"
# The Phish Spreadsheet: the fuller source list, for shows archive.org lacks.
SPREADSHEET_ID = "1yAXu83gJBz08cW5OXoqNuN1IbvDXD2vCrDKj4zn1qmU"
SPREADSHEET_URL = f"https://docs.google.com/spreadsheets/d/{SPREADSHEET_ID}"
FIRST_YEAR, LAST_YEAR = 1983, 2026

DURATION_TOL_S = 0.15    # source file vs phish.in track, same transfer
JOINT_CLIP_S = 2.5       # audio on each side of a joint in the rendered clips
MIN_MATCH_RATIO = 0.5    # tracks matched / tracks with audio to accept an item
FETCH_WORKERS = 8

# Taper labels for band members talking. Kept in step with the notes scanner
# that produced the first report (tmp/docs/find_missing_banter.rb).
BANTER_RE = re.compile(
    r"\b(banter|speaks?|talking|chatter|dialog(ue)?|monolog(ue)?|stage talk)\b"
    r"|\b(trey|fish|fishman|page|mike)\b.*\b(thanks|talks?|rap|story|speech|announcement)\b"
    r"|\b(talks?)\b.*\b(trey|fish|fishman|page|mike)\b",
    re.I)
NOT_BANTER_RE = re.compile(
    r"speak to me|no smoking|venue announcement|post show|thanks? (to|you)|thanx"
    r"|talking heads|conan", re.I)
# Lines that are only room noise, not anyone talking.
NOISE_ONLY_RE = re.compile(
    r"^[\s\W]*(set\s*\w*\s*)?(intro|outro|crowd|crowd noise|tuning|applause|encore break"
    r"|encore call|announcer|mic checks?|pa announcement)[\s\W]*$", re.I)
PROSE_RE = re.compile(r"[.!?]\s+\w|\b(was|were|is|are|had|has|the band|this|that|which)\b"
                      r".*\b(and|but|so|because)\b", re.I)
TRACK_TITLE_RE = re.compile(r"banter|speaks|talk|chatter|announcement|rap\b", re.I)


def load_junction_module():
    spec = importlib.util.spec_from_file_location("audio_junction_analysis", JUNCTION_SCRIPT)
    module = importlib.util.module_from_spec(spec)
    sys.modules["audio_junction_analysis"] = module
    spec.loader.exec_module(module)
    return module


aja = load_junction_module()


# ---------------------------------------------------------------------------
# Notes scan (which shows to look at)


def banter_note_line(raw):
    line = raw.strip()
    if not line or len(line) > 70:
        return False
    if line.startswith(("*", "-", "#", "[", "note", "Note", "http", "Source", "Lineage")):
        return False
    if PROSE_RE.search(line) or NOISE_ONLY_RE.match(line) or NOT_BANTER_RE.search(line):
        return False
    if not BANTER_RE.search(line):
        return False
    words = len(re.sub(r"^[\W\d]+", "", line).split())
    return words <= 7 or bool(re.match(r"^\W*(d\d)?t?\d", line, re.I))


def note_hits(taper_notes):
    lines = [l.rstrip() for l in (taper_notes or "").splitlines()]
    hits = []
    for i, line in enumerate(lines):
        if not banter_note_line(line):
            continue
        prev = next((l.strip() for l in reversed(lines[:i]) if l.strip()), None)
        nxt = next((l.strip() for l in lines[i + 1:] if l.strip()), None)
        hits.append({"line": line.strip(), "prev": prev, "next": nxt})
    return hits


def notes_line_for(file_name, hits):
    """The notes entry for a source file, by its track token (d1t09 -> d1t09, t09, 09)."""
    stem = Path(file_name).stem.lower()
    m = re.search(r"(d\d+)?t(\d+)$", stem)
    if not m:
        return next((h["line"] for h in hits if stem in h["line"].lower()), None)
    disc, num = m.group(1), int(m.group(2))
    patterns = [rf"\b{disc}t0*{num}\b" if disc else None, rf"\bt0*{num}\b",
                rf"^\W*0*{num}[\.\)\-\s:]"]
    for pat in patterns:
        if not pat:
            continue
        for h in hits:
            if re.search(pat, h["line"], re.I):
                return h["line"]
    return None


def notes_line_by_neighbors(hits, after, before):
    """A notes entry sitting between lines that name the anchor tracks."""
    def names(track):
        if not track:
            return []
        return [re.sub(r"[^a-z0-9 ]", "", p.lower()).strip()
                for p in re.split(r"\s*-?>\s*", track["title"]) if p.strip()]
    def mentions(line, track):
        line = re.sub(r"[^a-z0-9 ]", "", (line or "").lower())
        return any(n and n in line for n in names(track))
    for h in hits:
        if (after and mentions(h["prev"], after)) or (before and mentions(h["next"], before)):
            return h["line"]
    return None


def fetch_show(date):
    resp = requests.get(f"{API_BASE}/shows/{date}", timeout=30)
    resp.raise_for_status()
    return resp.json()


def fetch_year_dates(year):
    dates = []
    page = 1
    while True:
        resp = requests.get(f"{API_BASE}/shows", timeout=60,
                            params={"year": year, "per_page": 100, "page": page})
        resp.raise_for_status()
        data = resp.json()
        dates += [s["date"] for s in data["shows"] if s.get("audio_status") != "missing"]
        if page >= data.get("total_pages", 1):
            return dates
        page += 1


def dates_from_notes():
    """Shows whose notes list more banter entries than they have banter tracks."""
    with ThreadPoolExecutor(FETCH_WORKERS) as pool:
        years = list(pool.map(fetch_year_dates, range(FIRST_YEAR, LAST_YEAR + 1)))
    all_dates = sorted(d for year in years for d in year)
    print(f"scanning taper notes of {len(all_dates)} shows", file=sys.stderr)

    def check(date):
        show = fetch_show(date)
        hits = note_hits(show.get("taper_notes"))
        if not hits:
            return None
        have = [t for t in show["tracks"]
                if TRACK_TITLE_RE.search(t["title"])
                or any(s["title"] == "Banter" for s in t.get("songs", []))]
        return date if len(hits) > len(have) else None

    with ThreadPoolExecutor(FETCH_WORKERS) as pool:
        flagged = [d for d in pool.map(check, all_dates) if d]
    print(f"{len(flagged)} shows flagged by notes", file=sys.stderr)
    return flagged


# ---------------------------------------------------------------------------
# archive.org source resolution


def parse_length(value):
    if value is None:
        return None
    s = str(value).strip()
    if re.fullmatch(r"\d+(\.\d+)?", s):
        return float(s)
    m = re.fullmatch(r"(?:(\d+):)?(\d+):(\d+(?:\.\d+)?)", s)
    if m:
        h, mi, se = m.groups()
        return int(h or 0) * 3600 + int(mi) * 60 + float(se)
    return None


def archive_items(date):
    resp = requests.get(f"{ARCHIVE}/advancedsearch.php", timeout=60, params={
        "q": f"phish AND date:[{date} TO {date}]",
        "fl[]": ["identifier", "title"], "rows": 50, "output": "json",
    })
    resp.raise_for_status()
    return [d["identifier"] for d in resp.json()["response"]["docs"]]


def archive_metadata(identifier):
    resp = requests.get(f"{ARCHIVE}/metadata/{identifier}", timeout=60)
    resp.raise_for_status()
    data = resp.json()
    files = []
    for f in data.get("files", []):
        name = f["name"]
        if not name.lower().endswith((".flac", ".shn", ".wav")):
            continue
        title = f.get("title") or Path(name).stem
        files.append({"name": name, "title": title, "length": parse_length(f.get("length"))})
    files.sort(key=lambda f: f["name"])
    checksums = [f["name"] for f in data.get("files", [])
                 if f["name"].lower().endswith((".ffp", ".md5", ".txt"))]
    return {"identifier": identifier, "files": files, "checksum_files": checksums,
            "description": data.get("metadata", {}).get("description", "")}


def match_item(files, tracks):
    """Map source files to phish.in tracks by duration. Returns
    (file_index -> track ids, track_id -> file indexes, matched track count)."""
    durations = {t["id"]: t["duration"] / 1000.0 for t in tracks if t.get("mp3_url")}
    file_to_tracks, track_to_files = {}, {}

    def close(a, b):
        return a is not None and abs(a - b) <= DURATION_TOL_S

    # One file, one track.
    for i, f in enumerate(files):
        for tid, dur in durations.items():
            if tid in track_to_files:
                continue
            if close(f["length"], dur):
                file_to_tracks[i] = [tid]
                track_to_files[tid] = [i]
                break
    # One track holding two or three consecutive files (TMWSIY > Avenu > TMWSIY).
    for tid, dur in durations.items():
        if tid in track_to_files:
            continue
        for i in range(len(files)):
            for n in (2, 3):
                group = files[i:i + n]
                if len(group) < n or any(j in file_to_tracks for j in range(i, i + n)):
                    continue
                lengths = [g["length"] for g in group]
                if None in lengths:
                    continue
                if close(sum(lengths), dur):
                    for j in range(i, i + n):
                        file_to_tracks[j] = [tid]
                    track_to_files[tid] = list(range(i, i + n))
                    break
            if tid in track_to_files:
                break
    # One file split into two or three consecutive tracks.
    ordered = [t for t in sorted(tracks, key=lambda t: t["position"]) if t["id"] in durations]
    for i, f in enumerate(files):
        if i in file_to_tracks or f["length"] is None:
            continue
        for k in range(len(ordered)):
            for n in (2, 3):
                group = ordered[k:k + n]
                if len(group) < n or any(t["id"] in track_to_files for t in group):
                    continue
                if close(sum(durations[t["id"]] for t in group), f["length"]):
                    file_to_tracks[i] = [t["id"] for t in group]
                    for t in group:
                        track_to_files[t["id"]] = [i]
                    break
            if i in file_to_tracks:
                break
    return file_to_tracks, track_to_files, len(track_to_files), len(durations)


def local_item(date, out_dir):
    """A hand-fetched source (e.g. from the Phish Spreadsheet) dropped into
    <out-dir>/<date>/source/, presented like an archive.org item."""
    src_dir = out_dir / date / "source"
    if not src_dir.is_dir():
        return None
    files = []
    for path in sorted(src_dir.rglob("*")):
        if not path.is_file() or path.suffix.lower() not in (".flac", ".shn", ".wav", ".mp3"):
            continue
        try:
            length = aja.probe_duration(path)
        except Exception:
            length = None
        out = aja.run(["ffprobe", "-v", "error", "-show_entries", "format_tags=title",
                       "-of", "default=noprint_wrappers=1:nokey=1", str(path)])
        title = out.stdout.decode().strip() or path.stem
        files.append({"name": str(path.relative_to(src_dir)), "title": title,
                      "length": length, "path": str(path)})
    if not files:
        return None
    return {"identifier": f"local:{src_dir}", "files": files, "checksum_files": [],
            "description": "", "local": True}


def resolve_source(date, tracks, out_dir):
    """Best source for the show - a local drop-in, else the archive.org item
    whose file lengths match phish.in - or None with the candidates tried."""
    tried = []
    best = None
    local = local_item(date, out_dir)
    if local:
        f2t, t2f, matched, total = match_item(local["files"], tracks)
        tried.append({"identifier": local["identifier"], "matched": matched, "total": total,
                      "files": len(local["files"])})
        if total and matched / total >= MIN_MATCH_RATIO:
            return {"meta": local, "file_to_tracks": f2t, "track_to_files": t2f,
                    "matched": matched, "total": total}, tried
    for identifier in archive_items(date):
        try:
            meta = archive_metadata(identifier)
        except requests.RequestException as e:
            tried.append({"identifier": identifier, "error": str(e)})
            continue
        f2t, t2f, matched, total = match_item(meta["files"], tracks)
        ratio = matched / total if total else 0.0
        tried.append({"identifier": identifier, "matched": matched, "total": total,
                      "files": len(meta["files"])})
        if ratio >= MIN_MATCH_RATIO and (best is None or matched > best["matched"]):
            best = {"meta": meta, "file_to_tracks": f2t, "track_to_files": t2f,
                    "matched": matched, "total": total}
    return best, tried


def spreadsheet_row(date, out_dir):
    """Download link, lineage and notes for a date from the Phish Spreadsheet."""
    import datetime
    import openpyxl
    path = out_dir / "phish_spreadsheet.xlsx"
    if not path.exists():
        resp = requests.get(f"{SPREADSHEET_URL}/export?format=xlsx", timeout=120)
        resp.raise_for_status()
        path.write_bytes(resp.content)
    wb = openpyxl.load_workbook(path, data_only=False, read_only=True)
    year = date[:4]
    sheet = wb[year] if year in wb.sheetnames else wb["'83-87"] if "'83-87" in wb.sheetnames else None
    if sheet is None:
        return None
    want = datetime.date.fromisoformat(date)
    for row in sheet.iter_rows(values_only=True):
        first = row[0]
        if isinstance(first, datetime.datetime):
            first = first.date()
        if first != want:
            continue
        cells = [c for c in row if c is not None]
        link = next((m.group(1) for c in cells
                     for m in [re.search(r'HYPERLINK\("([^"]+)"', str(c))]
                     if m and "phish.net" not in m.group(1)), None)
        return {"link": link, "source": str(row[8]) if len(row) > 8 and row[8] else "",
                "notes": str(row[9]) if len(row) > 9 and row[9] else ""}
    return None


# ---------------------------------------------------------------------------
# Download + verify


def flac_header_md5(path):
    with open(path, "rb") as fh:
        head = fh.read(42)
    if head[:4] != b"fLaC" or (head[4] & 0x7F) != 0:
        return None
    return head[26:42].hex()


def expected_md5s(identifier, checksum_files):
    """{"ffp": {name: audio md5}, "file": {name: whole-file md5}} from the item's
    checksum listings. An .ffp fingerprints the decoded audio (what the FLAC
    STREAMINFO header carries); an .md5 hashes the file bytes."""
    found = {"ffp": {}, "file": {}}
    for name in checksum_files:
        try:
            text = requests.get(f"{ARCHIVE}/download/{identifier}/{name}", timeout=60).text
        except requests.RequestException:
            continue
        for m in re.finditer(r"([^\s:*]+\.flac)\s*:\s*([0-9a-fA-F]{32})", text):
            found["ffp"][Path(m.group(1)).name] = m.group(2).lower()
        for m in re.finditer(r"([0-9a-fA-F]{32})\s+\*?([^\s]+\.flac)", text):
            found["file"][Path(m.group(2)).name] = m.group(1).lower()
    return found


def verify_download(path, md5s):
    """True/False against the item's checksums, None when it lists none."""
    name = Path(path).name
    if name in md5s["ffp"]:
        return flac_header_md5(path) == md5s["ffp"][name]
    if name in md5s["file"]:
        h = hashlib.md5()
        with open(path, "rb") as fh:
            for chunk in iter(lambda: fh.read(1 << 20), b""):
                h.update(chunk)
        return h.hexdigest() == md5s["file"][name]
    return None


def download_source_file(identifier, name, dest_dir):
    dest = dest_dir / Path(name).name
    if dest.exists():
        return dest
    dest_dir.mkdir(parents=True, exist_ok=True)
    url = f"{ARCHIVE}/download/{identifier}/{name}"
    print(f"  downloading {url}", file=sys.stderr)
    tmp = dest.with_suffix(dest.suffix + ".part")
    # archive.org's mirrors throw intermittent 5xx; a retry usually lands elsewhere.
    for attempt in range(3):
        try:
            with requests.get(url, stream=True, timeout=300) as resp:
                resp.raise_for_status()
                with open(tmp, "wb") as fh:
                    for chunk in resp.iter_content(1 << 20):
                        fh.write(chunk)
            tmp.rename(dest)
            return dest
        except requests.RequestException as e:
            if attempt == 2:
                raise
            print(f"  retrying after {e}", file=sys.stderr)
    return dest


# ---------------------------------------------------------------------------
# Joints


@dataclass
class Edge:
    head: np.ndarray
    tail: np.ndarray


def load_track_edges(mp3_url):
    path = aja.download_audio(mp3_url)
    duration = aja.probe_duration(path)
    window = min(aja.EDGE_WINDOW_S, duration)
    return Edge(head=aja.decode_segment(path, 0, window),
                tail=aja.decode_segment(path, max(duration - window, 0), window))


def load_file_edges(path):
    duration = aja.probe_duration(path)
    window = min(aja.EDGE_WINDOW_S, duration)
    return Edge(head=aja.decode_segment(path, 0, window),
                tail=aja.decode_segment(path, max(duration - window, 0), window))


def render_preview(src, out_path):
    """Listenable mp3 of the whole source file (128k; the FLAC stays on disk)."""
    if not out_path.exists():
        aja.run(["ffmpeg", "-v", "error", "-y", "-i", str(src), "-b:a", "128k", str(out_path)])
    return out_path.name


def joint(tail_edge, head_edge, clip_path):
    j = aja.score_junction(tail_edge.tail, head_edge.head)
    n = int(JOINT_CLIP_S * aja.SAMPLE_RATE)
    spliced = np.concatenate([tail_edge.tail[-n:], head_edge.head[:n]]).astype(np.float32)
    import tempfile
    with tempfile.NamedTemporaryFile(suffix=".f32") as tmp:
        tmp.write(spliced.tobytes())
        tmp.flush()
        aja.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(aja.SAMPLE_RATE),
                 "-ac", "1", "-i", tmp.name, "-b:a", "128k", str(clip_path)])
    return {"score": round(j.score, 2), "verdict": aja.classify(j.score),
            "detail": j.parts(), "clip": clip_path.name}


# ---------------------------------------------------------------------------
# Per-show analysis


@dataclass
class Candidate:
    date: str
    key: str
    source_item: str
    source_file: str
    source_title: str
    length_s: float
    source_path: str
    md5_verified: bool | None
    after_id: int | None
    after_title: str | None
    after_position: int | None
    before_id: int | None
    before_title: str | None
    before_position: int | None
    status: str                      # candidate | already_present | unanchored
    note: str = ""
    joints: dict = field(default_factory=dict)
    notes_line: str | None = None
    after_set: str | None = None
    before_set: str | None = None
    preview: str | None = None       # rendered mp3 of the whole source file, in clips/
    members: list = field(default_factory=list)  # every file in the run (1 for a lone file)


@dataclass
class ShowReport:
    date: str
    venue: str
    url: str
    note_hits: list
    source_item: str | None
    matched: int
    total: int
    tried: list
    unmatched_files: list
    candidates: list
    error: str | None = None
    spreadsheet: dict | None = None
    filler_skipped: list = field(default_factory=list)


def analyze_show(date, out_dir):
    show = fetch_show(date)
    tracks = sorted(show["tracks"], key=lambda t: t["position"])
    by_id = {t["id"]: t for t in tracks}
    hits = note_hits(show.get("taper_notes"))
    report = ShowReport(date=date, venue=show.get("venue_name") or "",
                        url=f"{SITE_BASE}/{date}", note_hits=hits, source_item=None,
                        matched=0, total=0, tried=[], unmatched_files=[], candidates=[])
    best, tried = resolve_source(date, tracks, out_dir)
    report.tried = tried
    if best is None:
        report.error = ("no archive.org item for this date" if not tried
                        else "no archive.org item matches phish.in's track durations")
        try:
            report.spreadsheet = spreadsheet_row(date, out_dir)
        except Exception as e:
            report.spreadsheet = {"link": None, "source": "", "notes": f"lookup failed: {e}"}
        return report

    meta = best["meta"]
    files = meta["files"]
    f2t = best["file_to_tracks"]
    report.source_item = meta["identifier"]
    report.matched, report.total = best["matched"], best["total"]
    # Filler is bonus material tacked onto the end of an item (a demo, another
    # show), not part of this performance. When the item or the notes call it
    # out, the trailing run of unmatched files is it.
    filler_text = f"{meta.get('description', '')}\n{show.get('taper_notes') or ''}"
    report.filler_skipped = []
    if re.search(r"\b(filler|bonus)\b", filler_text, re.I) and f2t:
        last_matched = max(f2t)
        trailing = [i for i in range(last_matched + 1, len(files))]
        report.filler_skipped = [files[i]["title"] for i in trailing]
        files = files[:last_matched + 1]
    report.unmatched_files = [
        {"name": f["name"], "title": f["title"], "length": f["length"],
         "banter": bool(BANTER_RE.search(f["title"]) and not NOT_BANTER_RE.search(f["title"]))}
        for i, f in enumerate(files) if i not in f2t
    ]

    show_dir = out_dir / date
    clip_dir = out_dir / "clips"
    clip_dir.mkdir(parents=True, exist_ok=True)
    md5s = None
    edge_cache = {}

    def track_edges(tid):
        if tid not in edge_cache:
            edge_cache[tid] = load_track_edges(by_id[tid]["mp3_url"])
        return edge_cache[tid]

    def fetch(f):
        return (Path(f["path"]) if meta.get("local")
                else download_source_file(meta["identifier"], f["name"], show_dir))

    def checksums():
        nonlocal md5s
        if md5s is None:
            md5s = (expected_md5s(meta["identifier"], meta["checksum_files"])
                    if not meta.get("local") else {"ffp": {}, "file": {}})
        return md5s

    # Consecutive unmatched files form one run: a lone banter file, or a whole
    # stretch (even a set) phish.in never got. Joints are only meaningful at a
    # run's ends, so only its first and last files are fetched.
    runs, i = [], 0
    while i < len(files):
        if i in f2t:
            i += 1
            continue
        j = i
        while j + 1 < len(files) and (j + 1) not in f2t:
            j += 1
        runs.append((i, j))
        i = j + 1

    for first, last in runs:
        prev_idx = next((j for j in range(first - 1, -1, -1) if j in f2t), None)
        next_idx = next((j for j in range(last + 1, len(files)) if j in f2t), None)
        after = by_id[f2t[prev_idx][-1]] if prev_idx is not None else None
        before = by_id[f2t[next_idx][0]] if next_idx is not None else None
        members = files[first:last + 1]
        f = members[0]
        key = f"{date}:{Path(f['name']).stem}"
        cand = Candidate(
            date=date, key=key, source_item=meta["identifier"], source_file=f["name"],
            source_title=f["title"], length_s=f["length"] or 0.0, source_path="",
            md5_verified=None,
            after_id=after and after["id"], after_title=after and after["title"],
            after_position=after and after["position"],
            before_id=before and before["id"], before_title=before and before["title"],
            before_position=before and before["position"],
            after_set=after and after.get("set_name"),
            before_set=before and before.get("set_name"),
            status="candidate" if len(members) == 1 else "run",
            members=[{"name": m["name"], "title": m["title"], "length": m["length"]}
                     for m in members],
        )
        cand.notes_line = (notes_line_for(f["name"], hits)
                           or notes_line_by_neighbors(hits, after, before))
        if after is None or before is None:
            if cand.status == "candidate":
                cand.status = "unanchored"
        elif before["position"] != after["position"] + 1:
            between = [t for t in tracks if after["position"] < t["position"] < before["position"]]
            same = [t for t in between
                    if abs(t["duration"] / 1000.0 - (f["length"] or -1)) <= DURATION_TOL_S]
            if same and len(members) == 1:
                cand.status = "already_present"
                cand.note = f"phish.in has {same[0]['title']} ({same[0]['duration'] / 1000:.1f}s) here"
            else:
                cand.note = "phish.in already has " + \
                    ", ".join(t["title"] for t in between) + " between these"
        if cand.status == "already_present":
            report.candidates.append(cand)
            continue

        head_path = fetch(members[0])
        tail_path = head_path if len(members) == 1 else fetch(members[-1])
        cand.source_path = str(head_path)
        cand.md5_verified = verify_download(head_path, checksums())
        stem = re.sub(r"[^a-z0-9]+", "-", key.lower())
        cand.preview = render_preview(head_path, clip_dir / f"{stem}-full.mp3")
        if len(members) > 1:
            cand.members[-1]["preview"] = render_preview(
                tail_path, clip_dir / f"{stem}-last-full.mp3")
        head_edge = load_file_edges(head_path)
        tail_edge = head_edge if len(members) == 1 else load_file_edges(tail_path)
        cand.joints = {}
        if after:
            cand.joints["in"] = joint(track_edges(after["id"]), head_edge, clip_dir / f"{stem}-in.mp3")
        if before:
            cand.joints["out"] = joint(tail_edge, track_edges(before["id"]), clip_dir / f"{stem}-out.mp3")
        if after and before:
            cand.joints["direct"] = joint(track_edges(after["id"]), track_edges(before["id"]),
                                          clip_dir / f"{stem}-direct.mp3")
        report.candidates.append(cand)
    return report


# ---------------------------------------------------------------------------
# Review page


def esc(s):
    return html.escape(str(s if s is not None else ""))


def tried_summary(t):
    if t.get("error"):
        return t["error"]
    return f"{t['matched']}/{t['total']} tracks matched, {t['files']} files"


def joint_cell(j):
    if not j:
        return "<td></td>"
    return (f'<td class="{j["verdict"].lower()}">'
            f'<audio controls preload="none" src="clips/{esc(j["clip"])}"></audio></td>')


def placement_text(c):
    if c.after_id is None and c.before_id is not None:
        return f"Start of {esc(c.before_set)}"
    if c.before_id is None and c.after_id is not None:
        return f"End of {esc(c.after_set)}"
    return f"Before: {esc(c.after_title)}<br>After: {esc(c.before_title)}"


def source_cell(c, md5=None):
    def player(name):
        return f'<audio controls preload="none" src="clips/{esc(name)}"></audio>'
    if len(c.members) > 1:
        first, last = c.members[0], c.members[-1]
        middle = ", ".join(esc(m["title"]) for m in c.members[1:-1])
        body = (f"<b>{len(c.members)} consecutive files not on phish.in</b><br>"
                f"{player(c.preview)}<br>{esc(first['title'])}"
                f"{'<br><small>' + middle + '</small>' if middle else ''}"
                f"<br>{player(last.get('preview'))}<br>{esc(last['title'])}")
    else:
        body = f"{player(c.preview) if c.preview else ''}<br>{esc(c.source_title)}"
    small = [esc(c.source_file)]
    if md5:
        small.append(md5)
    if c.notes_line:
        small.append(f"notes: <code>{esc(c.notes_line)}</code>")
    if c.note:
        small.append(esc(c.note))
    return f"<td>{body}<br><small>{' - '.join(small)}</small></td>"


def write_review(out_dir, reports):
    sections = []
    n_cand = 0
    for r in sorted(reports, key=lambda r: r.date):
        hits = "".join(
            f"<li><code>{esc(h['line'])}</code> <small>(after <code>{esc(h['prev'])}</code>, "
            f"before <code>{esc(h['next'])}</code>)</small></li>" for h in r.note_hits)
        head = (f'<h2 id="{r.date}">{r.date} {esc(r.venue)} '
                f'<a href="{r.url}" target="_blank">phish.in</a></h2>'
                f"<p>Notes entries:</p><ul>{hits or '<li>none</li>'}</ul>")
        if r.error:
            tried = "".join(
                f"<li><a href='{ARCHIVE}/details/{esc(t['identifier'])}' target='_blank'>"
                f"{esc(t['identifier'])}</a>: {esc(tried_summary(t))}</li>"
                for t in r.tried)
            sheet = ""
            if r.spreadsheet:
                link = (f"<a href='{esc(r.spreadsheet['link'])}' target='_blank'>download</a>"
                        if r.spreadsheet.get("link") else "no download link")
                sheet = (f"<p>Phish Spreadsheet: {link}; source <code>{esc(r.spreadsheet.get('source'))}"
                         f"</code> {esc(r.spreadsheet.get('notes'))}. Download and extract it into "
                         f"<code>data/banter_scan/{r.date}/source/</code>, then re-run "
                         f"<code>rake banter_scan:run[{r.date}]</code>.</p>")
            elif r.spreadsheet is None and not [t for t in r.tried if not t["identifier"].startswith("local:")]:
                sheet = f"<p>Not in the Phish Spreadsheet either (<a href='{SPREADSHEET_URL}'>sheet</a>).</p>"
            sections.append(f'<section class="unresolved">{head}<p><b>Unresolved:</b> {esc(r.error)}.'
                            f"</p><ul>{tried or '<li>no archive.org items for this date</li>'}</ul>{sheet}</section>")
            continue
        link = (esc(r.source_item) if r.source_item.startswith("local:") else
                f"<a href='{ARCHIVE}/details/{esc(r.source_item)}' target='_blank'>{esc(r.source_item)}</a>")
        src = f"<p>Source: {link} - {r.matched}/{r.total} phish.in tracks matched by duration."
        if r.filler_skipped:
            src += (f" Skipped {len(r.filler_skipped)} trailing filler file(s): "
                    + ", ".join(esc(t) for t in r.filler_skipped) + ".")
        src += "</p>"
        rows = []
        for c in r.candidates:
            placement = placement_text(c)
            if c.status == "already_present":
                rows.append(f'<tr class="{c.status}">{source_cell(c)}<td>{placement}</td>'
                            f'<td colspan="4">already on phish.in</td></tr>')
                continue
            if c.status in ("unanchored", "run"):
                rows.append(f'<tr class="{c.status}">{source_cell(c)}<td>{placement}</td>'
                            f"{joint_cell(c.joints.get('in'))}{joint_cell(c.joints.get('out'))}"
                            f"{joint_cell(c.joints.get('direct'))}<td></td></tr>")
                continue
            n_cand += 1
            md5 = {True: "md5 ok", False: "MD5 MISMATCH", None: "no checksum file"}[c.md5_verified]
            payload = esc(json.dumps({
                "date": c.date, "key": c.key, "after_id": c.after_id, "after_title": c.after_title,
                "after_position": c.after_position, "before_id": c.before_id,
                "before_title": c.before_title, "source_path": c.source_path,
                "source_item": c.source_item, "source_file": c.source_file,
            }))
            rows.append(
                f'<tr class="row" data-payload="{payload}">{source_cell(c, md5)}'
                f"<td>{placement}</td>"
                f"{joint_cell(c.joints.get('in'))}{joint_cell(c.joints.get('out'))}"
                f"{joint_cell(c.joints.get('direct'))}"
                f'<td><label><input type="checkbox" class="approve"> approve</label><br>'
                f'<input class="title" value="Banter" size="14"><br>'
                f'<textarea class="notes" rows="3" cols="22" placeholder="tag notes"></textarea></td></tr>')
        table = ("<table><tr><th>Source file</th><th>Placement</th>"
                 "<th>Joint in</th><th>Joint out</th><th>Direct</th><th>Decision</th></tr>"
                 f"{''.join(rows)}</table>") if rows else "<p>Every source file matches a phish.in track; nothing is missing here.</p>"
        sections.append(f"<section>{head}{src}{table}</section>")

    toc = " | ".join(f'<a href="#{r.date}">{r.date}</a>' for r in sorted(reports, key=lambda r: r.date))
    (out_dir / "review.html").write_text(f"""<!doctype html>
<meta charset="utf-8">
<title>Banter placement review</title>
<style>
  body {{ font: 14px/1.5 -apple-system, sans-serif; margin: 2rem auto; max-width: 1400px; padding: 0 1rem; }}
  table {{ border-collapse: collapse; width: 100%; margin-bottom: 1rem; }}
  td, th {{ border: 1px solid #ccc; padding: 4px 8px; text-align: left; vertical-align: top; }}
  td.continuous {{ background: #d4edda; }}
  td.suspect {{ background: #fff3cd; }}
  td.broken {{ background: #f8d7da; }}
  tr.already_present {{ color: #777; }}
  tr.unanchored, tr.run {{ background: #f6f6f6; }}
  section.unresolved {{ background: #fdf5f5; padding: 0 1rem; }}
  audio {{ height: 28px; width: 220px; }}
  code {{ font-size: 12px; }}
  #export {{ position: fixed; top: 1rem; right: 1rem; padding: .5rem 1rem; }}
  #toc {{ font-size: 12px; }}
</style>
<button id="export">Export approved.json</button>
<h1>Banter placement review</h1>
<p>{len(reports)} shows, {n_cand} candidate files. Joint in: track before &gt; source file.
Joint out: source file &gt; track after. Direct: the two tracks as phish.in has them now.
Green/yellow/red is the continuity score. Approve, Export, then
<code>rake "banter_scan:apply[path/to/approved.json]"</code>.</p>
<p id="toc">{toc}</p>
{''.join(sections)}
<script>
const KEY = "banter_scan_progress";
function payloadOf(r) {{ return JSON.parse(r.dataset.payload); }}
function save() {{
  const state = {{}};
  document.querySelectorAll(".row").forEach(r => {{
    state[payloadOf(r).key] = {{
      approved: r.querySelector("input.approve").checked,
      title: r.querySelector("input.title").value,
      notes: r.querySelector("textarea.notes").value,
    }};
  }});
  try {{ localStorage.setItem(KEY, JSON.stringify(state)); }} catch (e) {{}}
}}
function restore() {{
  let state = {{}};
  try {{ state = JSON.parse(localStorage.getItem(KEY) || "{{}}"); }} catch (e) {{}}
  document.querySelectorAll(".row").forEach(r => {{
    const s = state[payloadOf(r).key];
    if (!s) return;
    r.querySelector("input.approve").checked = !!s.approved;
    if (s.title) r.querySelector("input.title").value = s.title;
    if (s.notes) r.querySelector("textarea.notes").value = s.notes;
  }});
}}
document.addEventListener("change", save);
document.addEventListener("input", save);
restore();
document.getElementById("export").onclick = () => {{
  const approved = [...document.querySelectorAll(".row")]
    .filter(r => r.querySelector("input.approve").checked)
    .map(r => Object.assign(payloadOf(r), {{
      title: r.querySelector("input.title").value || "Banter",
      notes: r.querySelector("textarea.notes").value,
    }}));
  const blob = new Blob([JSON.stringify(approved, null, 2)], {{type: "application/json"}});
  const a = Object.assign(document.createElement("a"),
    {{href: URL.createObjectURL(blob), download: "approved.json"}});
  a.click();
}};
</script>
""")


def report_to_dict(r):
    d = asdict(r)
    return d


def report_from_dict(d):
    d = dict(d)
    d["candidates"] = [Candidate(**c) for c in d["candidates"]]
    return ShowReport(**d)


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--out-dir", type=Path, required=True)
    p.add_argument("--dates", default="", help="comma-separated YYYY-MM-DD list")
    p.add_argument("--from-notes", action="store_true",
                   help="scan every show's taper notes for missing banter entries")
    p.add_argument("--rebuild", action="store_true",
                   help="rewrite review.html from the existing report.json")
    args = p.parse_args()
    out_dir = args.out_dir
    out_dir.mkdir(parents=True, exist_ok=True)
    report_path = out_dir / "report.json"

    existing = {}
    if report_path.exists():
        existing = {r["date"]: r for r in json.loads(report_path.read_text())["shows"]}

    if args.rebuild:
        write_review(out_dir, [report_from_dict(d) for d in existing.values()])
        print(f"Review page written to {out_dir / 'review.html'}", file=sys.stderr)
        return

    dates = [d.strip() for d in args.dates.split(",") if d.strip()]
    if args.from_notes:
        dates += dates_from_notes()
    if not dates:
        p.error("give --dates or --from-notes")

    for date in sorted(set(dates)):
        print(f"{date}", file=sys.stderr)
        try:
            report = analyze_show(date, out_dir)
        except Exception as e:  # keep going; the page shows what failed
            report = ShowReport(date=date, venue="", url=f"{SITE_BASE}/{date}", note_hits=[],
                                source_item=None, matched=0, total=0, tried=[],
                                unmatched_files=[], candidates=[], error=f"{type(e).__name__}: {e}")
        existing[date] = report_to_dict(report)
        n = sum(1 for c in report.candidates if c.status == "candidate")
        print(f"  {report.error or f'{report.source_item}: {n} candidate(s)'}", file=sys.stderr)
        report_path.write_text(json.dumps({"shows": list(existing.values())}, indent=2))

    write_review(out_dir, [report_from_dict(d) for d in existing.values()])
    print(f"Review page written to {out_dir / 'review.html'}", file=sys.stderr)


if __name__ == "__main__":
    main()
