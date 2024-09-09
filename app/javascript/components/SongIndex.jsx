import React, { useEffect, useState } from "react";
import { formatNumber } from "./utils";
import LayoutWrapper from "./LayoutWrapper";
import Songs from "./Songs";
import ReactPaginate from "react-paginate";

const SongIndex = () => {
  const [songs, setSongs] = useState([]);
  const [page, setPage] = useState(0);
  const [totalPages, setTotalPages] = useState(1);
  const [totalEntries, setTotalEntries] = useState(0);
  const [sortOption, setSortOption] = useState("title:asc");

  useEffect(() => {
    const fetchSongs = async () => {
      try {
        const response = await fetch(
          `/api/v2/songs?page=${page + 1}&sort=${sortOption}`
        );
        const data = await response.json();

        setSongs(data.songs);
        setTotalPages(data.total_pages);
        setTotalEntries(data.total_entries);
      } catch (error) {
        console.error("Error fetching songs:", error);
      }
    };

    fetchSongs();
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
        <h1 className="title">Songs</h1>
        <h2 className="subtitle">{formatNumber(totalEntries)} total</h2>
        <div className="select is-fullwidth">
          <select value={sortOption} onChange={handleSortChange}>
            <option value="title:asc">Sort by Title (A-Z)</option>
            <option value="title:desc">Sort by Title (Z-A)</option>
            <option value="tracks_count:desc">Sort by Tracks Count (High to Low)</option>
            <option value="tracks_count:asc">Sort by Tracks Count (Low to High)</option>
          </select>
        </div>
      </div>
    }>
      <div className="section-title mobile-title">
        <div className="title-left">Songs</div>
        <span className="detail-right">{formatNumber(totalEntries)} total</span>
      </div>
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
  );
};

export default SongIndex;
