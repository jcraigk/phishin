export const erasLoader = async () => {
  const response = await fetch("/api/v2/years");
  if (!response.ok) throw response;
  const data = await response.json();

  const erasData = data.reduce((acc, { era, period, shows_count, shows_duration, venues_count, cover_art_urls }) => {
    if (!acc[era]) {
      acc[era] = { periods: [], total_shows: 0, total_duration: 0 };
    }
    acc[era].periods.push({ period, shows_count, venues_count, cover_art_urls }); // Include cover_art_urls
    acc[era].total_shows += shows_count;
    acc[era].total_duration += shows_duration;
    return acc;
  }, {});

  Object.keys(erasData).forEach((era) => {
    erasData[era].periods.sort((a, b) => b.period.localeCompare(a.period));
  });

  return erasData;
};

import React, { useState } from "react";
import { Link, useLoaderData } from "react-router-dom";
import { formatNumber } from "./helpers/utils";
import LayoutWrapper from "./layout/LayoutWrapper";
import MobileApps from "./pages/MobileApps";
import GitHubButton from "./pages/GitHubButton";
import DiscordButton from "./pages/DiscordButton";
import CoverArt from "./CoverArt";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faList, faTh, faRss, faSortAmountDown, faSortAmountUp } from "@fortawesome/free-solid-svg-icons";

const Eras = () => {
  const eras = useLoaderData();
  const [viewMode, setViewMode] = useState("grid");
  const [sortOption, setSortOption] = useState("desc");

  const totalShows = Object.keys(eras).reduce((sum, era) => sum + eras[era].total_shows, 0);
  const totalDurationMs = Object.keys(eras).reduce((sum, era) => sum + eras[era].total_duration, 0);
  const totalHours = Math.round(totalDurationMs / (1000 * 60 * 60));

  const handleViewModeChange = (mode) => setViewMode(mode);
  const handleSortOptionChange = (option) => setSortOption(option);

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

  const renderSortButtons = () => (
    <div className="view-toggle buttons has-addons">
      <button
        className={`button ${sortOption === "desc" ? "is-selected" : ""}`}
        onClick={() => handleSortOptionChange("desc")}
        disabled={sortOption === "desc"}
      >
        <span className="icon">
          <FontAwesomeIcon icon={faSortAmountDown} />
        </span>
      </button>
      <button
        className={`button ${sortOption === "asc" ? "is-selected" : ""}`}
        onClick={() => handleSortOptionChange("asc")}
        disabled={sortOption === "asc"}
      >
        <span className="icon">
          <FontAwesomeIcon icon={faSortAmountUp} />
        </span>
      </button>
    </div>
  );

  const renderListItem = ({ period, shows_count, venues_count, cover_art_urls }) => (
    <Link to={`/${period}`} key={period} className="list-item-link">
      <li className="list-item">
        <div className="main-row">
          <span className="leftside-primary">
            <CoverArt coverArtUrls={cover_art_urls} css="cover-art-small" />
            <span className="date">{period}</span>
          </span>
          <span className="leftside-secondary">
            {formatNumber(venues_count, "venue")}
          </span>
          <span className="rightside-group">
            {formatNumber(shows_count, "show")}
          </span>
        </div>
      </li>
    </Link>
  );

  const renderGridItem = ({ period, shows_count, venues_count, cover_art_urls }) => (
    <Link to={`/${period}`} key={period} className="list-item-link">
      <li className="grid-item period-item" style={{ backgroundImage: `url(${cover_art_urls.medium})` }}>
        <div className="period-overlay">
          <p className={`period ${period.includes("-") ? "period-range" : ""}`}>{period}</p>
          <p className="period-details">
            {formatNumber(venues_count, "venue")} • {formatNumber(shows_count, "show")}
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
      <p>🍩 {formatNumber(totalShows)} shows</p>
      <p className="hidden-phone">🎵 {formatNumber(totalHours)} hours of music</p>

      <div className="mt-3">{renderViewToggleButtons()}</div>
      <div className="mt-2">{renderSortButtons()}</div>

      <MobileApps className="mt-5" />

      <div className="hidden-mobile">
        <p className="has-text-weight-bold mb-2 mt-5 project-open-source">This project is open source</p>
        <GitHubButton className="mb-2" />
        <br />
        <DiscordButton className="mb-2" />
        <br />
        <a href="/feeds/rss" className="button" target="_blank">
          <FontAwesomeIcon icon={faRss} className="mr-1" />
          RSS
        </a>
      </div>
    </div>
  );

  return (
    <>
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
                  <div className="title-left">{era} Era</div>
                  <span className="detail-right">{formatNumber(eras[era].total_shows, "show")}</span>
                </div>
                <ul className={`${viewMode === "grid" ? "grid-view" : ""} ${viewMode === "grid" && eras[era].periods.length < 3 ? "limited-width" : ""}`}>
                  {eras[era].periods
                    .sort((a, b) =>
                      sortOption === "asc" ? a.period.localeCompare(b.period) : b.period.localeCompare(a.period)
                    )
                    .map((periodData) =>
                      viewMode === "list" ? renderListItem(periodData) : renderGridItem(periodData)
                    )}
                </ul>
              </React.Fragment>
            )
          )}
        </div>
      </LayoutWrapper>
    </>
  );
};

export default Eras;


