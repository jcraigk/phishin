import { authFetch } from "./helpers/utils";

export const coverArtInspectorLoader = async ({ request }) => {
  const url = new URL(request.url);
  const page = url.searchParams.get("page") || 1;
  const perPage = url.searchParams.get("per_page") || 50;

  try {
    const response = await authFetch(`/api/v2/shows?page=${page}&per_page=${perPage}`);
    if (!response.ok) throw response;
    const data = await response.json();
    return {
      shows: data.shows,
      totalPages: data.total_pages,
      totalEntries: data.total_entries,
      page: parseInt(page, 10) - 1,
      perPage: parseInt(perPage)
    };
  } catch (error) {
    throw new Response("Error fetching data", { status: 500 });
  }
};

import React, { useState } from "react";
import { useLoaderData, useNavigate, useOutletContext } from "react-router-dom";
import { Helmet } from "react-helmet-async";
import LayoutWrapper from "./layout/LayoutWrapper";
import CoverArt from "./CoverArt";
import Pagination from "./controls/Pagination";
import { paginationHelper } from "./helpers/pagination";

const CoverArtInspector = () => {
  const { shows, totalPages, totalEntries, page, perPage } = useLoaderData(); // Fetch the data from the loader
  const { openAppModal } = useOutletContext();
  const navigate = useNavigate();

  const {
    tempPerPage,
    handlePageClick,
    handlePerPageInputChange,
    handlePerPageBlurOrEnter
  } = paginationHelper(page, "", perPage);

  const sidebarContent = (
    <div className="sidebar-content">
      <p className="sidebar-title">Album Covers</p>
      <p className="sidebar-subtitle">{totalEntries} total</p>
    </div>
  );

  return (
    <>
      <Helmet>
        <title>Album Covers - Phish.in</title>
      </Helmet>
      <LayoutWrapper sidebarContent={sidebarContent}>
        <div className="grid-container">
          {shows.map((show) => (
            <CoverArt
              key={show.id}
              coverArtUrls={show.cover_art_urls}
              albumCoverUrl={show.album_cover_url}
              openAppModal={openAppModal}
              size="medium"
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
