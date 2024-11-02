import { authFetch } from "./helpers/utils";
import React, { useState, useEffect } from "react";
import { useLoaderData, Link } from "react-router-dom";
import { Helmet } from "react-helmet-async";
import LayoutWrapper from "./layout/LayoutWrapper";
import Shows from "./Shows";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faList, faTh, faCircleChevronLeft, faCircleChevronRight } from "@fortawesome/free-solid-svg-icons";

export const eraShowsLoader = async ({ params }) => {
  const { year } = params;
  let url = `/api/v2/shows?per_page=1000`;

  if (year.includes("-")) {
    url += `&year_range=${year}`;
  } else {
    url += `&year=${year}`;
  }

  const response = await authFetch(url);
  if (!response.ok) throw response;
  const data = await response.json();
  return { shows: data.shows, year };
};

const EraShows = () => {
  const { shows, year } = useLoaderData();
  const [viewMode, setViewMode] = useState("grid");
  const [yearsData, setYearsData] = useState(null);

  useEffect(() => {
    const fetchYearsData = async () => {
      try {
        const response = await fetch("/api/v2/years");
        if (!response.ok) throw response;
        const data = await response.json();
        setYearsData(data);
      } catch (error) {
        console.error("Error fetching years data", error);
      }
    };
    fetchYearsData();
  }, []);

  const handleViewModeChange = (mode) => {
    setViewMode(mode);
  };

  const renderViewToggleButtons = () => (
    <div className="view-toggle buttons has-addons">
      <button
        className={`button ${viewMode === "list" ? "is-selected" : ""}`}
        onClick={() => handleViewModeChange("list")}
        disabled={viewMode === "list"}
      >
        <span className="icon">
          <FontAwesomeIcon icon={faList} />
        </span>
      </button>
      <button
        className={`button ${viewMode === "grid" ? "is-selected" : ""}`}
        onClick={() => handleViewModeChange("grid")}
        disabled={viewMode === "grid"}
      >
        <span className="icon">
          <FontAwesomeIcon icon={faTh} />
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
      <p className="sidebar-subtitle">{shows.length} shows</p>
      {renderViewToggleButtons()}
      <div className="hidden-mobile">{yearLinks()}</div>
    </div>
  );

  return (
    <>
      <Helmet>
        <title>{year} - Phish.in</title>
      </Helmet>
      <LayoutWrapper sidebarContent={sidebarContent}>
        <div className="display-phone-only">{renderViewToggleButtons()}</div>
        <Shows shows={shows} tourHeaders={true} viewMode={viewMode} />
        {yearLinks()}
      </LayoutWrapper>
    </>
  );
};

export default EraShows;
