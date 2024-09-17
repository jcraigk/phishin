import { authFetch } from "./utils";

export const showLoader = async ({ params, request }) => {
  const { date } = params;
  const url = `/api/v2/shows/${date}`;
  try {
    const response = await authFetch(url);
    if (response.status === 404) {
      throw new Response("Show not found", { status: 404 });
    }
    const data = await response.json();
    const baseUrl = new URL(request.url).origin;
    return { show: data, baseUrl };
  } catch (error) {
    if (error instanceof Response) throw error;
    throw new Response("Error fetching data", { status: 500 });
  }
};


import React, { useState, useRef, useEffect } from "react";
import { Link, useLoaderData, useOutletContext } from "react-router-dom";
import { formatDate, formatDateMed, formatDateLong, formatDurationShow, toggleLike } from "./utils";
import LayoutWrapper from "./LayoutWrapper";
import Tracks from "./Tracks";
import Modal from "react-modal";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faHeart, faCaretDown, faShare, faExternalLinkAlt, faCaretLeft, faCaretRight, faTimes } from "@fortawesome/free-solid-svg-icons";
import { useNotification } from "./NotificationContext";
import { Helmet } from 'react-helmet-async';

Modal.setAppElement("body");

const Show = ({ trackSlug }) => {
  const { show, baseUrl } = useLoaderData();
  const [tracks, setTracks] = useState(show.tracks);
  const trackRefs = useRef([]);
  const { setNotice, setAlert } = useNotification();
  const [isDropdownActive, setIsDropdownActive] = useState(false);
  const [isTaperNotesModalOpen, setIsTaperNotesModalOpen] = useState(false);
  const dropdownRef = useRef(null);
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

  const handleLikeToggle = async () => {
    const jwt = localStorage.getItem("jwt");
    if (!jwt) {
      setAlert("Please login to like a show");
      return;
    }

    const result = await toggleLike({
      id: show.id,
      type: "Show",
      isLiked: show.liked_by_user,
      jwt,
    });

    if (result.success) {
      setShow((prevShow) => ({
        ...prevShow,
        liked_by_user: result.isLiked,
        likes_count: result.isLiked ? prevShow.likes_count + 1 : prevShow.likes_count - 1,
      }));
      setNotice("Like saved");
    } else {
      console.error("Failed to toggle like");
    }
  };

  const copyToClipboard = () => {
    const showUrl = `${baseUrl}/${show.date}`;
    navigator.clipboard.writeText(showUrl);
    setNotice("URL of show copied to clipboard");
  };

  const openPhishNet = () => {
    const phishNetUrl = `https://phish.net/setlists/?d=${show.date}`;
    window.open(phishNetUrl, "_blank");
  };

  const toggleDropdown = () => {
    setIsDropdownActive(!isDropdownActive);
  };

  const openTaperNotesModal = () => {
    setIsTaperNotesModalOpen(true);
  };

  const closeTaperNotesModal = () => {
    setIsTaperNotesModalOpen(false);
  };

  const sidebarContent = (
    <>
      <Helmet>
        <title>{matchedTrack ? `${matchedTrack.title} - ${formatDate(show.date)} - Phish.in` : `${formatDate(show.date)} - Phish.in`}</title>
        <meta property="og:title" content={trackSlug && matchedTrack ? `Listen to ${matchedTrack.title} from ${formatDateLong(show.date)}` : `Listen to ${formatDateLong(show.date)}`} />
        <meta property="og:type" content="music.playlist" />
        <meta property="og:audio" content={matchedTrack?.mp3_url} />
      </Helmet>
      <div className="sidebar-content">
        <p className="show-date">{formatDateMed(show.date)}</p>
        <p className="show-venue">
          <Link to={`/venues/${show.venue.slug}`} className="show-venue">{show.venue.name}</Link>
        </p>
        <p className="show-location">
          <Link to={`/map?term=${encodeURIComponent(show.venue.location)}&distance=50`} className="show-location">{show.venue.location}</Link>
        </p>
        <p className="show-duration">
          {formatDurationShow(show.duration)} • <span className="taper-notes" onClick={openTaperNotesModal}>Taper Notes</span>
        </p>
        <hr />
        <div className="like-button mb-2">
          <FontAwesomeIcon
            icon={faHeart}
            className={`heart-icon ${show.liked_by_user ? "liked" : ""}`}
            onClick={handleLikeToggle}
          />{" "}
          {show.likes_count}
        </div>
        <div ref={dropdownRef} className={`dropdown is-right ${isDropdownActive ? "is-active" : ""}`} style={{ width: "100%" }}>
          <div className="dropdown-trigger">
            <button className="button" onClick={toggleDropdown} aria-haspopup="true" aria-controls="dropdown-menu">
              <span className="icon is-small">
                <FontAwesomeIcon icon={faCaretDown} />
              </span>
            </button>
          </div>
          <div className="dropdown-menu" id="dropdown-menu" role="menu">
            <div className="dropdown-content">
              <a className="dropdown-item" onClick={copyToClipboard}>
                <span className="icon">
                  <FontAwesomeIcon icon={faShare} />
                </span>
                <span>Share</span>
              </a>
              <a className="dropdown-item" onClick={openPhishNet}>
                <span className="icon">
                  <FontAwesomeIcon icon={faExternalLinkAlt} />
                </span>
                <span>Lookup at phish.net</span>
              </a>
            </div>
          </div>
        </div>
        <hr />
        <Link to={`/${show.previous_show_date}`} className="previous-show">
          <FontAwesomeIcon icon={faCaretLeft} style={{ marginRight: "5px" }} />
          Previous show
        </Link>
        <Link to={`/${show.next_show_date}`} className="next-show" style={{ float: "right" }}>
          Next show
          <FontAwesomeIcon icon={faCaretRight} style={{ marginLeft: "5px" }} />
        </Link>

        <Modal
          isOpen={isTaperNotesModalOpen}
          onRequestClose={closeTaperNotesModal}
          contentLabel="Taper Notes"
          className="modal-content"
          overlayClassName="modal-overlay"
        >
          <button onClick={closeTaperNotesModal} className="button is-pulled-right">
            <FontAwesomeIcon icon={faTimes} />
          </button>
          <h2 className="title mb-2">Taper Notes</h2>
          <p dangerouslySetInnerHTML={{ __html: show.taper_notes.replace(/\n/g, "<br />") }}></p>
        </Modal>
      </div>
    </>
  );

  return (
    <LayoutWrapper sidebarContent={sidebarContent}>
      <Tracks tracks={tracks} setTracks={setTracks} showView={true} trackRefs={trackRefs} />
    </LayoutWrapper>
  );
};

export default Show;
