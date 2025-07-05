import React, { useEffect, useState } from "react";
import { useOutletContext, useNavigate } from "react-router-dom";
import { formatDurationShow, formatDate, formatNumber } from "./helpers/utils";
import TagBadges from "./controls/TagBadges";
import LikeButton from "./controls/LikeButton";
import ShowContextMenu from "./controls/ShowContextMenu";
import CoverArt from "./CoverArt";
import AudioStatusBadge from "./controls/AudioStatusBadge";

const Shows = ({ shows, numbering = false, tourHeaders = false, viewMode = "list" }) => {
  const { activeTrack } = useOutletContext();
  const navigate = useNavigate();
  const [loadedImages, setLoadedImages] = useState({});
  let itemNumber = 1;

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
      <ul
        className={`${viewMode === "grid" ? "grid-view" : "list-view"} ${
          viewMode === "grid" && tourShows.length < 3 ? "limited-width" : ""
        }`}
      >
        {tourShows.map((show) =>
          viewMode === "list" ? renderListItem(show) : renderGridItem(show)
        )}
      </ul>
    </React.Fragment>
  );

  const renderListItem = (show) => {
    const currentItemNumber = itemNumber++;

    return (
      <li
        key={show.date}
        className={`list-item ${show.date === activeTrack?.show_date ? "active-item" : ""}`}
        onClick={() => handleShowClick(show.date)}
      >
        <div className="main-row">
          {numbering && <span className="leftside-numbering">#{currentItemNumber}</span>}
          <span className="leftside-primary">
            <CoverArt coverArtUrls={show.cover_art_urls} css="cover-art-small" />
            <span className="text date">{formatDate(show.date)}</span>
          </span>
          <span className="leftside-secondary">{show.venue_name}</span>
          <span className="leftside-tertiary">
            <TagBadges tags={show.tags} parentId={show.date} />
          </span>
          <div className="rightside-group">
            <span className="rightside-primary">
              {show.audio_status === 'complete' ? (
                formatDurationShow(show.duration)
              ) : (
                <AudioStatusBadge audioStatus={show.audio_status} size="small" />
              )}
            </span>
            <span className="rightside-secondary">
              {show.audio_status === 'complete' && (
                <LikeButton likable={show} type="Show" />
              )}
            </span>
            <span className="rightside-menu">
              <ShowContextMenu show={show} adjacentLinks={false} />
            </span>
          </div>
        </div>
      </li>
    );
  };

  const renderGridItem = (show) => {
    const isLoaded = loadedImages[show.date] || false;

    return (
      <li
        key={show.date}
        className={`grid-item ${!isLoaded ? "loading-shimmer" : ""}`}
        onClick={() => handleShowClick(show.date)}
        style={{
          backgroundImage: isLoaded ? `url(${show.cover_art_urls.medium})` : "none",
          opacity: isLoaded ? 1 : 0.9, // Force re-render to fix iOS Safari bug
        }}
      >
        {!isLoaded && <div className="loading-shimmer" />}
        <div className="overlay">
          <p className="show-date">{formatDate(show.date)}</p>
          <p className="venue-name">{show.venue_name}</p>
          <p className="venue-location">{show.venue.location}</p>
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
    <div>
      {Object.entries(tours).map(([tourName, tourShows]) =>
        renderListItemsForTour(tourShows, tourName)
      )}
    </div>
  );
};

export default Shows;
