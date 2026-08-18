#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11,<3.13"
# dependencies = [
#   "requests",
# ]
# ///
"""Find sandwiches that were split across two tracks, and review the join.

A sandwich is a song played around another ("HYHU > Terrapin > HYHU"). Some are
stored as one track, but many are split: a bare "Hold Your Head Up" followed by
"Terrapin > Hold Your Head Up", or the mirror of that. This scans the phish.in
API for adjacent pairs where the outer song repeats across the track boundary
and writes one review page (not per year) where a human confirms the merge.

The audition is the joint itself: the last seconds of the first track butted
against the first seconds of the second, so a glitch at the splice is audible
before anything is merged.

Usage (normally via the rake tasks):
  uv run scripts/audio_sandwich_analysis.py --json data/sandwich_scan/report.json \\
    --html data/sandwich_scan/review.html
  uv run scripts/audio_sandwich_analysis.py --rebuild data/sandwich_scan
"""

import argparse
import base64
import html as html_escape
import json
import re
import sys
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict, dataclass, field
from pathlib import Path

import requests

API_BASE = "https://phish.in/api/v2"
SITE_BASE = "https://phish.in"
REPO_ROOT = Path(__file__).resolve().parent.parent
# Seconds auditioned on each side of the joint. Short: the only question is
# whether the two tracks butt together cleanly.
JOINT_S = 2.5
SEGUE_RE = re.compile(r"\s*-?>\s*")
FETCH_WORKERS = 12

# Abbreviations used when a song appears inside a multi-song title. Any song can
# be the bread of a sandwich; these are only the ones that get shortened.
ABBREVIATIONS = {
    "hold your head up": "HYHU",
    "the man who stepped into yesterday": "TMWSIY",
    "you enjoy myself": "YEM",
}
# Spoken-word segments recur naturally through a show - a Gamehendge set runs
# "Narration > The Lizards > Narration" as three real tracks - so a repeat
# around them is not a split sandwich.
NOT_BREAD = {
    "narration", "banter", "interview", "(check) banter", "jam",
    "intro", "outro", "soundcheck", "crowd", "tuning",
}
# Titles that already carry the abbreviation, so a scan sees both spellings.
ALIASES = {
    "hyhu": "hold your head up",
    "tmwsiy": "the man who stepped into yesterday",
    "yem": "you enjoy myself",
}


def norm(title):
    t = title.strip().lower()
    return ALIASES.get(t, t)


def parts_of(title):
    return [p.strip() for p in SEGUE_RE.split(title) if p.strip()]


def abbreviate(title):
    return ABBREVIATIONS.get(norm(title), title.strip())


@dataclass
class SandwichCandidate:
    label: str
    date: str
    set_name: str
    outer: str            # canonical outer song title
    merged_title: str     # what the combined track should be called
    first_id: int
    first_title: str
    first_position: int
    first_mp3_url: str
    first_duration_s: float
    first_waveform_url: str
    first_share_url: str
    second_id: int
    second_title: str
    second_position: int
    second_mp3_url: str
    second_duration_s: float
    second_waveform_url: str
    second_share_url: str
    shape: str            # which arrangement was matched, for the report
    # A sandwich can also be three whole tracks ("HYHU", "Jennifer Dances",
    # "HYHU"); the third is absent for the two-track shapes.
    third_id: int = 0
    third_title: str = ""
    third_position: int = 0
    third_mp3_url: str = ""
    third_duration_s: float = 0.0
    third_waveform_url: str = ""
    third_share_url: str = ""


def fmt_ts(seconds):
    seconds = int(round(float(seconds)))
    m, s = divmod(seconds, 60)
    h, m = divmod(m, 60)
    return f"{h}:{m:02d}:{s:02d}" if h else f"{m}:{s:02d}"


def merged_title_for(outer, first_title, second_title):
    """The sandwich the two tracks add up to, outer song abbreviated.

    The inner songs are whatever the two titles hold once the outer song is
    stripped from the ends, in playing order."""
    # outer is a normalized key; the display spelling comes from whichever title
    # actually holds it, so a song with no abbreviation keeps its real casing.
    spelled = next((p for p in parts_of(first_title) + parts_of(second_title)
                    if norm(p) == norm(outer)), outer)
    outer_abbr = abbreviate(spelled)
    inner = []
    for part in parts_of(first_title) + parts_of(second_title):
        if norm(part) == norm(outer):
            continue
        inner.append(part.strip())
    # Consecutive duplicates would read "A > B > B > A" when both halves name
    # the same inner song; the sandwich only has it once.
    deduped = []
    for part in inner:
        if not deduped or norm(deduped[-1]) != norm(part):
            deduped.append(part)
    return " > ".join([outer_abbr, *deduped, outer_abbr])


