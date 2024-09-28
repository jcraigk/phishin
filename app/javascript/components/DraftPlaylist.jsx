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
      <p className="sidebar-title">Draft Playlist</p>
      <div className="sidebar-info">
        {draftPlaylist.length} tracks
      </div>
      <div className="sidebar-extras mt-2">
        <FontAwesomeIcon icon={published ? faGlobe : faLock} className="mr-1" />
        {published ? "Public" : "Private"}
      </div>

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
        Edit
      </button>
    </div>
  );

  return (
    <LayoutWrapper sidebarContent={sidebarContent}>
      <h2 className="title">{name || "(Untitled Playlist)"}</h2>

      {draftPlaylist.length < 2 && (
        <div className="notification show-info">
          <span className="icon">
            <FontAwesomeIcon icon={faExclamationCircle} />
          </span>
          Playlists must have least 2 tracks before they can be saved or shared.
        </div>
      )}

      <Tracks tracks={draftPlaylist} viewStyle="playlist" numbering={true} omitSecondary={true} />
    </LayoutWrapper>
  );
};

export default DraftPlaylist;
