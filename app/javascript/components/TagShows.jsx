import { authFetch } from "./utils";

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
    const tagName = tag ? tag.name : "Unknown Tag";

    const showsResponse = await authFetch(
      `/api/v2/shows?tag_slug=${tagSlug}&sort=${sortOption}&page=${page}&per_page=10`
    );
    if (!showsResponse.ok) throw showsResponse;
    const showsData = await showsResponse.json();

    return {
      tagName,
      shows: showsData.shows,
      totalPages: showsData.total_pages,
      page: parseInt(page, 10) - 1,
      sortOption,
    };
  } catch (error) {
    throw new Response("Error fetching data", { status: 500 });
  }
};

import React from "react";
import { useLoaderData, useNavigate } from "react-router-dom";
import LayoutWrapper from "./LayoutWrapper";
import Shows from "./Shows";
import ReactPaginate from "react-paginate";
import { Helmet } from 'react-helmet-async';

const TagShows = () => {
  const { tagName, shows, totalPages, page, sortOption } = useLoaderData();
  const navigate = useNavigate();

  const handleSortChange = (event) => {
    navigate(`?page=1&sort=${event.target.value}`);
  };

  const handlePageClick = (data) => {
    navigate(`?page=${data.selected + 1}&sort=${sortOption}`);
  };

  const sidebarContent = (
    <div className="sidebar-content">
      <h1 className="title">Shows Tagged with "{tagName}"</h1>
      <div className="select is-fullwidth mb-5">
        <select value={sortOption} onChange={handleSortChange}>
          <option value="date:desc">Sort by Date (Newest First)</option>
          <option value="date:asc">Sort by Date (Oldest First)</option>
          <option value="likes_count:desc">Sort by Title (A-Z)</option>
          <option value="likes_count:asc">Sort by Title (Z-A)</option>
          <option value="likes_count:desc">Sort by Likes (Most to Least)</option>
          <option value="likes_count:asc">Sort by Likes (Least to Most)</option>
        </select>
      </div>
    </div>
  );

  return (
    <>
      <Helmet>
        <title>{tagName} - Shows - Phish.in</title>
      </Helmet>
      <LayoutWrapper sidebarContent={sidebarContent}>
        <Shows shows={shows} setShows={() => {}} numbering={false} setHeaders={false} />
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

export default TagShows;
