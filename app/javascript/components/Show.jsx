import { authFetch } from "./helpers/utils";
import { createTaperNotesModalContent } from "./helpers/modals";

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
import { formatDate } from "./helpers/utils";
import ShowContextMenu from "./controls/ShowContextMenu";
import LikeButton from "./controls/LikeButton";
import Tracks from "./Tracks";
import TagBadges from "./controls/TagBadges";
import CoverArt from "./CoverArt";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faCircleChevronLeft, faCircleChevronRight, faCircleXmark, faInfoCircle } from "@fortawesome/free-solid-svg-icons";

const Show = ({ trackSlug }) => {
  const show = useLoaderData();
  const [tracks, setTracks] = useState(show.tracks);
  const [taperNotesModalClosed, setTaperNotesModalClosed] = useState(false);
  const trackRefs = useRef([]);
  const { playTrack, openAppModal, closeAppModal } = useOutletContext();
  const [matchedTrack, setMatchedTrack] = useState(tracks[0]);
  const [showIncompleteNotification, setShowIncompleteNotification] = useState(show.incomplete);
  const [showAdminNotesNotification, setShowAdminNotesNotification] = useState(!!show.admin_notes);

  useEffect(() => {
    setTracks(show.tracks);
    setShowIncompleteNotification(show.incomplete);

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

  useEffect(() => {
    if (trackSlug === 'taper-notes' && !taperNotesModalClosed) {
      openAppModal(createTaperNotesModalContent(show));
      setTaperNotesModalClosed(true);
    }
  }, [trackSlug, show, openAppModal]);

  const handleClose = (notificationType) => {
    if (notificationType === "incomplete") setShowIncompleteNotification(false);
    if (notificationType === "adminNotes") setShowAdminNotesNotification(false);
  };

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
      <div id="layout-container">
        <aside id="sidebar" className="hidden-mobile">
          <div className="sidebar-content">
            <div className="mb-4">
              <CoverArt
                coverArtUrls={show.cover_art_urls}
                albumCoverUrl={show.album_cover_url}
                openAppModal={openAppModal}
                closeAppModal={closeAppModal}
                size="medium"
              />
            </div>

            <div className="sidebar-title show-cover-title">
              {formatDate(show.date)}
            </div>

            <p className="sidebar-info">
              <Link to={`/venues/${show.venue.slug}`}>{show.venue_name}</Link>
            </p>
            <p className="sidebar-info">
              <Link
                to={`/map?term=${show.venue.location}`}
                onClick={(e) => e.stopPropagation()}
              >
                {show.venue.location}
              </Link>
            </p>

            <hr className="sidebar-hr" />

            <div className="sidebar-control-container">
              <LikeButton likable={show} type="Show" />
              <ShowContextMenu show={show} />
            </div>

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
          </div>
        </aside>

        <section id="main-content">
          {showIncompleteNotification && infoBox("This show's audio is incomplete", () => handleClose("incomplete"))}
          {showAdminNotesNotification && infoBox(show.admin_notes, () => handleClose("adminNotes"))}

          <div className="display-mobile-only mt-1">
            <div className="mobile-show-wrapper">
              <div className="mobile-show-container">
                <div className="mobile-show-image">
                  <CoverArt
                    coverArtUrls={show.cover_art_urls}
                    albumCoverUrl={show.album_cover_url}
                    openAppModal={openAppModal}
                    closeAppModal={closeAppModal}
                    size="medium"
                  />
                </div>
                <div className="mobile-show-info">
                  <span className="mobile-show-date">{formatDate(show.date)}</span>
                  <span className="mobile-show-venue">
                    {show.venue_name}
                    <br />
                    {show.venue.location}
                  </span>
                  <span className="mobile-show-context">
                    <ShowContextMenu show={show} css="context-nudge-right" />
                  </span>
                </div>
              </div>
            </div>
          </div>

          <Tracks tracks={tracks} viewStyle="show" trackRefs={trackRefs} trackSlug={trackSlug} />
        </section>
      </div>
    </>
  );
};

export default Show;
