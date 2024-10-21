import React, { useState } from "react";
import { useOutletContext, useNavigate } from "react-router-dom";
import { formatDurationShow, formatDate } from "./helpers/utils";
import TagBadges from "./controls/TagBadges";
import LikeButton from "./controls/LikeButton";
import ShowContextMenu from "./controls/ShowContextMenu";
import CoverArt from "./CoverArt";

const Shows = ({ shows, numbering = false, tourHeaders = false }) => {
  const { activeTrack } = useOutletContext();
  const navigate = useNavigate();
  const [viewMode, setViewMode] = useState(() => {
  return window.innerWidth < 420 ? "list" : "grid";
}); // "list" or "grid"

  let lastTourName = null;

  const handleShowClick = (showDate) => {
    navigate(`/${showDate}`);
  };

  if (shows.length === 0) {
    return <h1 className="title">No shows found</h1>;
  }

  const renderShowItem = (show, index) => {
    const isNewTour = show.tour_name !== lastTourName;
    if (isNewTour) {
      lastTourName = show.tour_name;
    }

    const tourShowCount = shows.filter((s) => s.tour_name === show.tour_name).length;

    return (
      <React.Fragment key={show.date}>
        {isNewTour && tourHeaders && viewMode === "list" && (
          <div className="section-title">
            <div className="title-left">{show.tour_name}</div>
            <span className="detail-right">{tourShowCount} shows</span>
          </div>
        )}
        <li
          className={`show-item ${viewMode} ${show.date === activeTrack?.show_date ? "active-item" : ""}`}
          onClick={() => handleShowClick(show.date)}
          style={{
            backgroundImage: viewMode === "grid" ? `url(${show.cover_art_urls.small})` : "none",
          }}
        >
          <div className="overlay">
            <span className="show-date">{formatDate(show.date)}</span>
            <ShowContextMenu show={show} adjacentLinks={false} />
          </div>
          {viewMode === "list" && (
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
          )}
        </li>
      </React.Fragment>
    );
  };

  return (
    <div className="shows-container">
      <div className="view-toggle">
        <button onClick={() => setViewMode("list")} disabled={viewMode === "list"}>List View</button>
        <button onClick={() => setViewMode("grid")} disabled={viewMode === "grid"}>Grid View</button>
      </div>
      <ul className={viewMode === "grid" ? "grid-view" : "list-view"}>
        {shows.map((show, index) => renderShowItem(show, index))}
      </ul>
    </div>
  );
};

export default Shows;
