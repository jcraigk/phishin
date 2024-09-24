import { authFetch } from "./utils";

export const songTracksLoader = async ({ params, request }) => {
  const url = new URL(request.url);
  const page = url.searchParams.get("page") || 1;
  const sortOption = url.searchParams.get("sort") || "date:desc";
  const { songSlug } = params;

  try {
    const songResponse = await fetch(`/api/v2/songs/${songSlug}`);
    if (songResponse.status === 404) {
      throw new Response("Song not found", { status: 404 });
    }
    if (!songResponse.ok) throw songResponse;
    const songData = await songResponse.json();

    const songTitle = songData.title;
    const originalInfo = songData.original
      ? "Original composition"
      : `Original Artist: ${songData.artist}`;

    const tracksResponse = await authFetch(
      `/api/v2/tracks?song_slug=${songSlug}&sort=${sortOption}&page=${page}&per_page=10`
    );
    if (!tracksResponse.ok) throw tracksResponse;
    const tracksData = await tracksResponse.json();

    return {
      songTitle,
      originalInfo,
      tracks: tracksData.tracks,
      totalEntries: tracksData.total_entries,
      totalPages: tracksData.total_pages,
      page: parseInt(page, 10) - 1,
      sortOption
    };
  } catch (error) {
    if (error instanceof Response) throw error;
    throw new Response("Error fetching data", { status: 500 });
  }
};

import React, { useRef, useEffect, useState } from "react";
import { useLoaderData, useNavigate, useOutletContext } from "react-router-dom";
import LayoutWrapper from "./LayoutWrapper";
import Tracks from "./Tracks";
import Pagination from "./Pagination";
import { Helmet } from 'react-helmet-async';

const SongTracks = () => {
  const { songTitle, originalInfo, tracks, totalEntries, totalPages, page, sortOption } = useLoaderData();
  const navigate = useNavigate();
  const { playTrack } = useOutletContext();

  const trackRefs = useRef([]);
  const [matchedTrack, setMatchedTrack] = useState(tracks[0]);

  useEffect(() => {
    if (tracks.length > 0) {
      const initialTrack = tracks[0];
      setMatchedTrack(initialTrack);
      if (trackRefs.current[0]) {
        trackRefs.current[0].scrollIntoView({ behavior: "smooth", block: "center" });
      }
    }
  }, [tracks]);

  const handleTrackClick = (track) => {
    playTrack(tracks, track);
    setMatchedTrack(track);
    const trackIndex = tracks.findIndex(t => t.id === track.id);
    if (trackRefs.current[trackIndex]) {
      trackRefs.current[trackIndex].scrollIntoView({ behavior: "smooth", block: "center" });
    }
  };

  const handleSortChange = (event) => {
    navigate(`?page=1&sort=${event.target.value}`);
  };

  const handlePageClick = (data) => {
    navigate(`?page=${data.selected + 1}&sort=${sortOption}`);
  };

  const sidebarContent = (
    <div className="sidebar-content">
      <p className="sidebar-title">{songTitle}</p>
      <p className="sidebar-subtitle sidebar-extras">{originalInfo}</p>
      <p className="sidebar-subtitle sidebar-extras">Total Tracks: {totalEntries}</p>

      <div className="sidebar-filters">
        <div className="select">
          <select value={sortOption} onChange={handleSortChange}>
            <option value="date:desc">Sort by Date (Newest First)</option>
            <option value="date:asc">Sort by Date (Oldest First)</option>
            <option value="likes_count:desc">Sort by Likes (Most to Least)</option>
            <option value="likes_count:asc">Sort by Likes (Least to Most)</option>
            <option value="duration:desc">Sort by Duration (Longest First)</option>
            <option value="duration:asc">Sort by Duration (Shortest First)</option>
          </select>
        </div>
      </div>
    </div>
  );

  return (
    <>
      <Helmet>
        <title>{songTitle} - Phish.in</title>
      </Helmet>
      <LayoutWrapper sidebarContent={sidebarContent}>
        <Tracks
          tracks={tracks}
          setTracks={() => {}}
          trackRefs={trackRefs}
        />
        {totalPages > 1 && (
          <Pagination
            totalPages={totalPages}
            handlePageClick={handlePageClick}
            currentPage={page}
          />
        )}
      </LayoutWrapper>
    </>
  );
};

export default SongTracks;
