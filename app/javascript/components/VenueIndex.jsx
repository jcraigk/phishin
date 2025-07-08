export const venueIndexLoader = async ({ request }) => {
  const url = new URL(request.url);
  const page = url.searchParams.get("page") || 1;
  const sortOption = url.searchParams.get("sort") || "name:asc";
  const firstChar = url.searchParams.get("first_char") || "";
  const perPage = url.searchParams.get("per_page") || 10;

  // Check localStorage for audio filter setting
  const hideMissingAudio = JSON.parse(localStorage.getItem('hideMissingAudio') || 'true');
  const audioStatusFilter = hideMissingAudio ? 'complete_or_partial' : 'any';

  try {
    const response = await fetch(`/api/v2/venues?page=${page}&sort=${sortOption}&first_char=${encodeURIComponent(firstChar)}&per_page=${perPage}&audio_status=${audioStatusFilter}`);
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

import React, { useState, useEffect, useRef } from "react";
import { useLoaderData, useNavigate } from "react-router-dom";
import { Helmet } from "react-helmet-async";
import { formatNumber } from "./helpers/utils";
import LayoutWrapper from "./layout/LayoutWrapper";
import Venues from "./Venues";
import PhoneTitle from "./PhoneTitle";
import Pagination from "./controls/Pagination";
import { paginationHelper } from "./helpers/pagination";
import { useAudioFilter } from "./contexts/AudioFilterContext";
import Loader from "./controls/Loader";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faSearch } from "@fortawesome/free-solid-svg-icons";

const FIRST_CHAR_LIST = ["#", ...Array.from({ length: 26 }, (_, i) => String.fromCharCode(65 + i))];

const VenueIndex = () => {
  const initialData = useLoaderData();
  const [venues, setVenues] = useState(initialData.venues);
  const [totalPages, setTotalPages] = useState(initialData.totalPages);
  const [totalEntries, setTotalEntries] = useState(initialData.totalEntries);

  const { page, perPage, sortOption, firstChar } = initialData;
  const navigate = useNavigate();
  const [searchTerm, setSearchTerm] = useState("");
  const { hideMissingAudio, getAudioStatusFilter } = useAudioFilter();

  // Track the initial filter state to prevent unnecessary re-fetches
  const initialFilterRef = useRef(null);
  const hasInitialized = useRef(false);

  const {
    tempPerPage,
    handlePageClick,
    handleSortChange,
    handlePerPageInputChange,
    handlePerPageBlurOrEnter
    } = paginationHelper(page, sortOption, perPage, firstChar);

  // Single fetch function for all data fetching needs
  const fetchVenues = async (fetchPage = page + 1, fetchSort = sortOption, fetchFirstChar = firstChar, fetchPerPage = perPage, audioStatusFilter = getAudioStatusFilter()) => {
    try {
      const response = await fetch(`/api/v2/venues?page=${fetchPage}&sort=${fetchSort}&first_char=${encodeURIComponent(fetchFirstChar)}&per_page=${fetchPerPage}&audio_status=${audioStatusFilter}`);
      if (!response.ok) throw response;
      const data = await response.json();

      setVenues(data.venues);
      setTotalPages(data.total_pages);
      setTotalEntries(data.total_entries);

      return data;
    } catch (error) {
      console.error("Error fetching venues:", error);
      throw error;
    }
  };

  // Re-fetch data when audio filter changes
  useEffect(() => {
    console.log('VenueIndex useEffect triggered');
    const currentAudioStatusFilter = getAudioStatusFilter();
    console.log('Current filter:', currentAudioStatusFilter, 'Initial filter:', initialFilterRef.current, 'Has initialized:', hasInitialized.current);

    // Initialize the ref on first run
    if (!hasInitialized.current) {
      console.log('Initializing filter ref');
      initialFilterRef.current = currentAudioStatusFilter;
      hasInitialized.current = true;
      return;
    }

    // If the filter hasn't changed, don't re-fetch
    if (currentAudioStatusFilter === initialFilterRef.current) {
      console.log('Filter unchanged, skipping fetch');
      return;
    }

            console.log('Filter changed, starting fetch');
    const handleFilterChange = async () => {
      try {
        // Reset to page 1 when filter changes
        await fetchVenues(1, sortOption, firstChar, perPage, currentAudioStatusFilter);

        // Update the ref to track the new filter state
        initialFilterRef.current = currentAudioStatusFilter;

        // Don't navigate when filter changes - just update the data
        // The URL will be updated next time the user interacts with pagination
      } catch (error) {
        // Error already logged in fetchVenues
      }
    };

    handleFilterChange();
  }, [hideMissingAudio, sortOption, firstChar, perPage, navigate]);

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
