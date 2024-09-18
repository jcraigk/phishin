import React, { useRef, useState, useEffect } from "react";
import { Link } from "react-router-dom";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faEllipsis, faShare, faExternalLinkAlt, faClipboard, faCirclePlus, faMapMarkerAlt, faLandmark, faAnglesLeft, faAnglesRight } from "@fortawesome/free-solid-svg-icons";
import { baseUrl } from "./utils";
import { useFeedback } from "./FeedbackContext";

const ShowContextMenu = ({ show, openTaperNotesModal }) => {
  const dropdownRef = useRef(null);
  const { setNotice, setAlert } = useFeedback();
  const [dropdownVisible, setDropdownVisible] = useState(false);

  const hideDropdown = () => {
    setDropdownVisible(false);
  };

  const copyToClipboard = () => {
    const showUrl = `${baseUrl(location)}/${show.date}`;
    navigator.clipboard.writeText(showUrl);
    setNotice("URL of show copied to clipboard");
    hideDropdown();
  };

  const openPhishNet = () => {
    const phishNetUrl = `https://phish.net/setlists/?d=${show.date}`;
    window.open(phishNetUrl, "_blank");
    hideDropdown();
  };

  const handleTaperNotesClick = () => {
    openTaperNotesModal();
    hideDropdown();
  };

  const toggleDropdownVisibility = () => {
    setDropdownVisible(!dropdownVisible);
  };

  const handleAddToPlaylist = () => {
    setAlert("Sorry, that's under construction! Try again next week :)");
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
    <div className="dropdown is-right" ref={dropdownRef}>
      <div className="dropdown-trigger">
        <button className="button" onClick={toggleDropdownVisibility}>
          <span className="icon is-small">
            <FontAwesomeIcon icon={faEllipsis} />
          </span>
        </button>
      </div>
      <div
        className="dropdown-menu"
        id="dropdown-menu"
        role="menu"
        style={{ display: dropdownVisible ? "block" : "none" }}
      >
        <div className="dropdown-content show-context-dropdown">
          <a className="dropdown-item" onClick={handleTaperNotesClick}>
            <span className="icon">
              <FontAwesomeIcon icon={faClipboard} />
            </span>
            Taper Notes
          </a>
          <Link className="dropdown-item" to={`/venues/${show.venue.slug}`}>
            <span className="icon">
              <FontAwesomeIcon icon={faLandmark} />
            </span>
            {show.venue_name}
          </Link>
          <Link className="dropdown-item" to={`/map?term=${show.venue.location}`}>
            <span className="icon">
              <FontAwesomeIcon icon={faMapMarkerAlt} />
            </span>
            {show.venue.location}
          </Link>
          <a className="dropdown-item" onClick={copyToClipboard}>
            <span className="icon">
              <FontAwesomeIcon icon={faShare} />
            </span>
            Share
          </a>
          <a className="dropdown-item" onClick={openPhishNet}>
            <span className="icon">
              <FontAwesomeIcon icon={faExternalLinkAlt} />
            </span>
            Phish.net
          </a>

          <Link className="dropdown-item" to={`/${show.previous_show_date}`}>
            <span className="icon">
              <FontAwesomeIcon icon={faAnglesLeft} />
            </span>
            Previous show
          </Link>
          <Link className="dropdown-item" to={`/${show.next_show_date}`}>
            <span className="icon">
              <FontAwesomeIcon icon={faAnglesRight} />
            </span>
            Next show
          </Link>
          <a className="dropdown-item" onClick={handleAddToPlaylist}>
            <span className="icon">
              <FontAwesomeIcon icon={faCirclePlus} />
            </span>
            <span>Add to Playlist</span>
          </a>
        </div>
      </div>
    </div>
  );
};

export default ShowContextMenu;
