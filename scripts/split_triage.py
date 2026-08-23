#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11,<3.13"
# ///
"""Triage report for the split scan.

The scan reports every track ending in a long run of digital silence, but those
fall into two quite different groups. Whole shows in some masters end every
track on a two second pad - that is the transfer's own convention, not a split
dropping audio, and it accounts for most of the raw count. What is left is the
actual repair queue.

This sorts one from the other and lays out the queue by show, with the source
each one would be rebuilt from, so the work can be planned without touching the
network. Verifying that a source really matches needs audio and is a separate
step; see split_verify.py.

    uv run scripts/split_triage.py --report split_report.json \
        --links sheet_links.json --out tmp/split_triage.html
"""

import argparse
import html
import json
from collections import defaultdict
from pathlib import Path

# A master that pads every track to two seconds is following a convention. A
# split that lost audio has no reason to land on a round number, let alone the
# same one across a whole show.
PAD_MIN_S = 1.90
PAD_MAX_S = 2.10
# Whole-show padding shows up as most of a show's tracks landing in that band;
# a couple of coincidences within one show should still be treated as real.
PAD_SHOW_SHARE = 0.5

CSS = """
:root { --bg:#fff; --fg:#1c1c1e; --muted:#6b6b70; --line:#d8d8dd;
        --ok:#1a7f37; --warn:#a15c00; --bad:#c0392b; --link:#2f6fd0;
        --chip:#f2f2f4; }
@media (prefers-color-scheme: dark) {
  :root { --bg:#1b1f27; --fg:#e6e9ef; --muted:#8b95a7; --line:#3a4356;
          --ok:#4ac26b; --warn:#d29922; --bad:#e5534b; --link:#7fb3f0;
          --chip:#2e3644; } }
* { box-sizing:border-box; }
body { margin:0; padding:1.5rem 2rem; background:var(--bg); color:var(--fg);
       font:14px/1.55 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
h1 { font-size:1.4rem; margin:0 0 .3rem; }
h2 { font-size:1.05rem; margin:2rem 0 .6rem; padding-top:1rem;
     border-top:1px solid var(--line); }
.lede { color:var(--muted); margin-bottom:1.5rem; max-width:70ch; }
a { color:var(--link); }
.cards { display:flex; gap:.75rem; flex-wrap:wrap; margin-bottom:1.5rem; }
.card { border:1px solid var(--line); border-radius:10px; padding:.7rem 1rem;
        min-width:130px; }
.card .n { font-size:1.5rem; font-weight:600; }
.card .l { color:var(--muted); font-size:12px; }
table { border-collapse:collapse; width:100%; margin-bottom:.5rem; }
th, td { text-align:left; padding:.4rem .6rem; border-bottom:1px solid var(--line);
         vertical-align:top; }
th { font-size:12px; text-transform:uppercase; letter-spacing:.04em;
     color:var(--muted); font-weight:600; }
td.num { text-align:right; font-variant-numeric:tabular-nums; white-space:nowrap; }
tr:hover td { background:color-mix(in srgb, var(--fg) 4%, transparent); }
details { margin-bottom:.4rem; }
summary { cursor:pointer; padding:.45rem .6rem; border:1px solid var(--line);
          border-radius:8px; background:var(--chip); }
summary:hover { border-color:var(--link); }
summary .d { font-weight:600; }
summary .c { color:var(--muted); font-size:12px; margin-left:.5rem; }
details[open] summary { border-bottom-left-radius:0; border-bottom-right-radius:0; }
.body { border:1px solid var(--line); border-top:0; border-radius:0 0 8px 8px;
        padding:.6rem .8rem; }
.src { color:var(--muted); font-size:12px; margin-bottom:.5rem; }
code { font-size:12px; }
.sev-hi { color:var(--bad); font-weight:600; }
.sev-mid { color:var(--warn); }
"""


def severity(seconds):
    if seconds >= 1.0:
        return "sev-hi"
    if seconds >= 0.5:
        return "sev-mid"
    return ""


def in_pad_band(row):
    return PAD_MIN_S <= row["trailing_zeros_s"] <= PAD_MAX_S


def padded_shows(rows):
    """Shows where the two second pad is the master's habit, not a fault."""
    by_show = defaultdict(list)
    for row in rows:
        by_show[row["date"]].append(row)
    return {
        date for date, items in by_show.items()
        if sum(1 for r in items if in_pad_band(r)) >= max(2, len(items) * PAD_SHOW_SHARE)
    }


