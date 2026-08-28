#!/usr/bin/env python3
"""Build a review site for the gapless scan: an index of affected shows and a
page per show that auditions every joint the fix would touch.

Each joint is rendered twice by the preview server, before and after the cut, so
the fix can be heard against the problem rather than inferred from a number.

    uv run scripts/gapless_review.py --json data/gapless_scan/report.json \
        --out data/gapless_review
"""
import argparse
import html
import json
from collections import defaultdict
from pathlib import Path

CSS = """
:root { --bg:#fff; --fg:#1c1c1e; --muted:#6b6b70; --line:#d8d8dd;
        --btn:#f2f2f4; --ok:#1a7f37; --warn:#a15c00; --link:#2f6fd0; }
@media (prefers-color-scheme: dark) {
  :root { --bg:#1b1f27; --fg:#e6e9ef; --muted:#8b95a7; --line:#3a4356;
          --btn:#2e3644; --ok:#4ac26b; --warn:#d29922; --link:#7fb3f0; } }
* { box-sizing: border-box; }
body { margin:0; padding:1.5rem; background:var(--bg); color:var(--fg);
       font:14px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
h1 { font-size:1.3rem; margin:0 0 .25rem; }
.meta { color:var(--muted); font-size:12px; margin-bottom:1.25rem; }
a { color:var(--link); }
table { border-collapse:collapse; width:100%; max-width:900px; }
th, td { text-align:left; padding:.4rem .6rem; border-bottom:1px solid var(--line); }
th { font-size:12px; text-transform:uppercase; letter-spacing:.04em;
     color:var(--muted); font-weight:600; }
tr:hover td { background:color-mix(in srgb, var(--fg) 4%, transparent); }
.joint { border:1px solid var(--line); border-radius:10px; padding:.85rem 1rem;
         margin-bottom:.85rem; max-width:900px; }
.joint h3 { margin:0 0 .15rem; font-size:14px; font-weight:600; }
.cuts { color:var(--muted); font-size:12px; margin-bottom:.6rem; }
.pair { display:flex; gap:1.25rem; flex-wrap:wrap; align-items:center; }
.side { display:flex; align-items:center; gap:.5rem; }
.tag { font-size:11px; text-transform:uppercase; letter-spacing:.04em;
       padding:.1rem .4rem; border-radius:4px; border:1px solid var(--line); }
.tag.before { color:var(--warn); }
.tag.after  { color:var(--ok); }
audio { height:32px; }
button { font:inherit; padding:.3rem .7rem; border-radius:7px;
         border:1px solid var(--line); background:var(--btn); color:var(--fg);
         cursor:pointer; }
.err { color:#c33; font-size:12px; }
"""

RENDER_JS = """
async function renderJoint(el) {
  const body = JSON.parse(el.dataset.req);
  const endpoint = el.dataset.endpoint || "/gapless_joint";
  const slot = el.querySelector(".pair");
  slot.innerHTML = '<span class="meta">rendering...</span>';
  try {
    const r = await fetch(endpoint, {
      method: "POST", headers: {"Content-Type": "application/json"},
      body: JSON.stringify(body)
    });
    const d = await r.json();
    if (!r.ok) throw new Error(d.error || r.statusText);
    slot.innerHTML =
      '<div class="side"><span class="tag before">before</span>' +
      '<audio controls preload="none" src="' + d.before + '"></audio></div>' +
      '<div class="side"><span class="tag after">after</span>' +
      '<audio controls preload="none" src="' + d.after + '"></audio></div>';
  } catch (e) {
    slot.innerHTML = '<span class="err">' + e.message + '</span>';
  }
}
// Render lazily: a show with 30 joints would otherwise start 60 ffmpeg jobs at
// once and the page would sit blank until they finished.
const io = new IntersectionObserver((entries) => {
  for (const e of entries) {
    if (!e.isIntersecting) continue;
    io.unobserve(e.target);
    renderJoint(e.target);
  }
}, {rootMargin: "300px"});
document.querySelectorAll(".joint").forEach(el => io.observe(el));
"""


def page(title, body, script=""):
    return (f"<!doctype html>\n<meta charset=utf-8>\n"
            f"<meta name=viewport content='width=device-width,initial-scale=1'>\n"
            f"<title>{html.escape(title)}</title>\n<style>{CSS}</style>\n"
            f"{body}\n" + (f"<script>{script}</script>\n" if script else ""))


def joints_for(tracks):
    """Adjacent pairs within a set where the fix would change the seam.

    A joint is worth auditioning when the tail of the earlier track or the head
    of the later one is going to be cut; where neither is, the seam is already
    whatever it is going to be.
    """
    by_pos = {(t["set"], t["position"]): t for t in tracks}
    out = []
    for t in tracks:
        nxt = by_pos.get((t["set"], t["position"] + 1))
        if not nxt:
            continue
        # The same cuts gapless_scan:apply makes, so what is auditioned here is
        # what the repair produces: trailing pure zeros, and a head only where
        # every threshold agreed where the padding ends.
        tail_cut = t.get("tail_zeros_s") or 0.0
        head_cut = (nxt.get("head_cut_s") or 0.0) if nxt.get("preceded_in_set") else 0.0
        if not tail_cut and not head_cut:
            continue
        out.append((t, nxt, tail_cut, head_cut))
    return out


