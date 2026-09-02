import React, { useContext, useEffect, useRef, useState } from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import {
  faArrowsLeftRight,
  faArrowsUpDown,
  faCloudArrowUp,
  faEllipsis,
  faLink,
  faPause,
  faPlay,
  faScissors,
  faTags,
  faTrashCan,
} from "@fortawesome/free-solid-svg-icons";
import { EditorContext } from "./AdminShowEditor";
import SongPicker from "./SongPicker";
import TagEditor from "./TagEditor";
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
  tags,
  stagedOptions,
  onReposition,
  isActive,
  isPlaying,
  onPlay,
  audioTool,
  onAudioTool,
}) => {
  const { show, setShow, setTrack, setError } = useContext(EditorContext);
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

  const audioName = audioTool?.trackId === track.id ? audioTool.name : null;

  const pickAudioTool = (name) => {
    setMenuOpen(false);
    onAudioTool(track.id, name);
  };

  const toggleTags = () => setTool((prev) => (prev === "tags" ? null : "tags"));

  const copyUrl = async () => {
    const url = `${window.location.origin}/${show.date}/${track.slug}`;
    try {
      await navigator.clipboard.writeText(url);
    } catch (e) {
      setError(`Could not copy URL: ${e.message}`);
    }
  };

  const groupedTags = track.track_tags
    .slice()
    .sort(
      (a, b) =>
        a.tag_name.localeCompare(b.tag_name) ||
        (a.starts_at_second || 0) - (b.starts_at_second || 0)
    )
    .reduce((acc, tag) => {
      (acc[tag.tag_name] = acc[tag.tag_name] || []).push(tag);
      return acc;
    }, {});

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
      <td className="admin-track-play">
        {hasAudio && (
          <button
            type="button"
            className="admin-preview-toggle"
            aria-label={isPlaying ? "Pause" : "Play"}
            onClick={onPlay}
          >
            <FontAwesomeIcon icon={isPlaying ? faPause : faPlay} />
          </button>
        )}
      </td>
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
      <td className="admin-track-tag-badges">
        {track.track_tags.length > 0 ? (
          <div
            className="tag-badges-container"
            role="button"
            tabIndex={0}
            title="Edit tags"
            onClick={toggleTags}
            onKeyDown={(e) => {
              if (e.key === "Enter") toggleTags();
            }}
          >
            {Object.entries(groupedTags).map(([name, group]) => (
              <div key={name} className="tag-badge">
                {name}
                {group.length > 1 ? ` (${group.length})` : ""}
              </div>
            ))}
          </div>
        ) : (
          <button
            type="button"
            className="admin-tag-add-button"
            title="Add tags"
            aria-label={`Add tags to ${track.title}`}
            onClick={toggleTags}
          >
            <FontAwesomeIcon icon={faTags} />
          </button>
        )}
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
          <span className={`admin-track-duration${isActive ? " is-active" : ""}`}>
            {formatDuration(track.duration)}
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
              {menuItem("Copy URL", faLink, true, () => {
                setMenuOpen(false);
                copyUrl();
              })}
              {menuItem("Reposition", faArrowsUpDown, true, () => {
                setMenuOpen(false);
                onReposition();
              })}
              {menuItem("Trim", faScissors, hasAudio, () => pickAudioTool("trim"))}
              {menuItem("Move boundary", faArrowsLeftRight, shiftable, () => pickAudioTool("boundary"))}
              {menuItem("Replace audio", faCloudArrowUp, true, () => pickTool("replace"))}
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
    {(audioName || tool === "tags") && (
      <tr className="admin-track-tool-row">
        <td colSpan={8}>
          {audioName === "trim" && (
            <TrimPanel
              key={`trim-${track.id}`}
              track={track}
              onClose={() => onAudioTool(track.id, "trim")}
            />
          )}
          {audioName === "boundary" && shiftable && (
            <BoundaryPanel
              key={`boundary-${track.id}`}
              track={track}
              next={next}
              onClose={() => onAudioTool(track.id, "boundary")}
            />
          )}
          {tool === "tags" && <TagEditor track={track} tags={tags} />}
        </td>
      </tr>
    )}
    </>
  );
};

export default TrackRow;
