export const songIndexLoader = async ({ request }) => {
  const url = new URL(request.url);
  const page = url.searchParams.get("page") || 1;
  const sortOption = url.searchParams.get("sort") || "title:asc";

  try {
    const response = await fetch(`/api/v2/songs?page=${page}&sort=${sortOption}`);
    if (!response.ok) response;
    const data = await response.json();
    return {
      songs: data.songs,
      totalPages: data.total_pages,
      totalEntries: data.total_entries,
      page: parseInt(page, 10) - 1,
      sortOption
    };
  } catch (error) {
    throw new Response("Error fetching data", { status: 500 });
  }
};

import React from "react";
import { useLoaderData, useNavigate } from "react-router-dom";
import { formatNumber } from "./utils";
import LayoutWrapper from "./LayoutWrapper";
import Songs from "./Songs";
import ReactPaginate from "react-paginate";

const SongIndex = () => {
  const { songs, totalPages, totalEntries, page, sortOption } = useLoaderData();
  const navigate = useNavigate();

  const handlePageClick = (data) => {
    navigate(`?page=${data.selected + 1}&sort=${sortOption}`);
  };

  const handleSortChange = (event) => {
    navigate(`?page=1&sort=${event.target.value}`);
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
