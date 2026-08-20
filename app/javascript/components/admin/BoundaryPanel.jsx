import React, { useContext, useState } from "react";
import { EditorContext } from "./AdminShowEditor";
import PreviewPlayer from "./PreviewPlayer";
import useJobRunner from "./useJobRunner";
import { adminPost, fetchJobAudio } from "./adminApi";

// Mirrors Admin::ShiftBoundaryJob::MIN_PART_S: both sides must keep real audio,
// so the allowed range shown here is the same one the API enforces.
const MIN_PART_S = 1.0;

// Mirrors TrackSlugGenerator#abbreviate_long_slug. Five fixed substitutions, so
// mirroring them costs less than showing a slug preview that quietly disagrees
// with the one the server writes for a Hold Your Head Up.
const SLUG_ABBREVIATIONS = [
  ["hold-your-head-up", "hyhu"],
  ["the-man-who-stepped-into-yesterday", "tmwsiy"],
  ["she-caught-the-katy-and-left-me-a-mule-to-ride", "she-caught-the-katy"],
  ["mcgrupp-and-the-watchful-hosemasters", "mcgrupp"],
  ["big-black-furry-creature-from-mars", "bbfcfm"],
];

// Mirrors TrackSlugGenerator#slugged_title and its abbreviation pass. The
// duplicate suffix is not applied here; it depends on the other tracks, so
// slugFor adds it.
const baseSlug = (title) => {
  const slug = (title || "")
    .toLowerCase()
    .replace(/'/g, "")
    .replace(/[^a-z0-9]/g, " ")
    .trim()
    .replace(/\s+/g, "-");
  return SLUG_ABBREVIATIONS.reduce(
    (result, [long, short]) => result.split(long).join(short),
    slug
  );
};

// TrackSlugGenerator numbers duplicate titles by POSITION order, counting only
// the tracks ahead of this one, so the preview has to count the same way over
// the titles this edit would leave behind rather than the ones stored now.
const slugFor = (trackId, titlesByPosition) => {
  const mine = titlesByPosition.find((t) => t.id === trackId);
  if (!mine) return "";
  let before = 0;
  for (const other of titlesByPosition) {
    if (other.id === trackId) break;
    if (other.title === mine.title) before += 1;
  }
  return `${baseSlug(mine.title)}${before === 0 ? "" : `-${before + 1}`}`;
};

const round = (value) => Math.round(value * 10) / 10;

const seconds = (ms) => round((ms || 0) / 1000);

const BoundaryPanel = ({ track, next }) => {
  const { show, reload, setGapsStale } = useContext(EditorContext);
  const [deltaS, setDeltaS] = useState(0);
  // null means "no edit yet, follow the stored title". The panel stays mounted
  // across a reload, so an apply resets to null and the inputs pick up whatever
  // the server actually saved rather than replaying the text that was typed.
  const [edits, setEdits] = useState({ first: null, second: null });
  const [previewUrls, setPreviewUrls] = useState([null, null]);
  const [previewedAt, setPreviewedAt] = useState(null);
  const { run, busy, status, error } = useJobRunner();

  const firstSeconds = seconds(track.duration);
  const secondSeconds = seconds(next.duration);
  const low = round(MIN_PART_S - firstSeconds);
  const high = round(secondSeconds - MIN_PART_S);
  const delta = Number.isFinite(deltaS) ? deltaS : 0;
  const inRange = delta >= low && delta <= high;
  // Titles are deliberately not part of this comparison. The preview is audio,
  // and a rename does not change a single sample of it, so editing a title
  // leaves a rendered preview valid. Changing the delta still invalidates it.
  const previewCurrent = previewedAt === delta;

  const setTitle = (key, value) =>
    setEdits((prev) => ({ ...prev, [key]: value }));

  const sides = [
    { key: "first", track },
    { key: "second", track: next },
  ].map((side) => ({
    ...side,
    title: edits[side.key] === null ? side.track.title : edits[side.key],
  }));
  const renamed = sides.filter((side) => side.title.trim() !== side.track.title);
  const anyBlank = sides.some((side) => side.title.trim() === "");

  // The show's titles as this edit would leave them, in position order, so a
  // slug preview accounts for a rename that collides with an untouched sibling.
  const titlesByPosition = show.tracks.map((t) => {
    const side = sides.find((s) => s.track.id === t.id);
    return { id: t.id, title: side ? side.title.trim() : t.title };
  });

  const clearPreview = () => {
    setPreviewUrls([null, null]);
    setPreviewedAt(null);
  };

  const changeDelta = (value) => {
    setDeltaS(round(value));
    clearPreview();
  };

  // Only the sides actually renamed are sent: an untouched side omits its key
  // so the job leaves that title, and its slug, alone.
  const titlesParam = () => {
    if (renamed.length === 0) return undefined;
    return renamed.reduce(
      (params, side) => ({ ...params, [side.key]: side.title.trim() }),
      {}
    );
  };

  const renderPreview = () =>
    run(
      () => adminPost(`/tracks/${track.id}/shift_boundary_preview`, { delta_s: delta }),
      async (job) => {
        const [first, second] = await Promise.all([
          fetchJobAudio(job.id, 0),
          fetchJobAudio(job.id, 1),
        ]);
        setPreviewUrls([first, second]);
        setPreviewedAt(delta);
      }
    );

  const applyShift = () => {
    const renameLines = renamed.map(
      (side) => ` Rename "${side.track.title}" to "${side.title.trim()}".`
    );
    const message =
      `Move the boundary between "${track.title}" and "${next.title}" by ` +
      `${delta.toFixed(1)}s?${renameLines.join("")}` +
      (renamed.length === 0 ? " Titles are unchanged." : "") +
      ` Both original audio files are backed up.`;
    if (!window.confirm(message)) return;
    run(
      () =>
        adminPost(`/tracks/${track.id}/shift_boundary_apply`, {
          delta_s: delta,
          titles: titlesParam(),
        }),
      async () => {
        clearPreview();
        setEdits({ first: null, second: null });
        await reload();
        if (show.published) setGapsStale(true);
      }
    );
  };

  return (
    <div className="admin-audio-panel">
      <h4>Boundary</h4>

      <p className="admin-audio-note">
        Between position {track.position} "{track.title}" and position{" "}
        {next.position} "{next.title}". A positive shift grows the first track
        and shrinks the second; a negative shift does the reverse. Allowed range
        is {low.toFixed(1)}s to {high.toFixed(1)}s.
      </p>

      <div className="admin-audio-fields">
        <label className="admin-audio-field">
          <span>Shift seconds</span>
          <input
            type="number"
            step="0.1"
            min={low}
            max={high}
            value={deltaS}
            disabled={busy}
            onChange={(e) => changeDelta(Number(e.target.value))}
          />
        </label>
      </div>

      <p className="admin-audio-note">
        Now {firstSeconds.toFixed(1)}s and {secondSeconds.toFixed(1)}s. After the
        shift: {round(firstSeconds + delta).toFixed(1)}s and{" "}
        {round(secondSeconds - delta).toFixed(1)}s. The combined length does not
        change.
      </p>

      <div className="admin-boundary-titles">
        {sides.map((side) => {
          const trimmed = side.title.trim();
          const drifted =
            trimmed !== "" &&
            !side.track.songs.some(
              (song) => song.title.toLowerCase() === trimmed.toLowerCase()
            );
          return (
            <label className="admin-boundary-title" key={side.key}>
              <span>Position {side.track.position} title</span>
              <input
                type="text"
                value={side.title}
                disabled={busy}
                onChange={(e) => setTitle(side.key, e.target.value)}
              />
              {show.published ? (
                <span className="admin-audio-status">
                  Slug stays "{side.track.slug}" because the show is published,
                  so existing links keep working.
                </span>
              ) : (
                <span className="admin-audio-status">
                  Slug: {trimmed === "" ? "needs a title" : slugFor(side.track.id, titlesByPosition)}
                </span>
              )}
              {drifted && (
                <span className="admin-audio-warning">
                  No song on this track is titled "{trimmed}". Renaming does not
                  change the song association; update it in the Songs control if
                  it is wrong. A segue title matching neither song is expected.
                </span>
              )}
            </label>
          );
        })}
      </div>

      <PreviewPlayer label={`New "${track.title}"`} url={previewUrls[0]} />
      <PreviewPlayer label={`New "${next.title}"`} url={previewUrls[1]} />

      <div className="admin-audio-actions">
        <button
          type="button"
          onClick={renderPreview}
          disabled={busy || !inRange || delta === 0}
        >
          Render Preview
        </button>
        <button
          type="button"
          onClick={applyShift}
          disabled={busy || !inRange || delta === 0 || !previewCurrent || anyBlank}
        >
          Apply Shift
        </button>
        {!inRange && (
          <span className="admin-audio-status">
            Shift must be between {low.toFixed(1)}s and {high.toFixed(1)}s.
          </span>
        )}
        {anyBlank && (
          <span className="admin-audio-status">
            A title cannot be blank. Restore it to leave that side unchanged.
          </span>
        )}
        {previewUrls[0] && !previewCurrent && (
          <span className="admin-audio-status">
            Shift changed. Render a new preview before applying.
          </span>
        )}
        {status && <span className="admin-audio-status">{status}</span>}
      </div>

      {error && <p className="admin-error">{error}</p>}
    </div>
  );
};

export default BoundaryPanel;
