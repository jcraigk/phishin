export const songIndexLoader = async ({ request }) => {
  const url = new URL(request.url);
  const page = url.searchParams.get("page") || 1;
  const sortOption = url.searchParams.get("sort") || "title:asc";

  try {
    const response = await fetch(`/api/v2/songs?page=${page}&sort=${sortOption}`);
    if (!response.ok) response;
    const data = await response.json();
    return {
      songs: data.songs,
      totalPages: data.total_pages,
      totalEntries: data.total_entries,
      page: parseInt(page, 10) - 1,
      sortOption
    };
  } catch (error) {
    throw new Response("Error fetching data", { status: 500 });
  }
};

import React, { useState } from "react";
import { useLoaderData, useNavigate } from "react-router-dom";
import { formatNumber } from "./utils";
import LayoutWrapper from "./LayoutWrapper";
import Songs from "./Songs";
import ReactPaginate from "react-paginate";
import { Helmet } from 'react-helmet-async';
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faSearch } from "@fortawesome/free-solid-svg-icons";

const SongIndex = () => {
  const { songs, totalPages, totalEntries, page, sortOption } = useLoaderData();
  const navigate = useNavigate();
  const [searchTerm, setSearchTerm] = useState("");

  const handlePageClick = (data) => {
    navigate(`?page=${data.selected + 1}&sort=${sortOption}`);
  };

  const handleSortChange = (event) => {
    navigate(`?page=1&sort=${event.target.value}`);
  };

  const handleSearchChange = (event) => {
    setSearchTerm(event.target.value);
  };

  const handleSearchSubmit = () => {
    if (!searchTerm) return;
    // Redirect to the search page with the 'songs' scope
    navigate(`/search?term=${encodeURIComponent(searchTerm)}&scope=songs`);
  };

  const handleKeyDown = (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      handleSearchSubmit();
    }
  };

  const sidebarContent = (
    <div className="sidebar-content">
      <p className="sidebar-title">Songs</p>
      <p className="sidebar-subtitle">{formatNumber(totalEntries)} total</p>
      <div className="select">
        <select value={sortOption} onChange={handleSortChange}>
          <option value="title:asc">Sort by Title (Alphabetical)</option>
          <option value="title:desc">Sort by Title (Reverse Alphabetical)</option>
          <option value="tracks_count:desc">Sort by Tracks Count (High to Low)</option>
          <option value="tracks_count:asc">Sort by Tracks Count (Low to High)</option>
        </select>
      </div>

      <div className="mt-5 hidden-mobile">
        <label className="label">Search Songs</label>
        <input
          className="input"
          type="text"
          value={searchTerm}
          onChange={handleSearchChange}
          onKeyDown={handleKeyDown}
          placeholder="Song title"
        />
        <button className="button mt-4" onClick={handleSearchSubmit}>
          <div className="icon mr-1">
            <FontAwesomeIcon icon={faSearch} />
          </div>
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
      </LayoutWrapper>
    </>
  );
};

export default SongIndex;

