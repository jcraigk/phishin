import React, { useContext, useEffect, useState } from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faGripVertical, faTrashCan } from "@fortawesome/free-solid-svg-icons";
import { EditorContext } from "./AdminShowEditor";
import SongPicker from "./SongPicker";
import { adminPatch, adminDelete } from "./adminApi";

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
  dropHint,
  lifted,
  onDragStart,
  onDragOver,
  onDrop,
  onDragEnd,
}) => {
  const { setShow, setTrack, setError } = useContext(EditorContext);
  const [title, setTitle] = useState(track.title || "");
  const [slug, setSlug] = useState(track.slug || "");
  const [busy, setBusy] = useState(false);

  useEffect(() => setTitle(track.title || ""), [track.title]);
  useEffect(() => setSlug(track.slug || ""), [track.slug]);

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

  const saveSlug = () => {
    if (slug === (track.slug || "") || slug.trim() === "") return;
    patchTrack({ slug: slug.trim() });
  };

  const deleteTrack = () => {
    if (!window.confirm(`Delete track "${track.title}"?`)) return;
    replaceShow(() => adminDelete(`/tracks/${track.id}`));
  };

  const problems = problemsFor(track);

  return (
    <tr
      className={`admin-track-row${dropHint ? ` is-drop-${dropHint}` : ""}${lifted ? " is-lifted" : ""}`}
      draggable
      onDragStart={onDragStart}
      onDragOver={onDragOver}
      onDrop={onDrop}
      onDragEnd={onDragEnd}
    >
      <td className="admin-track-handle" aria-hidden="true">
        <FontAwesomeIcon icon={faGripVertical} />
      </td>
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
      <td className="admin-track-slug">
        <input
          type="text"
          aria-label="Slug"
          value={slug}
          disabled={busy}
          onChange={(e) => setSlug(e.target.value)}
          onBlur={saveSlug}
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
      <td className="admin-track-actions">
        <button
          type="button"
          className="admin-icon-button"
          aria-label="Delete track"
          title="Delete track"
          disabled={busy}
          onClick={deleteTrack}
        >
          <FontAwesomeIcon icon={faTrashCan} />
        </button>
      </td>
    </tr>
  );
};

export default TrackRow;
