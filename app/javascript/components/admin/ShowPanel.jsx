import React, { useContext, useEffect, useRef, useState } from "react";
import { useNavigate } from "react-router";
import { EditorContext } from "./AdminShowEditor";
import { adminGet, adminPost, adminPatch, adminDelete } from "./adminApi";

const DEBOUNCE_MS = 300;

const BLANK_VENUE = { name: "", city: "", state: "", country: "USA" };

const ShowPanel = () => {
  const { show, setShow, setError } = useContext(EditorContext);
  const navigate = useNavigate();
  const [collapsed, setCollapsed] = useState(false);
  const [venueQuery, setVenueQuery] = useState("");
  const [venueResults, setVenueResults] = useState([]);
  const [venueOpen, setVenueOpen] = useState(false);
  const [newVenue, setNewVenue] = useState(null);
  const [tours, setTours] = useState([]);
  const [taperNotes, setTaperNotes] = useState(show.taper_notes || "");
  const [adminNotes, setAdminNotes] = useState(show.admin_notes || "");
  const [gap, setGap] = useState(String(show.performance_gap_value ?? ""));
  const [busy, setBusy] = useState(false);
  const venueRef = useRef(null);

  useEffect(() => setTaperNotes(show.taper_notes || ""), [show.taper_notes]);
  useEffect(() => setAdminNotes(show.admin_notes || ""), [show.admin_notes]);
  useEffect(
    () => setGap(String(show.performance_gap_value ?? "")),
    [show.performance_gap_value]
  );

  useEffect(() => {
    adminGet("/tours")
      .then((data) => setTours(data.tours))
      .catch((e) => setError(e.message));
  }, [setError]);

  useEffect(() => {
    const term = venueQuery.trim();
    if (term === "") {
      setVenueResults([]);
      return undefined;
    }
    let cancelled = false;
    const timer = setTimeout(async () => {
      try {
        const data = await adminGet(`/venues?q=${encodeURIComponent(term)}`);
        if (!cancelled) setVenueResults(data.venues);
      } catch (e) {
        if (!cancelled) setError(e.message);
      }
    }, DEBOUNCE_MS);

    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [venueQuery, setError]);

  useEffect(() => {
    const onDocumentClick = (e) => {
      if (venueRef.current && !venueRef.current.contains(e.target)) {
        setVenueOpen(false);
      }
    };
    document.addEventListener("mousedown", onDocumentClick);
    return () => document.removeEventListener("mousedown", onDocumentClick);
  }, []);

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
    setVenueQuery("");
    setVenueResults([]);
    setVenueOpen(false);
    await patchShow({ venue_id: venue.id });
  };

  const createVenue = async () => {
    setError(null);
    setBusy(true);
    try {
      const venue = await adminPost("/venues", newVenue);
      setNewVenue(null);
      await selectVenue(venue);
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  };

  const deleteShow = async () => {
    const typed = window.prompt(
      `Type ${show.date} to confirm deleting this show and all of its tracks.`
    );
    if (typed !== show.date) return;
    setError(null);
    setBusy(true);
    try {
      await adminDelete(`/shows/${show.date}`);
      navigate("/admin");
    } catch (e) {
      setError(e.message);
      setBusy(false);
    }
  };

  const saveText = (field, current, stored) => {
    if (current === (stored || "")) return;
    patchShow({ [field]: current });
  };

  const saveGap = () => {
    const stored = String(show.performance_gap_value ?? "");
    if (gap === stored || gap === "") return;
    patchShow({ performance_gap_value: Number(gap) });
  };

  return (
    <section className="admin-show-panel">
      <button
        type="button"
        className="admin-panel-toggle"
        onClick={() => setCollapsed(!collapsed)}
      >
        {collapsed ? "Show details" : "Hide details"}
      </button>

      {!collapsed && (
        <div className="admin-panel-body">
          <div className="admin-field" ref={venueRef}>
            <label htmlFor="admin-venue">Venue</label>
            <p className="admin-current-value">
              {show.venue_name || (
                <span className="admin-attention">No venue set</span>
              )}
            </p>
            <input
              id="admin-venue"
              type="text"
              placeholder="Search venues"
              value={venueQuery}
              disabled={busy}
              onFocus={() => setVenueOpen(true)}
              onChange={(e) => {
                setVenueQuery(e.target.value);
                setVenueOpen(true);
              }}
            />
            {venueOpen && venueQuery.trim() !== "" && (
              <ul className="admin-venue-results">
                {venueResults.map((venue) => (
                  <li key={venue.id}>
                    <button type="button" onClick={() => selectVenue(venue)}>
                      {venue.name}, {venue.city}
                      {venue.state ? `, ${venue.state}` : ""} ({venue.country})
                    </button>
                  </li>
                ))}
                <li>
                  <button
                    type="button"
                    onClick={() =>
                      setNewVenue({ ...BLANK_VENUE, name: venueQuery.trim() })
                    }
                  >
                    Create venue
                  </button>
                </li>
              </ul>
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

          <div className="admin-field">
            <label htmlFor="admin-tour">Tour</label>
            <select
              id="admin-tour"
              value={show.tour_id ?? ""}
              disabled={busy}
              onChange={(e) =>
                patchShow({
                  tour_id: e.target.value === "" ? null : Number(e.target.value),
                })
              }
            >
              <option value="">No tour set</option>
              {tours.map((tour) => (
                <option key={tour.id} value={tour.id}>
                  {tour.name}
                </option>
              ))}
            </select>
            {show.tour_id === null && (
              <span className="admin-attention">Needs a tour</span>
            )}
          </div>

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
            <textarea
              id="admin-admin-notes"
              rows={3}
              value={adminNotes}
              disabled={busy}
              onChange={(e) => setAdminNotes(e.target.value)}
              onBlur={() =>
                saveText("admin_notes", adminNotes, show.admin_notes)
              }
            />
          </div>

          <div className="admin-field">
            <label htmlFor="admin-gap">Performance gap value</label>
            <input
              id="admin-gap"
              type="number"
              min="0"
              value={gap}
              disabled={busy}
              onChange={(e) => setGap(e.target.value)}
              onBlur={saveGap}
            />
          </div>

          <div className="admin-field">
            <label htmlFor="admin-matches-pnet">
              <input
                id="admin-matches-pnet"
                type="checkbox"
                checked={Boolean(show.matches_pnet)}
                disabled={busy}
                onChange={(e) => patchShow({ matches_pnet: e.target.checked })}
              />
              {" "}Matches Phish.net
            </label>
          </div>

          <button
            type="button"
            className="admin-danger"
            disabled={busy}
            onClick={deleteShow}
          >
            Delete Show
          </button>
        </div>
      )}
    </section>
  );
};

export default ShowPanel;
