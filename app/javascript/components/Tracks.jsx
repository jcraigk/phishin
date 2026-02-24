import React, { useState, useEffect } from "react";
import { useOutletContext, Link } from "react-router";
import { formatDurationTrack, formatDurationShow, formatDate, truncate } from "./helpers/utils";
import TagBadges from "./controls/TagBadges";
import HighlightedText from "./controls/HighlightedText";
import LikeButton from "./controls/LikeButton";
import TrackContextMenu from "./controls/TrackContextMenu";
import AudioStatusBadge from "./controls/AudioStatusBadge";
import CoverArt from "./CoverArt";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faScissors } from "@fortawesome/free-solid-svg-icons";

const SHIMMER_GRADIENT = 'linear-gradient(90deg, transparent 0%, transparent 20%, rgba(171, 217, 255, 0.45) 45%, rgba(171, 217, 255, 0.45) 55%, transparent 80%, transparent 100%)';
const FOCUS_BOX_SHADOW = 'inset 0 -3px 0 #ABD9FF';

const Tracks = ({ tracks, viewStyle, numbering = false, omitSecondary = false, highlight, trackRefs, trackSlug }) => {
  const { playTrack, activeTrack, setCustomPlaylist, isPlaying } = useOutletContext();
  const [isDarkMode, setIsDarkMode] = useState(
    typeof window !== 'undefined' && window.matchMedia('(prefers-color-scheme: dark)').matches
  );

  useEffect(() => {
    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
    const handleChange = (e) => setIsDarkMode(e.matches);
    mediaQuery.addEventListener('change', handleChange);
    return () => mediaQuery.removeEventListener('change', handleChange);
  }, []);

  // Override DarkReader's color modifications, matching the play button's approach
  useEffect(() => {
    if (!isDarkMode) return;
    document.querySelectorAll('.track-shimmer').forEach(el => {
      el.style.setProperty('background', SHIMMER_GRADIENT, 'important');
    });
    document.querySelectorAll('.track-item.focus').forEach(el => {
      el.style.setProperty('box-shadow', FOCUS_BOX_SHADOW, 'important');
    });
  }, [isDarkMode, activeTrack?.id, trackSlug, isPlaying]);

  const handleTrackClick = (track) => {
    if (track.audio_status === 'missing') return;

    playTrack(tracks, track);
    if (viewStyle !== "playlist") {
      setCustomPlaylist(null);
    }
    // Don't reset customPlaylist when viewStyle === "playlist"
    // as it's already set by the Playlist component
  };

  const calculateTrackDetails = (track) => {
    const startSecond = parseInt(track.starts_at_second) || 0;
    const endSecond = parseInt(track.ends_at_second) || 0;
    let actualDuration;
    let isExcerpt = false;

    if (startSecond > 0 && endSecond > 0) {
      actualDuration = (endSecond - startSecond) * 1000;
    } else if (startSecond > 0) {
      actualDuration = track.duration - startSecond * 1000;
    } else if (endSecond > 0) {
      actualDuration = endSecond * 1000;
    } else {
      actualDuration = track.duration;
    }

    if (actualDuration < track.duration) isExcerpt = true;

    return { actualDuration, isExcerpt };
  };

  const renderTrackItem = (track, index) => {
    const { actualDuration, isExcerpt } = calculateTrackDetails(track);
    const hasMissingAudio = track.audio_status === 'missing';
    const shouldFocus = viewStyle === "show" && track.slug === trackSlug;
    const isActive = track.id === activeTrack?.id;

    return (
      <li
        key={track.id}
        className={[
          "list-item",
          viewStyle === "show" ? "track-item" : "",
          isActive ? "active-item" : "",
          shouldFocus ? "focus" : "",
          hasMissingAudio ? "no-audio" : ""
        ].filter(Boolean).join(" ")}
        onClick={() => handleTrackClick(track)}
        ref={trackRefs ? (el) => (trackRefs.current[track.position - 1] = el) : null}
      >
        {isActive && isPlaying && <span className="track-shimmer" />}
        <div className="main-row">
          {numbering && <span className="leftside-numbering">#{index + 1}</span>}
          <span className="leftside-primary">
            {!viewStyle && (
              <>
                <CoverArt
                  coverArtUrls={track.show_cover_art_urls}
                  css="cover-art-small"
                  size="small"
                />
                <span className="text date-link">
                  <Link to={`/${track.show_date}/${track.slug}`} onClick={(e) => e.stopPropagation()}>
                    {formatDate(track.show_date)}
                  </Link>
                </span>{" "}
              </>
            )}
            <>
              <HighlightedText text={truncate(track.title, 50)} highlight={highlight} />
              {viewStyle === "playlist" && (
                <span className="text date-link">
                  <Link to={`/${track.show_date}/${track.slug}`} onClick={(e) => e.stopPropagation()}>
                    {formatDate(track.show_date)}
                  </Link>
                </span>
              )}
            </>
          </span>
          {viewStyle !== "show" && !omitSecondary && (
            <span className="leftside-secondary">{track.venue_location}</span>
          )}
          <span className="leftside-tertiary">
            <TagBadges tags={track.tags} parentId={track.id} highlight={highlight} />
          </span>
          <div className="rightside-group">
            <span className={`rightside-primary ${isExcerpt ? "excerpt" : ""}`}>
              {track.audio_status === 'complete' ? (
                <>
                  {isExcerpt && <FontAwesomeIcon icon={faScissors} className="excerpt-icon" />}
                  {formatDurationTrack(actualDuration)}
                </>
              ) : (
                <AudioStatusBadge audioStatus={track.audio_status} size="small" />
              )}
            </span>
            <span className="rightside-secondary">
              {track.audio_status === 'complete' && (
                <LikeButton likable={track} type="Track" />
              )}
            </span>
            <span className="rightside-menu">
              <TrackContextMenu
                track={track}
                indexInPlaylist={index}
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
                        setTracks.reduce((total, t) => {
                          if (t.audio_status === 'missing') return total;
                          const { actualDuration } = calculateTrackDetails(t);
                          return total + actualDuration;
                        }, 0)
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
