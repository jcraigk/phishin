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
#   "openpyxl",
# ]
# ///
"""Find the Fall 1995 band/audience chess-match banter still embedded in song
tracks so it can be split into its own track.

The match ran 1995-09-30 through 1995-12-31. The band moved at the top of set
1 (or during a set-1 jam) and a fan climbed the ladder at the top of set 2 to
answer, so the scan looks at every set opener of every show in the window plus
the tracks the taper notes single out, and transcribes any on-mic speech at
the head and tail of each (the whole track for the singled-out ones). Speech
that mentions the game is a candidate; the review page proposes a cut where
the music starts and auditions both sides through lead_scan_server.py.

For shows with no hit, archive.org items for the date and the Phish
Spreadsheet row are consulted so a source that does carry a chess file can be
named for a manual look. Nothing is fetched or modified here.

Usage:
  uv run scripts/audio_chess_analysis.py --out-dir data/chess_scan
  uv run scripts/audio_chess_analysis.py --out-dir data/chess_scan --date 1995-09-30,1995-12-05
  uv run scripts/audio_chess_analysis.py --out-dir data/chess_scan --rebuild
"""

import argparse
import importlib.util
import json
import re
import sys
from dataclasses import asdict, dataclass, field
from pathlib import Path

import numpy as np
import requests

REPO_ROOT = Path(__file__).resolve().parent.parent
EDGE_SCRIPT = REPO_ROOT / "scripts" / "audio_edge_analysis.py"
BANTER_SCRIPT = REPO_ROOT / "scripts" / "audio_banter_analysis.py"
API_BASE = "https://phish.in/api/v2"
SITE_BASE = "https://phish.in"

TOUR_START = "1995-09-30"
TOUR_END = "1995-12-31"
CHESS_TITLE_RE = re.compile(r"chess", re.I)
CHESS_SONG_TITLE = "Audience Chess Move"
TITLE_CHOICES = ["Audience Chess Move", "Band Chess Move"]

# Words that only come up when the game is being discussed score higher than
# words with everyday uses ("move", "king").
STRONG_WORDS = re.compile(
    r"\b(chess|pawns?|knights?|bishops?|rooks?|checkmate|greenpeace|pooh|chess ?board"
    r"|grand ?master|stalemate|castling|gambit|portuguese|(?:opening|defen[cs]e)\b.{0,20}"
    r"\b(?:move|game|chess)|(?:sicilian|french|english|queen'?s|king'?s) (?:opening|defen[cs]e)"
    r"|crush you)\b", re.I)
WEAK_WORDS = re.compile(
    r"\b(moves?|kings?|queens?|castle|ladder|the board|the game|pieces?|check|white|black"
    r"|your turn|our turn|the match|strategy|represent|opening|defen[cs]e|crush)\b", re.I)

# Where the notes say the game was discussed on tape but the show holds no
# chess track. Titles are regexes against track titles; those tracks are
# scanned end to end rather than just at their edges.
EVIDENCE = {
    "1995-09-30": {"note": "Board unveiled and opening moves during White Rabbit jam (set 1)",
                   "titles": [r"white rabbit"]},
    "1995-10-02": {"note": "Night Moves Jam in set 1 extended the match (phish.net)",
                   "titles": [r"night moves"]},
    "1995-10-14": {"note": "Taper: {2}Chess Move>Reba", "titles": [r"^reba$"]},
    "1995-10-15": {"note": "Taper: Chess Move>Julius is the first song of set 2",
                   "titles": [r"^julius$"]},
    "1995-11-15": {"note": "Band won game 1 at this show (phish.net)", "titles": []},
    "1995-11-16": {"note": "Game 2 opening moves during a short jam after Runaway Jim, "
                           "Trey on percussion (taper: 3.Chess Jam)",
                   "titles": [r"runaway jim"]},
    "1995-12-05": {"note": "Taper: 01 - [01:12] - chess move intro; faded in on the master DAT",
                   "titles": [r"^poor heart$"]},
    "1995-12-31": {"note": "Taper: 01. Chess Move/Crowd 00:53 before Drowned; game 2 ended "
                           "here (audience won)",
                   "titles": [r"^drowned$"]},
}

