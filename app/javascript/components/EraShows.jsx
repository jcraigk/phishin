import { authFetch } from "./helpers/utils";
import React, { useEffect, useState, useCallback } from "react";
import { useLoaderData, Link, useOutletContext } from "react-router-dom";
import { Helmet } from "react-helmet-async";
import LayoutWrapper from "./layout/LayoutWrapper";
import Shows from "./Shows";
import Loader from "./controls/Loader";
import { useAudioFilteredData } from "./hooks/useAudioFilteredData";
import { getAudioStatusFilter } from "./helpers/utils";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faList, faTh, faCircleChevronLeft, faCircleChevronRight, faSortAmountDown, faSortAmountUp } from "@fortawesome/free-solid-svg-icons";

const buildShowsUrl = (year, audioStatusFilter) => {
  let url = `/api/v2/shows?per_page=1000&audio_status=${audioStatusFilter}`;

  if (year.includes("-")) {
    url += `&year_range=${year}`;
  } else {
    url += `&year=${year}`;
  }

  return url;
};

export const eraShowsLoader = async ({ params }) => {
  const { year } = params;

  const audioStatusFilter = getAudioStatusFilter();
  const url = buildShowsUrl(year, audioStatusFilter);

  const response = await authFetch(url);
  if (!response.ok) throw response;
  const data = await response.json();
  return { shows: data.shows, year };
};

const EraShows = () => {
  const { shows: initialShows, year } = useLoaderData();
  const { viewMode, setViewMode, sortOption, setSortOption } = useOutletContext();
  const [yearsData, setYearsData] = useState(null);

  // Simplified fetch function for audio filter integration
  const fetchShows = useCallback(async (audioStatusFilter) => {
    const url = buildShowsUrl(year, audioStatusFilter);
    const response = await authFetch(url);
    const data = await response.json();
    return data.shows;
  }, [year]);

  const { data: shows, isLoading } = useAudioFilteredData(initialShows, fetchShows, [year]);

  const sortedShows = [...shows].sort((a, b) => {
    if (sortOption === "asc") {
      return new Date(a.date) - new Date(b.date);
    } else {
      return new Date(b.date) - new Date(a.date);
    }
  });

  useEffect(() => {
    const fetchYearsData = async () => {
      const response = await fetch("/api/v2/years");
      const data = await response.json();
      setYearsData(data);
    };
    fetchYearsData();
  }, []);

  const renderViewToggleButtons = () => (
    <div className="view-toggle buttons has-addons">
      <button
        className={`button ${viewMode === "list" ? "is-selected" : ""}`}
        onClick={() => setViewMode("list")}
        disabled={viewMode === "list"}
      >
        <span className="icon">
          <FontAwesomeIcon icon={faList} />
        </span>
      </button>
      <button
        className={`button ${viewMode === "grid" ? "is-selected" : ""}`}
        onClick={() => setViewMode("grid")}
        disabled={viewMode === "grid"}
      >
        <span className="icon">
          <FontAwesomeIcon icon={faTh} />
        </span>
      </button>
    </div>
  );

  const renderSortButtons = () => (
    <div className="view-toggle buttons has-addons">
      <button
        className={`button ${sortOption === "desc" ? "is-selected" : ""}`}
        onClick={() => setSortOption("desc")}
        disabled={sortOption === "desc"}
      >
        <span className="icon">
          <FontAwesomeIcon icon={faSortAmountDown} />
        </span>
      </button>
      <button
        className={`button ${sortOption === "asc" ? "is-selected" : ""}`}
        onClick={() => setSortOption("asc")}
        disabled={sortOption === "asc"}
      >
        <span className="icon">
          <FontAwesomeIcon icon={faSortAmountUp} />
        </span>
      </button>
    </div>
  );

  const yearLinks = () => {
    if (!yearsData) return null;
    const yearIndex = yearsData.findIndex((y) => y.period === year);
    const previousYear = yearsData[yearIndex - 1]?.period;
    const nextYear = yearsData[yearIndex + 1]?.period;

    return (
      <div className="mt-5">
        {previousYear && (
          <Link to={`/${previousYear}`}>
            <FontAwesomeIcon icon={faCircleChevronLeft} className="mr-1" />
            Previous year
          </Link>
        )}
        {nextYear && (
          <Link to={`/${nextYear}`} className="is-pulled-right">
            Next year
            <FontAwesomeIcon icon={faCircleChevronRight} className="ml-1" />
          </Link>
        )}
      </div>
    );
  };

  const sidebarContent = (
    <div className="sidebar-content">
      <p className="sidebar-title">{year}</p>
      <p className="sidebar-subtitle">{sortedShows.length} shows</p>

      <div className="buttons mb-0">
        {renderViewToggleButtons()}
        {renderSortButtons()}
      </div>

      <div className="hidden-mobile">{yearLinks()}</div>
    </div>
  );

  return (
    <>
      <Helmet>
        <title>{year} - Phish.in</title>
      </Helmet>
      <LayoutWrapper sidebarContent={sidebarContent}>
        {isLoading ? (
          <Loader />
        ) : (
          <>
            <div className="display-phone-only">
              <div className="buttons mt-2 mb-2">
                {renderViewToggleButtons()}
                {renderSortButtons()}
              </div>
            </div>
            <Shows shows={sortedShows} tourHeaders={true} viewMode={viewMode} />
            {yearLinks()}
          </>
        )}
      </LayoutWrapper>
    </>
  );
};

export default EraShows;
