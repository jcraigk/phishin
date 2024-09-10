import React, { useEffect, useState } from "react";
import { useParams, Link } from "react-router-dom";
import LayoutWrapper from "./LayoutWrapper";
import Tracks from "./Tracks";
import ReactPaginate from "react-paginate";

const TagTracks = () => {
  const { tag_slug } = useParams();
  const [tracks, setTracks] = useState([]);
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

    const fetchTracks = async () => {
      try {
        const response = await fetch(`/api/v2/tracks?tag_slug=${tag_slug}&sort=${sortOption}&page=${page + 1}&per_page=${itemsPerPage}`);
        const data = await response.json();
        setTracks(data.tracks);
        setTotalPages(data.total_pages); // Assuming the API returns `total_pages`
      } catch (error) {
        console.error("Error fetching tracks:", error);
      }
    };

    fetchTagName();
    fetchTracks();
  }, [tag_slug, sortOption, page]);

  const handleSortChange = (event) => {
    setSortOption(event.target.value);
    setPage(0);
  };

  const handlePageClick = (data) => {
    setPage(data.selected);
  };

  const sidebarContent = (
    <div className="sidebar-content">
      <h1 className="title">Tracks Tagged with "{tagName}"</h1>
      <div className="select is-fullwidth mb-5">
        <select value={sortOption} onChange={handleSortChange}>
          <option value="date:desc">Sort by Date (Newest First)</option>
          <option value="date:asc">Sort by Date (Oldest First)</option>
          <option value="likes_count:desc">Sort by Title (A-Z)</option>
          <option value="likes_count:asc">Sort by Title (Z-A)</option>
          <option value="likes_count:desc">Sort by Likes (Most to Least)</option>
          <option value="likes_count:asc">Sort by Likes (Least to Most)</option>
          <option value="duration:desc">Sort by Duration (Longest First)</option>
          <option value="duration:asc">Sort by Duration (Shortest First)</option>
        </select>
      </div>
    </div>
  );

  return (
    <LayoutWrapper sidebarContent={sidebarContent}>
      <Tracks tracks={tracks} numbering={false} set_headers={false} show_dates={true} />
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

export default TagTracks;
