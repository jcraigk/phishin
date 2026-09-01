import React, { useContext, useEffect, useState } from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faChevronDown, faChevronRight } from "@fortawesome/free-solid-svg-icons";
import { EditorContext } from "./AdminShowEditor";
import TagEditor from "./TagEditor";
import TaginPanel from "./TaginPanel";
import { adminDelete, adminGet, adminPatch, adminPost } from "./adminApi";

const ShowTagRow = ({ showTag, managed, onSaved, onError }) => {
  const [notes, setNotes] = useState(showTag.notes || "");
  const [busy, setBusy] = useState(false);

  useEffect(() => setNotes(showTag.notes || ""), [showTag.notes]);

  const saveNotes = async () => {
    if (notes === (showTag.notes || "")) return;
    setBusy(true);
    onError(null);
    try {
      onSaved(await adminPatch(`/show_tags/${showTag.id}`, { notes }));
    } catch (e) {
      onError(e.message);
    } finally {
      setBusy(false);
    }
  };

  const remove = async () => {
    if (!window.confirm(`Remove the ${showTag.tag_name} tag from this show?`)) return;
    setBusy(true);
    onError(null);
    try {
      onSaved(await adminDelete(`/show_tags/${showTag.id}`));
    } catch (e) {
      onError(e.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <li className="admin-tag-row">
      <div className="admin-tag-row-header">
        <span className="admin-tag-name">{showTag.tag_name}</span>
        {managed && <span className="admin-tag-managed">sheet-managed</span>}
        <input
          type="text"
          className="admin-tag-notes"
          placeholder="Notes"
          value={notes}
          disabled={busy}
          onChange={(e) => setNotes(e.target.value)}
          onBlur={saveNotes}
        />
        <button type="button" className="admin-danger" disabled={busy} onClick={remove}>
          Remove
        </button>
      </div>
    </li>
  );
};

const AddShowTag = ({ tags, onSaved, onError }) => {
  const { show } = useContext(EditorContext);
  const [tagId, setTagId] = useState("");
  const [notes, setNotes] = useState("");
  const [busy, setBusy] = useState(false);

  const add = async () => {
    if (tagId === "") return;
    setBusy(true);
    onError(null);
    try {
      onSaved(
        await adminPost(`/shows/${show.date}/show_tags`, {
          tag_id: Number(tagId),
          notes,
        })
      );
      setTagId("");
      setNotes("");
    } catch (e) {
      onError(e.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="admin-tag-add">
      <select
        aria-label="Tag"
        value={tagId}
        disabled={busy}
        onChange={(e) => setTagId(e.target.value)}
      >
        <option value="">Add a tag...</option>
        {tags.map((tag) => (
          <option key={tag.id} value={tag.id}>
            {tag.name}
          </option>
        ))}
      </select>
      <input
        type="text"
        className="admin-tag-notes"
        placeholder="Notes"
        value={notes}
        disabled={busy}
        onChange={(e) => setNotes(e.target.value)}
      />
      <button type="button" disabled={busy || tagId === ""} onClick={add}>
        Add
      </button>
    </div>
  );
};

const TrackTagBlock = ({ track, tags, taginTags }) => {
  const [open, setOpen] = useState(track.track_tags.length > 0);

  return (
    <li className="admin-tag-track">
      <button
        type="button"
        className="admin-tag-track-header"
        onClick={() => setOpen(!open)}
      >
        <span className="admin-tag-disclosure">
          <FontAwesomeIcon icon={open ? faChevronDown : faChevronRight} fixedWidth />
        </span>
        <span className="admin-audio-position">{track.position}</span>
        <span className="admin-audio-title">{track.title}</span>
        <span className="admin-audio-duration">
          {track.track_tags.length} tag{track.track_tags.length === 1 ? "" : "s"}
        </span>
      </button>
      {open && <TagEditor track={track} tags={tags} taginTags={taginTags} />}
    </li>
  );
};

const TagsTab = () => {
  const { show, setShow } = useContext(EditorContext);
  const [tags, setTags] = useState([]);
  const [taginTags, setTaginTags] = useState([]);
  const [error, setError] = useState(null);

  useEffect(() => {
    adminGet("/tags")
      .then((data) => {
        setTags(data.tags);
        setTaginTags(data.tagin_tags || []);
      })
      .catch((e) => setError(e.message));
  }, []);

  return (
    <div className="admin-tags-tab">
      {error && <p className="admin-error">{error}</p>}

      <h3>Show tags</h3>
      {show.show_tags.length === 0 ? (
        <p className="admin-audio-status">No tags on this show.</p>
      ) : (
        <ul className="admin-tag-rows">
          {show.show_tags.map((showTag) => (
            <ShowTagRow
              key={showTag.id}
              showTag={showTag}
              managed={taginTags.includes(showTag.tag_name)}
              onSaved={setShow}
              onError={setError}
            />
          ))}
        </ul>
      )}
      <AddShowTag tags={tags} onSaved={setShow} onError={setError} />

      <h3>Track tags</h3>
      <ul className="admin-tag-tracks">
        {show.tracks.map((track) => (
          <TrackTagBlock
            key={track.id}
            track={track}
            tags={tags}
            taginTags={taginTags}
          />
        ))}
      </ul>

      <h3>Spreadsheet sync</h3>
      <TaginPanel />
    </div>
  );
};

export default TagsTab;
