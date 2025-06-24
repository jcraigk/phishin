import { authFetch } from "./helpers/utils";

export const playlistIndexLoader = async ({ request }) => {
  const url = new URL(request.url);
  const page = url.searchParams.get("page") || 1;
  const sortOption = url.searchParams.get("sort") || "likes_count:desc";
  const filter = url.searchParams.get("filter") || "all";
  const perPage = url.searchParams.get("per_page") || 10;

  try {
    const response = await authFetch(`/api/v2/playlists?page=${page}&sort=${sortOption}&filter=${filter}&per_page=${perPage}`);
    if (!response.ok) throw response;
    const data = await response.json();
    return {
      playlists: data.playlists,
      totalPages: data.total_pages,
      totalEntries: data.total_entries,
      page: parseInt(page, 10) - 1,
      sortOption,
      filter,
      perPage: parseInt(perPage)
    };
  } catch (error) {
    throw new Response("Error fetching data", { status: 500 });
  }
};


import React, { useState } from "react";
import { useLoaderData, useNavigate, useOutletContext } from "react-router-dom";
import { Helmet } from "react-helmet-async";
import { formatNumber } from "./helpers/utils";
import LayoutWrapper from "./layout/LayoutWrapper";
import Playlists from "./Playlists";
import Pagination from "./controls/Pagination";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faSearch } from "@fortawesome/free-solid-svg-icons";
import { paginationHelper } from "./helpers/pagination";

const PlaylistIndex = () => {
  const {
    playlists,
    totalPages,
    totalEntries,
    page,
    sortOption,
    filter,
    perPage
  } = useLoaderData();
  const navigate = useNavigate();
  const [searchTerm, setSearchTerm] = useState("");
  const { user } = useOutletContext();
  const {
    tempPerPage,
    handlePageClick,
    handleSortChange,
    handlePerPageInputChange,
    handlePerPageBlurOrEnter
  } = paginationHelper(page, sortOption, perPage, "", filter);

  const handleFilterChange = (event) => {
    setFilter(event.target.value);
    navigate(`?page=1&sort=${sortOption}&filter=${event.target.value}&per_page=${perPage}`);
  };

  const handleSearchChange = (event) => {
    setSearchTerm(event.target.value);
  };

  const handleSearchSubmit = () => {
    if (!searchTerm) return;
    navigate(`/search?term=${encodeURIComponent(searchTerm)}&scope=playlists`);
  };

  const handleKeyDown = (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      handleSearchSubmit();
    }
  };

  const sidebarContent = (
    <div className="sidebar-content">
      <p className="sidebar-title">Playlists</p>
      <p className="sidebar-subtitle">{formatNumber(totalEntries)} total</p>

      <div className="sidebar-filters">
        <div className="select">
          <select id="sort" value={sortOption} onChange={handleSortChange}>
            <option value="name:asc">Sort by Name (A-Z)</option>
            <option value="name:desc">Sort by Name (Z-A)</option>
            <option value="likes_count:desc">Sort by Likes (High to Low)</option>
            <option value="likes_count:asc">Sort by Likes (Low to High)</option>
            <option value="duration:desc">Sort by Duration (Long to Short)</option>
            <option value="duration:asc">Sort by Duration (Short to Long)</option>
            <option value="tracks_count:desc">Sort by Tracks (High to Low)</option>
            <option value="tracks_count:asc">Sort by Tracks (Low to High)</option>
            <option value="updated_at:desc">Sort by Updated (New to Old)</option>
            <option value="updated_at:asc">Sort by Updated (Old to New)</option>
          </select>
        </div>

        {user && (
          <div className="select">
            <select id="playlist-filter" value={filter} onChange={handleFilterChange}>
              <option value="all">All Published Playlists</option>
              <option value="mine">Playlists I Made</option>
              <option value="liked">Playlists I Liked</option>
            </select>
          </div>
        )}
      </div>

      <div className="mt-6 hidden-mobile">
        <hr />
        <input
          id="search"
          className="input"
          type="text"
          value={searchTerm}
          onChange={handleSearchChange}
          onKeyDown={handleKeyDown}
          placeholder="Search playlists"
        />
        <button className="button mt-4" onClick={handleSearchSubmit}>
          <FontAwesomeIcon icon={faSearch} className="mr-1" />
          Search
        </button>
      </div>
    </div>
  );

  return (
    <>
      <Helmet>
        <title>Playlists - Phish.in</title>
      </Helmet>
      <LayoutWrapper sidebarContent={sidebarContent}>
        <Playlists playlists={playlists} />
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

export default PlaylistIndex;
