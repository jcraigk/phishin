import React, { useEffect } from "react";
import { useNavigate, useOutletContext } from "react-router-dom";
import LayoutWrapper from "./LayoutWrapper";
import Tracks from "./Tracks";
import { formatDurationShow } from "./utils";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faExclamationCircle, faClock, faGlobe, faLock } from "@fortawesome/free-solid-svg-icons";

const DraftPlaylist = () => {
  const {
    draftPlaylist,
    setDraftPlaylist,
    draftPlaylistMeta, // Use metadata object
    setDraftPlaylistMeta, // Use metadata setter
    user,
    setCustomPlaylist,
    setNotice,
    setAlert,
    openDraftPlaylistModal // Open the DraftPlaylistModal
  } = useOutletContext();
  const navigate = useNavigate();

  const { name, slug, description, published } = draftPlaylistMeta; // Destructure metadata

  useEffect(() => {
    if (draftPlaylistMeta.name !== "(Untitled Playlist)") {
      setDraftPlaylistMeta(draftPlaylistMeta);
    }
  }, [draftPlaylistMeta]);

  const handleSavePlaylist = async () => {
    if (draftPlaylist.length < 2) {
      setAlert("Please add at least 2 tracks to save the playlist.");
      return;
    }

    const url = draftPlaylist.id
      ? `/api/v2/playlists/${draftPlaylist.id}`
      : "/api/v2/playlists";
    const method = draftPlaylist.id ? "PUT" : "POST";

    try {
      const response = await authFetch(url, {
        method,
        body: JSON.stringify({
          ...draftPlaylistMeta, // Use metadata directly here
          track_ids: draftPlaylist.map((track) => track.id),
          starts_at_seconds: draftPlaylist.map((track) => track.starts_at_second || 0),
          ends_at_seconds: draftPlaylist.map((track) => track.ends_at_second || track.duration),
        }),
      });

      if (!response.ok) throw new Error("Failed to save playlist");

      const updatedPlaylist = await response.json();
      setCustomPlaylist(updatedPlaylist);
      setDraftPlaylist([]);
      setNotice(`Playlist "${name}" saved successfully`);
      navigate(`/play/${updatedPlaylist.slug}`);
    } catch (error) {
      setAlert("Error saving playlist");
    }
  };

  // Open the DraftPlaylistModal
  const handleEditDetails = () => {
    openDraftPlaylistModal();
  };

  const sidebarContent = (
    <div className="sidebar-content">
      <h1 className="sidebar-title">{name}</h1>
      <div className="sidebar-info">
        <div className="sidebar-extras" style={{ overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
          {description || "(No description)"}
        </div>
        <div className="sidebar-extras mt-2">
          <FontAwesomeIcon icon={published ? faGlobe : faLock} className="mr-1" />
          {published ? "Public" : "Private"}
        </div>
      </div>
      <div className="show-duration mt-3">
        <FontAwesomeIcon icon={faClock} className="mr-1" />
        {formatDurationShow(draftPlaylist.reduce((total, track) => {
          const start = track.starts_at_second || 0;
          const end = track.ends_at_second || track.duration / 1000; // Convert milliseconds to seconds
          return total + (end - start);
        }, 0) * 1000)} {/* Convert back to milliseconds */}
      </div>
      <div className="sidebar-info mt-2">
        {draftPlaylist.length} tracks
      </div>
      <button onClick={handleEditDetails} className="button mt-6">
        Edit Details
      </button>
      <hr />
      {draftPlaylist.length >= 2 && (
        <button
          className="button is-success"
          onClick={handleSavePlaylist}
        >
          Save Playlist
        </button>
      )}
    </div>
  );

  return (
    <LayoutWrapper sidebarContent={sidebarContent}>
      <div className="main-content">
        {draftPlaylist.length < 2 && (
          <div className="notification show-info">
            <span className="icon">
              <FontAwesomeIcon icon={faExclamationCircle} />
            </span>
            Add at least 2 tracks to save and share your custom playlist.
          </div>
        )}
        <Tracks tracks={draftPlaylist} viewStyle="playlist" />
      </div>
    </LayoutWrapper>
  );
};

export default DraftPlaylist;
