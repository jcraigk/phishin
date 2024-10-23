import React, { useEffect, useState } from "react";
import { useOutletContext, useNavigate } from "react-router-dom";
import { formatDurationShow, formatDate, formatNumber } from "./helpers/utils";
import TagBadges from "./controls/TagBadges";
import LikeButton from "./controls/LikeButton";
import ShowContextMenu from "./controls/ShowContextMenu";
import CoverArt from "./CoverArt";

const Shows = ({ shows, numbering = false, tourHeaders = false, viewMode }) => {
  const { activeTrack } = useOutletContext();
  const navigate = useNavigate();
  const [loadedImages, setLoadedImages] = useState({}); // Keep track of loaded images

  const handleShowClick = (showDate) => {
    navigate(`/${showDate}`);
  };

  useEffect(() => {
    if (viewMode === "grid") {
      shows.forEach((show) => {
        if (!loadedImages[show.date]) {
          const img = new Image();
          img.src = show.cover_art_urls.medium;
          img.onload = () => {
            setLoadedImages((prev) => ({ ...prev, [show.date]: true }));
          };
        }
      });
    }
  }, [viewMode, shows, loadedImages]);

  if (shows.length === 0) {
    return <h1 className="title">No shows found</h1>;
  }

  const renderTourHeader = (tourName, tourShowCount) => (
    <div className="section-title">
      <div className="title-left">{tourName}</div>
      <span className="detail-right">{formatNumber(tourShowCount, "show")}</span>
    </div>
  );

  const renderListItemsForTour = (tourShows, tourName) => (
    <React.Fragment key={tourName}>
      {tourHeaders && renderTourHeader(tourName, tourShows.length)}
      <ul className={viewMode === "grid" ? "grid-view" : "list-view"}>
        {tourShows.map((show, index) =>
          viewMode === "list" ? renderListItem(show, index) : renderGridItem(show)
        )}
      </ul>
    </React.Fragment>
  );

  const renderListItem = (show, index) => (
    <li
      key={show.date}
      className={`list-item ${show.date === activeTrack?.show_date ? "active-item" : ""}`}
      onClick={() => handleShowClick(show.date)}
    >
      <div className="main-row">
        {numbering && <span className="leftside-numbering">#{index + 1}</span>}
        <span className="leftside-primary">
          <CoverArt coverArtUrls={show.cover_art_urls} css="cover-art-small" />
          <span className="show-date">{formatDate(show.date)}</span>
        </span>
        <span className="leftside-secondary">{show.venue_name}</span>
        <span className="leftside-tertiary">
          <TagBadges tags={show.tags} parentId={show.date} />
        </span>
        <div className="rightside-group">
          <span className="rightside-primary">{formatDurationShow(show.duration)}</span>
          <span className="rightside-secondary">
            <LikeButton likable={show} type="Show" />
          </span>
          <span className="rightside-menu">
            <ShowContextMenu show={show} adjacentLinks={false} />
          </span>
        </div>
      </div>
    </li>
  );

  const renderGridItem = (show) => {
    const isLoaded = loadedImages[show.date] || false;

    return (
      <li
        key={show.date}
        className={`grid-item ${!isLoaded ? "loading-shimmer" : ""}`}
        onClick={() => handleShowClick(show.date)}
        style={{
          backgroundImage: isLoaded ? `url(${show.cover_art_urls.medium})` : "none",
        }}
      >
        {!isLoaded && <div className="loading-shimmer" />}
        <div className="overlay">
          <p className="show-date">{formatDate(show.date)}</p>
          <p className="venue-name">{show.venue_name}</p>
        </div>
      </li>
    );
  };

  // Group shows by tour
  const tours = shows.reduce((acc, show) => {
    if (!acc[show.tour_name]) {
      acc[show.tour_name] = [];
    }
    acc[show.tour_name].push(show);
    return acc;
  }, {});

  return (
    <div className="shows-wrapper">
      {Object.entries(tours).map(([tourName, tourShows]) =>
        renderListItemsForTour(tourShows, tourName)
      )}
    </div>
  );
};

export default Shows;
