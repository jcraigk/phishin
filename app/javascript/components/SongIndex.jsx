import { getAudioStatusFilter } from "./helpers/utils";

export const songIndexLoader = async ({ request }) => {
  const url = new URL(request.url);
  const page = url.searchParams.get("page") || 1;
  const sortOption = url.searchParams.get("sort") || "title:asc";
  const perPage = url.searchParams.get("per_page") || 10;

  const audioStatusFilter = getAudioStatusFilter();

  try {
    const response = await fetch(`/api/v2/songs?page=${page}&sort=${sortOption}&per_page=${perPage}&audio_status=${audioStatusFilter}`);
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

import React, { useState, useCallback } from "react";
import { useLoaderData, useNavigate } from "react-router-dom";
import { Helmet } from "react-helmet-async";
import { formatNumber } from "./helpers/utils";
import LayoutWrapper from "./layout/LayoutWrapper";
import Songs from "./Songs";
import Pagination from "./controls/Pagination";
import PhoneTitle from "./PhoneTitle";
import { paginationHelper } from "./helpers/pagination";
import { useAudioFilteredData } from "./hooks/useAudioFilteredData";
import Loader from "./controls/Loader";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faSearch } from "@fortawesome/free-solid-svg-icons";

const SongIndex = () => {
  const initialData = useLoaderData();
  const { page, sortOption, perPage } = initialData;
  const navigate = useNavigate();
  const [searchTerm, setSearchTerm] = useState("");

  const {
    tempPerPage,
    handlePageClick,
    handleSortChange,
    handlePerPageInputChange,
    handlePerPageBlurOrEnter
  } = paginationHelper(page, sortOption, perPage);

  // Simplified fetch function for audio filter integration
  const fetchSongs = useCallback(async (audioStatusFilter) => {
    try {
      const response = await fetch(`/api/v2/songs?page=${page + 1}&sort=${sortOption}&per_page=${perPage}&audio_status=${audioStatusFilter}`);
      if (!response.ok) throw response;
      const data = await response.json();
      return data;
    } catch (error) {
      console.error("Error fetching songs:", error);
      throw error;
    }
  }, [page, sortOption, perPage]);

    const { data: songsData, isLoading } = useAudioFilteredData(initialData, fetchSongs, [page, sortOption, perPage]);

  const songs = songsData?.songs || initialData.songs;
  const totalPages = songsData?.total_pages || initialData.totalPages;
  const totalEntries = songsData?.total_entries || initialData.totalEntries;

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

  const sidebarContent = (
    <div className="sidebar-content">
      <p className="sidebar-title">Songs</p>
      <p className="sidebar-subtitle">{formatNumber(totalEntries)} total</p>

      <div className="sidebar-filters">
        <div className="select">
          <select id="sort" value={sortOption} onChange={handleSortChange}>
            <option value="title:asc">Sort by Title (Alphabetical)</option>
            <option value="title:desc">Sort by Title (Reverse Alphabetical)</option>
            <option value="tracks_count:desc">Sort by Tracks Count (High to Low)</option>
            <option value="tracks_count:asc">Sort by Tracks Count (Low to High)</option>
          </select>
        </div>
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
        <PhoneTitle title="Songs" />
        {isLoading ? (
          <Loader />
        ) : (
          <>
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
          </>
        )}
      </LayoutWrapper>
    </>
  );
};

export default SongIndex;
