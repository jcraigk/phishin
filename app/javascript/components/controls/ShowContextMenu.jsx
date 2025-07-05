import React, { useRef, useState, useEffect } from "react";
import { Link, useOutletContext } from "react-router-dom";
import { formatDate, formatDurationShow, truncate } from "../helpers/utils";
import { useFeedback } from "../contexts/FeedbackContext";
import { useAudioFilter } from "../contexts/AudioFilterContext";
import LikeButton from "./LikeButton";
import TagBadges from "./TagBadges";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faEllipsis, faShareFromSquare, faExternalLinkAlt, faClipboard, faCirclePlus, faMapMarkerAlt, faLandmark, faCircleChevronLeft, faCircleChevronRight, faDownload, faClock } from "@fortawesome/free-solid-svg-icons";
import { createTaperNotesModalContent } from "../helpers/modals";

const ShowContextMenu = ({ show, adjacentLinks = true, css }) => {
  const dropdownRef = useRef(null);
  const { setNotice, setAlert } = useFeedback();
  const { openAppModal } = useOutletContext();
  const [dropdownVisible, setDropdownVisible] = useState(false);
  const { user, draftPlaylist, setDraftPlaylist, setIsDraftPlaylistSaved } = useOutletContext();
  const { showMissingAudio } = useAudioFilter();

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

  const handleTaperNotesClick = () => {
    openAppModal(createTaperNotesModalContent(show));
  };

  const toggleDropdownVisibility = (e) => {
    e.stopPropagation();
    setDropdownVisible(!dropdownVisible);
  };

  const handleAddToPlaylist = (e) => {
    if (user === "anonymous") {
      setAlert("You must login to edit playlists");
      return;
    }
    e.stopPropagation();
    setDraftPlaylist([...draftPlaylist, ...show.tracks]);
    setNotice("Show added to draft playlist");
    hideDropdown();
    setIsDraftPlaylistSaved(false);
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

  const handleRequestAlbumZip = async () => {
    const response = await fetch(`/api/v2/shows/request_album_zip`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ date: show.date })
    });

    if (response.status === 204) {
      setNotice("Album is being generated - refresh the page in ~30 seconds");
    } else if (response.status === 409) {
      setAlert("Album is already being generated");
    } else {
      setAlert("Sorry - album downloads are currently disabled");
    }
  };

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
    <div className="dropdown context-dropdown is-right" ref={dropdownRef}>
      <div className="dropdown-trigger">
        <button className="button" onClick={toggleDropdownVisibility}>
          <FontAwesomeIcon icon={faEllipsis} className="icon" />
        </button>
      </div>
      <div
        className="dropdown-menu"
        role="menu"
        style={{ display: dropdownVisible ? "block" : "none" }}
      >
        <div className={`dropdown-content context-dropdown-content ${css ? css : ""}`.trim()}>

          {show.audio_status !== 'missing' && (
            <span className="dropdown-item">
              <FontAwesomeIcon icon={faClock} className="mr-1 text-gray" />
              {formatDurationShow(show.duration)}
            </span>
          )}

          <Link
            className="dropdown-item"
            to={`/venues/${show.venue.slug}`}
            onClick={(e) => e.stopPropagation()}
          >
            <FontAwesomeIcon icon={faLandmark} className="icon" />
            {truncate(show.venue_name, 25)}
          </Link>

          <Link
            className="dropdown-item"
            to={`/map?term=${show.venue.location}`
            }
            onClick={(e) => e.stopPropagation()}
          >
            <FontAwesomeIcon icon={faMapMarkerAlt} className="icon" />
            {truncate(show.venue.location, 25)}
          </Link>

          {show.audio_status !== 'missing' && (
            <a className="dropdown-item" onClick={handleTaperNotesClick}>
              <FontAwesomeIcon icon={faClipboard} className="icon" />
              Taper Notes
            </a>
          )}

          <hr className="dropdown-divider" />

          {show.audio_status !== 'missing' && (
            <div className="dropdown-item display-phone-only">
              <LikeButton likable={show} type="Show" />
            </div>
          )}

          {show.tags?.length > 0 && (
            <div className="dropdown-item display-mobile-only">
              <TagBadges tags={show.tags} parentId={show.date} />
            </div>
          )}

          <a className="dropdown-item" onClick={(e) => copyToClipboard(e, false)}>
            <FontAwesomeIcon icon={faShareFromSquare} className="icon" />
            Share
          </a>

          {show.audio_status !== 'missing' && (
            show.album_zip_url ? (
              <a href={show.album_zip_url} className="dropdown-item" onClick={(e) => e.stopPropagation()}>
                <FontAwesomeIcon icon={faDownload} className="icon" />
                Download MP3s
              </a>
            ) : (
              <a className="dropdown-item" onClick={(e) => {
                e.stopPropagation();
                handleRequestAlbumZip(show.id, setNotice, setAlert);
              }}>
                <FontAwesomeIcon icon={faDownload} className="icon" />
                Request MP3 Download
              </a>
            )
          )}
          <a className="dropdown-item" onClick={openPhishNet}>
            <FontAwesomeIcon icon={faExternalLinkAlt} className="icon" />
            Phish.net
          </a>

          {adjacentLinks && (
            <>
              <Link
                className="dropdown-item"
                to={`/${previousShowDate}`}
                onClick={(e) => {
                  e.stopPropagation();
                  hideDropdown();
                }}
              >
                <FontAwesomeIcon icon={faCircleChevronLeft} className="icon" />
                Previous show
              </Link>
              <Link
                className="dropdown-item"
                to={`/${nextShowDate}`}
                onClick={(e) => {
                  e.stopPropagation();
                  hideDropdown();
                }}
              >
                <FontAwesomeIcon icon={faCircleChevronRight} className="icon" />
                Next show
              </Link>
            </>
          )}

          {show.audio_status !== 'missing' && (
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
