import React, { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import ReactPaginate from "react-paginate";
import { formatNumber } from "./utils";
import LayoutWrapper from "./LayoutWrapper";

const Venues = () => {
  const [venues, setVenues] = useState([]);
  const [page, setPage] = useState(0);
  const [totalPages, setTotalPages] = useState(1);
  const [totalEntries, setTotalEntries] = useState(0);
  const [sortOption, setSortOption] = useState("name:asc");

  useEffect(() => {
    const fetchVenues = async () => {
      try {
        const response = await fetch(
          `/api/v2/venues?page=${page + 1}&sort=${sortOption}`
        );
        const data = await response.json();

        setVenues(data.venues);
        setTotalPages(data.total_pages);
        setTotalEntries(data.total_entries);
      } catch (error) {
        console.error("Error fetching venues:", error);
      }
    };

    fetchVenues();
  }, [page, sortOption]);

  const handlePageClick = (data) => {
    setPage(data.selected);
  };

  const handleSortChange = (event) => {
    setSortOption(event.target.value);
    setPage(0);
  };

  return (
    <LayoutWrapper sidebarContent={
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
      </div>
    }>
      <div className="section-title mobile-title">
        <div className="title-left">Venues</div>
        <span className="detail-right">{formatNumber(totalEntries)} total</span>
      </div>
      <ul>
        {venues.map((venue) => (
          <Link to={`/venues/${venue.slug}`} key={venue.slug} className="list-item-link">
            <li className="list-item">
              <span className="leftside-primary">{venue.name}</span>
              <span className="leftside-secondary">{venue.location}</span>
              <span className="rightside-primary">{formatNumber(venue.shows_count)} shows</span>
            </li>
          </Link>
        ))}
      </ul>
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

export default Venues;
