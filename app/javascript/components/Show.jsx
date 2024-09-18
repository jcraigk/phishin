import { authFetch, baseUrl } from "./utils";

export const showLoader = async ({ params, request }) => {
  const { date } = params;
  const url = `/api/v2/shows/${date}`;
  try {
    const response = await authFetch(url);
    if (response.status === 404) {
      throw new Response("Show not found", { status: 404 });
    }
    return await response.json();
  } catch (error) {
    if (error instanceof Response) throw error;
    throw new Response("Error fetching data", { status: 500 });
  }
};

import React, { useState, useRef, useEffect } from "react";
import { Link, useLoaderData, useOutletContext } from "react-router-dom";
import { formatDate, formatDateMed, formatDateLong, formatDurationShow } from "./utils";
import LayoutWrapper from "./LayoutWrapper";
import ShowContextMenu from "./ShowContextMenu";
import LikeButton from "./LikeButton";
import Tracks from "./Tracks";
import Modal from "react-modal";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faAnglesLeft, faAnglesRight, faCircleXmark, faInfoCircle } from "@fortawesome/free-solid-svg-icons";
import { Helmet } from 'react-helmet-async';

Modal.setAppElement("body");

const Show = ({ trackSlug }) => {
  const show = useLoaderData();
  const [tracks, setTracks] = useState(show.tracks);
  const trackRefs = useRef([]);
  const [isTaperNotesModalOpen, setIsTaperNotesModalOpen] = useState(false);
  const { playTrack } = useOutletContext();
  const [matchedTrack, setMatchedTrack] = useState(tracks[0]);

  useEffect(() => {
    let foundTrack;
    if (trackSlug) foundTrack = tracks.find((track) => track.slug === trackSlug);
    if (!foundTrack) foundTrack = tracks[0];
    if (foundTrack) {
      playTrack(tracks, foundTrack, true);
      setMatchedTrack(foundTrack);
      // Scroll to the matched track
      const trackIndex = tracks.findIndex((track) => track.slug === foundTrack.slug);
      if (trackRefs.current[trackIndex]) {
        trackRefs.current[trackIndex].scrollIntoView({ behavior: "smooth", block: "center" });
      }
    }
  }, [trackSlug, tracks]);

  const openTaperNotesModal = () => {
    setIsTaperNotesModalOpen(true);
  };

  const closeTaperNotesModal = () => {
    setIsTaperNotesModalOpen(false);
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
      <p className="sidebar-info">
        {formatDurationShow(show.duration)}
      </p>

      <hr />

      <div className="sidebar-control-wrapper">
        <LikeButton likable={show} />
        <ShowContextMenu show={show} openTaperNotesModal={openTaperNotesModal} />
      </div>

      <div className="sidebar-extras">
        <hr />
        <Link to={`/${show.previous_show_date}`}>
          <FontAwesomeIcon icon={faAnglesLeft} style={{ marginRight: "5px" }} />
          Previous show
        </Link>
        <Link to={`/${show.next_show_date}`} className="is-pulled-right">
          Next show
          <FontAwesomeIcon icon={faAnglesRight} style={{ marginLeft: "5px" }} />
        </Link>
      </div>
    </div>
  );

  const infoBox = (message) => (
    <div className="notification show-info">
      <span className="icon">
        <FontAwesomeIcon icon={faInfoCircle} />
      </span>
      {message}
    </div>
  );

  return (
    <>
      <Modal
        isOpen={isTaperNotesModalOpen}
        onRequestClose={closeTaperNotesModal}
        contentLabel="Taper Notes"
        className="modal-content"
        overlayClassName="modal-overlay"
      >
        <FontAwesomeIcon
          icon={faCircleXmark}
          onClick={closeTaperNotesModal}
          className="is-pulled-right close-btn is-size-3"
          style={{ cursor: "pointer" }}
        />
        <h2 className="title mb-5">Taper Notes</h2>
        <p dangerouslySetInnerHTML={{ __html: show.taper_notes.replace(/\n/g, "<br />") }}></p>
      </Modal>
      <Helmet>
        <title>{matchedTrack ? `${matchedTrack.title} - ${formatDate(show.date)} - Phish.in` : `${formatDate(show.date)} - Phish.in`}</title>
        <meta property="og:title" content={trackSlug && matchedTrack ? `Listen to ${matchedTrack.title} from ${formatDateLong(show.date)}` : `Listen to ${formatDateLong(show.date)}`} />
        <meta property="og:type" content="music.playlist" />
        <meta property="og:audio" content={matchedTrack?.mp3_url} />
      </Helmet>
      <LayoutWrapper sidebarContent={sidebarContent}>
        {show.incomplete && infoBox("This show's audio is incomplete")}
        {show.admin_notes && infoBox(show.admin_notes)}
        <Tracks tracks={tracks} setTracks={setTracks} showView={true} trackRefs={trackRefs} trackSlug={trackSlug} />
      </LayoutWrapper>
    </>
  );
};

export default Show;
