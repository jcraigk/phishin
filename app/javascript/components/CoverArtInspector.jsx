import { getAudioStatusFilter } from "./helpers/utils";

const buildShowsUrl = (page, perPage, audioStatusFilter) => {
  return `/api/v2/shows?page=${page}&per_page=${perPage}&audio_status=${audioStatusFilter}`;
};

export const coverArtInspectorLoader = async ({ request }) => {
  const url = new URL(request.url);
  const page = url.searchParams.get("page") || 1;
  const perPage = url.searchParams.get("per_page") || 50;
  const audioStatusFilter = getAudioStatusFilter();
  const response = await fetch(buildShowsUrl(page, perPage, audioStatusFilter));
  if (!response.ok) throw response;
  const data = await response.json();
  return {
    shows: data.shows,
    totalPages: data.total_pages,
    totalEntries: data.total_entries,
    page: parseInt(page, 10) - 1,
    perPage: parseInt(perPage)
  };
};

import React, { useState } from "react";
import { useLoaderData, useNavigate, useOutletContext } from "react-router-dom";
import { Helmet } from "react-helmet-async";
import LayoutWrapper from "./layout/LayoutWrapper";
import CoverArt from "./CoverArt";
import Pagination from "./controls/Pagination";
import { paginationHelper } from "./helpers/pagination";
import { formatNumber } from "./helpers/utils";

const CoverArtInspector = () => {
  const { shows, totalPages, totalEntries, page, perPage } = useLoaderData();
  const navigate = useNavigate();
  const { openAppModal, closeAppModal } = useOutletContext();
  const [selectedOption, setSelectedOption] = useState("coverArt");
  const {
    tempPerPage,
    handlePageClick,
    handlePerPageInputChange,
    handlePerPageBlurOrEnter
  } = paginationHelper(page, "", perPage);

  const handleOptionChange = (e) => {
    setSelectedOption(e.target.value);
  };

  const sidebarContent = (
    <div className="sidebar-content">
      <p className="sidebar-title">Cover Art</p>
      <p className="sidebar-subtitle">{formatNumber(totalEntries)} total</p>
      <div className="dropdown mt-3">
        <select id="coverArtOption" value={selectedOption} onChange={handleOptionChange} className="input">
          <option value="coverArt">Raw Cover Art</option>
          <option value="albumCover">Album Covers</option>
        </select>
      </div>
    </div>
  );

  return (
    <>
      <Helmet>
        <title>Cover Art - Phish.in</title>
      </Helmet>
              <LayoutWrapper sidebarContent={sidebarContent}>
            <div className="cover-art-inspector-container">
              {shows.map((show) => (
                <CoverArt
                  key={show.id}
                  coverArtUrls={show.cover_art_urls}
                  albumCoverUrl={show.album_cover_url}
                  openAppModal={openAppModal}
                  closeAppModal={closeAppModal}
                  size="medium"
                  css="cover-art-inspector"
                  selectedOption={selectedOption}
                            />
          ))}
        </div>
        <Pagination
          totalPages={totalPages}
          handlePageClick={handlePageClick}
          currentPage={page}
          perPage={tempPerPage}
          handlePerPageInputChange={handlePerPageInputChange}
          handlePerPageBlurOrEnter={handlePerPageBlurOrEnter}
        />
      </LayoutWrapper>
    </>
  );
};

export default CoverArtInspector;