YAMNET_HOP_S = 0.48
YAMNET_WIN_S = 0.96
SPEECH_MIN_RUN_S = 2.0     # shorter speech-scored runs are crowd blips
SPEECH_MERGE_GAP_S = 4.0   # runs closer than this are one conversation
TRANSCRIBE_PAD_S = 1.5
MUSIC_ONSET_THRESHOLD = 0.5
MUSIC_SUSTAIN_S = 4.0


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


edge = load_module("audio_edge_analysis", EDGE_SCRIPT)
banter = load_module("audio_banter_analysis", BANTER_SCRIPT)


# ---------------------------------------------------------------------------
# Data


@dataclass
class SpeechRun:
    start: float
    end: float
    text: str
    score: int
    hits: list


@dataclass
class Candidate:
    label: str
    date: str
    set_name: str
    position: int
    title: str
    track_id: int
    mp3_url: str
    share_url: str
    duration_s: float
    songs: list          # [{id, title}]
    tags: list           # tag names on the track
    region: str          # head | tail | full
    scanned_s: float     # seconds actually analysed in this region
    runs: list = field(default_factory=list)      # SpeechRun dicts
    cut_point: float = 0.0                        # proposed cut, seconds
    chess_side: str = "before"                    # chess part is before/after the cut
    score: int = 0
    reason: str = ""
    waveform_image_url: str = ""
    tag_details: list = field(default_factory=list)   # the track's tag payloads, for the page


@dataclass
class ShowReport:
    date: str
    venue: str
    location: str
    existing: list       # chess tracks already split out: [{set, position, title, url, duration_s}]
    evidence: list       # note lines about the game, from taper notes + EVIDENCE
    candidates: list     # Candidate dicts
    other_speech: list   # Candidate dicts with speech but no chess words
    sources: dict        # archive.org / spreadsheet findings
    error: str = ""


# ---------------------------------------------------------------------------
# Show selection


def fetch_show(date):
    resp = requests.get(f"{API_BASE}/shows/{date}", timeout=30)
    resp.raise_for_status()
    return resp.json()


def tour_dates(start, end):
    dates = banter.fetch_year_dates("1995")
    return sorted(d for d in dates if start <= d <= end)


def note_evidence(taper_notes):
    lines = []
    for line in (taper_notes or "").splitlines():
        if CHESS_TITLE_RE.search(line):
            lines.append(line.strip())
    return lines


def candidate_tracks(show, scan_all, window_s):
    """(track, region) pairs to analyse. Set openers get head and tail windows;
    tracks the notes single out are scanned end to end; --all does every track."""
    tracks = sorted(show["tracks"], key=lambda t: t["position"])
    evidence = EVIDENCE.get(show["date"], {})
    full_titles = [re.compile(p, re.I) for p in evidence.get("titles", [])]
    by_set = {}
    for t in tracks:
        by_set.setdefault(t["set_name"], []).append(t)

    jobs = []
    for set_name, set_tracks in by_set.items():
        if set_name == "Soundcheck":
            continue
        for i, t in enumerate(set_tracks):
            if not t.get("mp3_url") or CHESS_TITLE_RE.search(t["title"]):
                continue
            if any(p.search(t["title"]) for p in full_titles):
                jobs.append((t, "full"))
                # The jam the notes point at may spill into the next track.
                if i + 1 < len(set_tracks) and not CHESS_TITLE_RE.search(set_tracks[i + 1]["title"]):
                    jobs.append((set_tracks[i + 1], "head"))
                continue
            if scan_all or i == 0:
                jobs.append((t, "head"))
                jobs.append((t, "tail"))
            elif i == 1 and CHESS_TITLE_RE.search(set_tracks[0]["title"]):
                # A chess track already opens the set; its neighbour may still
                # hold the rest of the exchange.
                jobs.append((t, "head"))
    seen = set()
    out = []
    jobs = [(t, "full" if region != "full" and t["duration"] / 1000.0 <= 2 * window_s else region)
            for t, region in jobs]
    for t, region in jobs:
        key = (t["id"], region)
        if key in seen or (region != "full" and (t["id"], "full") in seen):
            continue
        seen.add(key)
        out.append((t, region))
    return out


