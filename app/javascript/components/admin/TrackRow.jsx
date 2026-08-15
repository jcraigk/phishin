import React, { useContext, useEffect, useState } from "react";
import { EditorContext } from "./AdminShowEditor";
import SongPicker from "./SongPicker";
import { adminPatch, adminDelete } from "./adminApi";

const SETS = ["S", "1", "2", "3", "4", "E", "E2", "E3"];

const formatDuration = (ms) => {
  if (!ms) return "";
  const total = Math.round(ms / 1000);
  const minutes = Math.floor(total / 60);
  return `${minutes}:${String(total % 60).padStart(2, "0")}`;
};

const problemsFor = (track) => {
  const problems = [];
  if (track.audio_status === "missing") problems.push("audio file");
  if (!track.title || track.title.trim() === "") problems.push("title");
  if (!track.position) problems.push("position");
  if (track.songs.length === 0) problems.push("songs");
  if (!track.set || track.set.trim() === "") problems.push("set");
  return problems;
};

const TrackRow = ({
  track,
  stagedOptions,
  dragging,
  onDragStart,
  onDragOver,
  onDrop,
  onDragEnd,
}) => {
  const { setShow, setTrack, setError } = useContext(EditorContext);
  const [title, setTitle] = useState(track.title || "");
  const [jamStart, setJamStart] = useState(
    track.jam_starts_at_second === null ? "" : String(track.jam_starts_at_second)
  );
  const [busy, setBusy] = useState(false);

  useEffect(() => setTitle(track.title || ""), [track.title]);
  useEffect(() => {
    setJamStart(
      track.jam_starts_at_second === null
        ? ""
        : String(track.jam_starts_at_second)
    );
  }, [track.jam_starts_at_second]);

  const patchTrack = async (body) => {
    setError(null);
    setBusy(true);
    try {
      setTrack(await adminPatch(`/tracks/${track.id}`, body));
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  };

  const replaceShow = async (action) => {
    setError(null);
    setBusy(true);
    try {
      setShow(await action());
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  };

  const saveTitle = () => {
    if (title === (track.title || "")) return;
    patchTrack({ title });
  };

  const saveJamStart = () => {
    const current =
      track.jam_starts_at_second === null
        ? ""
        : String(track.jam_starts_at_second);
    if (jamStart === current) return;
    patchTrack({ jam_starts_at_second: jamStart === "" ? null : Number(jamStart) });
  };

  const deleteTrack = () => {
    if (!window.confirm(`Delete track "${track.title}"?`)) return;
    replaceShow(() => adminDelete(`/tracks/${track.id}`));
  };

  const problems = problemsFor(track);

  return (
    <tr
      className={`admin-track-row${dragging ? " is-drag-over" : ""}`}
      draggable
      onDragStart={onDragStart}
      onDragOver={onDragOver}
      onDrop={onDrop}
      onDragEnd={onDragEnd}
    >
      <td className="admin-track-handle" aria-hidden="true">::</td>
      <td className="admin-track-position">{track.position}</td>
      <td className="admin-track-validity">
        {problems.length > 0 && (
          <span
            className="admin-invalid"
            title={`Missing: ${problems.join(", ")}`}
          >
            *
          </span>
        )}
      </td>
      <td>
        <select
          value={track.set || ""}
          aria-label="Set"
          disabled={busy}
          onChange={(e) => patchTrack({ set: e.target.value })}
        >
          {!track.set && <option value="">--</option>}
          {SETS.map((s) => (
            <option key={s} value={s}>{s}</option>
          ))}
        </select>
      </td>
      <td className="admin-track-title">
        <input
          type="text"
          aria-label="Title"
          value={title}
          disabled={busy}
          onChange={(e) => setTitle(e.target.value)}
          onBlur={saveTitle}
        />
      </td>
      <td className="admin-track-songs">
        <SongPicker
          value={track.songs}
          onChange={(songs) =>
            patchTrack({ song_ids: songs.map((s) => s.id) })
          }
        />
      </td>
      <td className="admin-track-audio">
        {track.audio_status === "missing" ? (
          <select
            value=""
            aria-label="Assign audio file"
            disabled={busy || stagedOptions.length === 0}
            onChange={(e) =>
              patchTrack({ staged_attachment_id: Number(e.target.value) })
            }
          >
            <option value="">
              {stagedOptions.length === 0 ? "No staged files" : "Assign file"}
            </option>
            {stagedOptions.map((file) => (
              <option key={file.attachment_id} value={file.attachment_id}>
                {file.filename}
              </option>
            ))}
          </select>
        ) : (
          formatDuration(track.duration)
        )}
      </td>
      <td>
        <input
          type="number"
          className="admin-track-jam"
          aria-label="Jam starts at second"
          min="0"
          value={jamStart}
          disabled={busy}
          onChange={(e) => setJamStart(e.target.value)}
          onBlur={saveJamStart}
        />
      </td>
      <td className="admin-track-actions">
        <button type="button" disabled={busy} onClick={deleteTrack}>
          Delete
        </button>
      </td>
    </tr>
  );
};

export default TrackRow;
