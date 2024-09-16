import { authFetch } from "./utils";

export const songTracksLoader = async ({ params, request }) => {
  const url = new URL(request.url);
  const page = url.searchParams.get("page") || 1;
  const sortOption = url.searchParams.get("sort") || "date:desc";
  const { songSlug } = params;

  try {
    const songResponse = await fetch(`/api/v2/songs/${songSlug}`);
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
      page: parseInt(page, 10) - 1, // Convert to zero-based index for pagination
      sortOption
    };
  } catch (error) {
    throw new Response("Error fetching data", { status: 500 });
  }
};

import React from "react";
import { useLoaderData, useNavigate } from "react-router-dom";
import LayoutWrapper from "./LayoutWrapper";
import Tracks from "./Tracks";
import ReactPaginate from "react-paginate";
import { Helmet } from 'react-helmet-async';

const SongTracks = () => {
  const { songTitle, originalInfo, tracks, totalEntries, totalPages, page, sortOption } = useLoaderData();
  const navigate = useNavigate();

  const handleSortChange = (event) => {
    navigate(`?page=1&sort=${event.target.value}`);
  };

  const handlePageClick = (data) => {
    navigate(`?page=${data.selected + 1}&sort=${sortOption}`);
  };

  const sidebarContent = (
    <div className="sidebar-content">
      <h1 className="title">{songTitle}</h1>
      <p className="subtitle">{originalInfo}</p>
      <p className="mb-5">Total Tracks: {totalEntries}</p>
      <div className="select is-fullwidth mb-5">
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
  );

  return (
    <>
      <Helmet>
        <title>{songTitle} - Phish.in</title>
      </Helmet>
      <LayoutWrapper sidebarContent={sidebarContent}>
        <Tracks tracks={tracks} setTracks={() => {}} />
        {totalPages > 1 && (
          <ReactPaginate
            previousLabel={"Previous"}
            nextLabel={"Next"}
            breakLabel={"..."}
            breakClassName={"break-me"}
            pageCount={totalPages}
            marginPagesDisplayed={1}
            pageRangeDisplayed={1}
            onPageChange={handlePageClick}
            containerClassName={"pagination"}
            activeClassName={"active"}
            forcePage={page}
          />
        )}
      </LayoutWrapper>
    </>
  );
};

export default SongTracks;
