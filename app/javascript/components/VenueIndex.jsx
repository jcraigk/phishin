import { getAudioStatusFilter } from "./helpers/utils";

export const venueIndexLoader = async ({ request }) => {
  const url = new URL(request.url);
  const page = url.searchParams.get("page") || 1;
  const sortOption = url.searchParams.get("sort") || "name:asc";
  const firstChar = url.searchParams.get("first_char") || "";
  const perPage = url.searchParams.get("per_page") || 10;
  const audioStatusFilter = getAudioStatusFilter();
  console.log(`[${new Date().toISOString()}] VenueIndex Loader: Loading with filter: ${audioStatusFilter}, page: ${page}, sort: ${sortOption}, firstChar: ${firstChar}, perPage: ${perPage}`);
  const response = await fetch(`/api/v2/venues?page=${page}&sort=${sortOption}&first_char=${encodeURIComponent(firstChar)}&per_page=${perPage}&audio_status=${audioStatusFilter}`);
  if (!response.ok) throw response;
  const data = await response.json();
  console.log(`[${new Date().toISOString()}] VenueIndex Loader: Loaded ${data.venues?.length || 0} venues`);

  return {
    venues: data.venues,
    totalPages: data.total_pages,
    totalEntries: data.total_entries,
    page: parseInt(page, 10) - 1,
    sortOption,
    firstChar,
    perPage: parseInt(perPage)
  };
};

import React, { useState, useCallback } from "react";
import { useLoaderData, useNavigate } from "react-router-dom";
import { Helmet } from "react-helmet-async";
import { formatNumber } from "./helpers/utils";
import LayoutWrapper from "./layout/LayoutWrapper";
import Venues from "./Venues";
import PhoneTitle from "./PhoneTitle";
import Pagination from "./controls/Pagination";
import { paginationHelper } from "./helpers/pagination";
import { useServerFilteredData } from "./hooks/useServerFilteredData";
import Loader from "./controls/Loader";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faSearch } from "@fortawesome/free-solid-svg-icons";

const FIRST_CHAR_LIST = ["#", ...Array.from({ length: 26 }, (_, i) => String.fromCharCode(65 + i))];

const VenueIndex = () => {
  const initialData = useLoaderData();
  const { page, perPage, sortOption, firstChar } = initialData;
  const navigate = useNavigate();
  const [searchTerm, setSearchTerm] = useState("");

  const {
    tempPerPage,
    handlePageClick,
    handleSortChange,
    handlePerPageInputChange,
    handlePerPageBlurOrEnter
  } = paginationHelper(page, sortOption, perPage, firstChar);

  const fetchVenues = useCallback(async (audioStatusFilter) => {
    console.log(`[${new Date().toISOString()}] VenueIndex: Fetching venues with filter: ${audioStatusFilter}, page: ${page + 1}, sort: ${sortOption}, firstChar: ${firstChar}, perPage: ${perPage}`);
    const response = await fetch(`/api/v2/venues?page=${page + 1}&sort=${sortOption}&first_char=${encodeURIComponent(firstChar)}&per_page=${perPage}&audio_status=${audioStatusFilter}`);
    if (!response.ok) throw response;
    const data = await response.json();
    console.log(`[${new Date().toISOString()}] VenueIndex: Received ${data.venues?.length || 0} venues`);
    return data;
  }, [page, sortOption, firstChar, perPage]);

  const { data: venuesData, isRefetching } = useServerFilteredData(initialData, fetchVenues, [page, sortOption, firstChar, perPage]);

  const venues = venuesData?.venues || initialData.venues;
  const totalPages = venuesData?.total_pages || initialData.totalPages;
  const totalEntries = venuesData?.total_entries || initialData.totalEntries;

  const handleFirstCharChange = (event) => {
    navigate(`?page=1&sort=${sortOption}&first_char=${event.target.value}&per_page=${perPage}`);
  };

  const handleSearchChange = (event) => {
    setSearchTerm(event.target.value);
  };

  const handleSearchSubmit = () => {
    if (!searchTerm) return;
    navigate(`/search?term=${encodeURIComponent(searchTerm)}&scope=venues`);
  };

  const handleKeyDown = (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      handleSearchSubmit();
    }
  };

  const sidebarContent = (
    <div className="sidebar-content">
      <p className="sidebar-title">Venues</p>
      <p className="sidebar-subtitle">{formatNumber(totalEntries)} total</p>

      <div className="sidebar-filters">
        <div className="select">
          <select id="sort" value={sortOption} onChange={handleSortChange}>
            <option value="name:asc">Sort by Name (A-Z)</option>
            <option value="name:desc">Sort by Name (Z-A)</option>
            <option value="shows_count:desc">Sort by Shows Count (High to Low)</option>
            <option value="shows_count:asc">Sort by Shows Count (Low to High)</option>
          </select>
        </div>
        <div className="select">
          <select id="first-char-filter" value={firstChar} onChange={handleFirstCharChange}>
            <option value="">All names</option>
            {FIRST_CHAR_LIST.map((char) => (
              <option key={char} value={char}>
                Names starting with {char}
              </option>
            ))}
          </select>
        </div>
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
          placeholder="Search venues"
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
        <title>Venues - Phish.in</title>
      </Helmet>
      <LayoutWrapper sidebarContent={sidebarContent}>
        <PhoneTitle title="Venues" />
        {isRefetching ? (
          <Loader />
        ) : (
          <>
            <Venues venues={venues} />
            <Pagination
              totalPages={totalPages}
              handlePageClick={handlePageClick}
              currentPage={page}
              perPage={tempPerPage}
              handlePerPageInputChange={handlePerPageInputChange}
              handlePerPageBlurOrEnter={handlePerPageBlurOrEnter}
            />
          </>
        )}
      </LayoutWrapper>
    </>
  );
};

export default VenueIndex;