# ---------------------------------------------------------------------------
# Speech analysis


def chess_score(text):
    strong = STRONG_WORDS.findall(text)
    weak = WEAK_WORDS.findall(text)
    hits = sorted({w.lower() for w in strong} | {w.lower() for w in weak})
    return 2 * len(strong) + len(weak), hits


def speech_runs(scores, yamnet, offset_s):
    """Contiguous stretches where YAMNet hears speech over both music and
    crowd, merged across short gaps. Returns [(start_s, end_s)]."""
    music = edge.median_smooth(scores[:, yamnet.music_idx], k=5)
    crowd = scores[:, yamnet.crowd_idx].max(axis=1)
    speech = scores[:, yamnet.speech_idx].max(axis=1)
    speechy = (speech > crowd) & (speech > music) & (speech > 0.15)
    runs = []
    start = None
    for i, flag in enumerate(speechy):
        if flag and start is None:
            start = i
        elif not flag and start is not None:
            runs.append((start, i))
            start = None
    if start is not None:
        runs.append((start, len(speechy)))
    merged = []
    for a, b in runs:
        if merged and (a - merged[-1][1]) * YAMNET_HOP_S <= SPEECH_MERGE_GAP_S:
            merged[-1] = (merged[-1][0], b)
        else:
            merged.append((a, b))
    out = []
    for a, b in merged:
        s = offset_s + a * YAMNET_HOP_S
        e = offset_s + b * YAMNET_HOP_S + YAMNET_WIN_S
        if e - s >= SPEECH_MIN_RUN_S:
            out.append((s, e))
    return out, music


def music_onset_after(music, offset_s, from_s):
    """First point after from_s where music holds for MUSIC_SUSTAIN_S."""
    look = max(1, int(round(MUSIC_SUSTAIN_S / YAMNET_HOP_S)))
    i0 = max(0, int((from_s - offset_s) / YAMNET_HOP_S))
    for i in range(i0, len(music)):
        w = music[i:i + look]
        if len(w) and float(np.median(w)) >= MUSIC_ONSET_THRESHOLD:
            return offset_s + i * YAMNET_HOP_S
    return None


def music_end_before(music, offset_s, to_s):
    """Last point before to_s where music was still holding."""
    look = max(1, int(round(MUSIC_SUSTAIN_S / YAMNET_HOP_S)))
    i0 = min(len(music) - 1, int((to_s - offset_s) / YAMNET_HOP_S))
    for i in range(i0, -1, -1):
        w = music[max(0, i - look + 1):i + 1]
        if len(w) and float(np.median(w)) >= MUSIC_ONSET_THRESHOLD:
            return offset_s + i * YAMNET_HOP_S + YAMNET_WIN_S
    return None


def analyze_region(yamnet, finder, path, duration_s, region, window_s):
    """Transcribe the speech in one region of a track. Returns (runs, music
    curve, offset) where runs are SpeechRun instances."""
    if region == "full":
        offset_s, length_s = 0.0, duration_s
    elif region == "head":
        offset_s, length_s = 0.0, min(window_s, duration_s)
    else:
        length_s = min(window_s, duration_s)
        offset_s = duration_s - length_s
    waveform = edge.decode_segment(path, offset_s, length_s)
    if not len(waveform):
        return [], np.zeros(0), offset_s, 0.0
    scores = yamnet.scores(waveform)
    spans, music = speech_runs(scores, yamnet, offset_s)
    runs = []
    for s, e in spans:
        a = max(offset_s, s - TRANSCRIBE_PAD_S)
        b = min(offset_s + length_s, e + TRANSCRIBE_PAD_S)
        i0, i1 = int((a - offset_s) * edge.SAMPLE_RATE), int((b - offset_s) * edge.SAMPLE_RATE)
        segments = finder.find(waveform[i0:i1], a)
        text = " ".join(seg["text"] for seg in segments).strip()
        if not text:
            continue
        score, hits = chess_score(text)
        runs.append(SpeechRun(start=round(min(seg["start"] for seg in segments), 1),
                              end=round(max(seg["end"] for seg in segments), 1),
                              text=text, score=score, hits=hits))
    return runs, music, offset_s, length_s


