import { authFetch } from "./helpers/utils";
import { createTaperNotesModalContent } from "./helpers/modals";

export const showLoader = async ({ params }) => {
  const { date } = params;

  // Check localStorage for audio filter setting
  const showMissingAudio = JSON.parse(localStorage.getItem('showMissingAudio') || 'false');
  const audioStatusFilter = showMissingAudio ? 'any' : 'complete_or_partial';

  const url = `/api/v2/shows/${date}?audio_status=${audioStatusFilter}`;
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
import { useAudioFilter } from "./contexts/AudioFilterContext";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faCircleChevronLeft, faCircleChevronRight, faCircleXmark, faInfoCircle, faExclamationCircle } from "@fortawesome/free-solid-svg-icons";

const Show = ({ trackSlug }) => {
  const show = useLoaderData();
  const [tracks, setTracks] = useState(show.tracks);
  const [taperNotesModalClosed, setTaperNotesModalClosed] = useState(false);
  const trackRefs = useRef([]);
  const { playTrack, openAppModal, closeAppModal } = useOutletContext();
  const [matchedTrack, setMatchedTrack] = useState(tracks[0]);
  const [showAdminNotesNotification, setShowAdminNotesNotification] = useState(!!show.admin_notes);
  const [showMissingAudioNotification, setShowMissingAudioNotification] = useState(show.audio_status === 'missing');
  const [showPartialAudioNotification, setShowPartialAudioNotification] = useState(show.audio_status === 'partial');
  const { showMissingAudio } = useAudioFilter();

  useEffect(() => {
    setTracks(show.tracks);
    setShowMissingAudioNotification(show.audio_status === 'missing');
    setShowPartialAudioNotification(show.audio_status === 'partial');

    const backgroundDiv = document.querySelector(".background-blur");
    if (show.cover_art_urls?.medium && backgroundDiv) {
      const imageUrl = show.cover_art_urls.medium;
      backgroundDiv.style.backgroundImage = `url(${imageUrl})`;
    }
  }, [show]);

  useEffect(() => {
    let foundTrack;
    if (trackSlug) foundTrack = tracks.find((track) => track.slug === trackSlug);
    if (foundTrack && foundTrack.audio_status !== 'missing') {
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
    if (notificationType === "adminNotes") setShowAdminNotesNotification(false);
    if (notificationType === "missingAudio") setShowMissingAudioNotification(false);
    if (notificationType === "partialAudio") setShowPartialAudioNotification(false);
  };

  const infoBox = (message, onClose, isWarning = false) => (
    <div className={`notification show-info ${isWarning ? 'is-warning' : ''}`}>
      <button className="close-btn" onClick={onClose}>
        <FontAwesomeIcon icon={faCircleXmark} />
      </button>
      <FontAwesomeIcon icon={isWarning ? faExclamationCircle : faInfoCircle} className="mr-1" />
      {message}
    </div>
  );

  // Get the appropriate navigation dates based on audio filter setting
  const getNavigationDates = () => {
    if (showMissingAudio) {
      return {
        previousShowDate: show.previous_show_date,
        nextShowDate: show.next_show_date
      };
    } else {
      return {
        previousShowDate: show.previous_show_date_with_audio,
        nextShowDate: show.next_show_date_with_audio
      };
    }
  };

  const { previousShowDate, nextShowDate } = getNavigationDates();

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
              {show.audio_status !== 'missing' && <LikeButton likable={show} type="Show" />}
              <ShowContextMenu show={show} />
            </div>

            <TagBadges tags={show.tags} parentId={show.date} />
            <hr className="sidebar-hr" />
            <Link to={`/${previousShowDate}`}>
              <FontAwesomeIcon icon={faCircleChevronLeft} className="mr-1" />
              Previous show
            </Link>
            <Link to={`/${nextShowDate}`} className="is-pulled-right">
              Next show
              <FontAwesomeIcon icon={faCircleChevronRight} className="ml-1" />
            </Link>
          </div>
        </aside>

        <section id="main-content">
          {showMissingAudioNotification && infoBox("No known audience recording exists for this show", () => handleClose("missingAudio"), true)}
          {showPartialAudioNotification && infoBox("This show has partial audio", () => handleClose("partialAudio"), true)}
          {showAdminNotesNotification && infoBox(show.admin_notes, () => handleClose("adminNotes"))}
          {show.audio_status === 'missing' && tracks.length === 0 && (
            <div className="notification is-info">
              <FontAwesomeIcon icon={faInfoCircle} className="mr-1" />
              The setlist for this date is unknown
            </div>
          )}

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
                  <span className="mobile-show-date">
                    {formatDate(show.date)}
                  </span>
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
