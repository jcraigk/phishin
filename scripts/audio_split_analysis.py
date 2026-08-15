#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11,<3.13"
# dependencies = [
#   "requests",
# ]
# ///
"""Find tracks that hold two songs joined by a segue, and review where to cut.

A title like "Mike's Song > I Am Hydrogen" is one track that should be two, each
with its own song association. This scans the phish.in API for those titles and
writes a review page where a human picks the cut point, auditioning the audio on
both sides of it, then exports approved.json for `rake split_scan:apply`.

No audio is analyzed or downloaded here - the scan is pure API, so a year takes
seconds. The audition clips are rendered on demand by scripts/lead_scan_server.py
(`rake split_scan:serve`), which is shared with the lead scan unchanged.

Usage (normally via the rake tasks):
  uv run scripts/audio_split_analysis.py --year 1989 \\
    --json data/split_scan/1989/report.json --html data/split_scan/1989/review.html
  uv run scripts/audio_split_analysis.py --rebuild data/split_scan/1989
"""

import argparse
import base64
import html as html_escape
import json
import re
import sys
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict, dataclass, field
from pathlib import Path

import requests

API_BASE = "https://phish.in/api/v2"
SITE_BASE = "https://phish.in"
REPO_ROOT = Path(__file__).resolve().parent.parent
# Seconds of audio auditioned on each side of the cut. The tail of the first
# song only has to confirm the phrase resolves; the head of the second is what
# the cut is judged on, so it runs long enough to hear the new song settle in.
CLIP_BEFORE_S = 5.0
CLIP_AFTER_S = 20.0
# Both halves must be at least this long for a cut to be plausible; mirrors
# TrackSplitService::MIN_PART_S, which rejects anything shorter on apply.
MIN_PART_S = 10.0
# Splits "A > B" and "A -> B" alike. Both mark a segue; the arrow form means
# seamless, a distinction the split does not preserve (see the design doc).
SEGUE_RE = re.compile(r"\s*-?>\s*")
# One request per show, so a whole-catalog scan is 2000+ round trips. They are
# independent reads, so they go out concurrently; the results are still
# reassembled in date order below.
FETCH_WORKERS = 12


def load_ignore_urls(path):
    """Share URLs of tracks to leave alone, one per line, # comments allowed."""
    if not path or not path.exists():
        return set()
    return {
        line.strip().rstrip("/")
        for line in path.read_text().splitlines()
        if line.strip() and not line.strip().startswith("#")
    }


@dataclass
class SplitCandidate:
    label: str  # "YYYY-MM-DD SetName tNN Title", as the lead scan formats it
    date: str
    set_name: str
    position: int
    title: str
    part_titles: list  # the two halves of the title, in order
    songs: list  # song titles from the track's API payload
    mp3_url: str
    share_url: str
    waveform_image_url: str
    duration_s: float
    cut_s: float  # default cut point; the reviewer moves it
    unmatched_parts: list = field(default_factory=list)
    tags: list = field(default_factory=list)


def fmt_ts(seconds):
    """Seconds as m:ss (or h:mm:ss), matching what audio players display."""
    seconds = int(round(float(seconds)))
    m, s = divmod(seconds, 60)
    h, m = divmod(m, 60)
    return f"{h}:{m:02d}:{s:02d}" if h else f"{m}:{s:02d}"


def fmt_tenths(seconds):
    """Seconds as m:ss.s, the editable form on the review page (e.g. 1:03.2)."""
    tenths = max(0, round(float(seconds) * 10))
    m, s = divmod(tenths, 600)
    return f"{m}:{s / 10:04.1f}"


def display_label(label):
    """Label for human-facing pages: drops the tNN position token and separates
    date, set and song with dashes (1989-05-26 - Set 1 - Mike's Song > Hydrogen)."""
    m = re.match(r"^(\d{4}-\d{2}-\d{2}) (.*?) t\d+ (.*)$", label)
    if m:
        return f"{m.group(1)} - {m.group(2)} - {m.group(3)}"
    return label


def segue_count(title):
    return title.count(">")


def split_title(title):
    """The two halves of a single-segue title, stripped."""
    return [p.strip() for p in SEGUE_RE.split(title, maxsplit=1)]


def unmatched_parts(part_titles, songs):
    """Part titles with no song of that name on the track.

    An early warning: apply resolves each half to a Song record, and a part that
    matches nothing here will need a catalog lookup or a human at that point."""
    known = {s.strip().casefold() for s in songs}
    return [p for p in part_titles if p.casefold() not in known]


def fetch_show_candidates(date, ignore_urls):
    """(candidates, multi_segue) for one show, from its API payload."""
    resp = requests.get(f"{API_BASE}/shows/{date}", timeout=30)
    resp.raise_for_status()
    tracks = sorted(resp.json()["tracks"], key=lambda t: t["position"])

    candidates, multi = [], []
    for t in tracks:
        if t["set_name"] == "Soundcheck":
            continue
        count = segue_count(t["title"])
        if not count:
            continue
        label = f"{date} {t['set_name']} t{t['position']:02d} {t['title']}"
        share = f"{SITE_BASE}/{date}/{t['slug']}" if t.get("slug") else ""
        if share and share.rstrip("/") in ignore_urls:
            print(f"  skipping {display_label(label)} (in ignore list)", file=sys.stderr)
            continue
        duration_s = (t.get("duration") or 0) / 1000.0
        if count > 1:
            # Not reviewable here: one cut point cannot describe two segues.
            # Footnoted so the size of the remaining problem stays visible.
            multi.append({"label": label, "title": t["title"], "share_url": share,
                          "segues": count})
            continue
        if not t.get("mp3_url"):
            print(f"  skipping {display_label(label)} (no mp3_url)", file=sys.stderr)
            continue
        if duration_s < 2 * MIN_PART_S:
            print(f"  skipping {display_label(label)} "
                  f"(only {duration_s:.0f}s, too short to split)", file=sys.stderr)
            continue
        parts = split_title(t["title"])
        songs = [s["title"] for s in t.get("songs", [])]
        candidates.append(SplitCandidate(
            label=label, date=date, set_name=t["set_name"], position=t["position"],
            title=t["title"], part_titles=parts, songs=songs,
            mp3_url=t["mp3_url"], share_url=share,
            waveform_image_url=t.get("waveform_image_url") or "",
            duration_s=round(duration_s, 1),
            # The midpoint is a neutral starting point, not a guess at the segue;
            # every row is expected to be moved by hand.
            cut_s=round(duration_s / 2, 1),
            unmatched_parts=unmatched_parts(parts, songs),
            tags=untimestamped_tags(t.get("tags") or []),
        ))
    return candidates, multi


