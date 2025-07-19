import React, { useEffect } from "react";
import { formatTime } from "../helpers/utils";
import { PLAYER_CONSTANTS } from "../helpers/playerConstants";
import { useWaveformImage } from "../hooks/useWaveformImage";

const ProgressBar = ({ activeTrack, currentTime, currentTrackIndex, activePlaylist, onScrubberClick, onScrub }) => {
  const { scrubberRef, progressBarRef, fadeClass } = useWaveformImage(activeTrack);

  useEffect(() => {
    const tracksWithAudio = activePlaylist ? activePlaylist.filter(track => track.mp3_url) : [];

    if (currentTrackIndex >= 0 && currentTrackIndex < tracksWithAudio.length) {
      const currentTrack = tracksWithAudio[currentTrackIndex];
      if (currentTrack?.duration && progressBarRef.current) {
        const duration = currentTrack.duration / 1000;
        const progress = (currentTime / duration) * 100;
        progressBarRef.current.style.background = `linear-gradient(to right, #03bbf2 ${progress}%, rgba(255,255,255,0) ${progress}%)`;
      }
    }
  }, [currentTime, currentTrackIndex, activePlaylist, progressBarRef]);

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
