import { authFetch } from "./utils";

export const tagTracksLoader = async ({ params, request }) => {
  const url = new URL(request.url);
  const page = url.searchParams.get("page") || 1;
  const sortOption = url.searchParams.get("sort") || "date:desc";
  const { tagSlug } = params;

  try {
    const tagResponse = await fetch(`/api/v2/tags`);
    if (!tagResponse.ok) throw tagResponse;
    const tagData = await tagResponse.json();
    const tag = tagData.find(t => t.slug === tagSlug);
    if (!tag) throw new Response("Tag not found", { status: 404 });

    const tracksResponse = await authFetch(
      `/api/v2/tracks?tag_slug=${tagSlug}&sort=${sortOption}&page=${page}&per_page=10`
    );
    if (!tracksResponse.ok) throw tracksResponse;
    const tracksData = await tracksResponse.json();
    console.log('hello')
    return {
      tag,
      tracks: tracksData.tracks,
      totalPages: tracksData.total_pages,
      page: parseInt(page, 10) - 1,
      sortOption,
    };
  } catch (error) {
    console.log(error);
    if (error instanceof Response) throw error;
    throw new Response("Error fetching data", { status: 500 });
  }
};

import React from "react";
import { useLoaderData, useNavigate } from "react-router-dom";
import LayoutWrapper from "./LayoutWrapper";
import Tracks from "./Tracks";
import ReactPaginate from "react-paginate";
import { Helmet } from 'react-helmet-async';

const TagTracks = () => {
  const { tag, tracks, totalPages, page, sortOption } = useLoaderData();
  const navigate = useNavigate();

  const handleSortChange = (event) => {
    navigate(`?page=1&sort=${event.target.value}`);
  };

  const handlePageClick = (data) => {
    navigate(`?page=${data.selected + 1}&sort=${sortOption}`);
  };

  const sidebarContent = (
    <div className="sidebar-content">
      <p className="sidebar-title">"{tag.name}" Tracks</p>

      <div className="sidebar-filters">
        <div className="select">
          <select value={sortOption} onChange={handleSortChange}>
            <option value="date:desc">Sort by Date (Newest First)</option>
            <option value="date:asc">Sort by Date (Oldest First)</option>
            <option value="likes_count:desc">Sort by Title (Alphabetical)</option>
            <option value="likes_count:asc">Sort by Title (Reverse Alphabetical)</option>
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
        <title>{tag.name} - Tracks - Phish.in</title>
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

export default TagTracks;