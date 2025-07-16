export const erasLoader = async () => {
  const response = await fetch("/api/v2/years").catch(error => {
    console.error("Error loading eras data:", error);
    throw error;
  });
  if (!response.ok) throw response;
  const data = await response.json();

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
      cover_art_urls
    });

    acc[era].total_shows += shows_count;
    acc[era].total_shows_with_audio += shows_with_audio_count;
    acc[era].total_duration += shows_duration;

    return acc;
  }, {});

  Object.keys(erasData).forEach((era) => {
    erasData[era].periods.sort((a, b) => b.period.localeCompare(a.period));
  });

  return erasData;
};

import React from "react";
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
  const eras = useLoaderData();
  const { viewMode, setViewMode, sortOption, setSortOption } = useOutletContext();
  const { hideMissingAudio } = useAudioFilter();

  const calculateTotals = () => {
    let totalShows = 0;
    let totalDuration = 0;

    Object.keys(eras).forEach((era) => {
      eras[era].periods.forEach((period) => {
        const showCount = hideMissingAudio ? period.shows_with_audio_count : period.shows_count;
        totalShows += showCount;
      });
      totalDuration += eras[era].total_duration;
    });

    return { totalShows, totalHours: Math.round(totalDuration / (1000 * 60 * 60)) };
  };

  const { totalShows, totalHours } = calculateTotals();

  const getDisplayCount = (period) => hideMissingAudio ? period.shows_with_audio_count : period.shows_count;
  const getDisplayVenuesCount = (period) => hideMissingAudio ? period.venues_with_audio_count : period.venues_count;

  const getEraTotal = (era) => {
    return eras[era].periods.reduce((sum, period) => sum + getDisplayCount(period), 0);
  };

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

  const renderListItem = (period) => (
    <Link to={`/${period.period}`} key={period.period} className="list-item-link">
      <li className="list-item">
        <div className="main-row">
          <span className="leftside-primary">
            <CoverArt coverArtUrls={period.cover_art_urls} css="cover-art-small" />
            <span className="text has-text-weight-bold">{period.period}</span>
          </span>
          <span className="leftside-secondary">
            {formatNumber(getDisplayVenuesCount(period), "venue")}
          </span>
          <span className="rightside-group">
            {formatNumber(getDisplayCount(period), "show")}
          </span>
        </div>
      </li>
    </Link>
  );

  const renderGridItem = (period) => (
    <Link to={`/${period.period}`} key={period.period} className="list-item-link">
      <li className="grid-item" style={{ backgroundImage: `url(${period.cover_art_urls?.medium})` }}>
        <div className="overlay">
          <p className={`period ${period.period.includes("-") ? "period-range" : ""}`}>{period.period}</p>
          <p className="period-details">
            {formatNumber(getDisplayVenuesCount(period), "venue")} • {formatNumber(getDisplayCount(period), "show")}
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
        {Object.keys(eras)
          .sort((a, b) => (sortOption === "asc" ? a.localeCompare(b) : b.localeCompare(a)))
          .map((era) => (
            <React.Fragment key={era}>
              <div className="section-title">
                <div className="title-left">{era}</div>
                <span className="detail-right">{formatNumber(getEraTotal(era), "show")}</span>
              </div>
              <ul className={`${viewMode === "grid" ? "grid-view" : ""} ${viewMode === "grid" && eras[era].periods.length < 3 ? "limited-width" : ""}`}>
                {viewMode === "list"
                  ? eras[era].periods.map(renderListItem)
                  : eras[era].periods.map(renderGridItem)}
              </ul>
            </React.Fragment>
          ))}
      </div>
    </LayoutWrapper>
  );
};

export default Eras;
