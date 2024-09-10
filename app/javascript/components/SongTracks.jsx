import React, { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import LayoutWrapper from "./LayoutWrapper";
import Tracks from "./Tracks";
import ReactPaginate from "react-paginate";

const SongTracks = () => {
  const { song_slug } = useParams();
  const [tracks, setTracks] = useState([]);
  const [songTitle, setSongTitle] = useState("");
  const [originalInfo, setOriginalInfo] = useState("");
  const [totalEntries, setTotalEntries] = useState(0);
  const [sortOption, setSortOption] = useState("date:desc");
  const [page, setPage] = useState(0);
  const [totalPages, setTotalPages] = useState(1);
  const itemsPerPage = 10;

  useEffect(() => {
    const fetchSongTitle = async () => {
      try {
        const response = await fetch(`/api/v2/songs/${song_slug}`);
        const data = await response.json();
        setSongTitle(data.title);

        if (data.original) {
          setOriginalInfo("Original composition");
        } else {
          setOriginalInfo(`Original Artist: ${data.artist}`);
        }
      } catch (error) {
        console.error("Error fetching song:", error);
      }
    };

    const fetchTracks = async () => {
      try {
        const response = await fetch(`/api/v2/tracks?song_slug=${song_slug}&sort=${sortOption}&page=${page + 1}&per_page=${itemsPerPage}`);
        const data = await response.json();
        setTracks(data.tracks);
        setTotalEntries(data.total_entries);
        setTotalPages(data.total_pages);
      } catch (error) {
        console.error("Error fetching tracks:", error);
      }
    };

    fetchSongTitle();
    fetchTracks();
  }, [song_slug, sortOption, page]);

  const handleSortChange = (event) => {
    setSortOption(event.target.value);
    setPage(0);
  };

  const handlePageClick = (data) => {
    setPage(data.selected);
  };

  const sidebarContent = (
    <div className="sidebar-content">
      <h1 className="title">{songTitle}</h1>
      <p className="subtitle">{originalInfo}</p>
      <p className="mb-5">Total Tracks: {totalEntries}</p>
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

export default SongTracks;