def propose_cut(runs, music, offset_s, region, duration_s):
    """Where to cut so the chess talk becomes its own track, and which side of
    the cut it sits on. Talk at the head is cut where the music settles in
    after the first cluster of speech (later speech is over the jam and stays
    with the song); talk at the tail is cut where the music ended before the
    last cluster."""
    scored = [r for r in runs if r.score > 0] or runs
    if not scored:
        return 0.0, "before"
    runs = sorted(runs, key=lambda r: r.start)
    first, last = min(r.start for r in scored), max(r.end for r in scored)
    mid = duration_s / 2
    if region == "tail" or (region == "full" and first > mid):
        cut = None
        for r in reversed(runs):
            if r.end > last:
                continue
            here = music_end_before(music, offset_s, r.start)
            if here is None:
                cut = r.start
                continue
            if cut is not None and here < cut - 0.01 and r.start < cut:
                cut = here
                continue
            cut = here if cut is None else cut
            break
        return round(max(0.0, cut if cut is not None else first), 1), "after"
    cut = None
    for r in runs:
        if r.start < first:
            continue
        if cut is not None and r.start > cut:
            break
        here = music_onset_after(music, offset_s, r.end)
        cut = r.end if here is None else max(cut or 0.0, here)
    return round(min(duration_s, cut if cut is not None else last), 1), "before"


# ---------------------------------------------------------------------------
# Sources


SOURCE_FILE_RE = re.compile(r"chess|move|intro|banter|crowd|tuning|talk", re.I)


def source_notes(date, tracks, out_dir):
    """archive.org items for the date whose files suggest a chess segment the
    imported source lacks, plus the Phish Spreadsheet row."""
    out = {"items": [], "spreadsheet": None, "error": ""}
    try:
        seen = set()
        for identifier in banter.archive_items(date):
            if identifier in seen:
                continue
            seen.add(identifier)
            try:
                meta = banter.archive_metadata(identifier)
            except requests.RequestException as e:
                out["items"].append({"identifier": identifier, "error": str(e)})
                continue
            f2t, _, matched, total = banter.match_item(meta["files"], tracks)
            interesting = []
            for i, f in enumerate(meta["files"]):
                named = bool(SOURCE_FILE_RE.search(f["name"]) or SOURCE_FILE_RE.search(f["title"] or ""))
                short_unmatched = i not in f2t and f["length"] is not None and f["length"] <= 240
                if named or short_unmatched:
                    interesting.append({"name": f["name"], "title": f["title"],
                                        "length": f["length"], "matched": i in f2t})
            out["items"].append({"identifier": identifier, "matched": matched, "total": total,
                                 "files": len(meta["files"]), "interesting": interesting,
                                 "url": f"https://archive.org/details/{identifier}"})
    except requests.RequestException as e:
        out["error"] = f"archive.org: {e}"
    try:
        out["spreadsheet"] = banter.spreadsheet_row(date, out_dir)
    except Exception as e:  # noqa: BLE001 - the sheet is best effort
        out["error"] = (out["error"] + " " if out["error"] else "") + f"spreadsheet: {e}"
    return out


# ---------------------------------------------------------------------------
# Per-show driver


