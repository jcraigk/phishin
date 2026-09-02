import React, { useState, useEffect } from "react";
import { useLocation } from "react-router";
import { formatDate, parseTimeParam } from "../helpers/utils";
import CoverArt from "../CoverArt";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faChevronUp, faChevronDown, faXmark } from "@fortawesome/free-solid-svg-icons";
import { usePlayer } from "../hooks/usePlayer";
import { useMediaSession } from "../hooks/useMediaSession";
import { PLAYER_CONSTANTS } from "../helpers/playerConstants";
import PlayerControls from "./PlayerControls";
import TrackInfo from "./TrackInfo";
import ProgressBar from "./ProgressBar";
import { useFeedback } from "../contexts/FeedbackContext";

const Player = ({ activePlaylist, activeTrack, setActiveTrack, customPlaylist, openAppModal, shouldAutoplay, setShouldAutoplay, onPlayingChange, onLoadingChange, onClose }) => {
  const location = useLocation();
  const [isPlayerCollapsed, setIsPlayerCollapsed] = useState(false);
  const { setNotice, setAlert } = useFeedback();

  // The URL "t" param names a start time for the track the page opened on.
  const [urlStartTime] = useState(() => {
    const param = new URLSearchParams(location.search).get("t");
    return param ? parseTimeParam(param) : null;
  });

  const {
    isPlaying,
    isLoading,
    currentTime,
    currentTrackIndex,
    togglePlayPause,
    scrub,
    skipToNextTrack,
    skipToPreviousTrack,
    canSkipToPrevious,
    canSkipToNext,
    canScrubForward,
    handleScrubberClick,
  } = usePlayer(activePlaylist, activeTrack, setActiveTrack, setNotice, setAlert, urlStartTime, shouldAutoplay, setShouldAutoplay);

  useEffect(() => {
    if (onPlayingChange) onPlayingChange(isPlaying);
  }, [isPlaying, onPlayingChange]);

  useEffect(() => {
    if (onLoadingChange) onLoadingChange(isLoading);
  }, [isLoading, onLoadingChange]);

  const togglePlayerPosition = () => {
    setIsPlayerCollapsed(!isPlayerCollapsed);
  };

  const handleTogglePlayPause = togglePlayPause;
  const handleSkipToNext = skipToNextTrack;
  const handleSkipToPrevious = skipToPreviousTrack;

  useEffect(() => {
    if (activeTrack && typeof window !== "undefined") {
      document.title = `${activeTrack.title} - ${formatDate(activeTrack.show_date)} - Phish.in`;
    }
  }, [activeTrack]);

  useMediaSession(activeTrack, {
    onPlayPause: handleTogglePlayPause,
    onNext: handleSkipToNext,
    onPrevious: handleSkipToPrevious,
    onScrub: scrub,
  }, isPlaying);

  // Keyboard shortcuts
  useEffect(() => {
    const handleKeyDown = (e) => {
      if (typeof document !== "undefined" && ["INPUT", "TEXTAREA"].includes(document.activeElement.tagName) || document.activeElement.isContentEditable) return;

      if (e.key === " " && !e.shiftKey) {
        e.preventDefault();
        handleTogglePlayPause();
      } else if (e.key === "ArrowLeft" && e.altKey) {
        e.preventDefault();
        scrub(-PLAYER_CONSTANTS.FINE_SCRUB_SECONDS);
      } else if (e.key === "ArrowRight" && e.altKey) {
        e.preventDefault();
        scrub(PLAYER_CONSTANTS.FINE_SCRUB_SECONDS);
      } else if (e.key === "ArrowLeft" && e.shiftKey) {
        e.preventDefault();
        scrub(-PLAYER_CONSTANTS.SCRUB_SECONDS);
      } else if (e.key === "ArrowRight" && e.shiftKey) {
        e.preventDefault();
        scrub(PLAYER_CONSTANTS.SCRUB_SECONDS);
      } else if (e.key === "ArrowLeft" && !e.shiftKey) {
        e.preventDefault();
        handleSkipToPrevious();
      } else if (e.key === "ArrowRight" && !e.shiftKey) {
        e.preventDefault();
        handleSkipToNext();
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [handleTogglePlayPause, handleSkipToPrevious, handleSkipToNext, scrub]);

  return (
    <div className={`audio-player ${activeTrack ? 'visible' : ''} ${isPlayerCollapsed ? 'collapsed' : ''} ${isPlaying && !isLoading ? 'playing' : ''}`}>
      <div
        className="chevron-button"
        onClick={togglePlayerPosition}
      >
        <FontAwesomeIcon icon={isPlayerCollapsed ? faChevronUp : faChevronDown} />
      </div>
      {onClose && (
        <div className="player-close-button" onClick={onClose}>
          <FontAwesomeIcon icon={faXmark} />
        </div>
      )}
      <div className="top-row">
        <div className="left-half">
          <CoverArt
            coverArtUrls={activeTrack?.show_cover_art_urls}
            albumCoverUrl={activeTrack?.show_album_cover_url}
            openAppModal={openAppModal}
            css="cover-art-small"
            size="medium"
          />
          <TrackInfo activeTrack={activeTrack} customPlaylist={customPlaylist} />
        </div>
        <div className="right-half">
          <PlayerControls
            isPlaying={isPlaying}
            isLoading={isLoading}
            onPlayPause={handleTogglePlayPause}
            onSkipPrevious={handleSkipToPrevious}
            onSkipNext={handleSkipToNext}
            onScrub={scrub}
            canSkipPrevious={canSkipToPrevious()}
            canSkipNext={canSkipToNext()}
            canScrubForward={canScrubForward()}
          />
        </div>
      </div>
      <ProgressBar
        activeTrack={activeTrack}
        currentTime={currentTime}
        currentTrackIndex={currentTrackIndex}
        activePlaylist={activePlaylist}
        onScrubberClick={handleScrubberClick}
        onScrub={scrub}
        isPlaying={isPlaying}
      />
    </div>
  );
};

export default Player;