def untimestamped_tags(tags):
    return [
        {"name": t.get("name") or "", "color": t.get("color") or "",
         "notes": t.get("notes") or ""}
        for t in tags
        if t.get("starts_at_second") is None and t.get("ends_at_second") is None
        and t.get("name")
    ]


def fetch_year_dates(year):
    resp = requests.get(f"{API_BASE}/shows",
                        params={"year": year, "per_page": 500}, timeout=30)
    resp.raise_for_status()
    shows = resp.json()["shows"]
    dates = sorted(s["date"] for s in shows if s["audio_status"] != "missing")
    print(f"{year}: {len(dates)} shows with audio", file=sys.stderr)
    return dates


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
        src = f"url(data:font/woff2;base64,{b64}) format(\"woff2\")"
        faces.append(
            '@font-face { font-family: "Open Sans Condensed"; font-style: normal; '
            f'font-weight: {weight}; font-display: swap; src: {src}; ' + "}")
    return "\n  ".join(faces)


def tag_picker(c, esc):
    if not c.tags:
        return ""
    rows = []
    for i, tag in enumerate(c.tags):
        name = tag.get("name", "")
        notes = tag.get("notes") or ""
        color = tag.get("color") or ""
        swatch = (f'<i class="swatch" style="background:{esc(color, quote=True)}"></i>'
                  if color.startswith("#") else "")
        title = f"{name}: {notes}" if notes else name
        label = (f'<span class="tname{" has-notes" if notes else ""}" '
                 f'title="{esc(title, quote=True)}">{swatch}{esc(name)}</span>')
        choices = "".join(
            f'<label class="tchoice"><input type="radio" '
            f'name="tag-{esc(c.share_url, quote=True)}-{i}" value="{side}"'
            f'{" checked" if side == "both" else ""}>'
            f'<span>{text}</span></label>'
            for side, text in (("both", "both"), ("first", "1st"), ("second", "2nd")))
        rows.append(f'<div class="trow" data-tag="{esc(name, quote=True)}">'
                    f'{label}<span class="tchoices">{choices}</span></div>')
    return ('<div class="tags"><span class="tags-h">tags</span>'
            + "".join(rows) + '</div>')


