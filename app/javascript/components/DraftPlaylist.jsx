import React from "react";
import { useOutletContext } from "react-router-dom";
import LayoutWrapper from "./LayoutWrapper";
import Tracks from "./Tracks";
import { formatDurationShow } from "./utils";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faExclamationCircle, faClock, faGlobe, faLock, faEdit, faCheck } from "@fortawesome/free-solid-svg-icons";

const DraftPlaylist = () => {
  const {
    draftPlaylist,
    draftPlaylistMeta,
    openDraftPlaylistModal
  } = useOutletContext();

  const { name, description, published } = draftPlaylistMeta;

  const handleEditDetails = () => {
    openDraftPlaylistModal();
  };

  const sidebarContent = (
    <div className="sidebar-content">
      <p className="sidebar-title">
        {name || "(Untitled Playlist)"}
      </p>
      <div className="sidebar-info">
        {draftPlaylist.length} tracks
      </div>
      <div className="sidebar-extras mt-2">
        <FontAwesomeIcon icon={published ? faGlobe : faLock} className="mr-1" />
        {published ? "Public" : "Private"}
      </div>

      {draftPlaylist.length > 1 && (
        <div className="sidebar-extras mt-2">
          <FontAwesomeIcon
            icon={draftPlaylistMeta.id ? faCheck : faExclamationCircle}
            className="mr-1"
          />
          {draftPlaylistMeta.id ? "Saved" : "Unsaved"}
        </div>
      )}

      <div className="show-duration">
        <FontAwesomeIcon icon={faClock} className="mr-1" />
        {formatDurationShow(draftPlaylist.reduce((total, track) => {
          const start = track.starts_at_second || 0;
          const end = track.ends_at_second || track.duration / 1000;
          return total + (end - start);
        }, 0) * 1000)}
      </div>

      <div className="playlist-description-container mt-3 mb-3 sidebar-extras">
        {description || "No description"}
      </div>
      <button onClick={handleEditDetails} className="button">
        <FontAwesomeIcon icon={faEdit} className="mr-1" />
        Edit / Save
      </button>
    </div>
  );

  return (
    <LayoutWrapper sidebarContent={sidebarContent}>
      {draftPlaylist.length < 2 && (
        <div className="notification show-info">
          <span className="icon">
            <FontAwesomeIcon icon={faExclamationCircle} />
          </span>
          Your playlist must have least 2 tracks before you can save and share it. Add items by clicking the ellipsis menus on any content on the site and selecting "Add to Playlist."
        </div>
      )}
      <Tracks tracks={draftPlaylist} viewStyle="playlist" numbering={true} />
    </LayoutWrapper>
  );
};

export default DraftPlaylist;
