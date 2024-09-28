import { authFetch } from "./util/utils";

export const myTracksLoader = async ({ request }) => {
  const url = new URL(request.url);
  const page = url.searchParams.get("page") || 1;
  const sortOption = url.searchParams.get("sort") || "date:desc";

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
import { useLoaderData, useNavigate, Link, useOutletContext } from "react-router-dom";
import { Helmet } from "react-helmet-async";
import LayoutWrapper from "./layout/LayoutWrapper";
import Tracks from "./Tracks";
import Pagination from "./controls/Pagination";

const MyTracks = () => {
  const { tracks, totalPages, page, sortOption } = useLoaderData();
  const navigate = useNavigate();
  const { user } = useOutletContext();

  const handleSortChange = (event) => {
    navigate(`?page=1&sort=${event.target.value}`);
  };

  const handlePageClick = (data) => {
    navigate(`?page=${data.selected + 1}&sort=${sortOption}`);
  };

  const sidebarContent = (
    <div className="sidebar-content">
      <p className="sidebar-title">My Tracks</p>

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

      {!user && (
        <div className="sidebar-details mt-6">
          <div className="sidebar-callout">
            <Link to="/login" className="button">
              Login to see your liked tracks!
            </Link>
          </div>
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

export default MyTracks;
