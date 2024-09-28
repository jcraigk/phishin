import { authFetch } from "./helpers/utils";

export const tagShowsLoader = async ({ params, request }) => {
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

    const showsResponse = await authFetch(
      `/api/v2/shows?tag_slug=${tagSlug}&sort=${sortOption}&page=${page}&per_page=10`
    );
    if (!showsResponse.ok) throw showsResponse;
    const showsData = await showsResponse.json();
    return {
      tag,
      shows: showsData.shows,
      totalPages: showsData.total_pages,
      page: parseInt(page, 10) - 1,
      sortOption,
    };
  } catch (error) {
    if (error instanceof Response) throw error;
    throw new Response("Error fetching data", { status: 500 });
  }
};

import React from "react";
import { useLoaderData, useNavigate } from "react-router-dom";
import { Helmet } from "react-helmet-async";
import LayoutWrapper from "./layout/LayoutWrapper";
import Shows from "./Shows";
import Pagination from "./controls/Pagination";

const TagShows = () => {
  const { tag, shows, totalPages, page, sortOption } = useLoaderData();
  const navigate = useNavigate();

  const handleSortChange = (event) => {
    navigate(`?page=1&sort=${event.target.value}`);
  };

  const handlePageClick = (data) => {
    navigate(`?page=${data.selected + 1}&sort=${sortOption}`);
  };

  const sidebarContent = (
    <div className="sidebar-content">
      <p className="sidebar-title">"{tag.name}" Shows</p>

      <div className="sidebar-filters">
        <div className="select">
          <select value={sortOption} onChange={handleSortChange}>
            <option value="date:desc">Sort by Date (Newest First)</option>
            <option value="date:asc">Sort by Date (Oldest First)</option>
            <option value="likes_count:desc">Sort by Title (Alphabetical)</option>
            <option value="likes_count:asc">Sort by Title (Reverse Alphabetical)</option>
            <option value="likes_count:desc">Sort by Likes (Most to Least)</option>
            <option value="likes_count:asc">Sort by Likes (Least to Most)</option>
          </select>
        </div>
      </div>
    </div>
  );

  return (
    <>
      <Helmet>
        <title>{tag.name} - Shows - Phish.in</title>
      </Helmet>
      <LayoutWrapper sidebarContent={sidebarContent}>
        <Shows shows={shows} />
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

export default TagShows;