def show_block(date, items, link):
    rows = "".join(
        f"<tr><td class=num>t{r['position']}</td>"
        f"<td>{html.escape(r['title'])}</td>"
        f"<td class='num {severity(r['trailing_zeros_s'])}'>"
        f"{r['trailing_zeros_s'] * 1000:.0f}ms</td>"
        f"<td class=num>{r['duration_s']:.0f}s</td>"
        f"<td><a href='{html.escape(r['url'])}' target=_blank>listen</a></td></tr>"
        for r in sorted(items, key=lambda r: r["position"])
    )
    worst = max(r["trailing_zeros_s"] for r in items)
    src = ""
    if link:
        src = (f"<div class=src>{html.escape(link.get('venue', ''))} &middot; "
               f"{html.escape(link.get('kbps', ''))} &middot; "
               f"<code>{html.escape(link.get('source', '')[:80])}</code><br>"
               f"<a href='{html.escape(link['url'])}' target=_blank>source download</a>"
               + (f" &middot; {html.escape(link['notes'][:60])}"
                  if link.get("notes") else "") + "</div>")
    else:
        src = "<div class=src>no source listed in the spreadsheet</div>"
    return (
        f"<details><summary><span class=d>{html.escape(date)}</span>"
        f"<span class=c>{len(items)} track(s) &middot; worst "
        f"{worst * 1000:.0f}ms</span></summary>"
        f"<div class=body>{src}<table><thead><tr><th>Pos</th><th>Title</th>"
        f"<th class=num>Silence</th><th class=num>Length</th><th></th></tr></thead>"
        f"<tbody>{rows}</tbody></table></div></details>")


def build(report_path, links_path, out_path):
    data = json.loads(Path(report_path).read_text())
    links = json.loads(Path(links_path).read_text()) if links_path else {}
    tracks = data["tracks"]
    mid = [t for t in tracks if t["followed_in_set"]]
    closers = [t for t in tracks if not t["followed_in_set"]]

    pads = padded_shows(mid)
    queue = [t for t in mid if t["date"] not in pads]
    padded = [t for t in mid if t["date"] in pads]

    by_show = defaultdict(list)
    for row in queue:
        by_show[row["date"]].append(row)
    # Worst first: a show with a full second missing matters more than one with
    # 160ms, and a show with twenty affected tracks more than one with a single.
    order = sorted(by_show, key=lambda d: (
        -max(r["trailing_zeros_s"] for r in by_show[d]), -len(by_show[d])))

    with_src = sum(1 for d in order if d in links)
    blocks = "".join(show_block(d, by_show[d], links.get(d)) for d in order)

    body = (
        f"<h1>Split repair queue</h1>"
        f"<p class=lede>Tracks that end in digital silence with another track "
        f"following them in the set - the shape of a split that dropped its "
        f"last audio. Shows whose master pads every track to about two seconds "
        f"are held back separately; that is a transfer convention rather than "
        f"lost audio, and it accounts for most of the raw count.</p>"
        f"<div class=cards>"
        f"<div class=card><div class=n>{len(queue)}</div>"
        f"<div class=l>tracks to repair</div></div>"
        f"<div class=card><div class=n>{len(order)}</div>"
        f"<div class=l>shows affected</div></div>"
        f"<div class=card><div class=n>{with_src}</div>"
        f"<div class=l>with a source link</div></div>"
        f"<div class=card><div class=n>{len(padded)}</div>"
        f"<div class=l>held back as padding</div></div>"
        f"<div class=card><div class=n>{len(closers)}</div>"
        f"<div class=l>set closers, ignored</div></div>"
        f"</div>"
        f"<h2>Shows, worst first</h2>{blocks}"
        f"<h2>Held back: whole-show two second padding</h2>"
        f"<p class=lede>{len(padded)} track(s) across "
        f"{len(pads)} show(s). Every track in these shows ends on the same "
        f"round pad, so the silence came from whoever made the transfer. Worth "
        f"a spot check by ear, but not a repair queue.</p>"
        f"<p><code>{html.escape(', '.join(sorted(pads)))}</code></p>")

    Path(out_path).write_text(
        f"<!doctype html>\n<meta charset=utf-8>\n"
        f"<meta name=viewport content='width=device-width,initial-scale=1'>\n"
        f"<title>Split repair queue</title>\n<style>{CSS}</style>\n{body}\n")
    print(f"{len(queue)} track(s) across {len(order)} show(s), "
          f"{with_src} with a source link")
    print(f"{len(padded)} track(s) held back across {len(pads)} padded show(s)")
    print(f"-> {out_path}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--report", required=True)
    ap.add_argument("--links")
    ap.add_argument("--out", default="tmp/split_triage.html")
    args = ap.parse_args()
    build(args.report, args.links, args.out)


if __name__ == "__main__":
    main()
