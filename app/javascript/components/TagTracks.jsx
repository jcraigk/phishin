import { authFetch } from "./helpers/utils";

export const tagTracksLoader = async ({ params, request }) => {
  const url = new URL(request.url);
  const page = url.searchParams.get("page") || 1;
  const sortOption = url.searchParams.get("sort") || "date:desc";
  const perPage = url.searchParams.get("per_page") || 10;
  const { tagSlug } = params;

  try {
    const tagResponse = await fetch(`/api/v2/tags`);
    if (!tagResponse.ok) throw tagResponse;
    const tagData = await tagResponse.json();
    const tag = tagData.find(t => t.slug === tagSlug);
    if (!tag) throw new Response("Tag not found", { status: 404 });

    const tracksResponse = await authFetch(
      `/api/v2/tracks?tag_slug=${tagSlug}&sort=${sortOption}&page=${page}&per_page=${perPage}`
    );
    if (!tracksResponse.ok) throw tracksResponse;
    const tracksData = await tracksResponse.json();
    return {
      tag,
      tracks: tracksData.tracks,
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

import React from "react";
import { useLoaderData } from "react-router-dom";
import { Helmet } from "react-helmet-async";
import LayoutWrapper from "./layout/LayoutWrapper";
import Tracks from "./Tracks";
import Pagination from "./controls/Pagination";
import { paginationHelper } from "./helpers/pagination";

const TagTracks = () => {
  const { tag, tracks, totalPages, page, sortOption, perPage } = useLoaderData();
  const {
    tempPerPage,
    handlePageClick,
    handleSortChange,
    handlePerPageInputChange,
    handlePerPageBlurOrEnter
  } = paginationHelper(page, sortOption, perPage);

  const sidebarContent = (
    <div className="sidebar-content">
      <p className="sidebar-title">"{tag.name}" Tracks</p>

      <div className="sidebar-filters">
        <div className="select">
          <select id="sort" value={sortOption} onChange={handleSortChange}>
            <option value="date:desc">Sort by Date (Newest First)</option>
            <option value="date:asc">Sort by Date (Oldest First)</option>
            <option value="likes_count:desc">Sort by Title (Alphabetical)</option>
            <option value="likes_count:asc">Sort by Title (Reverse Alphabetical)</option>
            <option value="likes_count:desc">Sort by Likes (High to Low)</option>
            <option value="likes_count:asc">Sort by Likes (Low to High)</option>
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

export default TagTracks;