def analyze_show(date, args, yamnet, finder):
    show = fetch_show(date)
    tracks = show["tracks"]
    existing = [{
        "set": t["set_name"], "position": t["position"], "title": t["title"],
        "url": f"{SITE_BASE}/{date}/{t['slug']}", "duration_s": round(t["duration"] / 1000, 1),
    } for t in sorted(tracks, key=lambda t: t["position"]) if CHESS_TITLE_RE.search(t["title"])]
    evidence = note_evidence(show.get("taper_notes"))
    if date in EVIDENCE:
        evidence.insert(0, EVIDENCE[date]["note"])

    candidates, other = [], []
    for t, region in candidate_tracks(show, args.all, args.window):
        label = f"{date} {t['set_name']} t{t['position']:02d} {t['title']}"
        print(f"  {label} [{region}]", file=sys.stderr)
        path = edge.download_audio(t["mp3_url"])
        duration_s = t["duration"] / 1000.0
        try:
            runs, music, offset_s, scanned = analyze_region(
                yamnet, finder, path, duration_s, region, args.window)
        except Exception as e:  # noqa: BLE001 - one bad decode must not stop the show
            print(f"    failed: {e}", file=sys.stderr)
            continue
        if not runs:
            continue
        cut, side = propose_cut(runs, music, offset_s, region, duration_s)
        score = sum(r.score for r in runs)
        c = Candidate(
            label=label, date=date, set_name=t["set_name"], position=t["position"],
            title=t["title"], track_id=t["id"], mp3_url=t["mp3_url"],
            share_url=f"{SITE_BASE}/{date}/{t['slug']}", duration_s=round(duration_s, 1),
            waveform_image_url=t.get("waveform_image_url", ""),
            tag_details=list(t.get("tags", [])),
            songs=[{"id": s["id"], "title": s["title"]} for s in t.get("songs", [])],
            tags=[g["name"] for g in t.get("tags", [])],
            region=region, scanned_s=round(scanned, 1), runs=[asdict(r) for r in runs],
            cut_point=cut, chess_side=side, score=score,
        )
        long_talk = any(r.end - r.start >= 8.0 for r in runs)
        if score > 0:
            c.reason = "chess words: " + ", ".join(sorted({h for r in runs for h in r.hits}))
            candidates.append(asdict(c))
        elif long_talk:
            c.reason = "long on-mic speech, no chess words"
            candidates.append(asdict(c))
        else:
            other.append(asdict(c))
        for r in runs:
            print(f"    {r.start:7.1f}-{r.end:7.1f}  score={r.score}  {r.text[:110]}", file=sys.stderr)

    sources = {}
    if not args.no_sources and (not candidates or date in EVIDENCE):
        print("  checking sources...", file=sys.stderr)
        sources = source_notes(date, tracks, args.out_dir)

    return ShowReport(
        date=date, venue=show.get("venue_name", ""),
        location=(show.get("venue") or {}).get("location", ""),
        existing=existing, evidence=evidence, candidates=candidates,
        other_speech=other, sources=sources,
    )


# ---------------------------------------------------------------------------
# Review page: the split scan's page, one row per candidate track, with the
# transcript tucked under a disclosure and a footer for shows that need a
# source rather than a split.

SPLIT_SCRIPT = REPO_ROOT / "scripts" / "audio_split_analysis.py"


def esc(s):
    return (str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
            .replace('"', "&quot;"))


def fmt_ts(seconds):
    seconds = max(0.0, float(seconds))
    m, s = divmod(seconds, 60)
    return f"{int(m)}:{s:04.1f}"


def triage(report):
    """Only speech that mentions the game is worth a row. Long speech with no
    chess words (sung verses, crowd, a thank-you) is kept in the collapsed
    list so the footer can still say the track was heard."""
    keep, other = [], list(report["other_speech"])
    for c in report["candidates"]:
        (keep if c["score"] > 0 else other).append(c)
    report["candidates"], report["other_speech"] = keep, other
    return report


def source_lines(sources):
    """Files in other archive.org items named like a chess or intro segment."""
    lines = []
    for it in sources.get("items", []):
        for f in it.get("interesting", []):
            if SOURCE_FILE_RE.search(f["name"] + " " + (f["title"] or "")):
                length = fmt_ts(f["length"]) if f["length"] is not None else "?"
                lines.append(f'<a href="{esc(it["url"])}" target="_blank">{esc(it["identifier"])}</a>'
                             f' &middot; {esc(f["title"] or f["name"])} ({length})'
                             f'{"" if f["matched"] else " &middot; not in phish.in"}')
    row = sources.get("spreadsheet")
    if row and row.get("link"):
        lines.append(f'<a href="{esc(row["link"])}" target="_blank">Phish Spreadsheet</a>'
                     f' &middot; {esc(row.get("source", ""))}')
    return lines


