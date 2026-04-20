import React from "react";
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
        className={`play-pause-btn ${isPlaying ? 'playing' : ''}`}
        onClick={onPlayPause}
        disabled={isLoading}
      >
        {isLoading ? (
          <span className="loading-spinner" />
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
