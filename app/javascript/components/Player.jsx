import React, { useState, useEffect, useRef } from "react";
import { Link } from "react-router-dom";
import { formatDate } from "./utils";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faPlay, faPause, faRotateRight, faRotateLeft, faStepForward, faStepBackward } from "@fortawesome/free-solid-svg-icons";

const Player = ({ currentPlaylist, activeTrack, setActiveTrack }) => {
  const audioRef = useRef();
  const scrubberRef = useRef();
  const progressBarRef = useRef();
  const [currentTime, setCurrentTime] = useState(0);

  // Toggle play/pause functionality
  const togglePlayPause = () => {
    if (audioRef.current.paused) {
      audioRef.current.play().catch((error) => {
        console.error("Play error:", error);
      });
      navigator.mediaSession.playbackState = 'playing';
    } else {
      audioRef.current.pause();
      navigator.mediaSession.playbackState = 'paused';
    }
  };

  // Scrub forward by 10 seconds
  const scrubForward = () => {
    audioRef.current.currentTime = Math.min(audioRef.current.currentTime + 10, audioRef.current.duration);
  };

  // Scrub backward by 10 seconds
  const scrubBackward = () => {
    audioRef.current.currentTime = Math.max(audioRef.current.currentTime - 10, 0);
  };

  // Media Session API hooks
  const setupMediaSession = () => {
    if ('mediaSession' in navigator) {
      // Set the media metadata
      navigator.mediaSession.metadata = new MediaMetadata({
        title: activeTrack.title,
        artist: "Phish",
        album: `${formatDate(activeTrack.show_date)} - ${activeTrack.venue_name}`,
        artwork: [
          {
            src: 'https://phish.in/static/logo-512.png',
            sizes: '512x512',
            type: 'image/png',
          }
        ]
      });

      // Set media session action handlers
      navigator.mediaSession.setActionHandler('previoustrack', skipToPreviousTrack);
      navigator.mediaSession.setActionHandler('nexttrack', skipToNextTrack);
      navigator.mediaSession.setActionHandler('play', togglePlayPause);
      navigator.mediaSession.setActionHandler('pause', togglePlayPause);
      navigator.mediaSession.setActionHandler('stop', togglePlayPause);
    }
  };

  // Apply mask dynamically when the track changes
  useEffect(() => {
    if (activeTrack && scrubberRef.current && progressBarRef.current) {
      scrubberRef.current.style.backgroundImage = `url(${activeTrack.waveform_image_url})`;
      progressBarRef.current.style.maskImage = `url(${activeTrack.waveform_image_url})`;
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

      setupMediaSession(); // Set up Media Session API
    }
  }, [activeTrack]);

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
      <div className="top-row">
        <div className="half">
          <div className="track-title">{activeTrack?.title}</div>
          <div className="track-info">
            <Link to={`/${activeTrack?.show_date}`}>
              {formatDate(activeTrack?.show_date)}
            </Link>
          </div>
          <div className="track-info">
            <Link to={`/venues/${activeTrack?.venue_slug}`}>
              {activeTrack?.venue_name}
            </Link>
            {" "}&bull;{" "}
            <Link to={`/map?term=${activeTrack?.venue_location}`}>
              {activeTrack?.venue_location}
            </Link>
          </div>
        </div>
        <div className="half">
          <div className="controls">
            <button onClick={skipToPreviousTrack}>
              <FontAwesomeIcon icon={faStepBackward} />
            </button>
            <button className="scrub-btn" onClick={scrubBackward}>
              <FontAwesomeIcon icon={faRotateLeft} />
            </button>
            <button className="play-pause-btn" onClick={togglePlayPause}>
              {audioRef.current?.paused ? <FontAwesomeIcon icon={faPlay} /> : <FontAwesomeIcon icon={faPause} />}
            </button>
            <button className="scrub-btn" onClick={scrubForward}>
              <FontAwesomeIcon icon={faRotateRight} />
            </button>
            <button onClick={skipToNextTrack}>
              <FontAwesomeIcon icon={faStepForward} />
            </button>
          </div>
        </div>
      </div>
      <div className="bottom-row">
        <p className="elapsed">{formatTime(currentTime)}</p>
        <div
          className="scrubber-bar"
          onClick={handleScrubberClick}
          ref={scrubberRef}
        >
          <div className="progress-bar" ref={progressBarRef}></div>
        </div>
        <p className="remaining">-{formatTime(audioRef.current?.duration - currentTime || 0)}</p>
      </div>
      <audio ref={audioRef} onTimeUpdate={handleTimeUpdate} />
    </div>

  );
};

export default Player;
