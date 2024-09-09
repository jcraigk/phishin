import React, { useEffect, useState } from "react";
import { useParams, Link } from "react-router-dom";
import LayoutWrapper from "./LayoutWrapper";
import Shows from "./Shows";
import ReactPaginate from "react-paginate";

const TagShows = ({ user }) => {
  const { tag_slug } = useParams();
  const [shows, setShows] = useState([]);
  const [tagName, setTagName] = useState("");
  const [sortOption, setSortOption] = useState("date:desc");
  const [page, setPage] = useState(0);
  const [totalPages, setTotalPages] = useState(1);
  const itemsPerPage = 10;

  useEffect(() => {
    const fetchTagName = async () => {
      try {
        const response = await fetch(`/api/v2/tags`);
        const data = await response.json();
        const tag = data.find(t => t.slug === tag_slug);
        if (tag) {
          setTagName(tag.name);
        }
      } catch (error) {
        console.error("Error fetching tag:", error);
      }
    };

    const fetchShows = async () => {
      try {
        const response = await fetch(`/api/v2/shows?tag_slug=${tag_slug}&sort=${sortOption}&page=${page + 1}&per_page=${itemsPerPage}`);
        const data = await response.json();
        setShows(data.shows);
        setTotalPages(data.total_pages); // Assuming the API returns `total_pages`
      } catch (error) {
        console.error("Error fetching shows:", error);
      }
    };

    fetchTagName();
    fetchShows();
  }, [tag_slug, sortOption, page]);

  const handleSortChange = (event) => {
    setSortOption(event.target.value);
    setPage(0); // Reset to first page on sort change
  };

  const handlePageClick = (data) => {
    setPage(data.selected);
  };

  const sidebarContent = (
    <div className="sidebar-content">
      <h1 className="title">Shows Tagged with "{tagName}"</h1>
      <div className="select is-fullwidth mb-5">
        <select value={sortOption} onChange={handleSortChange}>
          <option value="date:desc">Sort by Date (Newest First)</option>
          <option value="date:asc">Sort by Date (Oldest First)</option>
          <option value="likes_count:desc">Sort by Title (A-Z)</option>
          <option value="likes_count:asc">Sort by Title (Z-A)</option>
          <option value="likes_count:desc">Sort by Likes (Most to Least)</option>
          <option value="likes_count:asc">Sort by Likes (Least to Most)</option>
        </select>
      </div>
      {!user && (
        <div className="sidebar-callout">
          <Link to="/login" className="button">
            Login to contribute!
          </Link>
        </div>
      )}
    </div>
  );

  return (
    <LayoutWrapper sidebarContent={sidebarContent}>
      {/* Pass setShows along with shows */}
      <Shows shows={shows} setShows={setShows} numbering={false} set_headers={false} />
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

export default TagShows;
