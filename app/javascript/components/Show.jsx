import { authFetch, getAudioStatusFilter } from "./helpers/utils";
import { createTaperNotesModalContent } from "./helpers/modals";

export const showLoader = async ({ params }) => {
  const { date } = params;
  const audioStatusFilter = getAudioStatusFilter();
  const url = `/api/v2/shows/${date}?audio_status=${audioStatusFilter}`;
  const response = await authFetch(url);
  if (response.status === 404) {
    throw new Response("Show not found", { status: 404 });
  }
  let show = await response.json();
  return show;
};

import React, { useState, useRef, useEffect, useMemo } from "react";
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
  const { playTrack, activeTrack, openAppModal, closeAppModal } = useOutletContext();
  const [matchedTrack, setMatchedTrack] = useState(tracks[0]);
  const [showAdminNotesNotification, setShowAdminNotesNotification] = useState(!!show.admin_notes);
  const [showPartialAudioNotification, setShowPartialAudioNotification] = useState(show.audio_status === 'partial');
  const { hideMissingAudio } = useAudioFilter();

  const filteredTracks = useMemo(() => {
    return hideMissingAudio ? tracks.filter(track => track.audio_status !== 'missing') : tracks;
  }, [tracks, hideMissingAudio]);

  useEffect(() => {
    setTracks(show.tracks);
    setShowPartialAudioNotification(show.audio_status === 'partial');

    const backgroundDiv = document.querySelector(".background-blur");
    if (show.cover_art_urls?.medium && backgroundDiv) {
      const imageUrl = show.cover_art_urls.medium;
      backgroundDiv.style.backgroundImage = `url(${imageUrl})`;
    }

    return () => {
      const backgroundDiv = document.querySelector(".background-blur");
      if (backgroundDiv) {
        backgroundDiv.style.backgroundImage = '';
      }
    };
  }, [show]);

  useEffect(() => {
    let foundTrack;
    if (trackSlug) foundTrack = tracks.find((track) => track.slug === trackSlug);
    if (foundTrack) {
      setMatchedTrack(foundTrack);
      const trackIndex = tracks.findIndex((track) => track.slug === foundTrack.slug);
      if (trackRefs.current[trackIndex]) {
        trackRefs.current[trackIndex].scrollIntoView({ behavior: "smooth" });
      }

      if (foundTrack.audio_status !== 'missing' && !activeTrack) {
        playTrack(filteredTracks, foundTrack, false);
      }
    }
  }, [trackSlug, tracks, filteredTracks]);

  useEffect(() => {
    if (trackSlug === 'taper-notes' && !taperNotesModalClosed) {
      openAppModal(createTaperNotesModalContent(show));
      setTaperNotesModalClosed(true);
    }
  }, [trackSlug, show, openAppModal]);

  const handleClose = (notificationType) => {
    if (notificationType === "adminNotes") setShowAdminNotesNotification(false);
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

  const getNavigationDates = () => {
    if (hideMissingAudio) {
      return {
        previousShowDate: show.previous_show_date_with_audio,
        nextShowDate: show.next_show_date_with_audio
      };
    } else {
      return {
        previousShowDate: show.previous_show_date,
        nextShowDate: show.next_show_date
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

          <Tracks tracks={filteredTracks} viewStyle="show" trackRefs={trackRefs} trackSlug={trackSlug} />
        </section>
      </div>
    </>
  );
};

export default Show;
