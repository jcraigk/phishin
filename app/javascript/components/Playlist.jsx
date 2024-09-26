import { authFetch } from "./utils";

export const playlistLoader = async ({ params }) => {
  const { playlistSlug } = params;

  try {
    const response = await authFetch(`/api/v2/playlists/${playlistSlug}`);
    if (response.status === 404) {
      throw new Response("Playlist not found", { status: 404 });
    }
    if (!response.ok) throw response;
    let playlist = await response.json();
    return playlist;
  } catch (error) {
    if (error instanceof Response) throw error;
    throw new Response("Error fetching data", { status: 500 });
  }
};

import React, { useState, useEffect, useRef } from "react";
import { useLoaderData, useOutletContext } from "react-router-dom";
import { Helmet } from "react-helmet-async";
import LayoutWrapper from "./LayoutWrapper";
import Tracks from "./Tracks";
import LikeButton from "./LikeButton";
import { formatDate, formatDateLong, formatDurationShow } from "./utils";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faClock, faCircleXmark, faInfoCircle } from "@fortawesome/free-solid-svg-icons";

const Playlist = () => {
  const playlist = useLoaderData();
  const trackRefs = useRef([]);
  const [tracks, setTracks] = useState(playlist.entries.map(entry => entry.track));
  const [showNotification, setShowNotification] = useState(true);

  const { playTrack, customPlaylist, setCustomPlaylist, activeTrack } = useOutletContext();

  useEffect(() => {
    if (!customPlaylist || customPlaylist.slug !== playlist.slug) {
      setCustomPlaylist(playlist);
      playTrack(tracks, tracks[0], true);
    }
  }, [playlist, tracks, customPlaylist, setCustomPlaylist, playTrack]);

  const handleCloseNotification = () => {
    setShowNotification(false);
  };

  const sidebarContent = (
    <div className="sidebar-content">
      <p className="sidebar-title">{playlist.name}</p>
      <p className="sidebar-info sidebar-extras mb-3">By {playlist.username}</p>
      <div className="show-duration mr-1">
        <FontAwesomeIcon icon={faClock} className="mr-1" />
        {formatDurationShow(playlist.duration)}
      </div>
      <p className="sidebar-info sidebar-extras">{playlist.tracks_count} tracks</p>
      <hr />
      <div className="sidebar-control-wrapper">
        <LikeButton likable={playlist} type="Playlist" />
      </div>
    </div>
  );

  return (
    <>
      <Helmet>
        <title>{`${playlist.name} - Phish.in`}</title>
        <meta property="og:title" content={`Listen to ${playlist.name}`} />
        <meta property="og:type" content="music.playlist" />
      </Helmet>
      <LayoutWrapper sidebarContent={sidebarContent}>
        {showNotification && (
          <div className="notification show-info">
            <button className="close-btn" onClick={handleCloseNotification}>
              <FontAwesomeIcon icon={faCircleXmark} />
            </button>
            <span className="icon">
              <FontAwesomeIcon icon={faInfoCircle} />
            </span>
            {playlist.description || "(No description)"}
            <p>Last updated: {formatDateLong(playlist.updated_at)}</p>
          </div>
        )}
        <Tracks tracks={tracks} viewStyle="playlist" />
      </LayoutWrapper>
    </>
  );
};

export default Playlist;
