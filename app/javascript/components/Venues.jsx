import React, { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import ReactPaginate from "react-paginate";
import { formatNumber } from "./utils";
import LayoutWrapper from "./LayoutWrapper";

const Venues = () => {
  const [venues, setVenues] = useState([]);
  const [page, setPage] = useState(0); // react-paginate uses 0-based index
  const [totalPages, setTotalPages] = useState(1);
  const [totalEntries, setTotalEntries] = useState(0);

  useEffect(() => {
    const fetchVenues = async () => {
      try {
        const response = await fetch(`/api/v2/venues?page=${page + 1}&sort=name:asc`);
        const data = await response.json();

        setVenues(data.venues);
        setTotalPages(data.total_pages);
        setTotalEntries(data.total_entries);
      } catch (error) {
        console.error("Error fetching venues:", error);
      }
    };

    fetchVenues();
  }, [page]);

  const handlePageClick = (data) => {
    setPage(data.selected);
  };

  const sidebarContent = (
    <div className="sidebar-content">
      <h1 className="title">Venues</h1>
      <p>Filters coming...</p>
    </div>
  );

  return (
    <LayoutWrapper sidebarContent={sidebarContent}>
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
      />
    </LayoutWrapper>
  );
};

export default Venues;
