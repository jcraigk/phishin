import React, { useEffect, useState, useRef } from "react";
import { useParams, Link, useOutletContext } from "react-router-dom";
import { formatDateLong, formatDurationShow } from "./utils";
import ErrorPage from "./pages/ErrorPage";
import LayoutWrapper from "./LayoutWrapper";
import Tracks from "./Tracks";
import Modal from "react-modal";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faHeart, faCaretDown, faShare, faExternalLinkAlt, faCaretLeft, faCaretRight, faTimes } from "@fortawesome/free-solid-svg-icons";
import { useNotification } from "./NotificationContext";

Modal.setAppElement("body");

const Show = () => {
  const { route_path } = useParams();
  const [show, setShow] = useState(null);
  const [error, setError] = useState(null);
  const { setNotice } = useNotification();
  const [isDropdownActive, setIsDropdownActive] = useState(false);
  const [isTaperNotesModalOpen, setIsTaperNotesModalOpen] = useState(false); // State for Taper Notes modal
  const dropdownRef = useRef(null);
  const baseUrl = window.location.origin;
  const { playTrack, activeTrack } = useOutletContext();

  useEffect(() => {
    const fetchShow = async () => {
      try {
        const response = await fetch(`/api/v2/shows/${route_path}`);
        if (response.status === 404) {
          setError(`No data was found for the date ${route_path}`);
          return;
        }
        const data = await response.json();
        setShow(data);
      } catch (error) {
        console.error("Error fetching show:", error);
        setError("An unexpected error has occurred.");
      }
    };

    fetchShow();
  }, [route_path]);

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

  const toggleLike = async () => {
    const jwt = localStorage.getItem("jwt");
    if (!jwt) {
      console.error("Please log in to like a show");
      return;
    }

    const isLiked = show.liked_by_user;
    const url = `/api/v2/likes?likable_type=Show&likable_id=${show.id}`;
    const method = isLiked ? "DELETE" : "POST";

    try {
      const response = await fetch(url, {
        method,
        headers: {
          "Content-Type": "application/json",
          "X-Auth-Token": jwt,
        },
      });

      if (response.ok) {
        setShow((prevShow) => ({
          ...prevShow,
          liked_by_user: !isLiked,
          likes_count: isLiked ? prevShow.likes_count - 1 : prevShow.likes_count + 1,
        }));
        setNotice("Like saved");
      } else {
        console.error("Failed to toggle like");
      }
    } catch (error) {
      console.error("Error toggling like:", error);
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
          onClick={toggleLike}
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
      <Tracks tracks={show.tracks} set_headers={true} show_dates={false} playTrack={playTrack} activeTrack={activeTrack} />
    </LayoutWrapper>
  );
};

export default Show;
