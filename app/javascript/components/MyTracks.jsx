import { authFetch } from "./utils";

export const myTracksLoader = async ({ request }) => {
  const url = new URL(request.url);
  const page = url.searchParams.get("page") || 1;
  const sortOption = url.searchParams.get("sort") || "date:desc";

  const jwt = typeof window !== "undefined" ? localStorage.getItem("jwt") : null;
  if (!jwt) {
    return { tracks: [], totalPages: 1, page: 0, sortOption };
  }

  try {
    const response = await authFetch(`/api/v2/tracks?liked_by_user=true&sort=${sortOption}&page=${page}&per_page=10`);
    if (!response.ok) throw response;
    const data = await response.json();
    return {
      tracks: data.tracks,
      totalPages: data.total_pages,
      page: parseInt(page, 10) - 1,
      sortOption,
    };
  } catch (error) {
    throw new Response("Error fetching data", { status: 500 });
  }
};

import React from "react";
import { useLoaderData, useNavigate, Link } from "react-router-dom";
import LayoutWrapper from "./LayoutWrapper";
import Tracks from "./Tracks";
import ReactPaginate from "react-paginate";
import { Helmet } from 'react-helmet-async';

const MyTracks = () => {
  const { tracks, totalPages, page, sortOption } = useLoaderData();
  const navigate = useNavigate();

  const handleSortChange = (event) => {
    navigate(`?page=1&sort=${event.target.value}`);
  };

  const handlePageClick = (data) => {
    navigate(`?page=${data.selected + 1}&sort=${sortOption}`);
  };

  const sidebarContent = (
    <div className="sidebar-content">
      <h1 className="title">My Tracks</h1>
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
      {!localStorage.getItem("jwt") && (
        <div className="sidebar-callout">
          <Link to="/login" className="button">
            Login to see your liked tracks!
          </Link>
        </div>
      )}
    </div>
  );

  return (
    <>
      <Helmet>
        <title>My Tracks - Phish.in</title>
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

export default MyTracks;
