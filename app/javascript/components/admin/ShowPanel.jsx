import React, { useContext, useEffect, useState } from "react";
import { EditorContext } from "./AdminShowEditor";
import { adminGet, adminPatch } from "./adminApi";
import FilterSelect from "./FilterSelect";

const ShowPanel = () => {
  const { show, setShow, setError } = useContext(EditorContext);
  const [tours, setTours] = useState([]);
  const [taperNotes, setTaperNotes] = useState(show.taper_notes || "");
  const [adminNotes, setAdminNotes] = useState(show.admin_notes || "");
  const [busy, setBusy] = useState(false);

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

  const saveText = (field, current, stored) => {
    if (current === (stored || "")) return;
    patchShow({ [field]: current });
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
                saveText("taper_notes", taperNotes, show.taper_notes)
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
                saveText("admin_notes", adminNotes, show.admin_notes)
              }
            />
          </div>
      </div>
    </section>
  );
};

export default ShowPanel;