def show_page(date, tracks, seconds):
    rows = []
    for first, second, tail_cut, head_cut in joints_for(tracks):
        req = json.dumps({
            "first_mp3_url": first["mp3_url"],
            "second_mp3_url": second["mp3_url"],
            "first_duration_s": first["duration_s"],
            "seconds": seconds,
            "tail_cut_s": round(tail_cut, 4),
            "head_cut_s": round(head_cut, 4),
        })
        cuts = []
        if tail_cut:
            cuts.append(f"tail &minus;{tail_cut * 1000:.1f}ms")
        if head_cut:
            cuts.append(f"head &minus;{head_cut * 1000:.1f}ms")
        rows.append(
            f'<div class="joint" data-req=\'{html.escape(req, quote=True)}\'>'
            f'<h3>Set {html.escape(str(first["set"]))} &middot; '
            f'{html.escape(first["title"])} &rarr; {html.escape(second["title"])}</h3>'
            f'<div class="cuts">t{first["position"]} &rarr; t{second["position"]} '
            f'&middot; {" &middot; ".join(cuts)}</div>'
            f'<div class="pair"><span class="meta">scroll to render</span></div>'
            f"</div>")
    # Only the tails that close a set. Those are the ones ending in a
    # deliberate fade, so the cut sits behind real audio and is worth hearing;
    # every other tail either runs into a joint above or into a track whose own
    # edges are already clean, where the trim changes nothing audible.
    #
    # A track can appear in both sections: one whose head is trimmed at a joint
    # and whose tail closes a set is heard as the second half of that joint and
    # again as an ending.
    tails = []
    for t in tracks:
        zeros = t.get("tail_zeros_s") or 0.0
        if not zeros or t.get("followed_in_set"):
            continue
        req = json.dumps({
            "mp3_url": t["mp3_url"], "seconds": 4.0,
            "tail_cut_s": round(zeros, 4),
        })
        tails.append(
            f'<div class="joint" data-endpoint="/gapless_tail" '
            f'data-req=\'{html.escape(req, quote=True)}\'>'
            f'<h3>t{t["position"]} &middot; {html.escape(t["title"])} '
            f'<span class="meta">(closes set {html.escape(str(t["set"]))})</span></h3>'
            f'<div class="cuts">'
            f'&minus;{zeros * 1000:.1f}ms of encoder padding after the fade</div>'
            f'<div class="pair"><span class="meta">scroll to render</span></div>'
            f"</div>")

    body = (f'<h1>{html.escape(date)}</h1>'
            f'<div class="meta"><a href="index.html">&larr; all shows</a> '
            f'&middot; {len(rows)} joint(s) &middot; {len(tails)} tail(s) '
            f'&middot; <a href="https://phish.in/{html.escape(date)}" target="_blank">'
            f"phish.in</a></div>"
            + (f"<h2>Joints</h2>{''.join(rows)}" if rows else "")
            + (f"<h2>Set-closing fades</h2>{''.join(tails)}" if tails else "")
            or "<p>Nothing to review.</p>")
    return page(f"{date} gapless review", body, RENDER_JS)


def build(report_path, out_dir, seconds):
    data = json.loads(Path(report_path).read_text())
    tracks = data["tracks"]
    if not any("head_cut_s" in t for t in tracks):
        raise SystemExit("report has no measurements - rerun the scan with DECODE=1")

    by_date = defaultdict(list)
    for t in tracks:
        by_date[t["date"]].append(t)

    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    rows, total, tail_total = [], 0, 0
    for date in sorted(by_date):
        items = sorted(by_date[date], key=lambda t: t["position"])
        n = len(joints_for(items))
        tails = sum(1 for t in items
                    if t.get("tail_zeros_s") and not t.get("followed_in_set"))
        if not n and not tails:
            continue
        total += n
        tail_total += tails
        (out / f"{date}.html").write_text(show_page(date, items, seconds))
        rows.append(f"<tr><td><a href='{date}.html'>{date}</a></td>"
                    f"<td>{n}</td><td>{tails}</td><td>{len(items)}</td></tr>")

    index = (f"<h1>Gapless review</h1>"
             f'<div class="meta">{len(rows)} show(s), {total} joint(s), '
             f"{tail_total} track ending(s). Everything plays before and after "
             f"the cut.</div>"
             f"<table><thead><tr><th>Date</th><th>Joints</th><th>Endings</th>"
             f"<th>Tracks in report</th></tr></thead><tbody>"
             f"{''.join(rows)}</tbody></table>")
    (out / "index.html").write_text(page("Gapless review", index))
    print(f"{len(rows)} show page(s), {total} joint(s), {tail_total} ending(s) "
          f"-> {out}/index.html")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", default="data/gapless_scan/report.json")
    ap.add_argument("--out", default="data/gapless_review")
    ap.add_argument("--seconds", type=float, default=1.5,
                    help="audio kept on each side of the seam")
    args = ap.parse_args()
    build(args.json, args.out, args.seconds)


if __name__ == "__main__":
    main()
