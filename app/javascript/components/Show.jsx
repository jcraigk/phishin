import React, { useEffect, useState, useRef } from "react";
import { useParams, Link } from "react-router-dom";
import { formatDateLong, formatDurationShow, toggleLike, authFetch } from "./utils";
import ErrorPage from "./pages/ErrorPage";
import LayoutWrapper from "./LayoutWrapper";
import Tracks from "./Tracks";
import Modal from "react-modal";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faHeart, faCaretDown, faShare, faExternalLinkAlt, faCaretLeft, faCaretRight, faTimes } from "@fortawesome/free-solid-svg-icons";
import { useNotification } from "./NotificationContext";
import { Helmet } from 'react-helmet-async';

Modal.setAppElement("body");

const Show = () => {
  const { routePath } = useParams();
  const [show, setShow] = useState(null);
  const [tracks, setTracks] = useState([]);
  const [error, setError] = useState(null);
  const { setNotice, setAlert } = useNotification();
  const [isDropdownActive, setIsDropdownActive] = useState(false);
  const [isTaperNotesModalOpen, setIsTaperNotesModalOpen] = useState(false);
  const dropdownRef = useRef(null);
  const baseUrl = window.location.origin;

  useEffect(() => {
    const fetchShow = async () => {
      try {
        const response = await authFetch(`/api/v2/shows/${routePath}`);
        if (response.status === 404) {
          setError(`No data was found for the date ${routePath}`);
          return;
        }
        const data = await response.json();
        setShow(data);
        setTracks(data.tracks); // Set the tracks when fetching show data
      } catch (error) {
        console.error("Error fetching show:", error);
        setError("An unexpected error has occurred.");
      }
    };

    fetchShow();
  }, [routePath]);

  useEffect(() => {
    const handleClickOutside = (event) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target)) {
        setIsDropdownActive(false);
      }
    };

    document.addEventListener("mousedown", handleClickOutside);
    return () => {
      document.removeEventListener("mousedown", handleClickOutside);
    };
  }, [dropdownRef]);

  if (error) {
    return <ErrorPage message={error} />;
  }

  if (!show) {
    return <div>Loading...</div>;
  }

  const handleLikeToggle = async () => {
    const jwt = localStorage.getItem("jwt");
    if (!jwt) {
      setAlert("Please log in to like a show");
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
    <div className="sidebar-content">
      <p className="show-date">{formatDateLong(show.date)}</p>
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
  );

  return (

    <LayoutWrapper sidebarContent={sidebarContent}>
      <Tracks tracks={tracks} setTracks={setTracks} showDates={false} setHeaders={true} />
    </LayoutWrapper>
  );
};

export default Show;
