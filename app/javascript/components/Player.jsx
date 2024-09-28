import React, { useState, useEffect, useRef } from "react";
import { Link, useLocation } from "react-router-dom";
import { formatDate, parseTimeParam } from "./utils";
import { useFeedback } from "./FeedbackContext";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faPlay, faPause, faRotateRight, faRotateLeft, faStepForward, faStepBackward, faChevronUp, faChevronDown } from "@fortawesome/free-solid-svg-icons";

const Player = ({ activePlaylist, activeTrack, setActiveTrack, audioRef, customPlaylist, isInputFocused }) => {
  const location = useLocation();
  const scrubberRef = useRef();
  const progressBarRef = useRef();
  const { setAlert, setNotice } = useFeedback();
  const [fadeClass, setFadeClass] = useState("fade-in");
  const [isFadeOutComplete, setIsFadeOutComplete] = useState(false);
  const [isImageLoaded, setIsImageLoaded] = useState(false);
  const [isPlayerCollapsed, setIsPlayerCollapsed] = useState(false);
  const [isFirstLoad, setIsFirstLoad] = useState(true);
  const [endTime, setEndTime] = useState(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);


  const togglePlayerPosition = () => {
    setIsPlayerCollapsed(!isPlayerCollapsed);
  };

  const togglePlayPause = () => {
    if (audioRef.current.paused) {
      audioRef.current.play();
      navigator.mediaSession.playbackState = 'playing';
      setIsPlaying(true);
    } else {
      audioRef.current.pause();
      navigator.mediaSession.playbackState = 'paused';
      setIsPlaying(false);
    }
  };

  const scrubForward = () => {
    audioRef.current.currentTime = Math.min(audioRef.current.currentTime + 10, audioRef.current.duration);
  };

  const scrubBackward = () => {
    audioRef.current.currentTime = Math.max(audioRef.current.currentTime - 10, 0);
  };

  // Media session hooks
  useEffect(() => {
    if ('mediaSession' in navigator) {
      navigator.mediaSession.setActionHandler('previoustrack', skipToPreviousTrack);
      navigator.mediaSession.setActionHandler('nexttrack', skipToNextTrack);
      navigator.mediaSession.setActionHandler('play', togglePlayPause);
      navigator.mediaSession.setActionHandler('pause', togglePlayPause);
      navigator.mediaSession.setActionHandler('stop', togglePlayPause);
    }
  }, []);

  // Hande activeTrack change
  useEffect(() => {
    if (activeTrack && audioRef.current) {
      if (typeof window !== "undefined") {
        document.title = `${activeTrack.title} - ${formatDate(activeTrack.show_date)} - Phish.in`;
      }
      if ('mediaSession' in navigator) {
        navigator.mediaSession.metadata = new MediaMetadata({
          title: activeTrack.title,
          artist: "Phish",
          album: `${formatDate(activeTrack.show_date)} - ${activeTrack.venue_name}`,
          artwork: [
            {
              src: 'https://phish.in/static/logo-square-512.png',
              sizes: '512x512',
              type: 'image/png',
            }
          ]
        });
      }

      setFadeClass("fade-out");
      setIsFadeOutComplete(false);
      setIsImageLoaded(false);

      const fadeOutTimer = setTimeout(() => {
        setIsFadeOutComplete(true);
      }, 500);

      const newImage = new Image();
      newImage.src = activeTrack.waveform_image_url;
      newImage.onload = () => setIsImageLoaded(true);

      audioRef.current.pause();
      audioRef.current.src = activeTrack.mp3_url;
      audioRef.current.load();

      audioRef.current.onloadedmetadata = () => {
        const startTime = activeTrack.starts_at_second ?? parseTimeParam(new URLSearchParams(location.search).get("t"));
        const endTime = activeTrack.ends_at_second ?? parseTimeParam(new URLSearchParams(location.search).get("e"));

        if (startTime && startTime <= audioRef.current.duration) {
          audioRef.current.currentTime = startTime;
        }

        setEndTime(endTime);
        audioRef.current.play().then(() => setIsFirstLoad(false)).catch((error) => {
          if (error.name === "NotAllowedError") {
            setNotice("Tap Play or press Spacebar to listen");
          }
        });
      };

      audioRef.current.onended = skipToNextTrack;

      return () => clearTimeout(fadeOutTimer);
    }
  }, [activeTrack, location.search]);

  useEffect(() => {
    if (isFadeOutComplete && isImageLoaded) {
      scrubberRef.current.style.backgroundImage = `url(${activeTrack.waveform_image_url})`;
      progressBarRef.current.style.maskImage = `url(${activeTrack.waveform_image_url})`;
      setFadeClass("fade-in");
    }
  }, [isFadeOutComplete, isImageLoaded]);

  const skipToNextTrack = () => {
    const currentIndex = activePlaylist.indexOf(activeTrack);
    const nextTrack = activePlaylist[currentIndex + 1];
    if (nextTrack) {
      setActiveTrack(nextTrack);
    } else {
      setAlert("This is the last track in the playlist")
    }
  };

  const skipToPreviousTrack = () => {
    const currentIndex = activePlaylist.indexOf(activeTrack);

    if (audioRef.current.currentTime > 10) {
      audioRef.current.currentTime = 0;
    } else {
      const previousTrack = activePlaylist[currentIndex - 1];
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
      if (isInputFocused) return;

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
  }, [isInputFocused, togglePlayPause, scrubBackward, scrubForward, skipToPreviousTrack, skipToNextTrack]);

  const handleTimeUpdate = () => {
    setCurrentTime(audioRef.current.currentTime);
    updateProgressBar();

    // Check if the track should skip to the next one at a specific end time
    if (endTime !== null && audioRef.current.currentTime >= endTime) {
      skipToNextTrack();
    }
  };

  const updateProgressBar = () => {
    const progress = (audioRef.current.currentTime / audioRef.current.duration) * 100;
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
    <div className={`audio-player ${activeTrack ? 'visible' : ''} ${isPlayerCollapsed ? 'collapsed' : ''}`}>
      <div
        className="chevron-button"
        onClick={togglePlayerPosition}
      >
        <FontAwesomeIcon icon={isPlayerCollapsed ? faChevronUp : faChevronDown} />
      </div>
      <div className="top-row">
        <div className={`left-half`}>
          <div className="track-title">{activeTrack?.title}</div>
          <div className="track-info">
            {customPlaylist ? (
              <Link to={`/play/${customPlaylist.slug}`}>
                {customPlaylist.name}
              </Link>
            ) : (
              <>
                <Link to={`/${activeTrack?.show_date}/${activeTrack?.slug}`}>
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
              </>
            )}
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
      <div className="bottom-row">
        <p className="elapsed" onClick={scrubBackward}>
          {formatTime(currentTime)}
        </p>
        <div
          className={`scrubber-bar ${fadeClass}`}
          onClick={handleScrubberClick}
          ref={scrubberRef}
        >
          <div className="progress-bar" ref={progressBarRef}></div>
        </div>
        <p className="remaining" onClick={scrubForward}>
          {activeTrack ? `-${formatTime((activeTrack.duration / 1000) - currentTime)}` : "0:00"}
        </p>
      </div>
      <audio ref={audioRef} onTimeUpdate={handleTimeUpdate} />
    </div>
  );
};

export default Player;
