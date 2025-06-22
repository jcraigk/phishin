import React, { useState, useEffect } from "react";
import { useLocation } from "react-router-dom";
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
import { useFeedback } from "./FeedbackContext";

const Player = ({ activePlaylist, activeTrack, setActiveTrack, customPlaylist, openAppModal }) => {
  const location = useLocation();
  const [isPlayerCollapsed, setIsPlayerCollapsed] = useState(false);
  const [endTime, setEndTime] = useState(null);
  const [hasPlayedInitially, setHasPlayedInitially] = useState(false);
  const [isInitialUrlPlaySession, setIsInitialUrlPlaySession] = useState(false);
  const [initialStartTime, setInitialStartTime] = useState(null);
  const [urlEndTime, setUrlEndTime] = useState(null);
  const { setNotice, setAlert } = useFeedback();

  // Parse URL parameters on initial load
  useEffect(() => {
    if (!hasPlayedInitially) {
      // Handle start/end times from URL
      const urlStartTimeString = new URLSearchParams(location.search).get("t");
      const urlEndTimeString = new URLSearchParams(location.search).get("e");

      if (urlStartTimeString || urlEndTimeString) setIsInitialUrlPlaySession(true);
      if (urlStartTimeString) {
        const parsed = parseTimeParam(urlStartTimeString);
        if (parsed !== null) setInitialStartTime(parsed);
      } else if (activeTrack?.starts_at_second) {
        setInitialStartTime(activeTrack.starts_at_second);
      }

      if (urlEndTimeString && activeTrack) {
        const parsed = parseTimeParam(urlEndTimeString);
        const trackDuration = activeTrack.duration / 1000;
        if (parsed !== null && parsed > 0 && parsed <= trackDuration) {
          setUrlEndTime(parsed);
        } else {
          setAlert("Invalid end time provided");
        }
      }
    }
  }, [location.search, activeTrack, hasPlayedInitially, setAlert]);

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
  } = useGaplessPlayer(activePlaylist, activeTrack, setActiveTrack, setNotice, setAlert, hasPlayedInitially ? null : initialStartTime);

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
    skipToNextTrack();
  };

  const handleSkipToPrevious = () => {
    setIsInitialUrlPlaySession(false);
    skipToPreviousTrack();
  };

  // Handle activeTrack change (when user selects a different track)
  useEffect(() => {
    if (activeTrack && gaplessPlayerRef.current && activePlaylist) {
      if (typeof window !== "undefined") {
        document.title = `${activeTrack.title} - ${formatDate(activeTrack.show_date)} - Phish.in`;
      }

      // Set end time based on whether we're in initial URL play session
      if (isInitialUrlPlaySession && urlEndTime !== null) {
        setEndTime(urlEndTime);
      } else {
        setEndTime(activeTrack.ends_at_second);
      }

      const trackIndex = activePlaylist.findIndex(track => track.id === activeTrack.id);
      if (trackIndex >= 0 && trackIndex !== currentTrackIndex) {
        gaplessPlayerRef.current.gotoTrack(trackIndex);
        // If user manually selected a track, clear initial URL session
        if (hasPlayedInitially) {
          setIsInitialUrlPlaySession(false);
        }
      }
    }
  }, [activeTrack, gaplessPlayerRef, activePlaylist, currentTrackIndex, isInitialUrlPlaySession, urlEndTime]);

  // Media session integration
  useMediaSession(activeTrack, {
    onPlayPause: handleTogglePlayPause,
    onNext: handleSkipToNext,
    onPrevious: handleSkipToPrevious,
    onScrub: scrub,
  });

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

  // End time checking
  useEffect(() => {
    if (endTime !== null && currentTime >= endTime) {
      if (isInitialUrlPlaySession && urlEndTime !== null) {
        // Initial play with URL end time - stop playback
        togglePlayPause();
        setIsInitialUrlPlaySession(false);
      } else {
        // Normal behavior: advance to next track
        skipToNextTrack();
      }
    }
  }, [currentTime, endTime, isInitialUrlPlaySession, urlEndTime, togglePlayPause, skipToNextTrack]);

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
      />
    </div>
  );
};

export default Player;
