import React, { useContext, useState } from "react";
import { EditorContext } from "./AdminShowEditor";
import TrackRow from "./TrackRow";
import { adminPost, adminPut } from "./adminApi";

const SETS = ["S", "1", "2", "3", "4", "E", "E2", "E3"];

const TracksTab = () => {
  const { show, setShow, setError } = useContext(EditorContext);
  const [dragIndex, setDragIndex] = useState(null);
  const [overIndex, setOverIndex] = useState(null);
  const [busy, setBusy] = useState(false);

  const tracks = show.tracks;

  // The payload does not say which staged file backs an attached track, so the
  // summary reports tracks still awaiting audio rather than claiming which files
  // are unused.
  const missingAudioCount = tracks.filter(
    (t) => t.audio_status === "missing"
  ).length;

  const commitOrder = async (ordered) => {
    setError(null);
    setBusy(true);
    try {
      setShow(
        await adminPut(`/shows/${show.date}/track_order`, {
          track_ids: ordered.map((t) => t.id),
        })
      );
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  };

  const handleDrop = (targetIndex) => {
    setOverIndex(null);
    if (dragIndex === null || dragIndex === targetIndex) {
      setDragIndex(null);
      return;
    }
    const ordered = [...tracks];
    const [moved] = ordered.splice(dragIndex, 1);
    ordered.splice(targetIndex, 0, moved);
    setDragIndex(null);
    commitOrder(ordered);
  };

  const insertTrack = async () => {
    const position = window.prompt(
      "Insert at position",
      String(tracks.length + 1)
    );
    if (position === null) return;
    const title = window.prompt("Track title", "");
    if (title === null) return;
    const set = window.prompt(`Set (${SETS.join(" ")})`, "1");
    if (set === null) return;

    setError(null);
    setBusy(true);
    try {
      setShow(
        await adminPost(`/shows/${show.date}/tracks`, {
          position: Number(position),
          title,
          set,
        })
      );
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="admin-tracks-tab">
      <div className="admin-tracks-toolbar">
        <button type="button" onClick={insertTrack} disabled={busy}>
          Insert track
        </button>
        <span className="admin-staged-summary">
          {show.staged_audio.length} staged file
          {show.staged_audio.length === 1 ? "" : "s"}
          {missingAudioCount > 0 &&
            `, ${missingAudioCount} track${
              missingAudioCount === 1 ? "" : "s"
            } awaiting audio`}
        </span>
      </div>

      {tracks.length === 0 ? (
        <p>This show has no tracks yet.</p>
      ) : (
        <table className="admin-tracks-table">
          <thead>
            <tr>
              <th aria-label="Drag handle" />
              <th>#</th>
              <th aria-label="Validity" />
              <th>Set</th>
              <th>Title</th>
              <th>Songs</th>
              <th>Audio</th>
              <th>Jam</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {tracks.map((track, index) => (
              <TrackRow
                key={track.id}
                track={track}
                stagedOptions={show.staged_audio}
                dragging={overIndex === index}
                onDragStart={(e) => {
                  setDragIndex(index);
                  e.dataTransfer.effectAllowed = "move";
                  e.dataTransfer.setData("text/plain", String(index));
                }}
                onDragOver={(e) => {
                  e.preventDefault();
                  e.dataTransfer.dropEffect = "move";
                  setOverIndex(index);
                }}
                onDrop={(e) => {
                  e.preventDefault();
                  handleDrop(index);
                }}
                onDragEnd={() => {
                  setDragIndex(null);
                  setOverIndex(null);
                }}
              />
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
};

export default TracksTab;
