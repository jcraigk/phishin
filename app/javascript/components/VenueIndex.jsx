export const venueIndexLoader = async ({ request }) => {
  const url = new URL(request.url);
  const page = url.searchParams.get("page") || 1;
  const sortOption = url.searchParams.get("sort") || "name:asc";
  const firstChar = url.searchParams.get("first_char") || "";
  const perPage = url.searchParams.get("per_page") || 10;

  try {
    const response = await fetch(`/api/v2/venues?page=${page}&sort=${sortOption}&first_char=${encodeURIComponent(firstChar)}&per_page=${perPage}`);
    if (!response.ok) throw response;
    const data = await response.json();
    return {
      venues: data.venues,
      totalPages: data.total_pages,
      totalEntries: data.total_entries,
      page: parseInt(page, 10) - 1,
      sortOption,
      firstChar,
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
import Venues from "./Venues";
import Pagination from "./controls/Pagination";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faSearch } from "@fortawesome/free-solid-svg-icons";

const FIRST_CHAR_LIST = ["#", ...Array.from({ length: 26 }, (_, i) => String.fromCharCode(65 + i))];

const VenueIndex = () => {
  const { venues, totalPages, totalEntries, page, perPage, sortOption, firstChar } = useLoaderData();
  const navigate = useNavigate();
  const [searchTerm, setSearchTerm] = useState("");
  const [tempPerPage, setTempPerPage] = useState(perPage);

  const handlePageClick = (data) => {
    navigate(`?page=${data.selected + 1}&sort=${sortOption}&first_char=${firstChar}&per_page=${perPage}`);
  };

  const handleSortChange = (event) => {
    navigate(`?page=1&sort=${event.target.value}&first_char=${firstChar}&per_page=${perPage}`);
  };

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

  const handlePerPageInputChange = (e) => {
    setTempPerPage(e.target.value); // Only update temp value
  };

  const submitPerPage = () => {
    if (tempPerPage && !isNaN(tempPerPage) && tempPerPage > 0) {
      navigate(`?page=1&sort=${sortOption}&first_char=${firstChar}&per_page=${tempPerPage}`);
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
      <p className="sidebar-title">Venues</p>
      <p className="sidebar-subtitle">{formatNumber(totalEntries)} total</p>

      <div className="sidebar-filters">
        <div className="select">
          <select value={sortOption} onChange={handleSortChange}>
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
        <Venues venues={venues} />
        <Pagination
          totalPages={totalPages}
          handlePageClick={handlePageClick}
          currentPage={page}
          perPage={tempPerPage}
          handlePerPageInputChange={handlePerPageInputChange}
          handlePerPageBlurOrEnter={handlePerPageBlurOrEnter}
        />
      </LayoutWrapper>
    </>
  );
};

export default VenueIndex;
