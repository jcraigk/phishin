import React, { useContext, useEffect, useState } from "react";
import { EditorContext } from "./AdminShowEditor";
import { adminGet, adminPost, adminPatch } from "./adminApi";
import FilterSelect from "./FilterSelect";

const BLANK_VENUE = { name: "", city: "", state: "", country: "USA" };

const venueLabel = (venue) =>
  `${venue.name}, ${venue.city}${venue.state ? `, ${venue.state}` : ""} (${venue.country})`;

// The venue picker that sits in the editor's title row. Selecting a venue
// saves immediately, like every other metadata control.
const VenueControl = () => {
  const { show, setShow, setError } = useContext(EditorContext);
  const [venues, setVenues] = useState([]);
  const [newVenue, setNewVenue] = useState(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    adminGet("/venues?all=true")
      .then((data) => setVenues(data.venues))
      .catch((e) => setError(e.message));
  }, [setError]);

  const selectVenue = async (venue) => {
    setError(null);
    setBusy(true);
    try {
      setShow(await adminPatch(`/shows/${show.date}`, { venue_id: venue.id }));
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
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
      setBusy(false);
    }
  };

  return (
    <div className="admin-venue-control">
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
      {!show.venue_name && <span className="admin-attention">No venue set</span>}

      {newVenue && (
        <div className="admin-modal-overlay" onClick={() => setNewVenue(null)}>
          <div className="admin-modal" onClick={(e) => e.stopPropagation()}>
            <h3>New Venue</h3>
            {["name", "city", "state", "country"].map((field) => (
              <label key={field} className="admin-modal-field">
                <span>{field[0].toUpperCase() + field.slice(1)}</span>
                <input
                  type="text"
                  value={newVenue[field]}
                  onChange={(e) =>
                    setNewVenue({ ...newVenue, [field]: e.target.value })
                  }
                />
              </label>
            ))}
            <div className="admin-modal-actions">
              <button
                type="button"
                disabled={busy || !newVenue.name || !newVenue.city}
                onClick={createVenue}
              >
                Save Venue
              </button>
              <button type="button" onClick={() => setNewVenue(null)}>
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default VenueControl;
