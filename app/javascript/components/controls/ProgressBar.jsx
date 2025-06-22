import React, { useEffect } from "react";
import { formatTime, updateProgressBar } from "../helpers/playerUtils";
import { PLAYER_CONSTANTS } from "../helpers/playerConstants";
import { useWaveformImage } from "../hooks/useWaveformImage";

const ProgressBar = ({ activeTrack, currentTime, currentTrackIndex, activePlaylist, onScrubberClick, onScrub }) => {
  const { scrubberRef, progressBarRef, fadeClass } = useWaveformImage(activeTrack);

  useEffect(() => {
    if (currentTrackIndex >= 0 && currentTrackIndex < activePlaylist.length) {
      const currentTrack = activePlaylist[currentTrackIndex];
      if (currentTrack && currentTrack.duration) {
        updateProgressBar(progressBarRef, currentTime, currentTrack.duration / 1000);
      }
    }
  }, [currentTime, currentTrackIndex, activePlaylist]);

  return (
    <div className="bottom-row">
      <p className="elapsed" onClick={() => onScrub(-PLAYER_CONSTANTS.SCRUB_SECONDS)}>
        {formatTime(currentTime)}
      </p>
      <div
        className={`scrubber-bar ${fadeClass}`}
        onClick={onScrubberClick}
        ref={scrubberRef}
      >
        <div className="progress-bar" ref={progressBarRef}></div>
      </div>
      <p className="remaining" onClick={() => onScrub(PLAYER_CONSTANTS.SCRUB_SECONDS)}>
        {activeTrack ? `-${formatTime((activeTrack.duration / 1000) - currentTime)}` : "0:00"}
      </p>
    </div>
  );
};

export default ProgressBar;
