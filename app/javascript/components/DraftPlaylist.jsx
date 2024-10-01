import React, { useEffect, useState } from "react";
import { useNavigate, useOutletContext } from "react-router-dom";
import LayoutWrapper from "./layout/LayoutWrapper";
import Tracks from "./Tracks";
import { formatDurationShow } from "./helpers/utils";
import { useFeedback } from "./controls/FeedbackContext";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faExclamationCircle, faClock, faGlobe, faLock, faEdit, faShareFromSquare, faCompactDisc, faCircleCheck } from "@fortawesome/free-solid-svg-icons";

const DraftPlaylist = () => {
  const {
    draftPlaylist,
    draftPlaylistMeta,
    isDraftPlaylistSaved,
    openDraftPlaylistModal,
    user
  } = useOutletContext();
  const { setNotice, setAlert } = useFeedback();
  const navigate = useNavigate();
  const [isSaved, setIsSaved] = useState(true);

  const { name, description, published } = draftPlaylistMeta;

  const handleEditDetails = () => {
    openDraftPlaylistModal();
  };

  // Check if playlist is saved
  useEffect(() => {
    const hasUnsavedChanges = draftPlaylist.length > 0 ||
      draftPlaylistMeta.name ||
      draftPlaylistMeta.description ||
      draftPlaylistMeta.slug;

    setIsSaved(!hasUnsavedChanges);
  }, [draftPlaylist, draftPlaylistMeta]);

  // Redirect and warn if not logged in
  useEffect(() => {
    if (user === "anonymous") {
      navigate("/");
      setAlert("You must be logged in to view that page");
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
          const start = track.starts_at_second || 0;
          const end = track.ends_at_second || track.duration / 1000;
          return total + (end - start);
        }, 0) * 1000)}
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
