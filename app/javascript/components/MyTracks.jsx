import { authFetch, getAudioStatusFilter } from "./helpers/utils";

const buildFetchUrl = (page, sortOption, perPage, audioStatusFilter) => {
  return `/api/v2/tracks?liked_by_user=true&sort=${sortOption}&page=${page}&per_page=${perPage}&audio_status=${audioStatusFilter}`;
};

export const myTracksLoader = async ({ request }) => {
  const url = new URL(request.url);
  const page = url.searchParams.get("page") || 1;
  const sortOption = url.searchParams.get("sort") || "date:desc";
  const perPage = url.searchParams.get("per_page") || 10;
  const audioStatusFilter = getAudioStatusFilter();
  const response = await authFetch(buildFetchUrl(page, sortOption, perPage, audioStatusFilter));
  if (!response.ok) throw response;
  const data = await response.json();
  return {
    tracks: data.tracks,
    totalPages: data.total_pages,
    page: parseInt(page, 10) - 1,
    sortOption,
    perPage: parseInt(perPage)
  };
};

import React, { useEffect } from "react";
import { useLoaderData, useNavigate, useOutletContext } from "react-router-dom";
import { Helmet } from "react-helmet-async";
import LayoutWrapper from "./layout/LayoutWrapper";
import Tracks from "./Tracks";
import Pagination from "./controls/Pagination";
import { paginationHelper } from "./helpers/pagination";
import { useFeedback } from "./contexts/FeedbackContext";

const MyTracks = () => {
  const { tracks, totalPages, page, sortOption, perPage } = useLoaderData();
  const navigate = useNavigate();
  const { user } = useOutletContext();
  const { setAlert } = useFeedback();
  const {
    tempPerPage,
    handlePageClick,
    handleSortChange,
    handlePerPageInputChange,
    handlePerPageBlurOrEnter
  } = paginationHelper(page, sortOption, perPage);

  // Redirect and warn if not logged in
  useEffect(() => {
    if (user === "anonymous") {
      navigate("/");
      setAlert("You must login to do that");
    }
  }, [navigate, user]);

  const sidebarContent = (
    <div className="sidebar-content">
      <p className="sidebar-title">My Tracks</p>

      <div className="sidebar-filters">
        <div className="select">
          <select id="sort" value={sortOption} onChange={handleSortChange}>
            <option value="date:desc">Sort by Date (Newest First)</option>
            <option value="date:asc">Sort by Date (Oldest First)</option>
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
        <title>My Tracks - Phish.in</title>
      </Helmet>
              <LayoutWrapper sidebarContent={sidebarContent}>
                      <Tracks tracks={tracks} setTracks={() => {}} />
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

export default MyTracks;

