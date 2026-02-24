import React, { useState, useEffect, useRef } from "react";
import { useLocation } from "react-router";
import { formatDate, parseTimeParam } from "../helpers/utils";
import CoverArt from "../CoverArt";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faChevronUp, faChevronDown } from "@fortawesome/free-solid-svg-icons";
import { useGaplessPlayer } from "../hooks/useGaplessPlayer";
import { useMediaSession } from "../hooks/useMediaSession";
import { PLAYER_CONSTANTS } from "../helpers/playerConstants";
import PlayerControls from "./PlayerControls";
import TrackInfo from "./TrackInfo";
import ProgressBar from "./ProgressBar";
import { useFeedback } from "../contexts/FeedbackContext";

const Player = ({ activePlaylist, activeTrack, setActiveTrack, customPlaylist, openAppModal, shouldAutoplay, setShouldAutoplay, onPlayingChange }) => {
  const location = useLocation();
  const [isPlayerCollapsed, setIsPlayerCollapsed] = useState(false);
  const [hasPlayedInitially, setHasPlayedInitially] = useState(false);
  const [isInitialUrlPlaySession, setIsInitialUrlPlaySession] = useState(false);
  const [initialStartTime, setInitialStartTime] = useState(null);
  const { setNotice, setAlert } = useFeedback();

  // Parse URL "t" param on initial load
  useEffect(() => {
    const urlStartTimeString = new URLSearchParams(location.search).get("t");

    if (urlStartTimeString) {
      setIsInitialUrlPlaySession(true);
      const parsed = parseTimeParam(urlStartTimeString);
      if (parsed !== null) setInitialStartTime(parsed);
    } else if (activeTrack?.starts_at_second) {
      setInitialStartTime(activeTrack.starts_at_second);
    }
  }, []);

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
  } = useGaplessPlayer(activePlaylist, activeTrack, setActiveTrack, setNotice, setAlert, hasPlayedInitially ? null : initialStartTime, shouldAutoplay, setShouldAutoplay);

  useEffect(() => {
    if (onPlayingChange) onPlayingChange(isPlaying);
  }, [isPlaying, onPlayingChange]);

  const togglePlayerPosition = () => {
    setIsPlayerCollapsed(!isPlayerCollapsed);
  };

  const handleTogglePlayPause = () => {
    if (!isPlaying && !hasPlayedInitially) {
      setHasPlayedInitially(true);
    }
    togglePlayPause();
  };

  const handleSkipToNext = () => {
    setIsInitialUrlPlaySession(false);
    setInitialStartTime(null);
    setHasPlayedInitially(true);
    skipToNextTrack();
  };

  const handleSkipToPrevious = () => {
    setIsInitialUrlPlaySession(false);
    setInitialStartTime(null);
    setHasPlayedInitially(true);
    skipToPreviousTrack();
  };

  useEffect(() => {
    if (activeTrack && gaplessPlayerRef.current && activePlaylist) {
      if (typeof window !== "undefined") {
        document.title = `${activeTrack.title} - ${formatDate(activeTrack.show_date)} - Phish.in`;
      }

      const tracksWithAudio = activePlaylist.filter(track => track.mp3_url);
      const trackIndex = tracksWithAudio.findIndex(track => track.id === activeTrack.id);

      if (trackIndex >= 0 && trackIndex !== currentTrackIndex) {
        gaplessPlayerRef.current.gotoTrack(trackIndex);

        const startSecond = parseInt(activeTrack.starts_at_second) || 0;
        if (startSecond > 0) {
          setTimeout(() => {
            if (gaplessPlayerRef.current) {
              gaplessPlayerRef.current.setPosition(startSecond * 1000);
            }
          }, 100);
        }

        if (hasPlayedInitially) {
          setIsInitialUrlPlaySession(false);
        }
      }
    }
  }, [activeTrack, gaplessPlayerRef, activePlaylist, currentTrackIndex]);

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
      } else if (e.key === "ArrowLeft" && !e.shiftKey) {
        e.preventDefault();
        handleSkipToPrevious();
      } else if (e.key === "ArrowRight" && !e.shiftKey) {
        e.preventDefault();
        handleSkipToNext();
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
  }, [handleTogglePlayPause, handleSkipToPrevious, handleSkipToNext, scrub]);

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
