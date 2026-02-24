import React from "react";
import { Link } from "react-router";
import { formatDate } from "../helpers/utils";

const TrackInfo = ({ activeTrack, customPlaylist }) => (
  <div className="track-details">
    <div className="track-title">
      <Link to={`/${activeTrack?.show_date}/${activeTrack?.slug}`}>
        {customPlaylist && activeTrack?.show_date
          ? `${activeTrack?.title} - ${formatDate(activeTrack.show_date)}`
          : activeTrack?.title
        }
      </Link>
    </div>
    <div className="track-info">
      {customPlaylist ? (
        <Link to={customPlaylist.name ? `/play/${customPlaylist.slug}` : '/draft-playlist'}>
          {customPlaylist.name || 'Draft Playlist'}
        </Link>
      ) : (
        <>
          <Link to={`/${activeTrack?.show_date}/${activeTrack?.slug}`}>
            {formatDate(activeTrack?.show_date)}
          </Link>
          <span className="hidden-phone">
            {" "}•{" "}
            <Link to={`/venues/${activeTrack?.venue_slug}`}>
              {activeTrack?.venue_name}
            </Link>
          </span>
        </>
      )}
    </div>
  </div>
);

export default TrackInfo;
