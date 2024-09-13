import React, { useState, useEffect, useRef } from "react";
import { Link } from "react-router-dom";
import { formatDate } from "./utils";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faPlay, faPause, faRotateRight, faRotateLeft, faStepForward, faStepBackward } from "@fortawesome/free-solid-svg-icons";
import { useNotification } from "./NotificationContext";


const Player = ({ currentPlaylist, activeTrack, setActiveTrack }) => {
  const audioRef = useRef();
  const scrubberRef = useRef();
  const progressBarRef = useRef();
  const [currentTime, setCurrentTime] = useState(0);
  const [fadeClass, setFadeClass] = useState("");
  const { setAlert, setNotice } = useNotification();

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

  const scrubForward = () => {
    audioRef.current.currentTime = Math.min(audioRef.current.currentTime + 10, audioRef.current.duration);
  };

  const scrubBackward = () => {
    audioRef.current.currentTime = Math.max(audioRef.current.currentTime - 10, 0);
  };

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

      navigator.mediaSession.setActionHandler('previoustrack', skipToPreviousTrack);
      navigator.mediaSession.setActionHandler('nexttrack', skipToNextTrack);
      navigator.mediaSession.setActionHandler('play', togglePlayPause);
      navigator.mediaSession.setActionHandler('pause', togglePlayPause);
      navigator.mediaSession.setActionHandler('stop', togglePlayPause);
    }
  };

  // Hande activeTrack change
  useEffect(() => {
    if (activeTrack && audioRef.current) {
      setFadeClass("fade-out");

      audioRef.current.pause();
      audioRef.current.src = activeTrack.mp3_url;
      audioRef.current.load();
      audioRef.current
        .play()
        .catch((error) => {
          console.error("Error playing audio:", error);
        });

      setupMediaSession();

      setTimeout(() => {
        scrubberRef.current.style.backgroundImage = `url(${activeTrack.waveform_image_url})`;
        progressBarRef.current.style.maskImage = `url(${activeTrack.waveform_image_url})`;

        setFadeClass("fade-in");
      }, 700);
    }
  }, [activeTrack]);

  const skipToNextTrack = () => {
    const currentIndex = currentPlaylist.indexOf(activeTrack);
    const nextTrack = currentPlaylist[currentIndex + 1];
    if (nextTrack) {
      setActiveTrack(nextTrack);
    } else {
      setAlert("This is the last track in the playlist")
    }
  };

  const skipToPreviousTrack = () => {
    const currentIndex = currentPlaylist.indexOf(activeTrack);

    if (audioRef.current.currentTime > 10) {
      audioRef.current.currentTime = 0;
    } else {
      const previousTrack = currentPlaylist[currentIndex - 1];
      if (previousTrack) {
        setActiveTrack(previousTrack);
      } else {
        setAlert("This is the first track in the playlist")
      }
    }
  };

  // Keyboard shortcuts
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

  const handleTimeUpdate = () => {
    setCurrentTime(audioRef.current.currentTime);
    updateProgressBar();
  };

  const updateProgressBar = () => {
    const progress = (currentTime / audioRef.current.duration) * 100;
    if (progressBarRef.current) {
      progressBarRef.current.style.background = `linear-gradient(to right, #03bbf2 ${progress}%, rgba(255,255,255,0) ${progress}%)`;
    }
  };

  const handleScrubberClick = (e) => {
    const clickPosition = e.nativeEvent.offsetX / e.target.offsetWidth;
    const newTime = clickPosition * audioRef.current.duration;
    audioRef.current.currentTime = newTime;
  };

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
            <button onClick={skipToPreviousTrack}>
              <FontAwesomeIcon icon={faStepBackward} />
            </button>
            <button
              className="scrub-btn scrub-back"
              onClick={scrubBackward}
            >
              <FontAwesomeIcon icon={faRotateLeft} />
              <span>10</span>
            </button>
            <button
              className="play-pause-btn"
              onClick={togglePlayPause}
            >
              {audioRef.current?.paused ? <FontAwesomeIcon icon={faPlay} className="play-icon" /> : <FontAwesomeIcon icon={faPause} />}
            </button>
            <button
              className="scrub-btn scrub-forward"
              onClick={scrubForward}
            >
              <FontAwesomeIcon icon={faRotateRight} />
              <span>10</span>
            </button>
            <button onClick={skipToNextTrack}>
              <FontAwesomeIcon icon={faStepForward} />
            </button>
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
