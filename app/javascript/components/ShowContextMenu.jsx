import React, { useRef, useState, useEffect } from "react";
import { Link, useOutletContext } from "react-router-dom";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faEllipsis, faShareFromSquare, faExternalLinkAlt, faClipboard, faCirclePlus, faMapMarkerAlt, faLandmark, faCircleChevronLeft, faCircleChevronRight } from "@fortawesome/free-solid-svg-icons";
import { useFeedback } from "./FeedbackContext";

const ShowContextMenu = ({ show, adjacentLinks = true, isLeft = false }) => {
  const dropdownRef = useRef(null);
  const { setNotice, setAlert } = useFeedback();
  const { activeTrack, currentTime, openModal } = useOutletContext(); // Use openModal from context
  const [dropdownVisible, setDropdownVisible] = useState(false);

  const hideDropdown = () => {
    setDropdownVisible(false);
  };

  const copyToClipboard = (e, includeTimestamp = false) => {
    e.stopPropagation();

    let url;
    if (includeTimestamp && activeTrack?.show_date === show.date) {
      const timestamp = `${Math.floor(currentTime / 60)}:${String(Math.floor(currentTime % 60)).padStart(2, "0")}`;
      url = `https://phish.in/${activeTrack.show_date}/${activeTrack.slug}?t=${timestamp}`;
    } else {
      url = `https://phish.in/${show.date}`;
    }
    navigator.clipboard.writeText(url);
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

    // Define modal content dynamically
    const modalContent = (
      <>
        <h2 className="title mb-5">Taper Notes for {show.date}</h2>
        <p dangerouslySetInnerHTML={{ __html: (show.taper_notes || "").replace(/\n/g, "<br />") }}></p>
      </>
    );

    // Use openModal to show the content
    openModal(modalContent);
    hideDropdown();
  };

  const toggleDropdownVisibility = (e) => {
    e.stopPropagation();
    setDropdownVisible(!dropdownVisible);
  };

  const handleAddToPlaylist = () => {
    setAlert("Sorry, that's under construction! Try again next month :)");
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
        <div className="dropdown-content context-dropdown-content">
          <a className="dropdown-item" onClick={(e) => copyToClipboard(e, false)}>
            <span className="icon">
              <FontAwesomeIcon icon={faShareFromSquare} />
            </span>
            Share
          </a>

          {activeTrack?.show_date === show.date && (
            <a className="dropdown-item" onClick={(e) => copyToClipboard(e, true)}>
              <span className="icon">
                <FontAwesomeIcon icon={faShareFromSquare} />
              </span>
              Share with timestamp
            </a>
          )}

          <a className="dropdown-item" onClick={openPhishNet}>
            <span className="icon">
              <FontAwesomeIcon icon={faExternalLinkAlt} />
            </span>
            Phish.net
          </a>

          <hr className="dropdown-divider" />

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


          {adjacentLinks && (
            <>
              <hr className="dropdown-divider" />

              <Link className="dropdown-item" to={`/${show.previous_show_date}`}>
              <span className="icon">
                <FontAwesomeIcon icon={faCircleChevronLeft} />
              </span>
              Previous show
            </Link>
            <Link className="dropdown-item" to={`/${show.next_show_date}`}>
              <span className="icon">
                <FontAwesomeIcon icon={faCircleChevronRight} />
              </span>
              Next show
            </Link>
          </>
          )}

          <hr className="dropdown-divider" />

          <a className="dropdown-item" onClick={handleAddToPlaylist}>
            <span className="icon">
              <FontAwesomeIcon icon={faCirclePlus} />
            </span>
            <span>Add to playlist</span>
          </a>
        </div>
      </div>
    </div>
  );
};

export default ShowContextMenu;