def scan_show(date, ignore_urls):
    """(candidates, footnotes, combined) for one show."""
    resp = requests.get(f"{API_BASE}/shows/{date}", timeout=30)
    resp.raise_for_status()
    tracks = sorted(resp.json()["tracks"], key=lambda t: t["position"])
    candidates, footnotes, combined = [], [], []
    paired = set()

    for i, t in enumerate(tracks):
        parts = [norm(p) for p in parts_of(t["title"])]
        # Any song can be the bread; the shape is what identifies a sandwich,
        # not a fixed list of songs.
        outer_here = [p for p in parts if p not in NOT_BREAD]
        if not outer_here:
            continue
        # A track that already holds a whole sandwich needs no merge, but it is
        # the reference set for what a finished one looks like, so it is kept.
        if len(parts) >= 3 and parts[0] == parts[-1]:
            if parts[0] not in NOT_BREAD:
                combined.append({
                    "date": date, "set_name": t["set_name"],
                    "position": t["position"], "title": t["title"],
                    "outer": parts[0],
                    "duration_s": round((t.get("duration") or 0) / 1000.0, 1),
                    "share_url": f"{SITE_BASE}/{date}/{t.get('slug', '')}",
                })
            continue
        if t["position"] in paired:
            continue
        matched = False
        # Three whole tracks: the outer song, something else, the outer song
        # again ("HYHU", "Jennifer Dances", "HYHU"). Checked before the pair
        # shapes because none of its titles carry a segue to match on.
        if i + 2 < len(tracks):
            mid, last = tracks[i + 1], tracks[i + 2]
            mparts = [norm(p) for p in parts_of(mid["title"])]
            lparts = [norm(p) for p in parts_of(last["title"])]
            for outer in outer_here:
                if not (len(parts) == 1 and parts[0] == outer
                        and lparts[-1] == outer
                        and outer not in mparts):
                    continue
                if not (t["set_name"] == mid["set_name"] == last["set_name"]):
                    continue
                if mid["position"] in paired or last["position"] in paired:
                    continue
                if not all(x.get("mp3_url") for x in (t, mid, last)):
                    continue
                inner = " > ".join(
                    [mid["title"].strip()]
                    + [p for p in parts_of(last["title"])
                       if norm(p) != outer])
                label = (f"{date} {t['set_name']} t{t['position']:02d} "
                         f"{t['title']} + {mid['title']} + {last['title']}")
                candidates.append(SandwichCandidate(
                    label=label, date=date, set_name=t["set_name"],
                    outer=outer,
                    merged_title=(f"{abbreviate(t['title'])} > {inner} > "
                                  f"{abbreviate(t['title'])}"),
                    first_id=t["id"], first_title=t["title"],
                    first_position=t["position"], first_mp3_url=t["mp3_url"],
                    first_duration_s=round((t.get("duration") or 0) / 1000.0, 1),
                    first_waveform_url=t.get("waveform_image_url") or "",
                    first_share_url=f"{SITE_BASE}/{date}/{t.get('slug', '')}",
                    second_id=mid["id"], second_title=mid["title"],
                    second_position=mid["position"], second_mp3_url=mid["mp3_url"],
                    second_duration_s=round((mid.get("duration") or 0) / 1000.0, 1),
                    second_waveform_url=mid.get("waveform_image_url") or "",
                    second_share_url=f"{SITE_BASE}/{date}/{mid.get('slug', '')}",
                    shape="A | B | A",
                    third_id=last["id"], third_title=last["title"],
                    third_position=last["position"], third_mp3_url=last["mp3_url"],
                    third_duration_s=round((last.get("duration") or 0) / 1000.0, 1),
                    third_waveform_url=last.get("waveform_image_url") or "",
                    third_share_url=f"{SITE_BASE}/{date}/{last.get('slug', '')}",
                ))
                matched = True
                paired.update({t["position"], mid["position"], last["position"]})
                break
        if matched:
            continue
        if i + 1 < len(tracks):
            nxt = tracks[i + 1]
            nparts = [norm(p) for p in parts_of(nxt["title"])]
            for outer in outer_here:
                # The outer song ends this track and ends the next one too
                # ("HYHU" then "Terrapin > HYHU"), or opens both.
                pair = ((parts[0] == outer and nparts[-1] == outer)
                        or (parts[-1] == outer and nparts[0] == outer))
                if not (pair and t["set_name"] == nxt["set_name"]):
                    continue
                if len(parts) == 1 and len(nparts) == 1:
                    continue  # two bare outer tracks: nothing sandwiched
                if not (t.get("mp3_url") and nxt.get("mp3_url")):
                    continue
                shape = "A | B>A" if len(parts) == 1 else "A>B | A"
                label = (f"{date} {t['set_name']} t{t['position']:02d} "
                         f"{t['title']} + {nxt['title']}")
                candidates.append(SandwichCandidate(
                    label=label, date=date, set_name=t["set_name"],
                    outer=outer,
                    merged_title=merged_title_for(outer, t["title"], nxt["title"]),
                    first_id=t["id"], first_title=t["title"],
                    first_position=t["position"], first_mp3_url=t["mp3_url"],
                    first_duration_s=round((t.get("duration") or 0) / 1000.0, 1),
                    first_waveform_url=t.get("waveform_image_url") or "",
                    first_share_url=f"{SITE_BASE}/{date}/{t.get('slug', '')}",
                    second_id=nxt["id"], second_title=nxt["title"],
                    second_position=nxt["position"], second_mp3_url=nxt["mp3_url"],
                    second_duration_s=round((nxt.get("duration") or 0) / 1000.0, 1),
                    second_waveform_url=nxt.get("waveform_image_url") or "",
                    second_share_url=f"{SITE_BASE}/{date}/{nxt.get('slug', '')}",
                    shape=shape,
                ))
                matched = True
                paired.update({t["position"], nxt["position"]})
                break
        if matched:
            continue
        # An outer song inside a multi-song title with no adjacent partner. Not
        # actionable here, but worth a human look, so it is footnoted.
        if len(parts) > 1:
            footnotes.append({
                "date": date, "set_name": t["set_name"], "position": t["position"],
                "title": t["title"],
                "share_url": f"{SITE_BASE}/{date}/{t.get('slug', '')}",
                "outer": next(iter(outer_here)),
            })
    return candidates, footnotes, combined


