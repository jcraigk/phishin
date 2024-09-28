import React from "react";
import { useOutletContext, useNavigate } from "react-router-dom";
import { formatDurationShow, formatDate } from "./util/utils";
import TagBadges from "./controls/TagBadges";
import LikeButton from "./controls/LikeButton";
import ShowContextMenu from "./controls/ShowContextMenu";

const Shows = ({ shows, numbering = false, tourHeaders = false }) => {
  const { activeTrack } = useOutletContext();
  const navigate = useNavigate();

  let lastTourName = null;

  const handleShowClick = (showDate) => {
    navigate(`/${showDate}`);
  };

  if (shows.length === 0) {
    return <h1 className="title">No shows found</h1>;
  }

  return (
    <ul>
      {shows.map((show, index) => {
        const isNewTour = show.tour_name !== lastTourName;

        if (isNewTour) {
          lastTourName = show.tour_name;
        }

        const tourShowCount = shows.filter((s) => s.tour_name === show.tour_name).length;

        return (
          <React.Fragment key={show.date}>
            {isNewTour && tourHeaders && (
              <div className="section-title">
                <div className="title-left">{show.tour_name}</div>
                <span className="detail-right">{tourShowCount} shows</span>
              </div>
            )}
            <li
              className={`list-item ${show.date === activeTrack?.show_date ? "active-item" : ""}`}
              onClick={() => handleShowClick(show.date)}
            >
              <div className="main-row">
                {numbering && <span className="leftside-numbering">#{index + 1}</span>}
                <span className="leftside-primary-medium">
                  {formatDate(show.date)}
                </span>
                <span className="leftside-secondary">{show.venue.name}</span>
                <span className="leftside-tertiary">
                  <TagBadges tags={show.tags} parentId={show.date} />
                </span>

                <div className="rightside-group">
                  <span className="rightside-primary">{formatDurationShow(show.duration)}</span>
                  <span className="rightside-secondary">
                    <LikeButton likable={show} type="Show" />
                  </span>
                  <span className="rightside-menu hidden-mobile">
                    <ShowContextMenu show={show} adjacentLinks={false} />
                  </span>
                </div>
              </div>
            </li>
          </React.Fragment>
        );
      })}
    </ul>
  );
};

export default Shows;
