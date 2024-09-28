import React, { useRef, useState, useEffect } from "react";
import { Link, useOutletContext } from "react-router-dom";
import { formatDate } from "./utils";
import { useFeedback } from "./FeedbackContext";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faEllipsis, faShareFromSquare, faExternalLinkAlt, faClipboard, faCirclePlus, faMapMarkerAlt, faLandmark, faCircleChevronLeft, faCircleChevronRight } from "@fortawesome/free-solid-svg-icons";

const ShowContextMenu = ({ show, adjacentLinks = true, isLeft = false }) => {
  const dropdownRef = useRef(null);
  const { setNotice, setAlert } = useFeedback();
  const { openAppModal } = useOutletContext();
  const [dropdownVisible, setDropdownVisible] = useState(false);
  const { user, draftPlaylist, setDraftPlaylist } = useOutletContext();

  const hideDropdown = () => {
    setDropdownVisible(false);
  };

  const copyToClipboard = (e) => {
    e.stopPropagation();
    navigator.clipboard.writeText(`https://phish.in/${show.date}`);
    setNotice("URL copied to clipboard");
    hideDropdown();
  };

  const openPhishNet = (e) => {
    e.stopPropagation();
    const phishNetUrl = `https://phish.net/setlists/?d=${show.date}`;
    window.open(phishNetUrl, "_blank");
    hideDropdown();
  };

  const handleTaperNotesClick = (e) => {
    e.stopPropagation();
    const modalContent = (
      <>
        <h2 className="title">Taper Notes</h2>
        <h3 className="subtitle">{formatDate(show.date)} &bull; {formatDate(show.venue_name)}</h3>
        <p dangerouslySetInnerHTML={{ __html: (show.taper_notes || "").replace(/\n/g, "<br />") }}></p>
      </>
    );
    openAppModal(modalContent);
    hideDropdown();
  };

  const toggleDropdownVisibility = (e) => {
    e.stopPropagation();
    setDropdownVisible(!dropdownVisible);
  };

  const handleAddToPlaylist = (e) => {
    if (!user) {
      setAlert("You must login to edit playlists");
      return;
    }
    e.stopPropagation();
    setDraftPlaylist([...draftPlaylist, ...show.tracks]);
    setNotice("Show added to draft playlist");
    hideDropdown();
  };

  // Close dropdown when clicking outside
  useEffect(() => {
    const handleClickOutside = (event) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target)) {
        hideDropdown();
      }
    };

    document.addEventListener("mousedown", handleClickOutside);
    return () => {
      document.removeEventListener("mousedown", handleClickOutside);
    };
  }, [dropdownRef]);

  return (
    <div className={`dropdown context-dropdown is-${isLeft ? "left" : "right"}`} ref={dropdownRef}>
      <div className="dropdown-trigger">
        <button className="button" onClick={toggleDropdownVisibility}>
          <FontAwesomeIcon icon={faEllipsis} className="icon is-small" />
        </button>
      </div>
      <div
        className="dropdown-menu"
        id="dropdown-menu"
        role="menu"
        style={{ display: dropdownVisible ? "block" : "none" }}
      >
        <div className="dropdown-content context-dropdown-content">
          <a className="dropdown-item" onClick={(e) => copyToClipboard(e, false)}>
            <FontAwesomeIcon icon={faShareFromSquare} className="icon" />
            Share
          </a>

          <a className="dropdown-item" onClick={openPhishNet}>
            <FontAwesomeIcon icon={faExternalLinkAlt} className="icon" />
            Phish.net
          </a>

          <hr className="dropdown-divider" />

          <a className="dropdown-item" onClick={handleTaperNotesClick}>
            <FontAwesomeIcon icon={faClipboard} className="icon" />
            Taper Notes
          </a>

          <Link className="dropdown-item" to={`/venues/${show.venue.slug}`}>
            <FontAwesomeIcon icon={faLandmark} className="icon" />
            {show.venue_name}
          </Link>

          <Link className="dropdown-item" to={`/map?term=${show.venue.location}`}>
            <FontAwesomeIcon icon={faMapMarkerAlt} className="icon" />
            {show.venue.location}
          </Link>


          {adjacentLinks && (
            <>
              <hr className="dropdown-divider" />

              <Link className="dropdown-item" to={`/${show.previous_show_date}`}>
                <FontAwesomeIcon icon={faCircleChevronLeft} className="icon" />
                Previous show
              </Link>
              <Link className="dropdown-item" to={`/${show.next_show_date}`}>
                <FontAwesomeIcon icon={faCircleChevronRight} className="icon" />
                Next show
              </Link>
            </>
          )}

          {show.tracks?.length > 0 && (
            <>
              <hr className="dropdown-divider" />
              <a className="dropdown-item" onClick={handleAddToPlaylist}>
                <FontAwesomeIcon icon={faCirclePlus} className="icon" />
                Add to playlist
              </a>
            </>
          )}
        </div>
      </div>
    </div>
  );
};

export default ShowContextMenu;
