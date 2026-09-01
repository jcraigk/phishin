import React, { useContext, useEffect, useState } from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faCheck, faXmark } from "@fortawesome/free-solid-svg-icons";
import { EditorContext } from "./AdminShowEditor";
import { adminGet, adminPatch } from "./adminApi";
import FilterSelect from "./FilterSelect";
import diffLines, { normalizeText } from "./diffLines";

const ShowPanel = () => {
  const { show, setShow, setError } = useContext(EditorContext);
  const [tours, setTours] = useState([]);
  const [taperNotes, setTaperNotes] = useState(show.taper_notes || "");
  const [adminNotes, setAdminNotes] = useState(show.admin_notes || "");
  const [busy, setBusy] = useState(false);
  const [pending, setPending] = useState(null);

  useEffect(() => setTaperNotes(show.taper_notes || ""), [show.taper_notes]);
  useEffect(() => setAdminNotes(show.admin_notes || ""), [show.admin_notes]);

  useEffect(() => {
    adminGet("/tours")
      .then((data) => setTours(data.tours))
      .catch((e) => setError(e.message));
  }, [setError]);

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
    <section className="admin-show-panel">
      <div className="admin-panel-body">
          {show.tour_id === null && (
            <div className="admin-field">
              <label htmlFor="admin-tour">Tour</label>
              <FilterSelect
                id="admin-tour"
                value=""
                placeholder="Filter tours"
                options={tours.map((tour) => ({ id: tour.id, label: tour.name }))}
                disabled={busy}
                onSelect={(option) => patchShow({ tour_id: option.id })}
              />
              <span className="admin-attention">
                No tour matched this date. Publish needs one.
              </span>
            </div>
          )}

          <div className="admin-field">
            <label htmlFor="admin-taper-notes">Taper notes</label>
            <textarea
              id="admin-taper-notes"
              rows={2}
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
              rows={2}
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

      </div>
      {pending && (
        <div className="admin-modal-overlay" onClick={cancelPending}>
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
    </section>
  );
};

export default ShowPanel;
