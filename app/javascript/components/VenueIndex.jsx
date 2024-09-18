export const venueIndexLoader = async ({ request }) => {
  const url = new URL(request.url);
  const page = url.searchParams.get("page") || 1;
  const sortOption = url.searchParams.get("sort") || "name:asc";
  const firstChar = url.searchParams.get("first_char") || "";

  try {
    const response = await fetch(`/api/v2/venues?page=${page}&sort=${sortOption}&first_char=${encodeURIComponent(firstChar)}`);
    if (!response.ok) response;
    const data = await response.json();
    return {
      venues: data.venues,
      totalPages: data.total_pages,
      totalEntries: data.total_entries,
      page: parseInt(page, 10) - 1,
      sortOption,
      firstChar
    };
  } catch (error) {
    throw new Response("Error fetching data", { status: 500 });
  }
};

import React from "react";
import { useLoaderData, useNavigate } from "react-router-dom";
import ReactPaginate from "react-paginate";
import { formatNumber } from "./utils";
import LayoutWrapper from "./LayoutWrapper";
import Venues from "./Venues";
import { Helmet } from 'react-helmet-async';

const FIRST_CHAR_LIST = ["#", ...Array.from({ length: 26 }, (_, i) => String.fromCharCode(65 + i))];

const VenueIndex = () => {
  const { venues, totalPages, totalEntries, page, sortOption, firstChar } = useLoaderData();
  const navigate = useNavigate();

  const handlePageClick = (data) => {
    navigate(`?page=${data.selected + 1}&sort=${sortOption}&first_char=${firstChar}`);
  };

  const handleSortChange = (event) => {
    navigate(`?page=1&sort=${event.target.value}&first_char=${firstChar}`);
  };

  const handleFirstCharChange = (event) => {
    navigate(`?page=1&sort=${sortOption}&first_char=${event.target.value}`);
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
    </div>
  );

  return (
    <>
      <Helmet>
        <title>Venues - Phish.in</title>
      </Helmet>
      <LayoutWrapper sidebarContent={sidebarContent}>
        <Venues venues={venues} />
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

export default VenueIndex;
