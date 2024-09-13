import React, { useState, useEffect, useRef } from "react";
import mapboxgl from "mapbox-gl";
import LayoutWrapper from "./LayoutWrapper";

const usStates = [
  "(US State)", "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA", "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME",
  "MD", "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
  "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY"
];

const MapView = ({ mapbox_token }) => {
  const mapContainer = useRef(null);
  const [map, setMap] = useState(null);

  const getQueryParams = () => {
    const params = new URLSearchParams(window.location.search);
    return {
      term: params.get("term") || "Burlington, VT",
      distance: params.get("distance") || "10",
      start_date: params.get("start_date") || "1983-12-02",
      end_date: params.get("end_date") || new Date().toISOString().split("T")[0],
      us_state: params.get("us_state") || "(US State)"
    };
  };

  const [formData, setFormData] = useState(getQueryParams());

  const defaultCoordinates = { lat: 44.47, lng: -73.21 }; // Burlington, VT
  const defaultRadius = 10;

  const isStateSelected = formData.us_state !== "(US State)";

  useEffect(() => {
    const { term, us_state } = formData;

    if (term !== "Burlington, VT" || us_state !== "(US State)") {
      handleSubmit(new Event("submit"));
    } else {
      initializeMap(defaultCoordinates.lat, defaultCoordinates.lng, defaultRadius);
    }
  }, [mapbox_token]);

  const initializeMap = (lat, lng, radius) => {
    if (map) {
      map.remove();
    }

    mapboxgl.accessToken = mapbox_token;

    const mapboxMap = new mapboxgl.Map({
      container: mapContainer.current,
      style: "mapbox://styles/mapbox/streets-v12",
      center: [lng, lat],
      zoom: 11,
    });

    mapboxMap.addControl(new mapboxgl.NavigationControl());
    setMap(mapboxMap);

    fetchShows(lat, lng, radius).then((venues) => {
      addMarkersToMap(mapboxMap, venues);
    });
  };

  const fetchShows = async (lat, lng, distance) => {
    const { start_date, end_date, us_state } = formData;
    let url = `/api/v2/shows?per_page=250&sort=date:desc&start_date=${start_date}&end_date=${end_date}`;

    if (isStateSelected) {
      url += `&us_state=${us_state}`;
    } else {
      url += `&lat=${lat}&lng=${lng}&distance=${distance}`;
    }

    try {
      const response = await fetch(url);
      const data = await response.json();

      const uniqueVenues = data.shows.reduce((acc, show) => {
        const venue = show.venue;
        const isDuplicate = acc.some((v) => v.slug === venue.slug);

        if (!isDuplicate && venue.latitude && venue.longitude) {
          acc.push({
            slug: venue.slug,
            name: venue.name,
            location: venue.location,
            lat: venue.latitude,
            lng: venue.longitude,
            shows: [{ date: show.date }],
          });
        } else if (isDuplicate) {
          const existingVenue = acc.find((v) => v.slug === venue.slug);
          existingVenue.shows.push({ date: show.date });
        }
        return acc;
      }, []);

      return uniqueVenues;
    } catch (error) {
      console.error("Error fetching shows:", error);
      return [];
    }
  };

  const addMarkersToMap = (mapInstance, venues) => {
    if (venues.length === 0) {
      const noResultsPopup = new mapboxgl.Popup({ closeButton: false })
        .setLngLat(mapInstance.getCenter()) // Show the popover at the center of the map
        .setHTML("<p style=\"font-family: 'Open Sans Condensed', sans-serif; font-weight: bold; font-size: 1.25rem;\">No results found for your search.</p>")
        .addTo(mapInstance);

      return;
    }

    const bounds = new mapboxgl.LngLatBounds();

    venues.forEach((venue) => {
      const popupContent = `
        <h3 style="font-family: 'Open Sans Condensed', sans-serif; font-weight: bold; font-size: 1.5rem;" class="mb-4">
          ${venue.name}
        </h3>
        <ul style="font-family: 'Open Sans Condensed', sans-serif; font-size: 1.2rem; line-height: 1.5rem;">
          ${venue.shows
            .map(
              (show) => `<li><a href="/${show.date}" style="outline: none; text-decoration: none;">${show.date.replace(/-/g, ".")}</a></li>`
            )
            .join("")}
        </ul>
      `;

      const popup = new mapboxgl.Popup({ closeButton: false }).setHTML(popupContent);

      new mapboxgl.Marker()
        .setLngLat([venue.lng, venue.lat])
        .setPopup(popup)
        .addTo(mapInstance);

      bounds.extend([venue.lng, venue.lat]);
    });

    if (venues.length > 0) {
      mapInstance.fitBounds(bounds, {
        padding: 50,
        maxZoom: 12,
        duration: 1000
      });
    }
  };

  const geocodeSearchTerm = async (term) => {
    const url = `https://api.mapbox.com/geocoding/v5/mapbox.places/${term}.json?access_token=${mapbox_token}`;
    try {
      const response = await fetch(url);
      const data = await response.json();
      const [lng, lat] = data.features[0].center;
      return { lat, lng };
    } catch (error) {
      console.error("Error with geocoding:", error);
      return null;
    }
  };

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setFormData({ ...formData, [name]: value });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();

    if (isStateSelected) {
      initializeMap(defaultCoordinates.lat, defaultCoordinates.lng, defaultRadius);
    } else {
      const { term, distance } = formData;

      const geocodeResult = await geocodeSearchTerm(term);
      if (geocodeResult) {
        const { lat, lng } = geocodeResult;
        initializeMap(lat, lng, distance);
      } else {
        alert("Could not find the location. Please try again.");
      }
    }
  };

  const sidebarContent = (
    <div className="sidebar-content">
      <form onSubmit={handleSubmit}>
        <div className="field">
          <label className="label">US State</label>
          <div className="control">
            <div className="select">
              <select name="us_state" value={formData.us_state} onChange={handleInputChange}>
                {usStates.map((state) => (
                  <option key={state} value={state}>
                    {state}
                  </option>
                ))}
              </select>
            </div>
          </div>
        </div>
        <div className="field">
          <label className="label">Location</label>
          <div className="control">
            <input
              className="input"
              type="text"
              name="term"
              placeholder="Place or zipcode"
              value={formData.term}
              onChange={handleInputChange}
              disabled={isStateSelected}
            />
          </div>
        </div>
        <div className="field">
          <label className="label">Distance (miles)</label>
          <div className="control">
            <input
              className="input"
              type="number"
              name="distance"
              placeholder="Distance (miles)"
              value={formData.distance}
              onChange={handleInputChange}
              disabled={isStateSelected}
            />
          </div>
        </div>
        <div className="field">
          <label className="label">Start Date</label>
          <div className="control">
            <input
              className="input"
              type="date"
              name="start_date"
              value={formData.start_date}
              onChange={handleInputChange}
            />
          </div>
        </div>
        <div className="field">
          <label className="label">End Date</label>
          <div className="control">
            <input
              className="input"
              type="date"
              name="end_date"
              value={formData.end_date}
              onChange={handleInputChange}
            />
          </div>
        </div>
        <div className="field">
          <div className="control">
            <button className="button is-primary" type="submit">
              Search
            </button>
          </div>
        </div>
      </form>
    </div>
  );

  return (
    <LayoutWrapper sidebarContent={sidebarContent}>
      <div
        className="map-container"
        ref={mapContainer}
        style={{ width: "100%", height: "500px" }}
      />
    </LayoutWrapper>
  );
};

export default MapView;
