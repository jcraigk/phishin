import React, { useState, useEffect, useRef } from "react";
import { formatDate } from "./utils";

const Player = ({ currentPlaylist, activeTrack, setActiveTrack }) => {
  const audioRef = useRef();
  const scrubberRef = useRef();
  const progressBarRef = useRef();
  const [currentTime, setCurrentTime] = useState(0);

  // Apply mask dynamically when the track changes
  useEffect(() => {
    if (activeTrack && scrubberRef.current && progressBarRef.current) {
      // Dynamically set the mask-image on the progress bar
      progressBarRef.current.style.maskImage = `url(${activeTrack.waveform_image_url})`;
      progressBarRef.current.style.webkitMaskImage = `url(${activeTrack.waveform_image_url})`; // For WebKit browsers
      progressBarRef.current.style.maskSize = '500px 70px'; // Ensure the mask fits the progress bar
      progressBarRef.current.style.maskRepeat = 'no-repeat'; // No repeat for the waveform mask
    }

    if (activeTrack && audioRef.current) {
      // Pause the current audio, load the new track, and start playing it
      audioRef.current.pause();
      audioRef.current.src = activeTrack.mp3_url;
      audioRef.current.load(); // Ensure the audio is loaded before playing
      audioRef.current
        .play()
        .then(() => {
          console.log("Audio started playing");
        })
        .catch((error) => {
          console.error("Error playing audio:", error);
        });
    }
  }, [activeTrack]);

  // Toggle play/pause functionality
  const togglePlayPause = () => {
    if (audioRef.current.paused) {
      audioRef.current.play().catch((error) => {
        console.error("Play error:", error);
      });
    } else {
      audioRef.current.pause();
    }
  };

  // Skip to the next track in the playlist
  const skipToNextTrack = () => {
    const currentIndex = currentPlaylist.indexOf(activeTrack);
    const nextTrack = currentPlaylist[currentIndex + 1];
    if (nextTrack) {
      setActiveTrack(nextTrack);
    }
  };

  // Skip to the previous track in the playlist
  const skipToPreviousTrack = () => {
    const currentIndex = currentPlaylist.indexOf(activeTrack);

    // If more than 10 seconds have passed in the current track, restart it
    if (audioRef.current.currentTime > 10) {
      audioRef.current.currentTime = 0; // Reset to the beginning of the current track
    } else {
      // Otherwise, skip to the previous track
      const previousTrack = currentPlaylist[currentIndex - 1];
      if (previousTrack) {
        setActiveTrack(previousTrack);
      }
    }
  };

  // Update the current time as the audio plays
  const handleTimeUpdate = () => {
    setCurrentTime(audioRef.current.currentTime);
    updateProgressBar(); // Update the progress bar based on current time
  };

  // Function to update the progress bar fill
  const updateProgressBar = () => {
    const progress = (currentTime / audioRef.current.duration) * 100;
    if (progressBarRef.current) {
      progressBarRef.current.style.width = `${(progress / 100) * 500}px`; // Adjust progress bar width based on 500px width
    }
  };

  // Handle user scrubbing
  const handleScrubberClick = (e) => {
    const clickPosition = e.nativeEvent.offsetX / e.target.offsetWidth;
    const newTime = clickPosition * audioRef.current.duration;
    audioRef.current.currentTime = newTime;
  };

  // Format time in MM:SS
  const formatTime = (timeInSeconds) => {
    const minutes = Math.floor(timeInSeconds / 60);
    const seconds = Math.floor(timeInSeconds % 60).toString().padStart(2, "0");
    return `${minutes}:${seconds}`;
  };

  return (
    <div className={`audio-player ${activeTrack ? 'visible' : ''}`}>
      <div className="track-info">
        <span>{formatDate(activeTrack?.show_date)}</span>
        <span>{activeTrack?.title}</span>
        <span>{activeTrack?.venue_name}</span>
      </div>
      <div className="controls">
        <button onClick={skipToPreviousTrack}>Previous</button>
        <button onClick={togglePlayPause}>
          {audioRef.current?.paused ? "Play" : "Pause"}
        </button>
        <button onClick={skipToNextTrack}>Next</button>
      </div>
      <div className="scrubber">
        <span>{formatTime(currentTime)}</span>
        <div
          className="scrubber-bar"
          onClick={handleScrubberClick}
          ref={scrubberRef}
        >
          <div className="progress-bar" ref={progressBarRef}></div>
        </div>
        <span>{formatTime(audioRef.current?.duration - currentTime || 0)}</span>
      </div>
      <audio ref={audioRef} onTimeUpdate={handleTimeUpdate} />
    </div>
  );
};

export default Player;