def fetch_dates_for_outer_songs():
    """Every show date with audio. The sandwich shape can involve any song, so
    the whole catalog is swept rather than the shows of a few named songs."""
    dates, page = [], 1
    while True:
        resp = requests.get(f"{API_BASE}/shows",
                            params={"page": page, "per_page": 1000}, timeout=60)
        resp.raise_for_status()
        data = resp.json()
        dates.extend(s["date"] for s in data.get("shows", [])
                     if s.get("audio_status") != "missing")
        if page >= data.get("total_pages", 1):
            break
        page += 1
    return sorted(set(dates))


def load_ignore_urls(path):
    if not path or not Path(path).exists():
        return set()
    return {
        line.strip().rstrip("/")
        for line in Path(path).read_text().splitlines()
        if line.strip() and not line.strip().startswith("#")
    }


def embedded_fonts():
    font_dir = REPO_ROOT / "node_modules/@fontsource/open-sans-condensed/files"
    faces = []
    for weight in (300, 700):
        path = font_dir / f"open-sans-condensed-latin-{weight}-normal.woff2"
        if not path.exists():
            continue
        b64 = base64.b64encode(path.read_bytes()).decode()
        src = f'url(data:font/woff2;base64,{b64}) format("woff2")'
        faces.append(
            '@font-face { font-family: "Open Sans Condensed"; font-style: normal; '
            f'font-weight: {weight}; font-display: swap; src: {src}; ' + "}")
    return "\n  ".join(faces)


