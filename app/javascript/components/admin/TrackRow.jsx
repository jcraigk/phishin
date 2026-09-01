import React, { useContext, useEffect, useRef, useState } from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import {
  faArrowsLeftRight,
  faArrowsUpDown,
  faCloudArrowUp,
  faEllipsis,
  faPause,
  faPlay,
  faScissors,
  faTrashCan,
} from "@fortawesome/free-solid-svg-icons";
import { EditorContext } from "./AdminShowEditor";
import SongPicker from "./SongPicker";
import TrimPanel from "./TrimPanel";
import ReplacePanel from "./ReplacePanel";
import BoundaryPanel from "./BoundaryPanel";
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
  next,
  stagedOptions,
  onReposition,
  previewActive,
  previewPlaying,
  previewTime,
  onTogglePreview,
  onSeekPreview,
}) => {
  const { setShow, setTrack, setError } = useContext(EditorContext);
  const [title, setTitle] = useState(track.title || "");
  const [busy, setBusy] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [tool, setTool] = useState(null);
  const menuRef = useRef(null);

  useEffect(() => {
    if (!menuOpen) return undefined;
    const onDocumentClick = (e) => {
      if (menuRef.current && !menuRef.current.contains(e.target)) {
        setMenuOpen(false);
      }
    };
    document.addEventListener("mousedown", onDocumentClick);
    return () => document.removeEventListener("mousedown", onDocumentClick);
  }, [menuOpen]);

  useEffect(() => setTitle(track.title || ""), [track.title]);

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

  const deleteTrack = () => {
    if (!window.confirm(`Delete track "${track.title}"?`)) return;
    replaceShow(() => adminDelete(`/tracks/${track.id}`));
  };

  const problems = problemsFor(track);
  const hasAudio = track.audio_status !== "missing";
  const shiftable = Boolean(next) && hasAudio && next.audio_status !== "missing";

  const pickTool = (name) => {
    setMenuOpen(false);
    setTool((prev) => (prev === name ? null : name));
  };

  const menuItem = (label, icon, enabled, onClick) => (
    <li>
      <button type="button" disabled={!enabled} onClick={onClick}>
        <FontAwesomeIcon icon={icon} fixedWidth /> {label}
      </button>
    </li>
  );

  return (
    <>
    <tr className="admin-track-row">
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
          <span className="admin-audio-cell">
            <button
              type="button"
              className="admin-preview-toggle"
              aria-label={previewPlaying ? "Pause" : "Play"}
              onClick={onTogglePreview}
            >
              <FontAwesomeIcon icon={previewPlaying ? faPause : faPlay} />
            </button>
            <span
              className="admin-row-waveform"
              style={
                track.waveform_url
                  ? { backgroundImage: `url(${track.waveform_url})` }
                  : undefined
              }
              onClick={(e) => {
                const rect = e.currentTarget.getBoundingClientRect();
                const frac = (e.clientX - rect.left) / rect.width;
                onSeekPreview(frac * ((track.duration || 0) / 1000));
              }}
            >
              <span
                className="admin-row-waveform-progress"
                style={{
                  maskImage: track.waveform_url
                    ? `url(${track.waveform_url})`
                    : undefined,
                  WebkitMaskImage: track.waveform_url
                    ? `url(${track.waveform_url})`
                    : undefined,
                  background: `linear-gradient(to right, var(--blue) ${
                    previewActive && track.duration
                      ? (previewTime / (track.duration / 1000)) * 100
                      : 0
                  }%, transparent 0)`,
                }}
              />
            </span>
            <span className="admin-track-duration">
              {previewActive
                ? formatDuration(previewTime * 1000)
                : formatDuration(track.duration)}
            </span>
          </span>
        )}
      </td>
      <td className="admin-track-actions">
        <div className="admin-row-menu" ref={menuRef}>
          <button
            type="button"
            className="admin-trash-button"
            aria-label="Track actions"
            title="Track actions"
            disabled={busy}
            onClick={() => setMenuOpen(!menuOpen)}
          >
            <FontAwesomeIcon icon={faEllipsis} />
          </button>
          {menuOpen && (
            <ul className="admin-row-menu-list">
              {menuItem("Reposition", faArrowsUpDown, true, () => {
                setMenuOpen(false);
                onReposition();
              })}
              {menuItem("Trim", faScissors, hasAudio, () => pickTool("trim"))}
              {menuItem("Replace audio", faCloudArrowUp, true, () => pickTool("replace"))}
              {menuItem("Boundary with next", faArrowsLeftRight, shiftable, () => pickTool("boundary"))}
              {menuItem("Delete track", faTrashCan, true, () => {
                setMenuOpen(false);
                deleteTrack();
              })}
            </ul>
          )}
        </div>
      </td>
    </tr>
    {tool === "replace" && (
      <ReplacePanel
        key={`replace-${track.id}`}
        track={track}
        onClose={() => setTool(null)}
      />
    )}
    {(tool === "trim" || tool === "boundary") && (
      <tr className="admin-track-tool-row">
        <td colSpan={6}>
          {tool === "trim" && <TrimPanel key={`trim-${track.id}`} track={track} />}
          {tool === "boundary" && shiftable && (
            <BoundaryPanel key={`boundary-${track.id}`} track={track} next={next} />
          )}
        </td>
      </tr>
    )}
    </>
  );
};

export default TrackRow;
