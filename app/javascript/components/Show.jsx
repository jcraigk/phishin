import { authFetch } from "./helpers/utils";

export const showLoader = async ({ params }) => {
  const { date } = params;
  const url = `/api/v2/shows/${date}`;
  try {
    const response = await authFetch(url);
    if (response.status === 404) {
      throw new Response("Show not found", { status: 404 });
    }
    let show = await response.json();
    return show;
  } catch (error) {
    if (error instanceof Response) throw error;
    throw new Response("Error fetching data", { status: 500 });
  }
};

import React, { useState, useRef, useEffect } from "react";
import { Link, useLoaderData, useOutletContext } from "react-router-dom";
import { Helmet } from "react-helmet-async";
import { formatDate, formatDateMed, formatDateLong, formatDurationShow } from "./helpers/utils";
import LayoutWrapper from "./layout/LayoutWrapper";
import ShowContextMenu from "./controls/ShowContextMenu";
import LikeButton from "./controls/LikeButton";
import Tracks from "./Tracks";
import TagBadges from "./controls/TagBadges";
import MapView from "./MapView";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faCircleChevronLeft, faCircleChevronRight, faCircleXmark, faInfoCircle, faClock } from "@fortawesome/free-solid-svg-icons";

const Show = ({ trackSlug }) => {
  const show = useLoaderData();
  const [tracks, setTracks] = useState(show.tracks);
  const trackRefs = useRef([]);
  const { playTrack, mapboxToken } = useOutletContext();
  const [matchedTrack, setMatchedTrack] = useState(tracks[0]);
  const [showIncompleteNotification, setShowIncompleteNotification] = useState(show.incomplete);
  const [showAdminNotesNotification, setShowAdminNotesNotification] = useState(!!show.admin_notes);

  useEffect(() => {
    setTracks(show.tracks);
  }, [show]);

  useEffect(() => {
    let foundTrack;
    if (trackSlug) foundTrack = tracks.find((track) => track.slug === trackSlug);
    if (!foundTrack) foundTrack = tracks[0];
    if (foundTrack) {
      playTrack(tracks, foundTrack, true);
      setMatchedTrack(foundTrack);
      const trackIndex = tracks.findIndex((track) => track.slug === foundTrack.slug);
      if (trackRefs.current[trackIndex]) {
        trackRefs.current[trackIndex].scrollIntoView({ behavior: "smooth", block: "center" });
      }
    }
  }, []);

  const handleClose = (notificationType) => {
    if (notificationType === "incomplete") setShowIncompleteNotification(false);
    if (notificationType === "adminNotes") setShowAdminNotesNotification(false);
  };

  const sidebarContent = (
    <div className="sidebar-content">
      <p className="sidebar-title">{formatDateMed(show.date)}</p>
      <p className="sidebar-info hidden-mobile">
        <Link to={`/venues/${show.venue.slug}`}>{show.venue_name}</Link>
      </p>
      <p className="sidebar-info hidden-mobile">
        <Link to={`/map?term=${encodeURIComponent(show.venue.location)}`}>{show.venue.location}</Link>
      </p>
      <div className="mr-1 show-duration">
        <FontAwesomeIcon icon={faClock} className="mr-1 text-gray" />
        {formatDurationShow(show.duration)}
      </div>

      <hr />

      <div className="sidebar-control-container">
        <div className="hidden-phone">
          <LikeButton likable={show} type="Show" />
        </div>
        <ShowContextMenu show={show} />
      </div>

      <div className="hidden-mobile">
        <TagBadges tags={show.tags} parentId={show.date} />
        <hr />
        <Link to={`/${show.previous_show_date}`}>
          <FontAwesomeIcon icon={faCircleChevronLeft} className="mr-1" />
          Previous show
        </Link>
        <Link to={`/${show.next_show_date}`} className="is-pulled-right">
          Next show
          <FontAwesomeIcon icon={faCircleChevronRight} className="ml-1" />
        </Link>

        <div className="sidebar-map mt-4">
          <MapView
            mapboxToken={mapboxToken}
            coordinates={{ lat: show.venue.latitude, lng: show.venue.longitude }}
            venues={[show.venue]}
            searchComplete={true}
            controls={false}
          />
        </div>
      </div>
    </div>
  );

  const infoBox = (message, onClose) => (
    <div className="notification show-info">
      <button className="close-btn" onClick={onClose}>
        <FontAwesomeIcon icon={faCircleXmark} />
      </button>
      <FontAwesomeIcon icon={faInfoCircle} className="mr-1" />
      {message}
    </div>
  );

  return (
    <>
      <Helmet>
        <title>{matchedTrack ? `${matchedTrack.title} - ${formatDate(show.date)} - Phish.in` : `${formatDate(show.date)} - Phish.in`}</title>
        <meta property="og:title" content={trackSlug && matchedTrack ? `Listen to ${matchedTrack.title} from ${formatDateLong(show.date)}` : `Listen to ${formatDateLong(show.date)}`} />
        <meta property="og:type" content="music.playlist" />
        <meta property="og:audio" content={matchedTrack?.mp3_url} />
      </Helmet>
      <LayoutWrapper sidebarContent={sidebarContent}>
        {showIncompleteNotification && infoBox("This show's audio is incomplete", () => handleClose("incomplete"))}
        {showAdminNotesNotification && infoBox(show.admin_notes, () => handleClose("adminNotes"))}
        <Tracks tracks={tracks} viewStyle="show" trackRefs={trackRefs} trackSlug={trackSlug} />
      </LayoutWrapper>
    </>
  );
};

export default Show;

