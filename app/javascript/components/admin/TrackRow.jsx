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
import { formatDurationTrack } from "../helpers/utils";
import useClickOutside from "./useClickOutside";

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

  useClickOutside(menuRef, menuOpen, () => setMenuOpen(false));

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

  const toggleTags = () => onAudioTool(track.id, "tags");

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
    <tr
      className={`admin-track-row${problems.length > 0 ? " has-problems" : ""}`}
      title={problems.length > 0 ? `Missing: ${problems.join(", ")}` : undefined}
    >
      <td className="admin-track-position">{track.position}</td>
      <td className="admin-track-play">
        {hasAudio && (
          <button
            type="button"
            className="admin-preview-toggle"
            aria-label={isPlaying ? "Pause" : "Play"}
            title={isPlaying ? "Pause" : "Play this track"}
            onClick={onPlay}
          >
            <FontAwesomeIcon icon={isPlaying ? faPause : faPlay} />
          </button>
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
            onClick={toggleTags}
            onKeyDown={(e) => {
              if (e.key === "Enter") toggleTags();
            }}
          >
            {Object.entries(groupedTags).map(([name, group]) => {
              const notes = group.map((t) => t.notes).filter((n) => n && n.trim());
              return (
                <div
                  key={name}
                  className={`tag-badge${notes.length ? " has-tip" : ""}`}
                  data-tip={notes.length ? notes.join("\n") : undefined}
                >
                  {name}
                  {group.length > 1 ? ` (${group.length})` : ""}
                </div>
              );
            })}
          </div>
        ) : (
          <button
            type="button"
            className="admin-tag-add-button"
            title="Add tags to this track"
            aria-label={`Add tags to ${track.title}`}
            onClick={toggleTags}
          >
            <FontAwesomeIcon icon={faTags} />
          </button>
        )}
      </td>
      <td className="admin-track-audio">
        {track.audio_status === "missing" ? (
          <span className="admin-track-duration is-missing">No audio</span>
        ) : (
          <span className={`admin-track-duration${isActive ? " is-active" : ""}`}>
            {track.duration ? formatDurationTrack(track.duration) : ""}
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
    {audioName && (
      <tr className="admin-track-tool-row">
        <td colSpan={7}>
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
          {audioName === "tags" && <TagEditor track={track} tags={tags} />}
        </td>
      </tr>
    )}
    </>
  );
};

export default TrackRow;
