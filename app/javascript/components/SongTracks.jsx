import { authFetch } from "./helpers/utils";

export const songTracksLoader = async ({ params, request }) => {
  const url = new URL(request.url);
  const page = url.searchParams.get("page") || 1;
  const sortOption = url.searchParams.get("sort") || "date:desc";
  const perPage = url.searchParams.get("per_page") || 10;
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
      : songData.artist;

    const tracksResponse = await authFetch(
      `/api/v2/tracks?song_slug=${songSlug}&sort=${sortOption}&page=${page}&per_page=${perPage}`
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
      sortOption,
      perPage: parseInt(perPage)
    };
  } catch (error) {
    if (error instanceof Response) throw error;
    throw new Response("Error fetching data", { status: 500 });
  }
};

import React, { useState } from "react";
import { useLoaderData, useNavigate } from "react-router-dom";
import { Helmet } from "react-helmet-async";
import LayoutWrapper from "./layout/LayoutWrapper";
import Tracks from "./Tracks";
import Pagination from "./controls/Pagination";

const SongTracks = () => {
  const { songTitle, originalInfo, tracks, totalEntries, totalPages, page, sortOption, perPage } = useLoaderData();
  const navigate = useNavigate();
  const [tempPerPage, setTempPerPage] = useState(perPage);

  const handleSortChange = (event) => {
    navigate(`?page=1&sort=${event.target.value}&per_page=${perPage}`);
  };

  const handlePageClick = (data) => {
    navigate(`?page=${data.selected + 1}&sort=${sortOption}&per_page=${perPage}`);
  };

  const handlePerPageInputChange = (e) => {
    setTempPerPage(e.target.value);
  };

  const submitPerPage = () => {
    if (tempPerPage && !isNaN(tempPerPage) && tempPerPage > 0) {
      navigate(`?page=1&sort=${sortOption}&per_page=${tempPerPage}`);
    }
  };

  const handlePerPageBlurOrEnter = (e) => {
    if (e.type === "blur" || (e.type === "keydown" && e.key === "Enter")) {
      e.preventDefault();
      submitPerPage();
      e.target.blur();
    }
  };

  const sidebarContent = (
    <div className="sidebar-content">
      <p className="sidebar-title">{songTitle}</p>
      <p className="sidebar-subtitle sidebar-extras">
        {originalInfo}<br />
        Total Tracks: {totalEntries}
      </p>

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
        <Tracks tracks={tracks} />
        {totalPages > 1 && (
          <Pagination
            totalPages={totalPages}
            handlePageClick={handlePageClick}
            currentPage={page}
            perPage={tempPerPage}
            handlePerPageInputChange={handlePerPageInputChange}
            handlePerPageBlurOrEnter={handlePerPageBlurOrEnter}
          />
        )}
      </LayoutWrapper>
    </>
  );
};

export default SongTracks;
