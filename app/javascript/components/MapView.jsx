import React, { useEffect, useRef, useState } from "react";
import mapboxgl from "mapbox-gl";
import { formatNumber } from "./helpers/utils";

const MapView = ({ mapboxToken, coordinates, venues, searchComplete, controls = true }) => {
  const mapContainer = useRef(null);
  const [map, setMap] = useState(null);

  useEffect(() => {
    if (!coordinates || !mapboxToken || map) return;

    mapboxgl.accessToken = mapboxToken;

    const mapboxMap = new mapboxgl.Map({
      container: mapContainer.current,
      style: "mapbox://styles/mapbox/streets-v12",
      center: [coordinates.lng, coordinates.lat],
      zoom: 11,
      attributionControl: false
    });

    mapboxMap.addControl(
      new mapboxgl.AttributionControl({
        compact: true,
      })
    );

    if (controls) {
      mapboxMap.addControl(new mapboxgl.NavigationControl());
    }

    setMap(mapboxMap);
  }, [coordinates, mapboxToken, controls, map]);

  useEffect(() => {
    if (map && venues) {
      addMarkersToMap(map, venues);
    }
  }, [map, venues]);

  const addMarkersToMap = (mapInstance, venues) => {
    if (!mapInstance || venues.length === 0) {
      if (searchComplete) {
        new mapboxgl.Popup({ closeButton: false })
          .setLngLat(mapInstance.getCenter())
          .setHTML("<p style=\"font-family: 'Open Sans Condensed', sans-serif; font-weight: bold; font-size: 1.2rem;\">No results found for your search.</p>")
          .addTo(mapInstance);
      }
      return;
    }

    const bounds = new mapboxgl.LngLatBounds();

    venues.forEach((venue) => {
      let marker;

      // If single venue, use custom icon
      if (venues.length === 1) {
        const customIcon = document.createElement('div');
        customIcon.className = 'custom-marker-icon';

        marker = new mapboxgl.Marker(customIcon).setLngLat([venue.longitude, venue.latitude]);

      } else {
        marker = new mapboxgl.Marker().setLngLat([venue.longitude, venue.latitude]);

        if (venue.shows && venue.shows.length > 0) {
          const popupContent = `
            <div class="map-popup">
              <h2>${venue.name}</h2>
              <h3>${venue.location} &bull; ${formatNumber(venue.shows_count, 'show')}</h3>
              ${venue.shows
                .map(
                  (show) => `
                  <a href="/${show.date}" class="show-badge">${show.date.replace(/-/g, ".")}</a>
                  `
                )
                .join("")}
            </div>
          `;
          const popup = new mapboxgl.Popup({ closeButton: false }).setHTML(popupContent);
          marker.setPopup(popup);
        }
      }

      marker.addTo(mapInstance);
      bounds.extend([venue.longitude, venue.latitude]);
    });

    if (venues.length === 1) {
      mapInstance.setZoom(8);
      mapInstance.setCenter([venues[0].longitude, venues[0].latitude]);
    } else if (venues.length > 0) {
      mapInstance.fitBounds(bounds, {
        padding: 50,
        maxZoom: 12,
        duration: 1000
      });
    }
  };

  return (
    <div className="map-container" ref={mapContainer} />
  );
};

export default MapView;
