import React, { useRef, useState, useEffect } from "react";
import { Link, useOutletContext } from "react-router-dom";
import { formatDate, formatDurationShow, truncate } from "../helpers/utils";
import { useFeedback } from "./FeedbackContext";
import LikeButton from "./LikeButton";
import TagBadges from "./TagBadges";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faEllipsis, faShareFromSquare, faExternalLinkAlt, faClipboard, faCirclePlus, faMapMarkerAlt, faLandmark, faCircleChevronLeft, faCircleChevronRight, faDownload, faClock } from "@fortawesome/free-solid-svg-icons";

const ShowContextMenu = ({ show, adjacentLinks = true, css }) => {
  const dropdownRef = useRef(null);
  const { setNotice, setAlert } = useFeedback();
  const { openAppModal } = useOutletContext();
  const [dropdownVisible, setDropdownVisible] = useState(false);
  const { user, draftPlaylist, setDraftPlaylist, setIsDraftPlaylistSaved } = useOutletContext();

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
        <h3 className="subtitle">{formatDate(show.date)} &bull; {show.venue_name}</h3>
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

  return (
    <div className="dropdown context-dropdown is-right" ref={dropdownRef}>
      <div className="dropdown-trigger">
        <button className="button" onClick={toggleDropdownVisibility}>
          <FontAwesomeIcon icon={faEllipsis} className="icon" />
        </button>
      </div>
      <div
        className="dropdown-menu"
        id="dropdown-menu"
        role="menu"
        style={{ display: dropdownVisible ? "block" : "none" }}
      >
        <div className={`dropdown-content context-dropdown-content ${css ? css : ""}`.trim()}>

          <span className="dropdown-item">
            <FontAwesomeIcon icon={faClock} className="mr-1 text-gray" />
            {formatDurationShow(show.duration)}
            </span>

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

          <a className="dropdown-item" onClick={handleTaperNotesClick}>
            <FontAwesomeIcon icon={faClipboard} className="icon" />
            Taper Notes
          </a>

          <hr className="dropdown-divider" />

          <div className="dropdown-item display-phone-only">
            <LikeButton likable={show} type="Show" />
          </div>

          {show.tags?.length > 0 && (
            <div className="dropdown-item display-phone-only">
              <TagBadges tags={show.tags} parentId={show.date} />
            </div>
          )}

          <a className="dropdown-item" onClick={(e) => copyToClipboard(e, false)}>
            <FontAwesomeIcon icon={faShareFromSquare} className="icon" />
            Share
          </a>

          {show.album_zip_url ? (
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
          )}
          <a className="dropdown-item" onClick={openPhishNet}>
            <FontAwesomeIcon icon={faExternalLinkAlt} className="icon" />
            Phish.net
          </a>

          {adjacentLinks && (
            <>
              <Link
                className="dropdown-item"
                to={`/${show.previous_show_date}`}
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
                to={`/${show.next_show_date}`}
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

          <hr className="dropdown-divider" />
          <a className="dropdown-item" onClick={handleAddToPlaylist}>
            <FontAwesomeIcon icon={faCirclePlus} className="icon" />
            Add to playlist
          </a>
        </div>
      </div>
    </div>
  );
};

export default ShowContextMenu;
