import { authFetch } from "./helpers/utils";

export const myShowsLoader = async ({ request }) => {
  const url = new URL(request.url);
  const page = url.searchParams.get("page") || 1;
  const sortOption = url.searchParams.get("sort") || "date:desc";
  const perPage = url.searchParams.get("per_page") || 10;

  try {
    const response = await authFetch(`/api/v2/shows?liked_by_user=true&sort=${sortOption}&page=${page}&per_page=${perPage}`);
    if (!response.ok) throw response;
    const data = await response.json();
    return {
      shows: data.shows,
      totalPages: data.total_pages,
      page: parseInt(page, 10) - 1,
      sortOption,
      perPage: parseInt(perPage)
    };
  } catch (error) {
    throw new Response("Error fetching data", { status: 500 });
  }
};

import React, { useState, useEffect } from "react";
import { useLoaderData, useNavigate, useOutletContext } from "react-router-dom";
import { Helmet } from "react-helmet-async";
import LayoutWrapper from "./layout/LayoutWrapper";
import Shows from "./Shows";
import Pagination from "./controls/Pagination";
import { useFeedback } from "./controls/FeedbackContext";

const MyShows = () => {
  const { shows, totalPages, page, sortOption, perPage } = useLoaderData();
  const navigate = useNavigate();
  const [tempPerPage, setTempPerPage] = useState(perPage);
  const { setAlert } = useFeedback();
  const { user } = useOutletContext();

  // Redirect and warn if not logged in
  useEffect(() => {
    if (user === "anonymous") {
      navigate("/");
      setAlert("You must be logged in to view that page");
    }
  }, [navigate, user]);

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
    </div>
  );

  return (
    <>
      <Helmet>
        <title>My Shows - Phish.in</title>
      </Helmet>
      <LayoutWrapper sidebarContent={sidebarContent}>
        <Shows shows={shows} />
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

export default MyShows;
