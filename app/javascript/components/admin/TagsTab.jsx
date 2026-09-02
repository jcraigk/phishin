import React, { useContext, useEffect, useState } from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import {
  faChevronDown,
  faChevronRight,
  faMagnifyingGlass,
  faTrashCan,
} from "@fortawesome/free-solid-svg-icons";
import MoonLoader from "react-spinners/MoonLoader";
import { EditorContext } from "./AdminShowEditor";
import TagEditor from "./TagEditor";
import useJobRunner from "./useJobRunner";
import { adminDelete, adminGet, adminPatch, adminPost } from "./adminApi";

const ShowTagRow = ({ showTag, onSaved, onError }) => {
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
        <input
          type="text"
          className="admin-tag-notes"
          placeholder="Notes"
          value={notes}
          disabled={busy}
          onChange={(e) => setNotes(e.target.value)}
          onBlur={saveNotes}
        />
        <button
          type="button"
          className="admin-trash-button"
          aria-label={`Remove ${showTag.tag_name} tag`}
          title="Remove tag"
          disabled={busy}
          onClick={remove}
        >
          <FontAwesomeIcon icon={faTrashCan} />
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

const PnetCheckPanel = () => {
  const { show } = useContext(EditorContext);
  const [report, setReport] = useState(null);
  const { run, busy, status, error } = useJobRunner();

  const check = () => {
    setReport(null);
    run(
      () => adminPost(`/shows/${show.date}/pnet_tag_check`),
      (job) => setReport(job?.payload?.report || "No report produced.")
    );
  };

  return (
    <section className="admin-pnet-check">
      <div className="admin-art-controls">
        <button type="button" disabled={busy} onClick={check}>
          <FontAwesomeIcon icon={faMagnifyingGlass} /> Check Phish.net
        </button>
        {busy && (
          <span className="admin-art-busy">
            <MoonLoader color="#c7c8ca" size={18} /> {status || "Checking..."}
          </span>
        )}
      </div>
      <p className="admin-audio-note">
        Compares this show's Tease tags against Phish.net setlist notes and the
        Tease Chart, then suggests additions and removals for manual review.
      </p>
      {error && <p className="admin-error">{error}</p>}
      {report && <pre className="admin-pnet-report">{report}</pre>}
    </section>
  );
};

const TrackTagBlock = ({ track, tags }) => {
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
      {open && <TagEditor track={track} tags={tags} />}
    </li>
  );
};

const TagsTab = () => {
  const { show, setShow } = useContext(EditorContext);
  const [tags, setTags] = useState([]);
  const [error, setError] = useState(null);

  useEffect(() => {
    adminGet("/tags")
      .then((data) => setTags(data.tags))
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
          <TrackTagBlock key={track.id} track={track} tags={tags} />
        ))}
      </ul>

      <h3>Phish.net check</h3>
      <PnetCheckPanel />
    </div>
  );
};

export default TagsTab;
