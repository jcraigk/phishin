import React, { useContext, useEffect, useState } from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faCheck, faTrashCan, faXmark } from "@fortawesome/free-solid-svg-icons";
import { EditorContext } from "./AdminShowEditor";
import { adminDelete, adminGet, adminPatch, adminPost } from "./adminApi";
import diffLines, { normalizeText } from "./diffLines";

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

const ShowTagsSection = () => {
  const { show, setShow, setError } = useContext(EditorContext);
  const [tags, setTags] = useState([]);

  useEffect(() => {
    adminGet("/tags")
      .then((data) => setTags(data.tags))
      .catch((e) => setError(e.message));
  }, [setError]);

  return (
    <section className="admin-tags-tab">
      <h3>
        Show tags
        <span className="admin-count">{show.show_tags.length}</span>
      </h3>
      {show.show_tags.length > 0 && (
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
    </section>
  );
};

const NotesTab = () => {
  const { show, setShow, setError } = useContext(EditorContext);
  const [taperNotes, setTaperNotes] = useState(show.taper_notes || "");
  const [adminNotes, setAdminNotes] = useState(show.admin_notes || "");
  const [busy, setBusy] = useState(false);
  const [pending, setPending] = useState(null);

  useEffect(() => setTaperNotes(show.taper_notes || ""), [show.taper_notes]);
  useEffect(() => setAdminNotes(show.admin_notes || ""), [show.admin_notes]);

  const patchShow = async (body) => {
    setError(null);
    setBusy(true);
    try {
      setShow(await adminPatch(`/shows/${show.date}`, body));
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  };

  const requestSave = (field, label, current, stored, revert) => {
    if (normalizeText(current) === normalizeText(stored)) return;
    setPending({
      field,
      label,
      current: normalizeText(current),
      stored: stored || "",
      revert,
    });
  };

  const confirmPending = () => {
    patchShow({ [pending.field]: pending.current });
    setPending(null);
  };

  const cancelPending = () => {
    pending.revert(pending.stored);
    setPending(null);
  };

  return (
    <div className="admin-notes-tab">
      <ShowTagsSection />

      <div className="admin-field">
        <label htmlFor="admin-taper-notes">Taper notes</label>
        <textarea
          id="admin-taper-notes"
          rows={28}
          value={taperNotes}
          disabled={busy}
          onChange={(e) => setTaperNotes(e.target.value)}
          onBlur={() =>
            requestSave(
              "taper_notes",
              "Taper Notes",
              taperNotes,
              show.taper_notes,
              setTaperNotes
            )
          }
        />
      </div>

      <div className="admin-field">
        <label htmlFor="admin-admin-notes">Admin notes</label>
        <textarea
          id="admin-admin-notes"
          rows={3}
          value={adminNotes}
          disabled={busy}
          onChange={(e) => setAdminNotes(e.target.value)}
          onBlur={() =>
            requestSave(
              "admin_notes",
              "Admin Notes",
              adminNotes,
              show.admin_notes,
              setAdminNotes
            )
          }
        />
      </div>

      {pending && (
        <div className="admin-modal-overlay">
          <div
            className="admin-modal admin-modal-wide"
            onClick={(e) => e.stopPropagation()}
          >
            <h3>Save {pending.label}?</h3>
            <div className="admin-diff">
              {diffLines(pending.stored, pending.current).map((line, i) =>
                line.type === "skip" ? (
                  <div key={i} className="admin-diff-skip">
                    {line.count} unchanged {line.count === 1 ? "line" : "lines"}
                  </div>
                ) : (
                  <div key={i} className={`admin-diff-line is-${line.type}`}>
                    <span className="admin-diff-sign">
                      {line.type === "add" ? "+" : line.type === "del" ? "-" : " "}
                    </span>
                    {line.text === "" ? " " : line.text}
                  </div>
                )
              )}
            </div>
            <div className="admin-modal-actions">
              <button type="button" disabled={busy} onClick={confirmPending}>
                <FontAwesomeIcon icon={faCheck} /> Save
              </button>
              <button type="button" onClick={cancelPending}>
                <FontAwesomeIcon icon={faXmark} /> Cancel
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default NotesTab;
