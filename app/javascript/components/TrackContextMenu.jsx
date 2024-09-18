import React, { useRef, useState, useEffect } from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faEllipsis, faShareFromSquare, faCirclePlus, faDownload, faMusic, faCircleChevronLeft, faCircleChevronRight } from "@fortawesome/free-solid-svg-icons";
import { baseUrl } from "./utils";
import { useFeedback } from "./FeedbackContext";
import { useOutletContext, Link } from "react-router-dom";

const TrackContextMenu = ({ track }) => {
  const dropdownRef = useRef(null);
  const { setNotice, setAlert } = useFeedback();
  const [dropdownVisible, setDropdownVisible] = useState(false);
  const { activeTrack, currentTime } = useOutletContext();

  const hideDropdown = () => {
    setDropdownVisible(false);
  };

  const share = (e, include_timestamp = false) => {
    e.stopPropagation();
    let url = `${baseUrl(location)}/${track.show_date}/${track.slug}`;
    if (include_timestamp && activeTrack?.id === track.id) {
      const minutes = Math.floor(currentTime / 60);
      const seconds = Math.floor(currentTime % 60).toString().padStart(2, "0");
      const timestamp = `${minutes}:${seconds}`;
      url += `?t=${timestamp}`;
    }
    navigator.clipboard.writeText(url);
    setNotice("URL copied to clipboard");
    hideDropdown();
  };

  const useEffect = () => {
    console.log(track);
  };

  const toggleDropdownVisibility = (e) => {
    e.stopPropagation();
    setDropdownVisible(!dropdownVisible);
  };

  const handleAddToPlaylist = (e) => {
    e.stopPropagation();
    setAlert("Sorry, that's under construction! Try again next month :)");
    hideDropdown();
  };

  const handleDownload = (e, trackId) => {
    e.stopPropagation();
    const link = document.createElement("a");
    link.href = `/download-track/${trackId}`;  // Use the Rails route
    link.setAttribute("download", true);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);  // Cleanup the element
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
          <a className="dropdown-item" onClick={(e) => share(e, false)}>
            <span className="icon">
              <FontAwesomeIcon icon={faShareFromSquare} />
            </span>
            Share
          </a>

          {activeTrack?.id === track.id && (
            <a className="dropdown-item" onClick={(e) => share(e, true)}>
              <span className="icon">
                <FontAwesomeIcon icon={faShareFromSquare} />
              </span>
              Share with Timestamp
            </a>
          )}

          <a
            className="dropdown-item"
            onClick={(e) => handleDownload(e, track.id)}
          >
            <span className="icon">
              <FontAwesomeIcon icon={faDownload} />
            </span>
            Download MP3
          </a>

          {track.songs?.sort((a, b) => a.title.localeCompare(b.title)).map((song) => (
            <div key={song.id}>
              <hr className="dropdown-divider" />

              <Link
                className="dropdown-item"
                to={`/songs/${song.slug}`}
              >
                <span className="icon">
                  <FontAwesomeIcon icon={faMusic} />
                </span>
                Song: {song.title}
              </Link>

              {song.previous_performance_gap != null && song.previous_performance_gap > 0 && (
                <Link
                  className="dropdown-item"
                  to={`/${song.previous_performance_slug}`}
                >
                  <span className="icon">
                    <FontAwesomeIcon icon={faCircleChevronLeft} />
                  </span>
                  Previous Performance (gap: {song.previous_performance_gap})
                </Link>
              )}

              {song.next_performance_gap != null && song.next_performance_gap > 0 && (
                <Link
                  className="dropdown-item"
                  to={`/${song.next_performance_slug}`}
                >
                  <span className="icon">
                    <FontAwesomeIcon icon={faCircleChevronRight} />
                  </span>
                  Next Performance (gap: {song.next_performance_gap})
                </Link>
              )}

            </div>
          ))}

          <hr className="dropdown-divider" />

          <a className="dropdown-item" onClick={handleAddToPlaylist}>
            <span className="icon">
              <FontAwesomeIcon icon={faCirclePlus} />
            </span>
            Add to Playlist
          </a>
        </div>
      </div>
    </div>
  );
};

export default TrackContextMenu;