def write_review_html(html_path, candidates, footnotes, combined=None,
                      quiet=False):
    combined = combined or []
    esc = html_escape.escape
    rows = []
    for c in sorted(candidates, key=lambda c: (c.date, c.first_position)):
        payload = esc(json.dumps({
            "label": c.label, "date": c.date,
            "merged_title": c.merged_title,
            "first_id": c.first_id, "first_title": c.first_title,
            "first_mp3_url": c.first_mp3_url,
            "first_duration_s": c.first_duration_s,
            "first_share_url": c.first_share_url,
            "second_id": c.second_id, "second_title": c.second_title,
            "second_mp3_url": c.second_mp3_url,
            "second_duration_s": c.second_duration_s,
            "second_share_url": c.second_share_url,
            "third_id": c.third_id, "third_title": c.third_title,
            "third_position": c.third_position,
            "third_mp3_url": c.third_mp3_url,
            "third_duration_s": c.third_duration_s,
            "third_share_url": c.third_share_url,
        }), quote=True)
        setlist = (f'<a class="pnet" target="_blank" title="setlist on phish.net"'
                   f' href="https://phish.net/setlists/?d={esc(c.date, quote=True)}"'
                   f'>&#x1F41F;</a>')

        def wave(url, title, share, pos, dur, side):
            img = (f'<img src="{esc(url, quote=True)}" loading="lazy">'
                   if url else '<span class="nowave">no waveform</span>')
            link = (f'<a href="{esc(share, quote=True)}" target="_blank">'
                    f'{esc(title)}</a>')
            return (
                f'<div class="half" data-side="{side}">'
                f'<div class="hhead"><span class="pos">t{pos:02d}</span> {link}'
                f'<span class="dur">{fmt_ts(dur)}</span></div>'
                f'<div class="wave">{img}</div></div>')

        def joint_row(idx, left_title, right_title):
            return (
                f'<div class="joint" data-joint="{idx}">'
                f'<button class="jplay" title="hear this joint">&#9654; joint</button>'
                f'<span class="jmeta">{esc(left_title)} &rarr; {esc(right_title)}'
                f' &middot; {JOINT_S}s each side</span>'
                f'<div class="audio"></div></div>')

        if c.third_id:
            joint = (joint_row(0, c.first_title, c.second_title)
                     + joint_row(1, c.second_title, c.third_title))
        else:
            joint = joint_row(0, c.first_title, c.second_title)

        rows.append(f"""
<div class="row" data-payload="{payload}">
  <div class="head">
    <input type="checkbox" class="approve" title="approve this merge (w)">
    <input type="checkbox" class="skip" title="leave these tracks alone (x or k)">
    <strong>{esc(c.date)}</strong>
    <span class="setname">{esc(c.set_name)}</span>
    {setlist}
    <span class="merged">{esc(c.merged_title)}</span>
    <span class="shape">{esc(c.shape)}</span>
    <span class="status"></span>
  </div>
  <div class="body">
    <div class="halves">
      {wave(c.first_waveform_url, c.first_title, c.first_share_url,
            c.first_position, c.first_duration_s, "first")}
      <div class="seam" title="the split being removed"></div>
      {wave(c.second_waveform_url, c.second_title, c.second_share_url,
            c.second_position, c.second_duration_s, "second")}
      {'<div class="seam" title="the split being removed"></div>' if c.third_id else ''}
      {wave(c.third_waveform_url, c.third_title, c.third_share_url,
            c.third_position, c.third_duration_s, "third") if c.third_id else ''}
    </div>
    {joint}
  </div>
</div>""")

    def listing(entries, blurb):
        items = "".join(
            f'<div class="fn"><span class="fndate">{esc(e["date"])}</span>'
            f'<span class="fnset">{esc(e["set_name"])} t{e["position"]:02d}</span>'
            + (f'<a href="{esc(e["share_url"], quote=True)}" target="_blank">'
               f'{esc(e["title"])}</a>' if e.get("share_url")
               else esc(e["title"]))
            + (f'<span class="fndur">{fmt_ts(e["duration_s"])}</span>'
               if e.get("duration_s") else '')
            + '</div>'
            for e in sorted(entries, key=lambda e: (e["date"], e["position"])))
        return f'<p class="meta">{blurb}</p>{items}'

    foot_html = listing(
        footnotes,
        "An outer song inside a multi-song title with no adjacent partner to "
        "merge with. Nothing to do here automatically &mdash; listed so each "
        "can be inspected by hand.") if footnotes else '<p class="meta">None.</p>'

    combined_counts = Counter(c["outer"] for c in combined)
    pending_counts = Counter(c.outer for c in candidates)
    tally = "".join(
        f'<tr><td>{esc(song.title())}</td>'
        f'<td>{combined_counts.get(song, 0)}</td>'
        f'<td>{pending_counts.get(song, 0)}</td></tr>'
        for song in sorted(set(combined_counts) | set(pending_counts),
                           key=lambda s: -(combined_counts.get(s, 0)
                                           + pending_counts.get(s, 0))))
    combined_html = (
        f'<table class="tally"><thead><tr><th>Song</th><th>Combined</th>'
        f'<th>Pending</th></tr></thead><tbody>{tally}</tbody>'
        f'<tfoot><tr><td>Total</td><td>{len(combined)}</td>'
        f'<td>{len(candidates)}</td></tr></tfoot></table>'
        + listing(combined,
                  "Sandwiches that already live in a single track. These are "
                  "the reference set &mdash; nothing to do, shown for "
                  "comparison against what is still pending.")
    ) if combined else '<p class="meta">None.</p>'

    html_path.parent.mkdir(parents=True, exist_ok=True)
    html_path.write_text(f"""<!doctype html>
<meta charset="utf-8">
<title>Sandwich merge review</title>
<link rel="icon" href='data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><text y=".9em" font-size="90">&#x1F96A;</text></svg>'>
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
  h1, h2 {{ font-family: "Open Sans Condensed", -apple-system, sans-serif;
            font-weight: 700; letter-spacing: .01em; }}
  h1 {{ font-size: 30px; margin: 0 0 1.2rem; }}
  h2 {{ font-size: 21px; color: var(--muted); margin-top: 2rem; }}
  a {{ color: var(--link);
       text-decoration-color: color-mix(in srgb, var(--link) 45%, transparent);
       text-underline-offset: 2px; }}
  a:hover {{ text-decoration-color: currentColor; }}
  .row {{ border: 1px solid transparent; border-bottom-color: var(--line);
          border-radius: 10px; padding: .85rem 1rem; transition: background .12s ease; }}
  .row:hover {{ background: var(--card); }}
  .row.done:not(.sel) .body {{ display: none; }}
  .row.done:not(.sel) .head {{ margin-bottom: 0; }}
  .row.skipped:not(.sel) {{ opacity: .55; }}
  .row.skipped:not(.sel) .merged {{ text-decoration: line-through; }}
  .row.sel {{ background: var(--sel); border-color: var(--sel-line);
              box-shadow: inset 3px 0 0 var(--link); }}
  .head {{ display: flex; gap: .6rem; align-items: center; flex-wrap: wrap;
           margin-bottom: .5rem; }}
  .head strong {{ font-family: "Open Sans Condensed", -apple-system, sans-serif;
                  font-size: 21px; font-weight: 700; }}
  .setname {{ color: var(--muted); font-size: 13px; }}
  .merged {{ font-weight: 600; font-size: 15px; }}
  .shape {{ color: var(--muted); font-size: 12px; font-variant-numeric: tabular-nums;
            border: 1px solid var(--line); border-radius: 999px; padding: .05rem .5rem; }}
  .dur {{ color: var(--muted); font-variant-numeric: tabular-nums; font-size: 13px;
          margin-left: auto; }}
  .pnet {{ text-decoration: none; font-size: 15px; line-height: 1; opacity: .75; }}
  .pnet:hover {{ opacity: 1; }}
  input[type="checkbox"] {{ width: 1.15rem; height: 1.15rem; cursor: pointer;
                            accent-color: var(--link); }}
  .skip {{ accent-color: var(--muted); }}
  img {{ max-width: 100%; }}
  .halves {{ display: flex; align-items: stretch; gap: 0; }}
  .half {{ flex: 1 1 0; min-width: 0; }}
  .hhead {{ display: flex; gap: .4rem; align-items: baseline; font-size: 13px;
            padding: 0 .2rem .2rem; }}
  .hhead .pos {{ color: var(--muted); font-variant-numeric: tabular-nums; }}
  .wave {{ position: relative; line-height: 0; background: var(--card);
           height: 84px; overflow: hidden; }}
  .half[data-side="first"] .wave {{ border-radius: 8px 0 0 8px; }}
  .half[data-side="second"] .wave {{ border-radius: 0 8px 8px 0; }}
  .wave img {{ width: 100%; height: 84px; display: block; object-fit: fill;
               filter: var(--wave-filter); }}
  .nowave {{ display: block; color: var(--muted); font-size: 12px;
             line-height: 84px; text-align: center; }}
  /* The seam is the split being removed: the one place a glitch could be. */
  .seam {{ flex: 0 0 2px; background: var(--accent); align-self: flex-end;
           height: 84px; }}
  .joint {{ display: flex; align-items: center; gap: .7rem; margin-top: .5rem; }}
  .jplay {{ font: inherit; font-size: 13px; padding: .22rem .7rem; cursor: pointer;
            background: var(--btn); color: var(--fg);
            border: 1px solid var(--btn-line); border-radius: 7px; }}
  .jplay:hover {{ background: var(--btn-hover); border-color: var(--muted); }}
  .jmeta {{ color: var(--muted); font-size: 12px; }}
  .joint .audio {{ flex: 1 1 auto; min-width: 0; }}
  .joint audio {{ width: 100%; height: 32px; }}
  @media (prefers-color-scheme: dark) {{ .joint audio {{ color-scheme: dark; }} }}
  .status {{ color: var(--muted); font-size: 13px; }}
  .status.err {{ color: var(--err); }}
  .status.busy {{ color: var(--accent); font-weight: 600; }}
  .meta {{ color: var(--muted); }}
  #tabs {{ display: flex; gap: .3rem; margin: 0 0 1rem; border-bottom: 1px solid var(--line); }}
  .tab {{ font: inherit; font-size: 14px; font-weight: 600; cursor: pointer;
          background: none; border: none; border-bottom: 2px solid transparent;
          color: var(--muted); padding: .5rem .9rem; margin-bottom: -1px; }}
  .tab:hover {{ color: var(--fg); }}
  .tab.active {{ color: var(--fg); border-bottom-color: var(--link); }}
  .tab span {{ font-variant-numeric: tabular-nums; font-weight: 400;
               font-size: 12px; color: var(--muted); margin-left: .35rem;
               background: var(--card); border: 1px solid var(--line);
               border-radius: 999px; padding: .05rem .4rem; }}
  .panel {{ display: none; }}
  .panel.active {{ display: block; }}
  .tally {{ border-collapse: collapse; margin: 0 0 1.4rem; min-width: 22rem; }}
  .tally th, .tally td {{ text-align: left; padding: .3rem .9rem .3rem 0;
                          border-bottom: 1px solid var(--line); }}
  .tally th {{ font-family: "Open Sans Condensed", -apple-system, sans-serif;
               font-size: 13px; color: var(--muted); text-transform: uppercase;
               letter-spacing: .04em; }}
  .tally td + td, .tally th + th {{ text-align: right;
                                    font-variant-numeric: tabular-nums; }}
  .tally tfoot td {{ font-weight: 700; border-bottom: none; }}
  .fndur {{ color: var(--muted); font-variant-numeric: tabular-nums;
            margin-left: auto; }}
  .fn {{ display: flex; gap: .6rem; align-items: baseline; padding: .16rem 0;
         border-bottom: 1px solid var(--line); font-size: 13px; }}
  .fndate {{ font-variant-numeric: tabular-nums; font-weight: 600; }}
  .fnset {{ color: var(--muted); font-variant-numeric: tabular-nums;
            flex: 0 0 7rem; }}
  #topbar {{ position: fixed; top: 0; left: 0; right: 0; z-index: 10;
             background: var(--header); border-bottom: 1px solid var(--line);
             padding: .55rem 1.5rem .35rem; }}
  #topbar .row1 {{ display: flex; align-items: center; gap: 1rem;
                   max-width: 1300px; margin: 0 auto; }}
  #topbar h1 {{ font-size: 21px; margin: 0; flex: 1 1 auto; }}
  #topbar h1 .count {{ color: var(--muted); font-weight: 400; font-size: 15px; }}
  #legend {{ display: flex; align-items: baseline; gap: .9rem;
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
  #export {{ padding: .4rem 1rem; font: inherit; font-weight: 600; cursor: pointer;
             background: var(--btn); color: var(--fg);
             border: 1px solid var(--btn-line); border-radius: 7px; }}
  #export:hover {{ background: var(--btn-hover); border-color: var(--muted); }}
  .offline {{ background: #fff4d6; border: 1px solid #d9ad4a; color: #6b4e00;
              padding: .6rem .8rem; margin-bottom: 1rem; border-radius: 4px; }}
</style>
<header id="topbar">
  <div class="row1">
    <h1>Sandwich merge review <span class="count">{len(rows)} candidates</span></h1>
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
<nav id="tabs">
  <button class="tab active" data-panel="pending">To merge <span>{len(rows)}</span></button>
  <button class="tab" data-panel="unpaired">Not paired <span>{len(footnotes)}</span></button>
  <button class="tab" data-panel="combined">Already combined <span>{len(combined)}</span></button>
</nav>
<section class="panel active" id="panel-pending">{"".join(rows)}</section>
<section class="panel" id="panel-unpaired">{foot_html}</section>
<section class="panel" id="panel-combined">{combined_html}</section>
<script>
const JOINT_S = {JOINT_S};

function payloadOf(row) {{ return JSON.parse(row.dataset.payload); }}

// The joint is one clip: the tail of the first track butted against the head of
// the second, rendered by the server the same way a merge would concatenate
// them. A glitch here is a glitch in the merge.
async function renderJoint(row, idx) {{
  const p = payloadOf(row);
  const status = row.querySelector(".status");
  const joint = row.querySelector('.joint[data-joint="' + (idx || 0) + '"]');
  if (!joint) return;
  const box = joint.querySelector(".audio");
  if (joint._loaded) return box.querySelector("audio");
  // Joint 0 is first|second; joint 1 (three-track shapes only) is second|third.
  const left = (idx === 1)
    ? {{url: p.second_mp3_url, dur: p.second_duration_s}}
    : {{url: p.first_mp3_url, dur: p.first_duration_s}};
  const rightUrl = (idx === 1) ? p.third_mp3_url : p.second_mp3_url;
  status.textContent = "rendering...";
  status.classList.add("busy");
  status.classList.remove("err");
  try {{
    const resp = await fetch("/joint", {{
      method: "POST",
      headers: {{"Content-Type": "application/json"}},
      body: JSON.stringify({{
        first_mp3_url: left.url,
        first_duration_s: left.dur,
        second_mp3_url: rightUrl,
        seconds: JOINT_S
      }})
    }});
    const data = await resp.json();
    if (!resp.ok) throw new Error(data.error || resp.statusText);
    let audio = box.querySelector("audio");
    if (!audio) {{
      audio = Object.assign(document.createElement("audio"),
        {{controls: true, preload: "none"}});
      box.append(audio);
    }}
    audio.src = data.url + "?t=" + Date.now();
    joint._loaded = true;
    status.textContent = "";
    status.classList.remove("busy");
    return audio;
  }} catch (e) {{
    status.textContent = (e instanceof TypeError || location.protocol === "file:")
      ? "no preview server \\u2014 run: rake sandwich_scan:serve"
      : "preview failed: " + e.message;
    status.classList.remove("busy");
    status.classList.add("err");
  }}
}}

async function playJoint(row, idx) {{
  idx = idx || 0;
  const joint = row.querySelector('.joint[data-joint="' + idx + '"]');
  const audio = (await renderJoint(row, idx))
    || (joint && joint.querySelector("audio"));
  if (!audio) return;
  document.querySelectorAll(".joint audio").forEach(a => {{
    if (a !== audio && !a.paused) a.pause();
  }});
  audio.currentTime = 0;
  audio.play().catch(() => {{}});
}}

function selectRow(row) {{
  if (window._sel === row) return;
  if (window._sel) window._sel.classList.remove("sel");
  window._sel = row;
  if (!row) return;
  row.classList.add("sel");
  if (!row.classList.contains("done")) renderJoint(row);
}}

function moveSelection(delta) {{
  const rows = [...document.querySelectorAll(".row")];
  if (!rows.length) return;
  const i = window._sel ? rows.indexOf(window._sel) : -1;
  const next = rows[Math.min(rows.length - 1, Math.max(0, i < 0 ? 0 : i + delta))];
  selectRow(next);
  if (next.scrollIntoView) next.scrollIntoView({{block: "nearest"}});
}}

function rowForShortcut(e) {{
  const focused = e.target && e.target.closest && e.target.closest(".row");
  if (focused) {{
    if (window._sel !== focused) selectRow(focused);
    return focused;
  }}
  return window._sel;
}}

function syncDone(row) {{
  const a = row.querySelector("input.approve");
  const s = row.querySelector("input.skip");
  row.classList.toggle("done", a.checked || s.checked);
  row.classList.toggle("skipped", s.checked);
  updateLegend();
}}

document.querySelectorAll(".row").forEach(row => {{
  const a = row.querySelector("input.approve");
  const s = row.querySelector("input.skip");
  const settle = (box, other) => box.addEventListener("change", () => {{
    if (box.checked && other) other.checked = false;
    syncDone(row);
    if (box.checked) return moveSelection(1);
    selectRow(row);
  }});
  settle(a, s);
  settle(s, a);
  row.addEventListener("mousedown", () => selectRow(row));
  row.querySelectorAll(".joint").forEach(j => {{
    const btn = j.querySelector(".jplay");
    if (btn) btn.addEventListener("click",
      () => playJoint(row, Number(j.dataset.joint)));
  }});
}});

document.addEventListener("keydown", e => {{
  if (e.metaKey || e.ctrlKey || e.altKey) return;
  const t = e.target && e.target.tagName;
  const typing = (t === "INPUT" && e.target.type === "text")
    || t === "TEXTAREA" || (e.target && e.target.isContentEditable);
  if (typing) return;
  if (e.key === "ArrowDown" || e.key === "ArrowUp") {{
    e.preventDefault();
    if (e.target && e.target.blur) e.target.blur();
    return moveSelection(e.key === "ArrowDown" ? 1 : -1);
  }}
  if (e.target && e.target.blur && (t === "AUDIO" || t === "INPUT" || t === "BUTTON")) {{
    e.target.blur();
  }}
  const RIGHT_HAND = {{";": "w", "'": "k"}};
  const key = (RIGHT_HAND[e.key] || e.key).toLowerCase();
  if (key === "e" || e.key === " " || e.key === "Spacebar") {{
    const row = rowForShortcut(e);
    if (!row) return;
    e.preventDefault();
    const playing = [...row.querySelectorAll(".joint audio")].find(x => !x.paused);
    if (playing) return playing.pause();
    // On a three-track row "e" walks the joints, so repeated presses audition
    // each splice in turn rather than replaying only the first.
    const joints = row.querySelectorAll(".joint");
    const idx = (row._nextJoint || 0) % joints.length;
    row._nextJoint = idx + 1;
    return playJoint(row, idx);
  }}
  const answerKeys = {{w: "approve", x: "skip", k: "skip"}};
  const answer = answerKeys[key];
  if (!answer) return;
  const row = rowForShortcut(e);
  if (!row) return;
  e.preventDefault();
  const box = row.querySelector("input." + answer);
  const other = row.querySelector(
    "input." + (answer === "approve" ? "skip" : "approve"));
  if (other) other.checked = false;
  box.checked = true;
  syncDone(row);
  moveSelection(1);
}});

const STORE_KEY = "sandwichscan:progress";
function rowKey(row) {{
  const p = payloadOf(row);
  return p.first_id + ":" + p.second_id;
}}
function saveProgress() {{
  const state = {{}};
  document.querySelectorAll(".row").forEach(row => {{
    const a = row.querySelector("input.approve");
    const s = row.querySelector("input.skip");
    if (a.checked) state[rowKey(row)] = "a";
    else if (s.checked) state[rowKey(row)] = "s";
  }});
  try {{ localStorage.setItem(STORE_KEY, JSON.stringify(state)); }}
  catch (e) {{ /* private mode: progress just stops persisting */ }}
}}
function restoreProgress() {{
  let state = null;
  try {{ state = JSON.parse(localStorage.getItem(STORE_KEY) || "null"); }}
  catch (e) {{ return; }}
  if (!state) return;
  document.querySelectorAll(".row").forEach(row => {{
    const mark = state[rowKey(row)];
    if (!mark) return;
    row.querySelector(mark === "a" ? "input.approve" : "input.skip").checked = true;
    syncDone(row);
  }});
}}

function updateLegend() {{
  const rows = [...document.querySelectorAll(".row")];
  const total = rows.length;
  const approved = rows.filter(r => r.querySelector("input.approve").checked).length;
  const skipped = rows.filter(r => r.querySelector("input.skip").checked).length;
  const set = (id, v) => {{
    const el = document.getElementById(id);
    if (el) el.textContent = v;
  }};
  set("n-approved", approved);
  set("n-skipped", skipped);
  set("n-total", total);
  const done = approved + skipped;
  document.querySelector("#legend .pct").textContent =
    (total ? Math.round((done / total) * 100) : 0) + "%";
  document.querySelector("#topbar .fill-ok").style.width =
    (total ? (approved / total) * 100 : 0) + "%";
  document.querySelector("#topbar .fill-skip").style.width =
    (total ? (skipped / total) * 100 : 0) + "%";
  saveProgress();
}}

if (location.protocol === "file:") {{
  const b = document.createElement("div");
  b.className = "offline";
  b.textContent = "Opened as a file \\u2014 joint previews need the server. "
    + "Run: rake sandwich_scan:serve and open the http:// URL.";
  document.body.prepend(b);
}}

document.querySelectorAll("#tabs .tab").forEach(tab => {{
  tab.addEventListener("click", () => {{
    document.querySelectorAll("#tabs .tab").forEach(t => t.classList.remove("active"));
    document.querySelectorAll(".panel").forEach(p => p.classList.remove("active"));
    tab.classList.add("active");
    const panel = document.getElementById("panel-" + tab.dataset.panel);
    if (panel) panel.classList.add("active");
  }});
}});

restoreProgress();
updateLegend();

document.getElementById("export").onclick = () => {{
  const approved = [...document.querySelectorAll(".row")]
    .filter(r => r.querySelector("input.approve").checked)
    .map(r => {{
      const p = payloadOf(r);
      const entry = {{
        label: p.label, date: p.date, merged_title: p.merged_title,
        first_id: p.first_id, first_title: p.first_title,
        first_share_url: p.first_share_url,
        second_id: p.second_id, second_title: p.second_title,
        second_share_url: p.second_share_url
      }};
      if (p.third_id) {{
        entry.third_id = p.third_id;
        entry.third_title = p.third_title;
        entry.third_share_url = p.third_share_url;
      }}
      return entry;
    }});
  const blob = new Blob([JSON.stringify(approved, null, 2)],
                        {{type: "application/json"}});
  const a = Object.assign(document.createElement("a"),
    {{href: URL.createObjectURL(blob), download: "approved.json"}});
  a.click();
}};
</script>
""")
    html_path.with_name("summary.json").write_text(json.dumps(
        {"candidates": len(candidates), "footnotes": len(footnotes)}))
    if not quiet:
        print(f"Review page written to {html_path}", file=sys.stderr)


