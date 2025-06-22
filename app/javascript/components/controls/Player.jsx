import React, { useState, useEffect } from "react";
import { useLocation } from "react-router-dom";
import { formatDate, parseTimeParam } from "../helpers/utils";
import { useFeedback } from "./FeedbackContext";
import CoverArt from "../CoverArt";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faChevronUp, faChevronDown } from "@fortawesome/free-solid-svg-icons";
import { useGaplessPlayer } from "../hooks/useGaplessPlayer";
import { useMediaSession } from "../hooks/useMediaSession";
import { PLAYER_CONSTANTS } from "../helpers/playerConstants";
import PlayerControls from "./PlayerControls";
import TrackInfo from "./TrackInfo";
import ProgressBar from "./ProgressBar";

const Player = ({ activePlaylist, activeTrack, setActiveTrack, customPlaylist, openAppModal }) => {
  const location = useLocation();
  const { setAlert } = useFeedback();
  const [isPlayerCollapsed, setIsPlayerCollapsed] = useState(false);
  const [endTime, setEndTime] = useState(null);

  const {
    gaplessPlayerRef,
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
  } = useGaplessPlayer(activePlaylist, activeTrack, setActiveTrack, setAlert);

  const togglePlayerPosition = () => {
    setIsPlayerCollapsed(!isPlayerCollapsed);
  };

  // Handle activeTrack change (when user selects a different track)
  useEffect(() => {
    if (activeTrack && gaplessPlayerRef.current && activePlaylist) {
      if (typeof window !== "undefined") {
        document.title = `${activeTrack.title} - ${formatDate(activeTrack.show_date)} - Phish.in`;
      }

      const startTime = activeTrack.starts_at_second ?? parseTimeParam(new URLSearchParams(location.search).get("t"));
      const endTime = activeTrack.ends_at_second ?? parseTimeParam(new URLSearchParams(location.search).get("e"));

      setEndTime(endTime);

      const trackIndex = activePlaylist.findIndex(track => track.id === activeTrack.id);
      if (trackIndex >= 0 && trackIndex !== currentTrackIndex) {
        gaplessPlayerRef.current.gotoTrack(trackIndex);

        if (startTime && startTime > 0) {
          setTimeout(() => {
            if (!gaplessPlayerRef.current) return;
            gaplessPlayerRef.current.setPosition(startTime * 1000);
          }, PLAYER_CONSTANTS.POSITION_DELAY);
        }
      }
    }
  }, [activeTrack, gaplessPlayerRef, activePlaylist, currentTrackIndex]);

  // Media session integration
  useMediaSession(activeTrack, {
    onPlayPause: togglePlayPause,
    onNext: skipToNextTrack,
    onPrevious: skipToPreviousTrack,
    onScrub: scrub,
  });

  // Keyboard shortcuts
  useEffect(() => {
    const handleKeyDown = (e) => {
      if (typeof document !== "undefined" && ["INPUT", "TEXTAREA"].includes(document.activeElement.tagName) || document.activeElement.isContentEditable) return;

      if (e.key === " " && !e.shiftKey) {
        e.preventDefault();
        togglePlayPause();
      } else if (e.key === "ArrowLeft" && !e.shiftKey) {
        e.preventDefault();
        skipToPreviousTrack();
      } else if (e.key === "ArrowRight" && !e.shiftKey) {
        e.preventDefault();
        skipToNextTrack();
      } else if (e.key === "ArrowLeft" && e.shiftKey) {
        e.preventDefault();
        scrub(-PLAYER_CONSTANTS.SCRUB_SECONDS);
      } else if (e.key === "ArrowRight" && e.shiftKey) {
        e.preventDefault();
        scrub(PLAYER_CONSTANTS.SCRUB_SECONDS);
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [togglePlayPause, skipToPreviousTrack, skipToNextTrack, scrub]);

  // End time checking
  useEffect(() => {
    if (endTime !== null && currentTime >= endTime) {
      skipToNextTrack();
    }
  }, [currentTime, endTime, skipToNextTrack]);

  return (
    <div className={`audio-player ${activeTrack ? 'visible' : ''} ${isPlayerCollapsed ? 'collapsed' : ''}`}>
      <div
        className="chevron-button"
        onClick={togglePlayerPosition}
      >
        <FontAwesomeIcon icon={isPlayerCollapsed ? faChevronUp : faChevronDown} />
      </div>
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
            onPlayPause={togglePlayPause}
            onSkipPrevious={skipToPreviousTrack}
            onSkipNext={skipToNextTrack}
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
      />
    </div>
  );
};

export default Player;
