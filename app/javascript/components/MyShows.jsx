import { authFetch } from "./utils";

export const myShowsLoader = async ({ request }) => {
  const url = new URL(request.url);
  const page = url.searchParams.get("page") || 1;
  const sortOption = url.searchParams.get("sort") || "date:desc";

  const jwt = typeof window !== "undefined" ? localStorage.getItem("jwt") : null;
  if (!jwt) {
    return { shows: [], totalPages: 1, page: 0, sortOption };
  }

  try {
    const response = await authFetch(`/api/v2/shows?liked_by_user=true&sort=${sortOption}&page=${page}&per_page=10`);
    if (!response.ok) throw response;
    const data = await response.json();
    return {
      shows: data.shows,
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
import { Helmet } from "react-helmet-async";
import LayoutWrapper from "./LayoutWrapper";
import Shows from "./Shows";
import Pagination from "./Pagination";

const MyShows = () => {
  const { shows, totalPages, page, sortOption } = useLoaderData();
  const navigate = useNavigate();

  const handleSortChange = (event) => {
    navigate(`?page=1&sort=${event.target.value}`);
  };

  const handlePageClick = (data) => {
    navigate(`?page=${data.selected + 1}&sort=${sortOption}`);
  };

  const sidebarContent = (
    <div className="sidebar-content">
      <p className="sidebar-title">My Shows</p>

      <div className="sidebar-filters">
        <div className="select">
          <select value={sortOption} onChange={handleSortChange}>
            <option value="date:desc">Sort by Date (Newest First)</option>
            <option value="date:asc">Sort by Date (Oldest First)</option>
            <option value="likes_count:desc">Sort by Likes (Most to Least)</option>
            <option value="likes_count:asc">Sort by Likes (Least to Most)</option>
          </select>
        </div>
      </div>

      <div className="sidebar-details">
        {!localStorage.getItem("jwt") && (
          <div className="sidebar-callout">
            <Link to="/login" className="button">
              Login to see your liked shows!
            </Link>
          </div>
        )}
      </div>
    </div>
  );

  return (
    <>
      <Helmet>
        <title>My Shows - Phish.in</title>
      </Helmet>
      <LayoutWrapper sidebarContent={sidebarContent}>
        <Shows shows={shows} setShows={() => {}} numbering={false} setHeaders={false} />
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

export default MyShows;