def note_html(r, c):
    runs = "".join(
        f'<div class="run{" hit" if run["score"] > 0 else ""}">'
        f'<span class="meta">{fmt_ts(run["start"])}-{fmt_ts(run["end"])}</span>'
        f'{"<span class=hits>" + esc(", ".join(run["hits"])) + "</span>" if run["hits"] else ""}'
        f'<div class="text">{esc(run["text"])}</div></div>'
        for run in c["runs"])
    hits = sorted({h for run in c["runs"] for h in run["hits"]})
    summary = (f'transcript ({len(c["runs"])} speech run{"s" if len(c["runs"]) != 1 else ""}, '
               f'scanned {c["region"]})' + (f' &middot; <span class="hits">{esc(", ".join(hits))}</span>' if hits else ""))
    existing = ", ".join(
        f'<a href="{esc(e["url"])}" target="_blank">{esc(e["set"])} t{e["position"]:02d}</a>'
        for e in r["existing"])
    extras = []
    if r["evidence"]:
        extras.append(f'<span class="evidence">{esc(r["evidence"][0])}</span>')
    if existing:
        extras.append(f'<span class="meta">chess tracks in this show: {existing}</span>')
    return (f'<details><summary>{summary}</summary>{runs}</details>'
            + (f'<div>{" &middot; ".join(extras)}</div>' if extras else ""))


def footer_html(reports):
    rows = []
    for r in reports:
        if r["candidates"]:
            continue
        src = source_lines(r["sources"])
        existing = ", ".join(
            f'<a href="{esc(e["url"])}" target="_blank">{esc(e["set"])} t{e["position"]:02d} ({fmt_ts(e["duration_s"])})</a>'
            for e in r["existing"])
        state = ("chess track present" if existing else
                 "notes say a chess move was taped" if r["evidence"] else "")
        heard = [c for c in r["other_speech"] if any(run["end"] - run["start"] >= 8 for run in c["runs"])]
        if heard:
            state += ("; " if state else "") + "speech but no chess words at " + ", ".join(
                f'<a href="{esc(c["share_url"])}" target="_blank">{esc(c["title"])}</a>' for c in heard)
        rows.append(f'<tr><td><a href="{SITE_BASE}/{r["date"]}" target="_blank">{r["date"]}</a></td>'
                    f'<td>{esc(r["venue"])}</td><td>{existing or state}</td>'
                    f'<td>{"<br>".join(src) or "<span class=meta>nothing named like a chess file</span>"}</td></tr>')
    return ('<div class="footer"><h2>Shows without an embedded candidate</h2>'
            '<p class="meta">Speech at the set openers held no chess talk. Where another '
            'archive.org transfer carries a file named like a chess move or set intro, it is '
            'listed for a manual look.</p>'
            '<table><tr><th>date</th><th>venue</th><th>phish.in</th><th>other sources</th></tr>'
            + "".join(rows) + "</table></div>")


def backfill_waveforms(reports):
    """Rows need the waveform image url and the tag payloads; reports written
    before they were stored get them from the show payload."""
    for r in reports:
        cands = r["candidates"] + r["other_speech"]
        if not cands or all(c.get("waveform_image_url") and "tag_details" in c for c in cands):
            continue
        by_id = {t["id"]: t for t in fetch_show(r["date"])["tracks"]}
        for c in cands:
            t = by_id.get(c["track_id"]) or {}
            c["waveform_image_url"] = t.get("waveform_image_url", "")
            c["tag_details"] = list(t.get("tags", []))


