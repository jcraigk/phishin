import React, { useContext, useEffect, useState } from "react";
import { EditorContext } from "./AdminShowEditor";
import { adminGet, adminPost, adminPatch } from "./adminApi";
import FilterSelect from "./FilterSelect";

const BLANK_VENUE = { name: "", city: "", state: "", country: "USA" };

const venueLabel = (venue) =>
  `${venue.name}, ${venue.city}${venue.state ? `, ${venue.state}` : ""} (${venue.country})`;

const ShowPanel = () => {
  const { show, setShow, setError } = useContext(EditorContext);
  const [venues, setVenues] = useState([]);
  const [newVenue, setNewVenue] = useState(null);
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
    adminGet("/venues?all=true")
      .then((data) => setVenues(data.venues))
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

  const selectVenue = async (venue) => {
    await patchShow({ venue_id: venue.id });
  };

  const createVenue = async () => {
    setError(null);
    setBusy(true);
    try {
      const venue = await adminPost("/venues", newVenue);
      setNewVenue(null);
      setVenues((prev) =>
        [...prev, venue].sort((a, b) => a.name.localeCompare(b.name))
      );
      await selectVenue(venue);
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
          <div className="admin-field">
            <label htmlFor="admin-venue">Venue</label>
            <FilterSelect
              id="admin-venue"
              value={show.venue_name || ""}
              placeholder="Filter venues"
              options={venues.map((venue) => ({ id: venue.id, label: venueLabel(venue), venue }))}
              disabled={busy}
              onSelect={(option) => selectVenue(option.venue)}
              footer={(query) => (
                <li>
                  <button
                    type="button"
                    onClick={() => setNewVenue({ ...BLANK_VENUE, name: query })}
                  >
                    Create venue
                  </button>
                </li>
              )}
            />
            {!show.venue_name && (
              <span className="admin-attention">No venue set</span>
            )}

            {newVenue && (
              <div className="admin-inline-form">
                {["name", "city", "state", "country"].map((field) => (
                  <input
                    key={field}
                    type="text"
                    placeholder={field}
                    value={newVenue[field]}
                    onChange={(e) =>
                      setNewVenue({ ...newVenue, [field]: e.target.value })
                    }
                  />
                ))}
                <button
                  type="button"
                  disabled={busy || !newVenue.name || !newVenue.city}
                  onClick={createVenue}
                >
                  Save venue
                </button>
                <button type="button" onClick={() => setNewVenue(null)}>
                  Cancel
                </button>
              </div>
            )}
          </div>

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
              rows={5}
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
            <input
              id="admin-admin-notes"
              type="text"
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