def write_review_html(html_path, candidates, multi, quiet=False):
    """Static review page: per row a cut time, nudges, an audition of each side
    of the cut, and the full-track waveform. Export writes approved.json for
    `rake split_scan:apply`."""
    esc = html_escape.escape
    rows = []
    for c in sorted(candidates, key=lambda c: c.label):
        shown = display_label(c.label)
        link = (f'<a href="{esc(c.share_url, quote=True)}" target="_blank">{esc(shown)}</a>'
                if c.share_url else esc(shown))
        payload = esc(json.dumps({
            "label": c.label, "mp3_url": c.mp3_url, "share_url": c.share_url,
            "cut_s": c.cut_s, "duration_s": c.duration_s,
            "part_titles": c.part_titles,
        }), quote=True)
        # The setlist is what settles an ambiguous segue - which song the second
        # half actually is, and whether the show even ran the way the title says.
        # Same url the app's show context menu uses.
        setlist = (f'<a class="pnet" target="_blank" title="setlist on phish.net"'
                   f' href="https://phish.net/setlists/?d={esc(c.date, quote=True)}"'
                   f'>&#x1F41F;</a>')
        warn = ""
        if c.unmatched_parts:
            # Apply has to resolve each half to a Song; a part that matches no
            # song on the track is the row most likely to fail there.
            warn = ('<span class="warn">&#9888;&#xFE0F; no song match: '
                    + esc(", ".join(c.unmatched_parts)) + '</span>')
        track_player = ""
        if c.waveform_image_url:
            track_player = (
                f'<div class="track" data-src="{esc(c.mp3_url, quote=True)}" '
                f'data-duration="{c.duration_s}">'
                f'<div class="tctl">'
                f'<button class="tplay" title="play the full track">&#9654;</button>'
                f'<button class="tt" title="use this position as the cut point">0:00</button>'
                f'</div>'
                f'<div class="wave">'
                f'<img src="{esc(c.waveform_image_url, quote=True)}" loading="lazy">'
                f'<span class="cut"></span><span class="pos"></span></div></div>')
        rows.append(f"""
<div class="row">
  <div class="head">
    <input type="checkbox" class="approve" data-payload="{payload}"
      title="approve this split (w)">
    <input type="checkbox" class="skip" title="do not split this track (x or k)">
    <strong>{link}</strong>
    <span class="dur">{fmt_ts(c.duration_s)}</span>
    {setlist}
    <span class="chosen"></span>
    {warn}
    <span class="status"></span>
  </div>
  <div class="body">
    <div class="controls">
      <div class="tune">
        <button class="replay" title="replay both audition clips (e)">&#x21ba;</button>
        <input class="cut" type="text" value="{fmt_tenths(c.cut_s)}"
          size="8" spellcheck="false" title="cut point">
        <button class="nudge" data-step="-1" title="1 second earlier (a)">&minus;1</button>
        <button class="nudge" data-step="-0.1" title="0.1 seconds earlier (s or [)">&minus;.1</button>
        <button class="nudge" data-step="0.1" title="0.1 seconds later (d or ])">+.1</button>
        <button class="nudge" data-step="1" title="1 second later (f)">+1</button>
      </div>
      <div class="parts">
        <div class="part" data-side="before">
          <span class="plabel">end of <b>{esc(c.part_titles[0])}</b></span>
          <div class="audio"></div>
        </div>
        <div class="part" data-side="after">
          <span class="plabel">start of <b>{esc(c.part_titles[1])}</b></span>
          <div class="audio"></div>
        </div>
      </div>
      {tag_picker(c, esc)}
    </div>
    {track_player}
  </div>
</div>""")

    footnote = ""
    if multi:
        items = "".join(
            f'<div class="meta">'
            + (f'<a href="{esc(m["share_url"], quote=True)}" target="_blank">'
               f'{esc(display_label(m["label"]))}</a>' if m["share_url"]
               else esc(display_label(m["label"])))
            + f' &middot; {m["segues"]} segues</div>'
            for m in sorted(multi, key=lambda m: m["label"]))
        footnote = (f'<h2>Multi-segue ({len(multi)}) &mdash; not reviewable here</h2>'
                    f'<p class="meta">Three or more songs in one track. Splitting '
                    f'these needs more than one cut point; follow-up work.</p>{items}')

    html_path.parent.mkdir(parents=True, exist_ok=True)
    html_path.write_text(f"""<!doctype html>
<meta charset="utf-8">
<title>Track split review</title>
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
  .row.done:not(.sel) .body {{ display: none; }}
  .row.done:not(.sel) .head {{ margin-bottom: 0; }}
  .dur {{ color: var(--muted); font-variant-numeric: tabular-nums; font-size: 14px; }}
  .chosen {{ display: none; font-variant-numeric: tabular-nums; font-weight: 600;
             color: var(--ok); font-size: 15px; }}
  .row.done:not(.sel) .chosen {{ display: inline; }}
  .row.skipped:not(.sel) {{ opacity: .55; }}
  .row.skipped:not(.sel) .head strong,
  .row.skipped:not(.sel) .head strong a {{ text-decoration: line-through;
                                           text-decoration-color: currentColor;
                                           text-decoration-thickness: 1px; }}
  .skip {{ accent-color: var(--muted); }}
  .head {{ display: flex; gap: .6rem; align-items: center; flex-wrap: wrap;
           margin-bottom: .5rem; }}
  .head strong {{ font-family: "Open Sans Condensed", -apple-system, sans-serif;
                  font-size: 21px; font-weight: 700; letter-spacing: .01em; }}
  .meta {{ color: var(--muted); }}
  .tune .nudge, .tune .replay, .track .tplay, .track .tt, #export {{
    background: var(--btn); color: var(--fg); border: 1px solid var(--btn-line);
    border-radius: 7px; transition: background .12s ease, border-color .12s ease;
  }}
  .tune .nudge:hover, .tune .replay:hover, .track .tplay:hover, .track .tt:hover,
  #export:hover {{ background: var(--btn-hover); border-color: var(--muted); }}
  .tune .nudge:active, .tune .replay:active, .track .tplay:active,
  .track .tt:active {{ transform: translateY(1px); }}
  /* Emoji, not text: an underline would sit under the glyph and read as a
     smudge, and it keeps its own opacity so a collapsed row stays clickable. */
  .pnet {{ text-decoration: none; font-size: 15px; line-height: 1;
           opacity: .75; transition: opacity .12s ease; }}
  .pnet:hover {{ opacity: 1; }}
  .warn {{ color: var(--err); font-weight: 600; }}
  input[type="checkbox"] {{ width: 1.15rem; height: 1.15rem; cursor: pointer;
                            accent-color: var(--link); }}
  img {{ max-width: 100%; }}
  #export {{ padding: .4rem 1rem; font: inherit; font-weight: 600;
             cursor: pointer; flex: 0 0 auto; }}
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
  #topbar .bar i {{ display: inline-block; height: 100%; vertical-align: top; }}
  #topbar .bar .fill-ok {{ background: var(--ok); }}
  #topbar .bar .fill-skip {{ background: var(--accent); opacity: .55; }}
  @media (max-width: 860px) {{ #legend .k {{ display: none; }} }}
  @media (max-width: 640px) {{ #legend .stat {{ display: none; }} }}
  .tune {{ display: flex; gap: .35rem; align-items: center; margin: .4rem 0 .4rem 1.6rem; }}
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
  .tune .replay {{ font: inherit; font-size: 15px; line-height: 1; cursor: pointer;
                   padding: .15rem .35rem; }}
  .head .status {{ color: var(--muted); font-size: 13px; }}
  .head .status.err {{ color: var(--err); }}
  .head .status.busy {{ background: color-mix(in srgb, var(--accent) 22%, transparent);
                        color: var(--accent); font-weight: 600;
                        border: 1px solid color-mix(in srgb, var(--accent) 40%, transparent);
                        padding: .12rem .65rem; border-radius: 999px;
                        font-size: 12px; letter-spacing: .01em; }}
  .offline {{ background: #fff4d6; border: 1px solid #d9ad4a; color: #6b4e00;
             padding: .6rem .8rem; margin-bottom: 1rem; border-radius: 4px; }}
  .body {{ display: flex; gap: .5rem; align-items: stretch; }}
  .controls {{ flex: 0 0 22rem; min-width: 0; }}
  /* The two halves stack, each under its own song name: the pair reads as
     "what you hear last" above "what you hear first", in playing order. */
  .parts {{ margin-left: 1.6rem; }}
  .part + .part {{ margin-top: .35rem; }}
  .part .plabel {{ display: block; color: var(--muted); font-size: 12px;
                   text-transform: uppercase; letter-spacing: .04em;
                   white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }}
  .part .plabel b {{ color: var(--fg); font-weight: 700; }}
  .tags {{ margin: .5rem 0 0 1.6rem; }}
  .tags-h {{ display: block; color: var(--muted); font-size: 12px;
             text-transform: uppercase; letter-spacing: .04em; margin-bottom: .15rem; }}
  .trow {{ display: flex; align-items: center; gap: .5rem; padding: .1rem 0; }}
  .tname {{ flex: 1 1 auto; min-width: 0; font-size: 13px;
            white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }}
  .tname .swatch {{ display: inline-block; width: .55rem; height: .55rem;
                    border-radius: 50%; margin-right: .35rem; vertical-align: baseline; }}
  .tname.has-notes {{ text-decoration: underline dotted
                      color-mix(in srgb, var(--muted) 70%, transparent);
                      text-underline-offset: 3px; cursor: help; }}
  .tchoices {{ display: flex; gap: .1rem; flex: 0 0 auto; }}
  .tchoice {{ cursor: pointer; }}
  .tchoice input {{ position: absolute; opacity: 0; pointer-events: none; }}
  .tchoice span {{ display: inline-block; font-size: 12px; line-height: 1;
                   padding: .22rem .45rem; border: 1px solid var(--btn-line);
                   background: var(--btn); color: var(--muted);
                   transition: background .12s ease, color .12s ease; }}
  .tchoice:first-child span {{ border-radius: 6px 0 0 6px; }}
  .tchoice:last-child span {{ border-radius: 0 6px 6px 0; }}
  .tchoice + .tchoice span {{ border-left: none; }}
  .tchoice input:checked + span {{ background: var(--link); color: #fff;
                                   border-color: var(--link); }}
  .tchoice:hover span {{ color: var(--fg); }}
  .tchoice input:focus-visible + span {{ outline: 2px solid var(--accent);
                                         outline-offset: 1px; }}
  .controls audio {{ width: 100%; height: 34px; }}
  @media (prefers-color-scheme: dark) {{
    .controls audio {{ color-scheme: dark; }}
  }}
  .track {{ display: flex; align-items: center; gap: 1rem; flex: 1 1 auto; min-width: 280px; }}
  .track .tctl {{ display: flex; flex-direction: column; align-items: stretch;
                  justify-content: center; gap: .25rem; flex: 0 0 auto; }}
  .track .tplay {{ font: inherit; padding: .1rem .55rem; cursor: pointer; }}
  .track .wave {{ position: relative; flex: 1; cursor: pointer; line-height: 0;
                  display: flex; align-items: stretch; border-radius: 8px;
                  overflow: hidden; background: var(--card); height: 96px; }}
  .track .wave img {{ width: 100%; height: 96px; display: block;
                      object-fit: fill; filter: var(--wave-filter);
                      flex: 0 0 auto; max-width: none; }}
  /* Cut marker: unlike the lead scan, the whole track is shown, because the cut
     can be anywhere in it. Same hairline weight as the playhead so neither
     marker buries the waveform under it. */
  .track .cut {{ position: absolute; top: 0; bottom: 0; width: 1px;
                 background: color-mix(in srgb, var(--accent) 65%, transparent);
                 pointer-events: none; }}
  .track .pos {{ position: absolute; top: 0; bottom: 0; width: 1px;
                 background: color-mix(in srgb, var(--ok) 65%, transparent);
                 pointer-events: none; display: none; }}
  .track .tt {{ font: inherit; font-size: 17px; font-variant-numeric: tabular-nums;
                min-width: 4rem; cursor: pointer; padding: .15rem .4rem; }}
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
  .row.sel {{ background: var(--sel); border-color: var(--sel-line);
              box-shadow: inset 3px 0 0 var(--link); }}
</style>
<header id="topbar">
  <div class="row1">
    <h1>Track split review <span class="count">{len(rows)} candidates</span></h1>
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
{footnote}
<script>
const YEAR = {json.dumps(html_path.resolve().parent.name)};
// Seconds auditioned on each side of the cut. Matches the scanner's constants.
const CLIP_BEFORE_S = {CLIP_BEFORE_S};
const CLIP_AFTER_S = {CLIP_AFTER_S};

// Accepts "1:03.2", "63.2", "1:03". Returns null on anything else so a typo is
// rejected visibly rather than silently splitting at the wrong place.
function parseTime(raw) {{
  const s = raw.trim();
  if (!s) return null;
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

function fmtClock(sec) {{
  const m = Math.floor(sec / 60);
  return m + ":" + String(Math.floor(sec - m * 60)).padStart(2, "0");
}}

function stopFullTrack() {{
  const cur = window._playing;
  if (!cur || cur.audio.paused) return;
  cur.audio.pause();
  if (cur.playBtn) {{ cur.playBtn.classList.remove("loading"); cur.playBtn.textContent = "\\u25B6"; }}
}}

function stopOtherFullTracks(keep) {{
  const cur = window._playing;
  if (!cur || cur.audio === keep || cur.audio.paused) return;
  cur.audio.pause();
  if (cur.playBtn) {{ cur.playBtn.classList.remove("loading"); cur.playBtn.textContent = "\\u25B6"; }}
}}

function stopPreviewClips() {{
  document.querySelectorAll(".audio audio").forEach(a => {{
    if (!a.paused) a.pause();
  }});
}}

// Both halves of one cut, rendered by the same server and the same ffmpeg chain
// the apply step uses - so what you hear is what gets written. Without the
// server (opened over file://) the field still edits the export.
async function renderPreview(row) {{
  const cb = row.querySelector("input.approve");
  const input = row.querySelector("input.cut");
  const status = row.querySelector(".status");
  const payload = JSON.parse(cb.dataset.payload);
  const secs = parseTime(input.value);
  if (secs === null) return;

  status.textContent = "rendering...";
  status.classList.remove("err");
  status.classList.add("busy");
  if (row._armWatchdog) row._armWatchdog();
  const ctl = new AbortController();
  // Drop whatever this row had in flight: it is for a cut point the reviewer
  // has moved past, and it would hold a server slot.
  if (row._inflight) row._inflight.abort();
  row._inflight = ctl;
  row._pending = (row._pending || 0) + 1;
  const dur = payload.duration_s || 0;
  // Two clips, one per side of the cut, clamped to the track.
  const sides = [
    {{side: "before", start: Math.max(0, secs - CLIP_BEFORE_S), end: secs}},
    {{side: "after", start: secs,
     end: dur ? Math.min(dur, secs + CLIP_AFTER_S) : secs + CLIP_AFTER_S}},
  ];
  try {{
    const timeout = setTimeout(() => ctl.abort(), 90000);
    let results;
    try {{
      // Both sides at once: they are independent renders and the server runs
      // several concurrently, so waiting for one before asking for the other
      // would double the time to hear the cut.
      results = await Promise.all(sides.map(async s => {{
        const resp = await fetch("/preview", {{
          method: "POST",
          signal: ctl.signal,
          headers: {{"Content-Type": "application/json"}},
          body: JSON.stringify({{
            mp3_url: payload.mp3_url, trim_start: s.start, trim_end: s.end,
            // Butt cut, no fades: the two halves come from one continuous
            // recording, and the apply step joins nothing - it just cuts.
            fade_in: 0, fade_out: 0
          }})
        }});
        const data = await resp.json();
        if (!resp.ok) throw new Error(data.error || resp.statusText);
        return {{side: s.side, url: data.url}};
      }}));
    }} finally {{
      clearTimeout(timeout);
    }}
    // A newer render owns the row now; leave its status alone.
    if (row._inflight !== ctl) {{
      if (Math.max(0, (row._pending || 1) - 1) === 0) {{
        status.textContent = "";
        status.classList.remove("busy");
      }}
      return;
    }}
    results.forEach(r => {{
      const box = row.querySelector('.part[data-side="' + r.side + '"] .audio');
      if (!box) return;
      let audio = box.querySelector("audio");
      if (!audio) {{
        audio = Object.assign(document.createElement("audio"),
          {{controls: true, preload: "none"}});
        // Never two sources at once: a clip stops the full track, and stops the
        // other side's clip so the pair is heard one after the other.
        audio.addEventListener("play", () => {{
          stopFullTrack();
          row.querySelectorAll(".audio audio").forEach(o => {{
            if (o !== audio && !o.paused) o.pause();
          }});
        }});
        box.append(audio);
      }}
      audio.src = r.url + "?t=" + Date.now();
    }});
    // Play the "after" side on arrival: what decides a cut is whether the
    // second song starts cleanly, so that is the clip worth hearing first.
    if (window._sel === row) {{
      const second = row.querySelector('.part[data-side="after"] audio');
      if (second) second.play().catch(() => {{}});
    }}
    status.textContent = "";
    status.classList.remove("busy");
  }} catch (e) {{
    if (e.name === "AbortError" && row._inflight !== ctl) {{
      if (Math.max(0, (row._pending || 1) - 1) > 0) return;
      status.textContent = "";
      status.classList.remove("busy");
      return;
    }}
    status.textContent =
      e.name === "AbortError" ? "render timed out \\u2014 retry, or check the server"
      : (e instanceof TypeError || location.protocol === "file:")
        ? "no preview server \\u2014 run: rake split_scan:serve[" + (YEAR || "YYYY") + "]"
        : "preview failed: " + e.message;
    status.classList.remove("busy");
    status.classList.add("err");
  }} finally {{
    row._pending = Math.max(0, (row._pending || 1) - 1);
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
// silences whatever the old row was playing.
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
  // Arriving at a row plays its full track, the same as the lead report: the
  // cut point is unknown until you have heard where the songs change, and the
  // waveform player is how you find it. The clips come once a cut is chosen.
  if (row._startTrack && !row.classList.contains("done")) row._startTrack();
}}

function moveSelection(delta) {{
  const rows = [...document.querySelectorAll(".row")];
  if (!rows.length) return;
  const i = window._sel ? rows.indexOf(window._sel) : -1;
  const next = rows[Math.min(rows.length - 1, Math.max(0, i < 0 ? 0 : i + delta))];
  selectRow(next);
  if (next._startTrack && !next.classList.contains("done")) next._startTrack();
  if (next.scrollIntoView) next.scrollIntoView({{block: "nearest"}});
}}

document.addEventListener("keydown", e => {{
  if (e.metaKey || e.ctrlKey || e.altKey) return;
  const t = e.target && e.target.tagName;
  if (e.key === "ArrowDown" || e.key === "ArrowUp") {{
    e.preventDefault();
    if (e.target && e.target.blur) e.target.blur();
    return moveSelection(e.key === "ArrowDown" ? 1 : -1);
  }}

  const typing = (t === "INPUT" && e.target.type !== "checkbox")
    || t === "TEXTAREA" || (e.target && e.target.isContentEditable);
  // The only text field is the m:ss.s cut time, so digits, ":" and "." are the
  // only characters it can need; every other printable key stays a shortcut.
  const isTimeChar = e.key.length === 1 && /[0-9.:]/.test(e.key);
  const isShortcutChar = e.key.length === 1 && !isTimeChar;
  if (typing && !(t === "INPUT" && isShortcutChar)) return;
  if (typing && isShortcutChar) e.preventDefault();
  if (e.target && e.target.blur && (t === "AUDIO" || t === "INPUT" || t === "BUTTON")) {{
    e.target.blur();
  }}
  if (e.key === " " || e.key === "Spacebar") {{
    e.preventDefault();
    if (!window._sel || !window._sel._toggle) return;
    return window._sel._toggle();
  }}
  // Right-hand aliases so the whole loop is reachable without moving hands:
  // / = c (adopt), ; = w (approve), ' = k (skip). The nudge pair , and . alias
  // the fine steps, the ones used most while dialling a cut in.
  const RIGHT_HAND = {{"/": "c", ",": "s", ".": "d", ";": "w", "'": "k"}};
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
  // a s d f map straight onto the four nudge buttons left to right, so the
  // home row is the button row. [ and ] stay as right-hand aliases for the
  // fine pair, which is the step used most while dialling a cut in.
  const nudgeKeys = {{
    a: -1, s: -0.1, d: 0.1, f: 1,
    "[": -0.1, "]": 0.1,
  }};
  const nudgeStep = nudgeKeys[key.toLowerCase()];
  if (nudgeStep !== undefined) {{
    if (!window._sel || !window._sel._nudge) return;
    e.preventDefault();
    window._sel._nudge(nudgeStep);
    return;
  }}
  const answerKeys = {{w: "approve", x: "skip", k: "skip"}};
  const answer = answerKeys[key.toLowerCase()];
  if (answer) {{
    if (!window._sel) return;
    const box = window._sel.querySelector("input." + answer);
    if (!box) return;
    e.preventDefault();
    const other = window._sel.querySelector(
      "input." + (answer === "approve" ? "skip" : "approve"));
    if (other) other.checked = false;
    box.checked = true;
    if (window._sel._syncDone) window._sel._syncDone();
    return moveSelection(1);
  }}
  // "e" toggles the clips: the pair plays in order, before then after, so one
  // key auditions the whole cut.
  if (e.key === "e" || e.key === "E") {{
    if (!window._sel) return;
    const clips = [...window._sel.querySelectorAll(".audio audio")];
    if (!clips.length) return;
    e.preventDefault();
    const playing = clips.find(c => !c.paused);
    if (playing) return playing.pause();
    if (window._sel._playPair) window._sel._playPair();
    return;
  }}
  if (e.key !== "ArrowLeft" && e.key !== "ArrowRight") return;

  const cur = window._playing;
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
    + "Run: rake split_scan:serve[" + YEAR + "] and open the http:// URL. "
    + "Editing cut points still works and still exports.";
  document.body.prepend(b);
}}

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
  const ok = document.querySelector("#topbar .fill-ok");
  const sk = document.querySelector("#topbar .fill-skip");
  if (ok) ok.style.width = (total ? (approved / total) * 100 : 0) + "%";
  if (sk) sk.style.width = (total ? (skipped / total) * 100 : 0) + "%";
  saveProgress();
}}

// Progress survives a reload, keyed by share url so it follows the track even
// if the page is rebuilt and the rows reorder. Approved rows also store their
// chosen cut, so a reload does not throw away the timing work.
const STORE_KEY = "splitscan:progress:" + YEAR;
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
    if (a && a.checked) {{
      let cut = null;
      try {{ cut = JSON.parse(a.dataset.payload).cut_s; }} catch (e) {{}}
      state[key] = {{mark: "a", cut_s: cut}};
    }} else if (s && s.checked) {{
      state[key] = {{mark: "s"}};
    }}
    const tags = tagChoices(row);
    if (Object.keys(tags).length) {{
      state[key] = Object.assign(state[key] || {{mark: null}}, {{tag_sides: tags}});
    }}
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
    const saved = state[rowKey(row)];
    if (!saved) return;
    if (saved.tag_sides) {{
      Object.keys(saved.tag_sides).forEach(name => {{
        const trow = [...row.querySelectorAll(".trow")]
          .find(t => t.dataset.tag === name);
        if (!trow) return;
        const pick = trow.querySelector('input[value="' + saved.tag_sides[name] + '"]');
        if (pick) pick.checked = true;
      }});
    }}
    if (!saved.mark) return;
    const box = row.querySelector(saved.mark === "a" ? "input.approve" : "input.skip");
    if (!box) return;
    box.checked = true;
    if (saved.mark === "a" && typeof saved.cut_s === "number" && row._setCut) {{
      row._setCut(saved.cut_s);
    }}
    // Setting .checked in script fires no "change", so collapse by hand.
    if (row._syncDone) row._syncDone();
  }});
}}

document.querySelectorAll(".row").forEach(row => {{
  const cb = row.querySelector("input.approve");
  const input = row.querySelector("input.cut");
  if (!cb || !input) return;
  const original = JSON.parse(cb.dataset.payload).cut_s;
  const duration = JSON.parse(cb.dataset.payload).duration_s || 0;

  let renderTimer = null;
  // Watchdog: the busy pill has several exit paths and any one going wrong
  // strands "rendering..." on screen. Guarantee it cannot outlive the work.
  const armWatchdog = () => {{
    clearTimeout(row._watchdog);
    row._deadline = Date.now() + 120000;
    row._watchdog = setTimeout(function tick() {{
      const st = row.querySelector(".status");
      if (!st.classList.contains("busy")) return;
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
    const st = row.querySelector(".status");
    st.textContent = "waiting...";
    st.classList.remove("err");
    st.classList.add("busy");
    renderTimer = setTimeout(() => renderPreview(row), 450);
  }};

  const commit = () => {{
    const secs = parseTime(input.value);
    const st = row.querySelector(".status");
    input.classList.toggle("invalid", secs === null);
    if (secs === null) {{
      clearTimeout(renderTimer);
      st.textContent = "use m:ss.s (e.g. 1:03.2)";
      st.classList.remove("busy");
      st.classList.add("err");
      return;
    }}
    const payload = JSON.parse(cb.dataset.payload);
    if (payload.cut_s === secs) {{
      if (!row._pending) {{
        clearTimeout(renderTimer);
        if (!st.classList.contains("err")) {{
          st.textContent = "";
          st.classList.remove("busy");
        }}
      }}
      return;
    }}
    payload.cut_s = secs;
    cb.dataset.payload = JSON.stringify(payload);
    row.classList.toggle("edited", Math.abs(secs - original) > 0.05);
    if (row._markCut) row._markCut(secs);
    if (row._syncDone) row._syncDone();
    scheduleRender();
  }};

  input.addEventListener("change", commit);
  input.addEventListener("keydown", e => {{ if (e.key === "Enter") {{ e.preventDefault(); commit(); }} }});
  // Used by restoreProgress to put a saved cut back in the field.
  row._setCut = secs => {{ input.value = fmtTime(secs); commit(); }};

  // Full-track player. Streams the original mp3 straight from phish.in and
  // scrubs on the waveform: this is how the segue gets found in the first place.
  const track = row.querySelector(".track");
  if (track) {{
    const wave = track.querySelector(".wave");
    const posEl = track.querySelector(".pos");
    const cutEl = track.querySelector(".cut");
    const label = track.querySelector(".tt");
    const playBtn = track.querySelector(".tplay");
    let full = null;

    // The whole track is shown, unlike the lead report's opening window: a
    // segue can land anywhere, so the waveform has to cover everywhere.
    const shown = duration || 1;
    const frac = secs => (shown > 0 ? Math.min(1, Math.max(0, secs / shown)) : 0);

    const markCut = secs => {{
      cutEl.style.left = (frac(secs) * 100) + "%";
    }};
    markCut(original);
    row._markCut = markCut;
    let atSecs = 0;

    // Clicking the readout adopts that position as the cut point.
    const adopt = () => {{
      const was = JSON.parse(cb.dataset.payload).cut_s;
      input.value = fmtTime(Math.round(atSecs * 10) / 10);
      input.classList.remove("invalid");
      commit();
      // Adopting is an explicit request to hear it, so render even when the
      // value did not actually change (commit no-ops in that case).
      if (JSON.parse(cb.dataset.payload).cut_s === was) scheduleRender();
      // Stop the full track shortly after: the clips are what to listen to
      // next, and letting the rest of the track run just has to be stopped.
      if (full && !full.paused) {{
        clearTimeout(row._adoptStop);
        const from = full.currentTime;
        row._adoptStop = setTimeout(() => {{
          if (!full || full.paused) return;
          const expected = from + 3;
          if (Math.abs(full.currentTime - expected) > 1) return;
          full.pause();
          if (row._paintBtn) row._paintBtn();
        }}, 3000);
      }}
    }};
    label.addEventListener("click", adopt);
    row._adopt = adopt;

    const paintBtn = () => {{
      playBtn.textContent = (full && !full.paused) ? "\\u23F8" : "\\u25B6";
    }};
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
      full.addEventListener("waiting", () => setLoading(true));
      full.addEventListener("stalled", () => setLoading(true));
      ["playing", "canplay", "error", "pause", "ended"].forEach(
        ev => full.addEventListener(ev, () => setLoading(false)));
      full.addEventListener("play", () => {{
        stopOtherFullTracks(full);
        window._playing = {{audio: full, label, posEl, duration, playBtn, row,
          mark: t => {{
            posEl.style.display = "block";
            posEl.style.left = (frac(t) * 100) + "%";
          }}}};
        stopPreviewClips();
      }});
      full.addEventListener("timeupdate", () => {{
        const d = full.duration || duration;
        if (!d) return;
        posEl.style.display = "block";
        posEl.style.left = (frac(full.currentTime) * 100) + "%";
        atSecs = full.currentTime;
        label.textContent = fmtClock(full.currentTime);
      }});
      full.addEventListener("ended", () => {{ paintBtn(); }});
      return full;
    }};

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

  row.addEventListener("mousedown", () => selectRow(row));

  const chosen = row.querySelector(".chosen");
  const skipBox = row.querySelector("input.skip");
  const syncDone = () => {{
    const skipped = skipBox && skipBox.checked;
    const on = cb.checked || skipped;
    row.classList.toggle("done", on);
    row.classList.toggle("skipped", !!skipped);
    if (chosen) chosen.textContent = (on && !skipped) ? input.value : "";
    if (on) {{
      stopRowAudio(row);
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
  const settle = (box, other) => box.addEventListener("change", () => {{
    if (box.checked && other) other.checked = false;
    syncDone();
    if (box.checked) return moveSelection(1);
    selectRow(row);
    if (row._startTrack) row._startTrack();
  }});
  settle(cb, skipBox);
  if (skipBox) settle(skipBox, cb);
  row._syncDone = syncDone;

  row.querySelectorAll(".trow input[type=radio]").forEach(radio => {{
    radio.addEventListener("change", saveProgress);
  }});

  // Play both clips back to back, so one press auditions the whole cut the way
  // the audio will actually run once the track is split.
  const playPair = () => {{
    const before = row.querySelector('.part[data-side="before"] audio');
    const after = row.querySelector('.part[data-side="after"] audio');
    if (!before || !before.src) {{
      if (after && after.src) {{ after.currentTime = 0; after.play().catch(() => {{}}); }}
      return;
    }}
    before.currentTime = 0;
    if (after && after.src) {{
      before.onended = () => {{
        before.onended = null;
        after.currentTime = 0;
        after.play().catch(() => {{}});
      }};
    }}
    before.play().catch(() => {{}});
  }};
  row._playPair = playPair;
  // "r" replays only the second half: a cut is judged on whether the next song
  // starts cleanly, so that is the clip worth hearing again on its own.
  row._restart = () => {{
    const after = row.querySelector('.part[data-side="after"] audio');
    if (!after || !after.src) return;
    const before = row.querySelector('.part[data-side="before"] audio');
    // Drop a pending hand-off from a pair playback, or the pair would restart
    // the "after" clip a second time when the first half runs out.
    if (before) {{ before.onended = null; if (!before.paused) before.pause(); }}
    after.currentTime = 0;
    after.play().catch(() => {{}});
  }};
  const replay = row.querySelector("button.replay");
  if (replay) replay.addEventListener("click", playPair);

  // Nudge from whatever is in the field so repeated clicks compound; an
  // unparseable field falls back to the committed value rather than 0.
  const nudgeBy = amount => {{
    const base = parseTime(input.value) ?? JSON.parse(cb.dataset.payload).cut_s;
    const next = Math.max(0, Math.round((base + amount) * 10) / 10);
    // Both halves must survive the cut, the same bound the apply step enforces.
    if (duration && (next < {MIN_PART_S} || next > duration - {MIN_PART_S})) return;
    input.value = fmtTime(next);
    input.classList.remove("invalid");
    commit();
  }};
  row.querySelectorAll("button.nudge").forEach(btn => {{
    btn.addEventListener("click", () => nudgeBy(Number(btn.dataset.step)));
  }});
  row._nudge = nudgeBy;
  row._armWatchdog = armWatchdog;
}});

restoreProgress();
updateLegend();

function tagChoices(row) {{
  const out = {{}};
  row.querySelectorAll(".trow").forEach(trow => {{
    const picked = trow.querySelector("input:checked");
    if (picked && picked.value !== "both") out[trow.dataset.tag] = picked.value;
  }});
  return out;
}}

document.getElementById("export").onclick = () => {{
  const approved = [...document.querySelectorAll("input.approve:checked")]
    .map(cb => {{
      const p = JSON.parse(cb.dataset.payload);
      // The apply step needs the track, the cut, and a label to report; the
      // rest is review-page bookkeeping.
      const entry = {{label: p.label, mp3_url: p.mp3_url, share_url: p.share_url,
               cut_s: p.cut_s}};
      const tags = tagChoices(cb.closest(".row"));
      if (Object.keys(tags).length) entry.tag_sides = tags;
      return entry;
    }});
  const blob = new Blob([JSON.stringify(approved, null, 2)], {{type: "application/json"}});
  const a = Object.assign(document.createElement("a"),
    {{href: URL.createObjectURL(blob), download: "approved.json"}});
  a.click();
}};
</script>
""")
    html_path.with_name("summary.json").write_text(json.dumps(
        {"candidates": len(candidates), "multi_segue": len(multi)}))
    if not quiet:
        print(f"Review page written to {html_path}", file=sys.stderr)