def report_json(candidates, footnotes, combined=None):
    return json.dumps({"candidates": [asdict(c) for c in candidates],
                       "footnotes": footnotes,
                       "combined": combined or []}, indent=2)


def load_report(path):
    data = json.loads(Path(path).read_text())
    candidates = [SandwichCandidate(**c) for c in data.get("candidates", [])]
    return candidates, data.get("footnotes", []), data.get("combined", [])


def rebuild_dir(dir_path, ignore_urls):
    report_path = Path(dir_path) / "report.json"
    if not report_path.exists():
        print(f"  no report.json in {dir_path}", file=sys.stderr)
        return
    candidates, footnotes, combined = load_report(report_path)
    kept = [c for c in candidates
            if c.first_share_url.rstrip("/") not in ignore_urls]
    if len(kept) != len(candidates):
        print(f"  dropping {len(candidates) - len(kept)} ignore-listed pair(s)",
              file=sys.stderr)
    report_path.write_text(report_json(kept, footnotes, combined))
    write_review_html(Path(dir_path) / "review.html", kept, footnotes, combined)


def main():
    p = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--show", action="append", default=[], metavar="YYYY-MM-DD",
                   help="Scan specific shows instead of every candidate show")
    p.add_argument("--rebuild", metavar="DIR",
                   help="Regenerate review.html from DIR/report.json")
    p.add_argument("--ignore-file", type=Path)
    p.add_argument("--json", type=Path, help="Write report.json here")
    p.add_argument("--html", type=Path, help="Write review.html here")
    args = p.parse_args()

    ignore_urls = load_ignore_urls(args.ignore_file)
    if ignore_urls:
        print(f"ignore list: {len(ignore_urls)} url(s)", file=sys.stderr)

    if args.rebuild:
        rebuild_dir(args.rebuild, ignore_urls)
        return

    dates = args.show or fetch_dates_for_outer_songs()
    print(f"scanning {len(dates)} show(s)", file=sys.stderr)

    candidates, footnotes, combined = [], [], []
    with ThreadPoolExecutor(max_workers=FETCH_WORKERS) as pool:
        results = pool.map(lambda d: scan_show(d, ignore_urls), sorted(dates))
        for date, (found, notes, done) in zip(sorted(dates), results):
            combined.extend(done)
            for c in found:
                print(f"  {c.date} {c.set_name} -> {c.merged_title}",
                      file=sys.stderr)
            candidates.extend(found)
            footnotes.extend(notes)

    kept = [c for c in candidates
            if c.first_share_url.rstrip("/") not in ignore_urls]
    print(f"\n{len(kept)} sandwich candidate(s), {len(footnotes)} unpaired, "
          f"{len(combined)} already combined", file=sys.stderr)
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(report_json(kept, footnotes, combined))
        print(f"Report written to {args.json}", file=sys.stderr)
    if args.html:
        write_review_html(args.html, kept, footnotes, combined)


if __name__ == "__main__":
    main()
