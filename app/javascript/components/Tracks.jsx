import React from "react";
import { useOutletContext, Link } from "react-router-dom";
import { formatDurationTrack, formatDurationShow, formatDate, truncate } from "./helpers/utils";
import TagBadges from "./controls/TagBadges";
import HighlightedText from "./controls/HighlightedText";
import LikeButton from "./controls/LikeButton";
import TrackContextMenu from "./controls/TrackContextMenu";
import CoverArt from "./CoverArt";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faScissors } from "@fortawesome/free-solid-svg-icons";

const Tracks = ({ tracks, viewStyle, numbering = false, omitSecondary = false, highlight, trackRefs, trackSlug }) => {
  const { playTrack, activeTrack, setCustomPlaylist } = useOutletContext();

  const handleTrackClick = (track) => {
    playTrack(tracks, track);
    if (viewStyle === "playlist") {
      setCustomPlaylist(tracks);
    } else {
      setCustomPlaylist(null);
    }
  };

  const calculateTrackDetails = (track) => {
    const isStartValid = Number.isFinite(track.starts_at_second);
    const isEndValid = Number.isFinite(track.ends_at_second);
    let actualDuration = track.duration;
    let isExcerpt = false;

    if (isStartValid && isEndValid && track.ends_at_second > track.starts_at_second) {
      actualDuration = (track.ends_at_second - track.starts_at_second) * 1000;
      if (actualDuration < track.duration) {
        isExcerpt = true;
      }
    } else if (isStartValid && track.ends_at_second === null) {
      actualDuration = track.duration - track.starts_at_second * 1000;
      if (actualDuration < track.duration) {
        isExcerpt = true;
      }
    } else if (track.starts_at_second === null && isEndValid) {
      actualDuration = track.ends_at_second * 1000;
      if (actualDuration < track.duration) {
        isExcerpt = true;
      }
    }

    return { actualDuration, isExcerpt };
  };

  const renderTrackItem = (track, index) => {
    const { actualDuration, isExcerpt } = calculateTrackDetails(track);

    return (
      <li
        key={track.id}
        className={`list-item ${viewStyle === "show" ? "track-item" : ""} ${track.id === activeTrack?.id ? "active-item" : ""
          } ${viewStyle === "show" && track.slug === trackSlug ? "focus" : ""}`}
        onClick={() => handleTrackClick(track)}
        ref={trackRefs ? (el) => (trackRefs.current[track.position - 1] = el) : null}
      >
        <div className="main-row">
          {numbering && <span className="leftside-numbering">#{index + 1}</span>}
          <span className="leftside-primary">
            {viewStyle !== "show" && (
              <>
                <CoverArt
                  coverArtUrls={track.show_cover_art_urls}
                  css="cover-art-small"
                  size="small"
                />
                <HighlightedText text={truncate(track.title, 50)} highlight={highlight} />

                <span className="text date-link">
                  <Link to={`/${track.show_date}/${track.slug}`} onClick={(e) => e.stopPropagation()}>
                    {formatDate(track.show_date)}
                  </Link>
                </span>{" "}
              </>
            )}
          </span>
          {viewStyle !== "show" && !omitSecondary && (
            <span className="leftside-secondary">{track.venue_location}</span>
          )}
          <span className="leftside-tertiary">
            <TagBadges tags={track.tags} parentId={track.id} highlight={highlight} />
          </span>
          <div className="rightside-group">
            <span className={`rightside-primary ${isExcerpt ? "excerpt" : ""}`}>
              {isExcerpt && <FontAwesomeIcon icon={faScissors} className="excerpt-icon" />}
              {formatDurationTrack(actualDuration)}
            </span>
            <span className="rightside-secondary">
              <LikeButton likable={track} type="Track" />
            </span>
            <span className="rightside-menu">
              <TrackContextMenu
                track={track}
                indexInPlaylist={track.position - 1}
                highlight={highlight}
              />
            </span>
          </div>
        </div>
      </li>
    );
  };

  return (
    <>
      {tracks.length === 0 ? (
        <h2 className="title">No tracks found</h2>
      ) : (
        <ul>
          {viewStyle === "show"
            ? Object.entries(
              tracks.reduce((groups, track) => {
                (groups[track.set_name] = groups[track.set_name] || []).push(track);
                return groups;
              }, {})
            ).map(([setName, setTracks]) => (
              <div key={setName} className="set-group">
                <div className="section-title">
                  <div className="title-left">{setName}</div>
                  <span className="detail-right">
                    {formatDurationShow(
                      setTracks.reduce((total, t) => total + t.duration, 0)
                    )}
                  </span>
                </div>
                <ul>{setTracks.map(renderTrackItem)}</ul>
              </div>
            ))
            : tracks.map(renderTrackItem)}
        </ul>
      )}
    </>
  );
};

export default Tracks;
