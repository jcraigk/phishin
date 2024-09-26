import { authFetch } from "./utils";

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
import { formatDate, formatDateMed, formatDateLong, formatDurationShow } from "./utils";
import LayoutWrapper from "./LayoutWrapper";
import ShowContextMenu from "./ShowContextMenu";
import LikeButton from "./LikeButton";
import Tracks from "./Tracks";
import TagBadges from "./TagBadges";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faCircleChevronLeft, faCircleChevronRight, faCircleXmark, faInfoCircle, faClock } from "@fortawesome/free-solid-svg-icons";

const Show = ({ trackSlug }) => {
  const show = useLoaderData();
  const [tracks, setTracks] = useState(show.tracks);
  const trackRefs = useRef([]);
  const { playTrack } = useOutletContext();
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
      <p className="sidebar-info sidebar-extras">
        <Link to={`/venues/${show.venue.slug}`}>{show.venue_name}</Link>
      </p>
      <p className="sidebar-info sidebar-extras">
        <Link to={`/map?term=${encodeURIComponent(show.venue.location)}`}>{show.venue.location}</Link>
      </p>
      <div className="show-duration mr-1">
        <FontAwesomeIcon icon={faClock} className="mr-1" />
        {formatDurationShow(show.duration)}
      </div>

      <hr />

      <div className="sidebar-control-wrapper">
        <LikeButton likable={show} type="Show" />
        <ShowContextMenu show={show} isLeft={true} />
      </div>

      <div className="sidebar-extras">
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
      </div>
    </div>
  );

  const infoBox = (message, onClose) => (
    <div className="notification show-info">
      <button className="close-btn" onClick={onClose}>
        <FontAwesomeIcon icon={faCircleXmark} />
      </button>
      <span className="icon">
        <FontAwesomeIcon icon={faInfoCircle} />
      </span>
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

