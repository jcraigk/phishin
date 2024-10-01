import React, { useEffect } from "react";
import { useNavigate, useOutletContext } from "react-router-dom";
import LayoutWrapper from "./layout/LayoutWrapper";
import Tracks from "./Tracks";
import { formatDurationShow } from "./helpers/utils";
import { useFeedback } from "./controls/FeedbackContext";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faExclamationCircle, faClock, faGlobe, faLock, faEdit, faShareFromSquare, faCompactDisc } from "@fortawesome/free-solid-svg-icons";

const DraftPlaylist = () => {
  const {
    draftPlaylist,
    draftPlaylistMeta,
    openDraftPlaylistModal,
    user
  } = useOutletContext();
  const { setNotice, setAlert } = useFeedback();
  const navigate = useNavigate();

  const { name, description, published } = draftPlaylistMeta;

  const handleEditDetails = () => {
    openDraftPlaylistModal();
  };

  // Redirect and warn if not logged in
  useEffect(() => {
    if (user === "anonymous") {
      navigate("/");
      setAlert("You must be logged in to view that page");
    }
  }, [navigate, user]);

  const sidebarContent = (
    <div className="sidebar-content">
      <p className="sidebar-title">Draft Playlist</p>
      <div className="sidebar-info hidden-phone">
        {draftPlaylist.length} tracks
      </div>
      <div className="hidden-mobile mt-2">
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
          className="button mr-1"
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
