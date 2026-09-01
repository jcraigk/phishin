import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faCheck, faXmark } from "@fortawesome/free-solid-svg-icons";
import React, { useContext, useEffect, useState } from "react";
import { EditorContext } from "./AdminShowEditor";
import { adminGet, adminPost, adminPatch } from "./adminApi";
import FilterSelect from "./FilterSelect";

const BLANK_VENUE = {
  name: "",
  city: "",
  state: "",
  country: "USA",
  latitude: "",
  longitude: "",
};

const FIELD_LABELS = {
  name: "Name",
  city: "City",
  state: "State",
  country: "Country",
  latitude: "Latitude",
  longitude: "Longitude",
};

const venueLabel = (venue) => {
  const place = `${venue.city}${venue.state ? `, ${venue.state}` : ""}`;
  const country = venue.country && venue.country !== "USA" ? ` (${venue.country})` : "";
  return `${venue.name} - ${place}${country}`;
};

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
      const venue = await adminPost("/venues", {
        ...newVenue,
        latitude: newVenue.latitude === "" ? undefined : Number(newVenue.latitude),
        longitude: newVenue.longitude === "" ? undefined : Number(newVenue.longitude),
      });
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
        value={
          (() => {
            const current = venues.find((venue) => venue.id === show.venue_id);
            return current ? venueLabel(current) : show.venue_name || "";
          })()
        }
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
            {Object.keys(FIELD_LABELS).map((field) => (
              <label key={field} className="admin-modal-field">
                <span>{FIELD_LABELS[field]}</span>
                <input
                  type="text"
                  placeholder={field === "latitude" ? "44.0429" : field === "longitude" ? "-72.7089" : ""}
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
                <FontAwesomeIcon icon={faCheck} /> Save Venue
              </button>
              <button type="button" onClick={() => setNewVenue(null)}>
                <FontAwesomeIcon icon={faXmark} /> Cancel
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default VenueControl;
