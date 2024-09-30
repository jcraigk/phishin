export const songIndexLoader = async ({ request }) => {
  const url = new URL(request.url);
  const page = url.searchParams.get("page") || 1;
  const sortOption = url.searchParams.get("sort") || "title:asc";
  const perPage = url.searchParams.get("per_page") || 10;

  try {
    const response = await fetch(`/api/v2/songs?page=${page}&sort=${sortOption}&per_page=${perPage}`);
    if (!response.ok) throw response;
    const data = await response.json();
    return {
      songs: data.songs,
      totalPages: data.total_pages,
      totalEntries: data.total_entries,
      page: parseInt(page, 10) - 1,
      sortOption,
      perPage: parseInt(perPage)
    };
  } catch (error) {
    throw new Response("Error fetching data", { status: 500 });
  }
};

import React, { useState } from "react";
import { useLoaderData, useNavigate } from "react-router-dom";
import { Helmet } from "react-helmet-async";
import { formatNumber } from "./helpers/utils";
import LayoutWrapper from "./layout/LayoutWrapper";
import Songs from "./Songs";
import Pagination from "./controls/Pagination";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faSearch } from "@fortawesome/free-solid-svg-icons";

const SongIndex = () => {
  const { songs, totalPages, totalEntries, page, sortOption, perPage } = useLoaderData(); // Include perPage
  const navigate = useNavigate();
  const [searchTerm, setSearchTerm] = useState("");
  const [tempPerPage, setTempPerPage] = useState(perPage); // Add tempPerPage state

  const handlePageClick = (data) => {
    navigate(`?page=${data.selected + 1}&sort=${sortOption}&per_page=${perPage}`); // Include perPage in query
  };

  const handleSortChange = (event) => {
    navigate(`?page=1&sort=${event.target.value}&per_page=${perPage}`); // Include perPage in query
  };

  const handleSearchChange = (event) => {
    setSearchTerm(event.target.value);
  };

  const handleSearchSubmit = () => {
    if (!searchTerm) return;
    navigate(`/search?term=${encodeURIComponent(searchTerm)}&scope=songs`);
  };

  const handleKeyDown = (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      handleSearchSubmit();
    }
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
      <p className="sidebar-title">Songs</p>
      <p className="sidebar-subtitle">{formatNumber(totalEntries)} total</p>
      <div className="select">
        <select id="sort" value={sortOption} onChange={handleSortChange}>
          <option value="title:asc">Sort by Title (Alphabetical)</option>
          <option value="title:desc">Sort by Title (Reverse Alphabetical)</option>
          <option value="tracks_count:desc">Sort by Tracks Count (High to Low)</option>
          <option value="tracks_count:asc">Sort by Tracks Count (Low to High)</option>
        </select>
      </div>

      <div className="mt-5 hidden-mobile">
        <hr />
        <input
          id="search"
          className="input"
          type="text"
          value={searchTerm}
          onChange={handleSearchChange}
          onKeyDown={handleKeyDown}
          placeholder="Search songs"
        />
        <button className="button mt-4" onClick={handleSearchSubmit}>
          <FontAwesomeIcon icon={faSearch} className="mr-1"/>
          Search
        </button>
      </div>
    </div>
  );

  return (
    <>
      <Helmet>
        <title>Songs - Phish.in</title>
      </Helmet>
      <LayoutWrapper sidebarContent={sidebarContent}>
        <Songs songs={songs} />
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

export default SongIndex;
