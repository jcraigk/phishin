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
import LayoutWrapper from "./LayoutWrapper";
import Shows from "./Shows";
import ReactPaginate from "react-paginate";
import { Helmet } from 'react-helmet-async';

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
      <h1 className="title">My Shows</h1>
      <div className="select is-fullwidth mb-5">
        <select value={sortOption} onChange={handleSortChange}>
          <option value="date:desc">Sort by Date (Newest First)</option>
          <option value="date:asc">Sort by Date (Oldest First)</option>
          <option value="likes_count:desc">Sort by Likes (Most to Least)</option>
          <option value="likes_count:asc">Sort by Likes (Least to Most)</option>
        </select>
      </div>
      {!localStorage.getItem("jwt") && (
        <div className="sidebar-callout">
          <Link to="/login" className="button">
            Login to see your liked shows!
          </Link>
        </div>
      )}
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

export default MyShows;