def write_review(out_dir, reports, songs):
    split = load_module("audio_split_analysis", SPLIT_SCRIPT)
    reports = sorted((triage(dict(r)) for r in reports), key=lambda r: r["date"])
    backfill_waveforms(reports)
    catalog = songs or split.fetch_song_catalog()
    by_title = {s["title"].casefold(): s["id"] for s in catalog}
    chess_id = by_title.get(CHESS_SONG_TITLE.casefold())
    if chess_id is None and catalog:
        print(f"  warning: no song titled {CHESS_SONG_TITLE!r} in the catalog", file=sys.stderr)

    rows = []
    for r in reports:
        for c in r["candidates"]:
            parts = [CHESS_SONG_TITLE, c["title"]]
            if c["chess_side"] == "after":
                parts.reverse()
            rows.append(split.SplitCandidate(
                label=c["label"], date=c["date"], set_name=c["set_name"], position=c["position"],
                title=c["title"], part_titles=parts,
                songs=[s["title"] for s in c["songs"]],
                mp3_url=c["mp3_url"], share_url=c["share_url"],
                waveform_image_url=c.get("waveform_image_url", ""),
                duration_s=c["duration_s"], cut_points=[], hint_s=c["cut_point"],
                tags=split.untimestamped_tags(c.get("tag_details", [])),
                note_html=note_html(r, c),
            ))
    split.write_review_html(out_dir / "review.html", rows, [], catalog=catalog, quiet=True,
                            title="Chess move review", footer_html=footer_html(reports),
                            store_key="chessscan:progress:v2",
                            migrate_from="splitscan:progress:chess_scan")


# ---------------------------------------------------------------------------
# Main


def load_reports(out_dir):
    path = out_dir / "report.json"
    if not path.exists():
        return {}
    data = json.loads(path.read_text())
    return {r["date"]: r for r in data.get("shows", [])}


def save_reports(out_dir, reports):
    (out_dir / "report.json").write_text(json.dumps(
        {"shows": [reports[d] for d in sorted(reports)]}, indent=2))


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--out-dir", type=Path, required=True)
    p.add_argument("--date", action="append", default=[],
                   help="show date(s), comma separated or repeated; default: the whole tour window")
    p.add_argument("--start", default=TOUR_START)
    p.add_argument("--end", default=TOUR_END)
    p.add_argument("--all", action="store_true", help="scan every track, not just set openers")
    p.add_argument("--window", type=float, default=180.0, help="seconds analysed at each edge")
    p.add_argument("--no-sources", action="store_true", help="skip archive.org / spreadsheet lookups")
    p.add_argument("--rebuild", action="store_true", help="rewrite review.html from report.json")
    p.add_argument("--merge", type=Path, nargs="*", default=None,
                   help="fold these workers' report.json files into --out-dir and rebuild")
    args = p.parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)

    reports = load_reports(args.out_dir)
    if args.merge is not None:
        for d in args.merge:
            reports.update(load_reports(d))
        write_review(args.out_dir, list(reports.values()), [])
        save_reports(args.out_dir, reports)
        print(f"Merged {len(args.merge)} report(s), {len(reports)} shows. Review: {args.out_dir / 'review.html'}")
        return
    if args.rebuild:
        write_review(args.out_dir, list(reports.values()), [])
        save_reports(args.out_dir, reports)
        print(f"Review: {args.out_dir / 'review.html'}")
        return

    dates = [d for group in args.date for d in group.split(",") if d]
    if not dates:
        dates = tour_dates(args.start, args.end)
    print(f"{len(dates)} show(s)", file=sys.stderr)

    yamnet = edge.Yamnet()
    finder = edge.LazyBanterFinder()
    for i, date in enumerate(dates, 1):
        print(f"[{i}/{len(dates)}] {date}", file=sys.stderr)
        try:
            report = analyze_show(date, args, yamnet, finder)
        except Exception as e:  # noqa: BLE001 - keep the batch going, record the failure
            print(f"  FAILED: {e}", file=sys.stderr)
            report = ShowReport(date=date, venue="", location="", existing=[], evidence=[],
                                candidates=[], other_speech=[], sources={}, error=str(e))
        reports[date] = asdict(report)
        save_reports(args.out_dir, reports)
        write_review(args.out_dir, list(reports.values()), [])
    print(f"Review: {args.out_dir / 'review.html'}")


if __name__ == "__main__":
    main()
