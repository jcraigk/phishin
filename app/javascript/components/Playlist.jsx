import { authFetch } from "./helpers/utils";

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

import React, { useState, useEffect } from "react";
import { useLoaderData, useOutletContext, useNavigate } from "react-router-dom";
import { Helmet } from "react-helmet-async";
import LayoutWrapper from "./layout/LayoutWrapper";
import Tracks from "./Tracks";
import LikeButton from "./controls/LikeButton";
import { formatDateLong, formatDurationShow } from "./helpers/utils";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faClock, faCircleXmark, faInfoCircle, faCalendar, faFileImport } from "@fortawesome/free-solid-svg-icons";

const Playlist = () => {
  const playlist = useLoaderData();
  const [showNotification, setShowNotification] = useState(true);
  const { playTrack, customPlaylist, setCustomPlaylist, user, setDraftPlaylist, setDraftPlaylistMeta } = useOutletContext();
  const navigate = useNavigate();
  const [tracks] = useState(
    playlist.entries.map(entry => ({
      ...entry.track,
      starts_at_second: entry.starts_at_second,
      ends_at_second: entry.ends_at_second
    }))
  );


  useEffect(() => {
    if (!customPlaylist || customPlaylist.slug !== playlist.slug) {
      setCustomPlaylist(playlist);
      playTrack(tracks, tracks[0], true);
    }
  }, [playlist, tracks, customPlaylist, setCustomPlaylist, playTrack]);

  const handleCloseNotification = () => {
    setShowNotification(false);
  };

  const handleSetAsDraft = () => {
    setDraftPlaylist(
      playlist.entries.map(entry => ({
        ...entry.track,
        starts_at_second: entry.starts_at_second,
        ends_at_second: entry.ends_at_second
      }))
    );

    const isOwner = playlist.username === user.username;
    const id = isOwner ? playlist.id : null;
    const namePrefix = isOwner ? "" : "Copy of ";
    const slugPrefix = isOwner ? "" : "copy-of-";

    setDraftPlaylistMeta({
      id,
      name: `${namePrefix}${playlist.name}`,
      slug: `${slugPrefix}${playlist.slug}`,
      description: playlist.description,
      published: isOwner ? playlist.published : false,
    });

    navigate("/draft-playlist");
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

        <button className="button" onClick={handleSetAsDraft}>
          <FontAwesomeIcon icon={faFileImport} className="mr-1" />
          Set as Draft
        </button>
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
          <div className="notification playlist-info">
            <button className="close-btn" onClick={handleCloseNotification}>
              <FontAwesomeIcon icon={faCircleXmark} />
            </button>
            <FontAwesomeIcon icon={faInfoCircle} className="mr-1" />
            {playlist.description || "This playlist has no description"}
            <p>
              <FontAwesomeIcon icon={faCalendar} className="mr-1" />
              Last updated: {formatDateLong(playlist.updated_at)}
            </p>
          </div>
        )}
        <Tracks tracks={tracks} viewStyle="playlist" omitSecondary={true} />
      </LayoutWrapper>
    </>
  );
};

export default Playlist;
