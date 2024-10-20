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
import { formatDate, formatDurationShow } from "./helpers/utils";
import LayoutWrapper from "./layout/LayoutWrapper";
import ShowContextMenu from "./controls/ShowContextMenu";
import LikeButton from "./controls/LikeButton";
import Tracks from "./Tracks";
import TagBadges from "./controls/TagBadges";
import MapView from "./MapView";
import CoverArt from "./CoverArt";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faCircleChevronLeft, faCircleChevronRight, faCircleXmark, faInfoCircle, faClock } from "@fortawesome/free-solid-svg-icons";

const Show = ({ trackSlug }) => {
  const show = useLoaderData();
  const [tracks, setTracks] = useState(show.tracks);
  const trackRefs = useRef([]);
  const { playTrack, mapboxToken, openAppModal } = useOutletContext();
  const [matchedTrack, setMatchedTrack] = useState(tracks[0]);
  const [showIncompleteNotification, setShowIncompleteNotification] = useState(show.incomplete);
  const [showAdminNotesNotification, setShowAdminNotesNotification] = useState(!!show.admin_notes);

  useEffect(() => {
    setTracks(show.tracks);

    const backgroundDiv = document.querySelector(".background-blur");
    if (show.cover_art_urls?.medium && backgroundDiv) {
      const imageUrl = show.cover_art_urls.medium;
      backgroundDiv.style.backgroundImage = `url(${imageUrl})`;
    }
  }, [show]);

  useEffect(() => {
    let foundTrack;
    if (trackSlug) foundTrack = tracks.find((track) => track.slug === trackSlug);
    if (foundTrack) {
      playTrack(tracks, foundTrack, true);
      setMatchedTrack(foundTrack);
      const trackIndex = tracks.findIndex((track) => track.slug === foundTrack.slug);
      if (trackRefs.current[trackIndex]) {
        trackRefs.current[trackIndex].scrollIntoView({ behavior: "smooth" });
      }
    }
  }, [trackSlug, tracks]);

  const handleClose = (notificationType) => {
    if (notificationType === "incomplete") setShowIncompleteNotification(false);
    if (notificationType === "adminNotes") setShowAdminNotesNotification(false);
  };

  const sidebarContent = (
    <div className="sidebar-content">
      <div className="hidden-mobile mb-2">
        <CoverArt
          coverArtUrls={show.cover_art_urls}
          albumCoverUrl={show.album_cover_url}
          openAppModal={openAppModal}
          size="medium"
        />
      </div>

      <div className="sidebar-title show-cover-title">
        <span className="display-mobile-only">
          <CoverArt
            coverArtUrls={show.cover_art_urls}
            albumCoverUrl={show.album_cover_url}
            openAppModal={openAppModal}
          />
        </span>
        {formatDate(show.date)}
      </div>

      <p className="sidebar-info hidden-mobile">
        <Link to={`/venues/${show.venue.slug}`}>{show.venue_name}</Link>
      </p>
      <div className="mr-1 show-duration">
        <FontAwesomeIcon icon={faClock} className="mr-1 text-gray" />
        {formatDurationShow(show.duration)}
      </div>

      <hr className="sidebar-hr" />

      <div className="sidebar-control-container">
        <div className="hidden-phone">
          <LikeButton likable={show} type="Show" />
        </div>
        <ShowContextMenu show={show} />
      </div>

      <div className="hidden-mobile">
        <TagBadges tags={show.tags} parentId={show.date} />
        <hr className="sidebar-hr" />
        <Link to={`/${show.previous_show_date}`}>
          <FontAwesomeIcon icon={faCircleChevronLeft} className="mr-1" />
          Previous show
        </Link>
        <Link to={`/${show.next_show_date}`} className="is-pulled-right">
          Next show
          <FontAwesomeIcon icon={faCircleChevronRight} className="ml-1" />
        </Link>

        {/* MapBox free tier limits preclude the sidebar maps */}
        {/* <div className="sidebar-map mt-4">
          <MapView
            mapboxToken={mapboxToken}
            coordinates={{ lat: show.venue.latitude, lng: show.venue.longitude }}
            venues={[show.venue]}
            searchComplete={true}
            controls={false}
          />
        </div> */}
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
      </Helmet>
      <div className="background-blur"></div>
      <LayoutWrapper sidebarContent={sidebarContent}>
        {showIncompleteNotification && infoBox("This show's audio is incomplete", () => handleClose("incomplete"))}
        {showAdminNotesNotification && infoBox(show.admin_notes, () => handleClose("adminNotes"))}

        <div className="display-phone-only mt-1">
          <div className="phone-show-container">
            <div className="phone-show-image">
              <CoverArt
                coverArtUrls={show.cover_art_urls}
                albumCoverUrl={show.album_cover_url}
                openAppModal={openAppModal}
                size="medium"
                css="phone-show-mobile"
              />
            </div>
            <div className="phone-show-info">
              <span className="phone-show-date">{formatDate(show.date)}</span>
              <span className="phone-show-venue">
                {show.venue_name}
              </span>
              <span className="phone-show-context">
                <ShowContextMenu show={show} css="context-nudge-right" />
              </span>
            </div>
          </div>
        </div>

        <Tracks tracks={tracks} viewStyle="show" trackRefs={trackRefs} trackSlug={trackSlug} />
      </LayoutWrapper>
    </>
  );
};

export default Show;

