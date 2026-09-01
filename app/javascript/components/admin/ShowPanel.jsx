import React, { useContext, useEffect, useState } from "react";
import { EditorContext } from "./AdminShowEditor";
import { adminGet, adminPatch } from "./adminApi";
import FilterSelect from "./FilterSelect";

const ShowPanel = () => {
  const { show, setShow, setError } = useContext(EditorContext);
  const [tours, setTours] = useState([]);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (show.tour_id !== null) return;
    adminGet("/tours")
      .then((data) => setTours(data.tours))
      .catch((e) => setError(e.message));
  }, [show.tour_id, setError]);

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

  if (show.tour_id !== null) return null;

  return (
    <section className="admin-show-panel">
      <div className="admin-panel-body">
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
      </div>
    </section>
  );
};

export default ShowPanel;
