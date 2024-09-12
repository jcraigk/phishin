import React, { useState, useEffect, useRef } from "react";
import { Link } from "react-router-dom";
import { formatDate } from "./utils";
import { Tooltip } from "react-tooltip";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faPlay, faPause, faRotateRight, faRotateLeft, faStepForward, faStepBackward } from "@fortawesome/free-solid-svg-icons";

const Player = ({ currentPlaylist, activeTrack, setActiveTrack }) => {
  const audioRef = useRef();
  const scrubberRef = useRef();
  const progressBarRef = useRef();
  const [currentTime, setCurrentTime] = useState(0);
  const [fadeClass, setFadeClass] = useState("");

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
    if (activeTrack && audioRef.current) {
      setFadeClass("fade-out");

      setTimeout(() => {
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

        setupMediaSession();

        scrubberRef.current.style.backgroundImage = `url(${activeTrack.waveform_image_url})`;
        progressBarRef.current.style.maskImage = `url(${activeTrack.waveform_image_url})`;

        setFadeClass("fade-in");
      }, 300);
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

  // Handle keyboard shortcuts
  useEffect(() => {
    const handleKeyDown = (e) => {
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
        scrubBackward();
      } else if (e.key === "ArrowRight" && e.shiftKey) {
        e.preventDefault();
        scrubForward();
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [togglePlayPause, scrubBackward, scrubForward, skipToPreviousTrack, skipToNextTrack]);

  // Update the current time as the audio plays
  const handleTimeUpdate = () => {
    setCurrentTime(audioRef.current.currentTime);
    updateProgressBar(); // Update the progress bar based on current time
  };

  // Function to update the progress bar fill
  const updateProgressBar = () => {
    const progress = (currentTime / audioRef.current.duration) * 100;
    if (progressBarRef.current) {
      // Dynamically adjust the gradient to reflect progress
      progressBarRef.current.style.background = `linear-gradient(to right, #03bbf2 ${progress}%, rgba(255,255,255,0) ${progress}%)`;
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
        <div className={`left-half`}>
          <div className="track-title">{activeTrack?.title}</div>
          <div className="track-info">
            <Link to={`/${activeTrack?.show_date}`}>
              {formatDate(activeTrack?.show_date)}
            </Link>
            {" "}&bull;{" "}
            <Link to={`/venues/${activeTrack?.venue_slug}`}>
              {activeTrack?.venue_name}
            </Link>
            <span className="venue-location">
              {" "}&bull;{" "}
              <Link to={`/map?term=${activeTrack?.venue_location}`}>
                {activeTrack?.venue_location}
              </Link>
            </span>
          </div>
        </div>
        <div className="right-half">
          <div className="controls">
            <button
              onClick={skipToPreviousTrack}
              data-tooltip-id="previous-track-tooltip"
              data-tooltip-content="[Shortcut] Left Arrow: scrub to beginning of current track or skip to previous track"
            >
              <FontAwesomeIcon icon={faStepBackward} />
            </button>
            <Tooltip id="previous-track-tooltip" effect="solid" place="top" type="dark" className="custom-tooltip" />
            <button
              className="scrub-btn scrub-back"
              onClick={scrubBackward}
              data-tooltip-id="scrub-back-tooltip"
              data-tooltip-content="[Shortcut] Shift + Left Arrow: scrub back 10 seconds"
            >
              <FontAwesomeIcon icon={faRotateLeft} />
              <span>10</span>
            </button>
            <Tooltip id="scrub-back-tooltip" effect="solid" place="top" type="dark" className="custom-tooltip" />
            <button
              className="play-pause-btn"
              onClick={togglePlayPause}
              data-tooltip-id="play-tooltip"
              data-tooltip-content="[Shortcut] Spacebar: toggle play/pause"
            >
              {audioRef.current?.paused ? <FontAwesomeIcon icon={faPlay} className="play-icon" /> : <FontAwesomeIcon icon={faPause} />}
            </button>
            <Tooltip id="play-tooltip" effect="solid" place="top" type="dark" className="custom-tooltip" />
            <button
              className="scrub-btn scrub-forward"
              onClick={scrubForward}
              data-tooltip-id="scrub-forward-tooltip"
              data-tooltip-content="[Shortcut] Shift + Right Arrow: scrub forward 10 seconds"
            >
              <FontAwesomeIcon icon={faRotateRight} />
              <span>10</span>
            </button>
            <Tooltip id="scrub-forward-tooltip" effect="solid" place="top" type="dark" className="custom-tooltip" />
            <button
              onClick={skipToNextTrack}
              data-tooltip-id="next-track-tooltip"
              data-tooltip-content="[Shortcut] Right Arrow: skip to next track"
            >
              <FontAwesomeIcon icon={faStepForward} />
            </button>
            <Tooltip id="next-track-tooltip" effect="solid" place="top" type="dark" className="custom-tooltip" />

          </div>
        </div>
      </div>
      <div className={`bottom-row ${fadeClass}`}>
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
