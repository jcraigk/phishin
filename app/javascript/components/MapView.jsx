import React, { useEffect, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import { formatNumber } from "./helpers/utils";
import Loader from "./controls/Loader";

const MapView = ({ mapboxToken, coordinates, venues, searchComplete, controls = true }) => {
  const mapContainer = useRef(null);
  const [map, setMap] = useState(null);
  const [mapboxgl, setMapboxgl] = useState(null);
  const navigate = useNavigate();

  useEffect(() => {
    if (!coordinates || !mapboxToken || map) return;

    import("mapbox-gl").then((mapboxglModule) => {
      const mapboxglInstance = mapboxglModule.default;
      setMapboxgl(mapboxglInstance);

      mapboxglInstance.accessToken = mapboxToken;

      const mapboxMap = new mapboxglInstance.Map({
        container: mapContainer.current,
        style: "mapbox://styles/mapbox/streets-v12",
        center: [coordinates.lng, coordinates.lat],
        zoom: 11,
        attributionControl: false,
      });

      mapboxMap.addControl(
        new mapboxglInstance.AttributionControl({
          compact: true,
        })
      );

      if (controls) {
        mapboxMap.addControl(new mapboxglInstance.NavigationControl());
      }

      setMap(mapboxMap);
    });
  }, [coordinates, mapboxToken, controls, map]);

  useEffect(() => {
    if (map && venues && mapboxgl) {
      addMarkersToMap(map, venues, mapboxgl);
    }
  }, [map, venues, mapboxgl]);

  const addMarkersToMap = (mapInstance, venues, mapboxglInstance) => {
    if (!mapInstance || venues.length === 0) {
      if (searchComplete) {
        new mapboxglInstance.Popup({ closeButton: false })
          .setLngLat(mapInstance.getCenter())
          .setHTML(
            "<p style=\"font-family: 'Open Sans Condensed', sans-serif; font-weight: bold; font-size: 1.2rem;\">No results found for your search.</p>"
          )
          .addTo(mapInstance);
      }
      return;
    }

    const bounds = new mapboxglInstance.LngLatBounds();

    venues.forEach((venue) => {
      let marker;

      // If single venue, use custom icon
      if (venues.length === 1) {
        const customIcon = document.createElement("div");
        customIcon.className = "custom-marker-icon";

        marker = new mapboxglInstance.Marker(customIcon).setLngLat([
          venue.longitude,
          venue.latitude,
        ]);
      } else {
        marker = new mapboxglInstance.Marker().setLngLat([
          venue.longitude,
          venue.latitude,
        ]);

        if (venue.shows && venue.shows.length > 0) {
          const popupContent = document.createElement("div");
          popupContent.className = "map-popup";

          const venueTitle = document.createElement("h2");
          venueTitle.textContent = venue.name;
          popupContent.appendChild(venueTitle);

          const venueLocation = document.createElement("h3");
          venueLocation.textContent = `${venue.location} • ${formatNumber(venue.shows_count, "show")}`;
          popupContent.appendChild(venueLocation);

          venue.shows.forEach((show) => {
            const showLink = document.createElement("a");
            showLink.href = `/${show.date}`;
            showLink.className = "show-badge";
            showLink.textContent = show.date.replace(/-/g, ".");
            showLink.onclick = (e) => {
              e.preventDefault();
              navigate(`/${show.date}`);
            };
            popupContent.appendChild(showLink);
          });

          const popup = new mapboxglInstance.Popup({ closeButton: false }).setDOMContent(popupContent);
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
        duration: 1000,
      });
    }
  };

  return (
    <>
      {!searchComplete && <Loader />}
      <div className="map-container" ref={mapContainer} />
    </>
  );
};

export default MapView;

