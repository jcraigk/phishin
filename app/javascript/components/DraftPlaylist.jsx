import React, { useEffect, useState } from "react";
import { useNavigate, useOutletContext } from "react-router-dom";
import LayoutWrapper from "./layout/LayoutWrapper";
import Tracks from "./Tracks";
import { formatDurationShow } from "./helpers/utils";
import { useFeedback } from "./contexts/FeedbackContext";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faExclamationCircle, faClock, faGlobe, faLock, faEdit, faShareFromSquare, faCompactDisc, faCircleCheck, faFileImport } from "@fortawesome/free-solid-svg-icons";

const DraftPlaylist = () => {
  const {
    activePlaylist,
    draftPlaylist,
    setDraftPlaylist,
    draftPlaylistMeta,
    isDraftPlaylistSaved,
    openDraftPlaylistModal,
    user
  } = useOutletContext();
  const { setNotice, setAlert } = useFeedback();
  const navigate = useNavigate();

  const { name, description, published } = draftPlaylistMeta;

  const handleEditDetails = () => {
    openDraftPlaylistModal();
  };

  const handleImportActivePlaylist = () => {
    setDraftPlaylist(activePlaylist);
  };

  // Redirect and warn if not logged in
  useEffect(() => {
    if (user === "anonymous") {
      navigate("/");
      setAlert("You must login to do that");
    }
  }, [navigate, user]);

  const isEmpty = draftPlaylist.length === 0 && !draftPlaylistMeta.name && !draftPlaylistMeta.description && !draftPlaylistMeta.slug;

  const sidebarContent = (
    <div className="sidebar-content">
      <p className="sidebar-title">Draft Playlist</p>

      {!isEmpty && (
        <div className="mt-3 mb-3 hidden-phone">
          {isDraftPlaylistSaved ? (
            <span className="badge-saved">
              <FontAwesomeIcon icon={faCircleCheck} className="mr-1" />
              Saved
            </span>
          ) : (
            <span className="badge-unsaved">
              <FontAwesomeIcon icon={faExclamationCircle} className="mr-1" />
              Unsaved changes
            </span>
          )}
        </div>
      )}

      <div className="hidden-phone">
        <FontAwesomeIcon icon={faCompactDisc} className="mr-1 text-gray" />
        {draftPlaylist.length} tracks
      </div>

      <div className="hidden-mobile">
        <FontAwesomeIcon icon={published ? faGlobe : faLock} className="mr-1 text-gray" />
        {published ? "Public" : "Private"}
      </div>

      <div className="hidden-phone">
        <FontAwesomeIcon icon={faClock} className="mr-1 text-gray" />
        {formatDurationShow(draftPlaylist.reduce((total, track) => {
          const startSecond = parseInt(track.starts_at_second) || 0;
          const endSecond = parseInt(track.ends_at_second) || 0;
          let actualDuration;

          if (startSecond > 0 && endSecond > 0) {
            actualDuration = (endSecond - startSecond) * 1000;
          } else if (startSecond > 0) {
            actualDuration = track.duration - startSecond * 1000;
          } else if (endSecond > 0) {
            actualDuration = endSecond * 1000;
          } else {
            actualDuration = track.duration;
          }

          return total + actualDuration;
        }, 0))}
      </div>

      <div className="playlist-description-container mt-3 mb-3 hidden-mobile">
        {description || "No description"}
      </div>

      {draftPlaylistMeta.id && (
        <button
          className="button hidden-phone mr-1"
          onClick={() => {
            navigator.clipboard.writeText(`https://phish.in/play/${draftPlaylistMeta.slug}`);
            setNotice("Playlist URL copied to clipboard");
          }}
        >
          <FontAwesomeIcon icon={faShareFromSquare} className="mr-1 text-gray" />
          Share
        </button>
      )}

      <button onClick={handleEditDetails} className="button">
        <FontAwesomeIcon icon={faEdit} className="mr-1 text-gray" />
        Edit
      </button>

      {activePlaylist.length > 0 && (
        <div className="hidden-mobile mt-3">
          <button onClick={handleImportActivePlaylist} className="button">
            <FontAwesomeIcon icon={faFileImport} className="mr-1 text-gray" />
            Import Active Playlist
          </button>
        </div>
      )}
    </div>
  );

  return (
    <LayoutWrapper sidebarContent={sidebarContent}>
      <h2 className="title">{name || "(Untitled Playlist)"}</h2>

      <div className="display-phone-only">
        <p>
          <FontAwesomeIcon icon={faCompactDisc} className="mr-1 text-gray" />
          Tracks: {draftPlaylistMeta.tracks_count}
        </p>
        <p className="mb-2">
          <FontAwesomeIcon icon={faClock} className="mr-1 text-gray" />
          Duration: {draftPlaylistMeta.duration ? formatDurationShow(draftPlaylistMeta.duration) : "0m"}
        </p>
      </div>

      {draftPlaylist.length < 2 && (
        <div className="notification show-info">
          <FontAwesomeIcon icon={faExclamationCircle} className="mr-1" />
          Playlists must have least 2 tracks before they can be saved or shared.
        </div>
      )}

      <Tracks tracks={draftPlaylist} viewStyle="playlist" numbering={true} omitSecondary={true} />
    </LayoutWrapper>
  );
};

export default DraftPlaylist;
