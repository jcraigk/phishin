export const erasLoader = async () => {
  try {
    const response = await fetch("/api/v2/years");
    if (!response.ok) throw response;
    const data = await response.json();

    // Calculate base totals from backend data
    const totalShowsWithAudio = data.reduce((sum, year) => sum + (year.shows_with_audio_count || 0), 0);
    const totalDuration = data.reduce((sum, year) => sum + (year.shows_duration || 0), 0);

    const erasData = data.reduce((acc, yearData) => {
      const {
        era,
        period,
        shows_count = 0,
        shows_with_audio_count = 0,
        shows_duration = 0,
        venues_count = 0,
        venues_with_audio_count = 0,
        cover_art_urls = {}
      } = yearData;

      if (!acc[era]) {
        acc[era] = {
          periods: [],
          total_shows: 0,
          total_shows_with_audio: 0,
          total_duration: 0
        };
      }

      acc[era].periods.push({
        period,
        shows_count,
        shows_with_audio_count,
        venues_count,
        venues_with_audio_count,
        cover_art_urls,
        display_count: shows_with_audio_count // Default to shows with audio
      });

      acc[era].total_shows += shows_with_audio_count;
      acc[era].total_shows_with_audio += shows_with_audio_count;
      acc[era].total_duration += shows_duration;

      return acc;
    }, {});

    Object.keys(erasData).forEach((era) => {
      erasData[era].periods.sort((a, b) => b.period.localeCompare(a.period));
    });

    // Add global totals to the data
    erasData._totals = {
      totalShows: totalShowsWithAudio, // Default to shows with audio
      totalShowsWithAudio,
      totalDuration
    };

    return erasData;
  } catch (error) {
    console.error("Error loading eras data:", error);
    throw error;
  }
};

import React, { useState } from "react";
import { Link, useLoaderData, useOutletContext } from "react-router-dom";
import { formatNumber } from "./helpers/utils";
import LayoutWrapper from "./layout/LayoutWrapper";
import MobileApps from "./pages/MobileApps";
import GitHubButton from "./pages/GitHubButton";
import DiscordButton from "./pages/DiscordButton";
import CoverArt from "./CoverArt";
import { useAudioFilter } from "./contexts/AudioFilterContext";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faList, faTh, faSortAmountDown, faSortAmountUp } from "@fortawesome/free-solid-svg-icons";

const Eras = () => {
  const initialEras = useLoaderData();
  const [eras, setEras] = useState(initialEras);
  const { viewMode, setViewMode, sortOption, setSortOption } = useOutletContext();
  const { showMissingAudio } = useAudioFilter();

  // Calculate display values based on current filter state
  const getDisplayErasData = () => {
    const rawEras = { ...eras };

    // Recalculate totals based on current filter
    let totalShows = 0;
    let totalDuration = 0;

    Object.keys(rawEras).forEach((era) => {
      if (era === '_totals') return;

      rawEras[era].total_shows = 0;
      rawEras[era].periods.forEach((period) => {
        const displayCount = showMissingAudio ? period.shows_count : period.shows_with_audio_count;
        const displayVenuesCount = showMissingAudio ? period.venues_count : period.venues_with_audio_count;
        period.display_count = displayCount;
        period.display_venues_count = displayVenuesCount;
        rawEras[era].total_shows += displayCount;
        totalShows += displayCount;
      });
    });

    // Keep original total duration
    totalDuration = rawEras._totals?.totalDuration || 0;

    rawEras._totals = {
      ...rawEras._totals,
      totalShows,
      totalDuration,
      showMissingAudio
    };

    return rawEras;
  };

  const displayEras = getDisplayErasData();

  // Use pre-calculated totals from the backend with fallback values
  const totals = displayEras._totals || {};
  const { totalShows = 0, totalShowsWithAudio = 0, totalDuration = 0 } = totals;
  const totalHours = Math.round(totalDuration / (1000 * 60 * 60)) || 0;

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

  const renderListItem = ({ period, shows_count = 0, shows_with_audio_count = 0, venues_count = 0, venues_with_audio_count = 0, cover_art_urls = {}, display_count = 0, display_venues_count = 0 }) => (
    <Link to={`/${period}`} key={period} className="list-item-link">
      <li className="list-item">
        <div className="main-row">
          <span className="leftside-primary">
            <CoverArt coverArtUrls={cover_art_urls} css="cover-art-small" />
            <span className="text has-text-weight-bold">{period}</span>
          </span>
          <span className="leftside-secondary">
            {formatNumber(display_venues_count, "venue")}
          </span>
          <span className="rightside-group">
            {formatNumber(display_count, "show")}
          </span>
        </div>
      </li>
    </Link>
  );

  const renderGridItem = ({ period, shows_count = 0, shows_with_audio_count = 0, venues_count = 0, venues_with_audio_count = 0, cover_art_urls = {}, display_count = 0, display_venues_count = 0 }) => (
    <Link to={`/${period}`} key={period} className="list-item-link">
      <li className="grid-item" style={{ backgroundImage: `url(${cover_art_urls?.medium})` }}>
        <div className="overlay">
          <p className={`period ${period.includes("-") ? "period-range" : ""}`}>{period}</p>
          <p className="period-details">
            {formatNumber(display_venues_count, "venue")} • {formatNumber(display_count, "show")}
          </p>
        </div>
      </li>
    </Link>
  );

  const sidebarContent = (
    <div className="sidebar-content">
      <p className="has-text-weight-bold">
        LIVE PHISH
        <span className="hidden-phone"> AUDIO STREAMS</span>
      </p>
      <p className="hidden-mobile mb-4">
        {formatNumber(totalShows)} shows • {formatNumber(totalHours)} hours of music
      </p>

      <div className="buttons mb-0">
        {renderViewToggleButtons()}
        {renderSortButtons()}
      </div>

      <div className="hidden-mobile">
        <p className="has-text-weight-bold mb-2 mt-5">This project is open source</p>
        <GitHubButton className="mr-2" />
        <DiscordButton />
      </div>

      <p className="has-text-weight-bold mb-2 mt-5">Download mobile app</p>
      <MobileApps />
    </div>
  );

  return (
    <LayoutWrapper sidebarContent={sidebarContent}>
      <div className="display-phone-only">
        {renderViewToggleButtons()}
        {renderSortButtons()}
      </div>

      <div>
        {Object.keys(displayEras)
          .filter(key => key !== '_totals') // Exclude the _totals key from rendering
          .sort((a, b) => (sortOption === "asc" ? a.localeCompare(b) : b.localeCompare(a)))
          .map((era) => (
            <React.Fragment key={era}>
              <div className="section-title">
                <div className="title-left">{era}</div>
                <span className="detail-right">{formatNumber(displayEras[era].total_shows, "show")}</span>
              </div>
              <ul className={`${viewMode === "grid" ? "grid-view" : ""} ${viewMode === "grid" && (displayEras[era]?.periods?.length || 0) < 3 ? "limited-width" : ""}`}>
                {viewMode === "list"
                  ? displayEras[era].periods.map(renderListItem)
                  : displayEras[era].periods.map(renderGridItem)}
              </ul>
            </React.Fragment>
          ))}
      </div>
    </LayoutWrapper>
  );
};

export default Eras;