def report_json(candidates, multi):
    return json.dumps({"candidates": [asdict(c) for c in candidates],
                       "multi_segue": multi}, indent=2)


def load_report(path):
    data = json.loads(path.read_text())
    candidates = [SplitCandidate(**c) for c in data.get("candidates", [])]
    return candidates, data.get("multi_segue", [])


def rebuild_dir(dir_path, ignore_urls):
    """Regenerate review.html from an existing report.json. No API calls."""
    report_path = dir_path / "report.json"
    if not report_path.exists():
        print(f"  no report.json in {dir_path}, skipping", file=sys.stderr)
        return
    candidates, multi = load_report(report_path)
    # The ignore list is authoritative on every rebuild, so adding a url there
    # drops the row without needing a rescan.
    kept = [c for c in candidates if c.share_url.rstrip("/") not in ignore_urls]
    if len(kept) != len(candidates):
        print(f"  dropping {len(candidates) - len(kept)} ignore-listed track(s)",
              file=sys.stderr)
    report_path.write_text(report_json(kept, multi))
    write_review_html(dir_path / "review.html", kept, multi)


def main():
    p = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--year", action="append", default=[], type=int, metavar="YYYY",
                   help="Scan every show of a year (repeatable)")
    p.add_argument("--show", action="append", default=[], metavar="YYYY-MM-DD",
                   help="Scan one show (repeatable)")
    p.add_argument("--rebuild", action="append", default=[], type=Path, metavar="DIR",
                   help="Regenerate review.html from DIR/report.json (repeatable)")
    p.add_argument("--ignore-file", type=Path,
                   default=REPO_ROOT / "data" / "split_scan" / "ignore.txt",
                   help="Share URLs to leave alone, one per line")
    p.add_argument("--json", type=Path, help="Write report.json here")
    p.add_argument("--html", type=Path, help="Write review.html here")
    args = p.parse_args()

    ignore_urls = load_ignore_urls(args.ignore_file)
    if ignore_urls:
        print(f"Ignoring {len(ignore_urls)} track(s) from {args.ignore_file}",
              file=sys.stderr)

    if args.rebuild:
        for d in args.rebuild:
            rebuild_dir(d, ignore_urls)
        return

    dates = list(args.show)
    for year in args.year:
        dates.extend(fetch_year_dates(year))
    if not dates:
        p.error("nothing to scan: pass --year, --show, or --rebuild")

    candidates, multi = [], []
    ordered = sorted(set(dates))
    with ThreadPoolExecutor(max_workers=FETCH_WORKERS) as pool:
        results = pool.map(lambda d: fetch_show_candidates(d, ignore_urls), ordered)
        for i, (date, (found, found_multi)) in enumerate(zip(ordered, results), 1):
            print(f"[{i}/{len(ordered)}] {date}", file=sys.stderr)
            for c in found:
                note = (f"  ! no song match for {', '.join(c.unmatched_parts)}"
                        if c.unmatched_parts else "")
                print(f"  {display_label(c.label)}{note}", file=sys.stderr)
            candidates.extend(found)
            multi.extend(found_multi)

    print(f"\n{len(candidates)} split candidate(s), "
          f"{len(multi)} multi-segue track(s)", file=sys.stderr)

    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(report_json(candidates, multi))
        print(f"Report written to {args.json}", file=sys.stderr)
    if args.html:
        write_review_html(args.html, candidates, multi)


if __name__ == "__main__":
    main()
