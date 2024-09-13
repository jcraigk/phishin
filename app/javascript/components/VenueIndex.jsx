import React, { useEffect, useState } from "react";
import ReactPaginate from "react-paginate";
import { formatNumber } from "./utils";
import LayoutWrapper from "./LayoutWrapper";
import Venues from "./Venues";

// List of first characters for the filter (A-Z and # for numbers)
const FIRST_CHAR_LIST = ["#", ...Array.from({ length: 26 }, (_, i) => String.fromCharCode(65 + i))];

const VenueIndex = () => {
  const [venues, setVenues] = useState([]);
  const [page, setPage] = useState(0);
  const [totalPages, setTotalPages] = useState(1);
  const [totalEntries, setTotalEntries] = useState(0);
  const [sortOption, setSortOption] = useState("name:asc");
  const [firstChar, setFirstChar] = useState("");

  useEffect(() => {
    const fetchVenues = async () => {
      try {
        const encodedFirstChar = encodeURIComponent(firstChar);
        const response = await fetch(
          `/api/v2/venues?page=${page + 1}&sort=${sortOption}&first_char=${encodedFirstChar}`
        );

        if (!response.ok) {
          const errorData = await response.json();
          throw new Error(errorData.error);
        }

        const data = await response.json();

        setVenues(data.venues);
        setTotalPages(data.total_pages);
        setTotalEntries(data.total_entries);
      } catch (error) {
        console.error("Error fetching venues:", error.message);
      }
    };

    fetchVenues();
  }, [page, sortOption, firstChar]);

  const handlePageClick = (data) => {
    setPage(data.selected);
  };

  const handleSortChange = (event) => {
    setSortOption(event.target.value);
    setPage(0); // Reset to first page when sort changes
  };

  const handleFirstCharChange = (event) => {
    setFirstChar(event.target.value);
    setPage(0); // Reset to first page when filter changes
  };

  return (
    <LayoutWrapper
      sidebarContent={
        <div className="sidebar-content">
          <h1 className="title">Venues</h1>
          <h2 className="subtitle">{formatNumber(totalEntries)} total</h2>
          <div className="select is-fullwidth">
            <select value={sortOption} onChange={handleSortChange}>
              <option value="name:asc">Sort by Name (A-Z)</option>
              <option value="name:desc">Sort by Name (Z-A)</option>
              <option value="shows_count:desc">Sort by Shows Count (High to Low)</option>
              <option value="shows_count:asc">Sort by Shows Count (Low to High)</option>
            </select>
          </div>
          <div className="select is-fullwidth mt-2">
            <select
              id="first-char-filter"
              value={firstChar}
              onChange={handleFirstCharChange}
            >
              <option value="">All names</option>
              {FIRST_CHAR_LIST.map((char) => (
                <option key={char} value={char}>
                  Names starting with {char}
                </option>
              ))}
            </select>
          </div>
        </div>
      }
    >
      {/* <div className="section-title mobile-title">
        <div className="title-left">Venues</div>
        <span className="detail-right">{formatNumber(totalEntries)} total</span>
      </div> */}
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
  );
};

export default VenueIndex;
