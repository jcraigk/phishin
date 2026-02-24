import React, { useState, useEffect } from "react";
import { useLocation, useOutletContext } from "react-router";
import { Helmet } from "react-helmet-async";
import MapView from "./MapView";
import LayoutWrapper from "./layout/LayoutWrapper";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faSearch } from "@fortawesome/free-solid-svg-icons";
import { useAudioFilter } from "./contexts/AudioFilterContext";
import { getAudioStatusFilter } from "./helpers/utils";

const usStates = [
  "(US State)", "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA", "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME",
  "MD", "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
  "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY"
];

const MapSearch = () => {
  const location = useLocation();
  const { mapboxToken } = useOutletContext();
  const { hideMissingAudio, getAudioStatusParam } = useAudioFilter();

  const getQueryParams = () => {
    const params = new URLSearchParams(location.search);
    return {
      term: params.get("term") || "Burlington, VT",
      distance: params.get("distance") || "10",
      start_date: params.get("start_date") || "1983-12-02",
      end_date: params.get("end_date") || new Date().toISOString().split("T")[0],
      us_state: params.get("us_state") || "(US State)"
    };
  };

  const [formData, setFormData] = useState(getQueryParams());
  const [venues, setVenues] = useState([]);
  const [searchComplete, setSearchComplete] = useState(false);
  const defaultCoordinates = { lat: 44.47, lng: -73.21 }; // Burlington, VT
  const defaultRadius = 10;
  const isStateSelected = formData.us_state !== "(US State)";

  useEffect(() => {
    if (formData.term !== "Burlington, VT" || formData.us_state !== "(US State)") {
      handleSubmit(new Event("submit"));
    } else {
      initializeMap(defaultCoordinates.lat, defaultCoordinates.lng, defaultRadius);
    }
  }, [mapboxToken]);

  useEffect(() => {
    if (formData.term !== "Burlington, VT" || formData.us_state !== "(US State)") {
      handleSubmit(new Event("submit"));
    } else {
      initializeMap(defaultCoordinates.lat, defaultCoordinates.lng, defaultRadius);
    }
  }, [hideMissingAudio]);

  const initializeMap = async (lat, lng, radius) => {
    setSearchComplete(false);
    const fetchedVenues = await fetchShows(lat, lng, radius);
    setVenues(fetchedVenues);
    setSearchComplete(true);
  };

  const fetchShows = async (lat, lng, distance) => {
    const { start_date, end_date, us_state } = formData;
    const audioStatusFilter = getAudioStatusParam();
    let url = `/api/v2/shows?per_page=250&sort=date:desc&start_date=${start_date}&end_date=${end_date}&audio_status=${audioStatusFilter}`;

    if (isStateSelected) {
      url += `&us_state=${us_state}`;
    } else {
      url += `&lat=${lat}&lng=${lng}&distance=${distance}`;
    }

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
          latitude: venue.latitude,
          longitude: venue.longitude,
          shows_count: venue.shows_count,
          shows: [{ date: show.date }]
        });
      } else if (isDuplicate) {
        const existingVenue = acc.find((v) => v.slug === venue.slug);
        existingVenue.shows.push({ date: show.date });
      }
      return acc;
    }, []);

    return uniqueVenues;
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
        alert("Sorry, couldn't find that location");
      }
    }
  };

  const geocodeSearchTerm = async (term) => {
    const url = `https://api.mapbox.com/geocoding/v5/mapbox.places/${term}.json?access_token=${mapboxToken}`;
    const response = await fetch(url);
    const data = await response.json();
    const [lng, lat] = data.features[0].center;
    return { lat, lng };
  };

  const sidebarContent = (
    <div className="sidebar-content">
      <form onSubmit={handleSubmit}>
        <label className="label">US State</label>
        <div className="select">
          <select name="us_state" value={formData.us_state} onChange={handleInputChange}>
            {usStates.map((state) => (
              <option key={state} value={state}>
                {state}
              </option>
            ))}
          </select>
        </div>
        <label className="label">Location</label>
        <input
          className="input"
          type="text"
          name="term"
          placeholder="Place or zipcode"
          value={formData.term}
          onChange={handleInputChange}
          disabled={isStateSelected}
        />
        <label className="label">Distance (miles)</label>
        <input
          className="input"
          type="number"
          name="distance"
          placeholder="Distance (miles)"
          value={formData.distance}
          onChange={handleInputChange}
          disabled={isStateSelected}
        />
        <label className="label">Start Date</label>
        <input
          className="input"
          type="date"
          name="start_date"
          value={formData.start_date}
          onChange={handleInputChange}
        />
        <label className="label">End Date</label>
        <input
          className="input"
          type="date"
          name="end_date"
          value={formData.end_date}
          onChange={handleInputChange}
        />
        <button className="button mt-4" type="submit">
          <FontAwesomeIcon icon={faSearch} className="mr-1" />
          Search
        </button>
      </form>
    </div>
  );

  return (
    <>
      <Helmet>
        <title>Map - Phish.in</title>
      </Helmet>
      <LayoutWrapper sidebarContent={sidebarContent}>
          <div className="map-search-results">
            <MapView
              mapboxToken={mapboxToken}
              coordinates={defaultCoordinates}
              venues={venues}
              searchComplete={searchComplete}
            />
          </div>
      </LayoutWrapper>
    </>
  );
};

export default MapSearch;
