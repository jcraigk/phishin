import React, { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import LayoutWrapper from "./LayoutWrapper";
import Tracks from "./Tracks";
import ReactPaginate from "react-paginate";
import { useNotification } from "./NotificationContext";

const MyTracks = () => {
  const [tracks, setTracks] = useState([]);
  const [sortOption, setSortOption] = useState("date:desc");
  const [page, setPage] = useState(0);
  const [totalPages, setTotalPages] = useState(1);
  const itemsPerPage = 10;
  const { setAlert } = useNotification();

  useEffect(() => {
    const fetchLikedTracks = async () => {
      const jwt = localStorage.getItem("jwt");
      if (!jwt) {
        setAlert("Please log in to view your liked tracks.");
        return;
      }

      try {
        const response = await fetch(
          `/api/v2/tracks?liked_by_user=true&sort=${sortOption}&page=${page + 1}&per_page=${itemsPerPage}`,
          {
            headers: {
              "Content-Type": "application/json",
              "X-Auth-Token": jwt,
            },
          }
        );
        const data = await response.json();
        setTracks(data.tracks);
        setTotalPages(data.total_pages);
      } catch (error) {
        console.error("Error fetching liked tracks:", error);
      }
    };

    fetchLikedTracks();
  }, [sortOption, page]);

  const handleSortChange = (event) => {
    setSortOption(event.target.value);
    setPage(0); // Reset to first page on sort change
  };

  const handlePageClick = (data) => {
    setPage(data.selected);
  };

  const sidebarContent = (
    <div className="sidebar-content">
      <h1 className="title">My Tracks</h1>
      <div className="select is-fullwidth mb-5">
        <select value={sortOption} onChange={handleSortChange}>
          <option value="date:desc">Sort by Date (Newest First)</option>
          <option value="date:asc">Sort by Date (Oldest First)</option>
          <option value="likes_count:desc">Sort by Likes (Most to Least)</option>
          <option value="likes_count:asc">Sort by Likes (Least to Most)</option>
          <option value="duration:desc">Sort by Duration (Longest First)</option>
          <option value="duration:asc">Sort by Duration (Shortest First)</option>
        </select>
      </div>
      {!localStorage.getItem("jwt") && (
        <div className="sidebar-callout">
          <Link to="/login" className="button">
            Login to see your liked tracks!
          </Link>
        </div>
      )}
    </div>
  );

  return (
    <LayoutWrapper sidebarContent={sidebarContent}>
      <Tracks tracks={tracks} setTracks={setTracks} numbering={false} set_headers={false} show_dates={true} />
      {totalPages > 1 && (
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
      )}
    </LayoutWrapper>
  );
};

export default MyTracks;
