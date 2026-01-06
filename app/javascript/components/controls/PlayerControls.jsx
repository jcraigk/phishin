import React, { useState, useEffect, useRef } from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faPlay, faPause, faRotateRight, faRotateLeft, faForward, faBackward } from "@fortawesome/free-solid-svg-icons";
import { PLAYER_CONSTANTS } from "../helpers/playerConstants";

const PlayerControls = ({
  isPlaying,
  isLoading,
  onPlayPause,
  onSkipPrevious,
  onSkipNext,
  onScrub,
  canSkipPrevious,
  canSkipNext,
  canScrubForward
}) => {
  const buttonRef = useRef(null);
  const spinnerRef = useRef(null);
  const [isDarkMode, setIsDarkMode] = useState(
    typeof window !== 'undefined' && window.matchMedia('(prefers-color-scheme: dark)').matches
  );

  useEffect(() => {
    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
    const handleChange = (e) => setIsDarkMode(e.matches);
    mediaQuery.addEventListener('change', handleChange);
    return () => mediaQuery.removeEventListener('change', handleChange);
  }, []);

  useEffect(() => {
    if (!buttonRef.current || !isDarkMode) return;
    const color = isPlaying ? '#03bbf2' : '#404040';
    buttonRef.current.style.setProperty('background-color', color, 'important');
    buttonRef.current.style.setProperty('background', color, 'important');
  }, [isDarkMode, isPlaying]);

  useEffect(() => {
    if (!spinnerRef.current || !isDarkMode) return;
    spinnerRef.current.style.setProperty('border-color', 'rgba(255, 255, 255, 0.5)', 'important');
    spinnerRef.current.style.setProperty('border-top-color', 'white', 'important');
  }, [isDarkMode, isLoading]);

  return (
    <div className="controls">
      <button
        className="skip-btn"
        onClick={onSkipPrevious}
        disabled={!canSkipPrevious}
      >
        <FontAwesomeIcon icon={faBackward} />
      </button>
      <button
        className="scrub-btn scrub-back"
        onClick={() => onScrub(-PLAYER_CONSTANTS.SCRUB_SECONDS)}
        disabled={isLoading}
      >
        <FontAwesomeIcon icon={faRotateLeft} />
        <span>{PLAYER_CONSTANTS.SCRUB_SECONDS}</span>
      </button>
      <button
        ref={buttonRef}
        className={`play-pause-btn ${isPlaying ? 'playing' : ''}`}
        onClick={onPlayPause}
        disabled={isLoading}
      >
        {isLoading ? (
          <span ref={spinnerRef} className="loading-spinner" />
        ) : isPlaying ? (
          <FontAwesomeIcon icon={faPause} />
        ) : (
          <FontAwesomeIcon icon={faPlay} className="play-icon" />
        )}
      </button>
      <button
        className="scrub-btn scrub-forward"
        onClick={() => onScrub(PLAYER_CONSTANTS.SCRUB_SECONDS)}
        disabled={isLoading || !canScrubForward}
      >
        <FontAwesomeIcon icon={faRotateRight} />
        <span>{PLAYER_CONSTANTS.SCRUB_SECONDS}</span>
      </button>
      <button
        className="skip-btn"
        onClick={onSkipNext}
        disabled={!canSkipNext}
      >
        <FontAwesomeIcon icon={faForward} />
      </button>
    </div>
  );
};

export default PlayerControls;
