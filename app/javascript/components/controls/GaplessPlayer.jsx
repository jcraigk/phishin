import React, { useState, useEffect, useRef } from "react";
import { Link, useLocation } from "react-router-dom";
import { formatDate, parseTimeParam } from "../helpers/utils";
import { useFeedback } from "./FeedbackContext";
import CoverArt from "../CoverArt";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faPlay, faPause, faRotateRight, faRotateLeft, faForward, faBackward, faChevronUp, faChevronDown } from "@fortawesome/free-solid-svg-icons";
import GaplessQueue from "gapless.js";

const GaplessPlayer = ({ activePlaylist, activeTrack, setActiveTrack, customPlaylist, openAppModal }) => {
  const location = useLocation();
  const scrubberRef = useRef();
  const progressBarRef = useRef();
  const gaplessPlayerRef = useRef(null);
  const { setAlert, setNotice } = useFeedback();
  const [fadeClass, setFadeClass] = useState("fade-in");
  const [isFadeOutComplete, setIsFadeOutComplete] = useState(false);
  const [isImageLoaded, setIsImageLoaded] = useState(false);
  const [isPlayerCollapsed, setIsPlayerCollapsed] = useState(false);
  const [firstLoad, setIsFirstLoad] = useState(true);
  const [endTime, setEndTime] = useState(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [currentTrackIndex, setCurrentTrackIndex] = useState(0);

  const togglePlayerPosition = () => {
    setIsPlayerCollapsed(!isPlayerCollapsed);
  };

  const togglePlayPause = () => {
    if (gaplessPlayerRef.current) {
      gaplessPlayerRef.current.togglePlayPause();
    }
  };

  const scrubForward = () => {
    if (gaplessPlayerRef.current && gaplessPlayerRef.current.currentTrack) {
      const newTime = Math.min(currentTime + 10, gaplessPlayerRef.current.currentTrack.duration || 0);
      gaplessPlayerRef.current.seek(newTime);
    }
  };

  const scrubBackward = () => {
    if (gaplessPlayerRef.current) {
      const newTime = Math.max(currentTime - 10, 0);
      gaplessPlayerRef.current.seek(newTime);
    }
  };

  const skipToNextTrack = () => {
    if (gaplessPlayerRef.current) {
      gaplessPlayerRef.current.playNext();
    }
  };

  const skipToPreviousTrack = () => {
    if (gaplessPlayerRef.current) {
      if (currentTime > 10) {
        gaplessPlayerRef.current.seek(0);
      } else {
        gaplessPlayerRef.current.playPrevious();
      }
    }
  };

  // Initialize gapless player when activePlaylist changes
  useEffect(() => {
    if (activePlaylist && activePlaylist.length > 0) {
      // Clean up existing player
      if (gaplessPlayerRef.current) {
        gaplessPlayerRef.current.stop();
        gaplessPlayerRef.current = null;
      }

      // Create track URLs array
      const tracks = activePlaylist.map(track => track.mp3_url);

      // Find the index of the active track
      const activeIndex = activePlaylist.findIndex(track => track.id === activeTrack?.id) || 0;

      // Create new gapless player
      gaplessPlayerRef.current = new GaplessQueue({
        tracks: tracks,
        onProgress: (track) => {
          if (track) {
            setCurrentTime(track.currentTime || 0);
            updateProgressBar(track.currentTime || 0, track.duration || 0);
          }
        },
        onStartNewTrack: (track, index) => {
          const newActiveTrack = activePlaylist[index];
          if (newActiveTrack && newActiveTrack.id !== activeTrack?.id) {
            setActiveTrack(newActiveTrack);
            setCurrentTrackIndex(index);
          }
        },
        onPlayNextTrack: (track, index) => {
          const nextTrack = activePlaylist[index];
          if (nextTrack) {
            setActiveTrack(nextTrack);
            setCurrentTrackIndex(index);
          } else {
            setAlert("This is the last track in the playlist");
          }
        },
        onPlayPreviousTrack: (track, index) => {
          const prevTrack = activePlaylist[index];
          if (prevTrack) {
            setActiveTrack(prevTrack);
            setCurrentTrackIndex(index);
          } else {
            setAlert("This is the first track in the playlist");
          }
        },
        onEnded: () => {
          setIsPlaying(false);
        }
      });

      // Set up play/pause state tracking
      const originalPlay = gaplessPlayerRef.current.play;
      const originalPause = gaplessPlayerRef.current.pause;

      gaplessPlayerRef.current.play = function() {
        setIsPlaying(true);
        return originalPlay.call(this);
      };

      gaplessPlayerRef.current.pause = function() {
        setIsPlaying(false);
        return originalPause.call(this);
      };

      // Go to the active track
      if (activeIndex >= 0) {
        gaplessPlayerRef.current.gotoTrack(activeIndex, false);
        setCurrentTrackIndex(activeIndex);
      }
    }

    return () => {
      if (gaplessPlayerRef.current) {
        gaplessPlayerRef.current.stop();
        gaplessPlayerRef.current = null;
      }
    };
  }, [activePlaylist]);

  // Handle activeTrack change (when user selects a different track)
  useEffect(() => {
    if (activeTrack && gaplessPlayerRef.current && activePlaylist) {
      if (typeof window !== "undefined") {
        document.title = `${activeTrack.title} - ${formatDate(activeTrack.show_date)} - Phish.in`;
      }

      if ('mediaSession' in navigator) {
        navigator.mediaSession.metadata = new MediaMetadata({
          title: activeTrack.title,
          artist: `Phish - ${formatDate(activeTrack.show_date)}`,
          album: `${formatDate(activeTrack.show_date)} - ${activeTrack.venue_name}`,
          artwork: [
            {
              src: activeTrack.show_cover_art_urls.medium,
              sizes: "256x256",
              type: "image/jpeg",
            }
          ]
        });
      }

      // Handle waveform image transition
      setFadeClass("fade-out");
      setIsFadeOutComplete(false);
      setIsImageLoaded(false);

      const fadeOutTimer = setTimeout(() => {
        setIsFadeOutComplete(true);
      }, 500);

      const newImage = new Image();
      newImage.src = activeTrack.waveform_image_url;
      newImage.onload = () => setIsImageLoaded(true);

      // Handle start/end time parameters
      const startTime = activeTrack.starts_at_second ?? parseTimeParam(new URLSearchParams(location.search).get("t"));
      const endTime = activeTrack.ends_at_second ?? parseTimeParam(new URLSearchParams(location.search).get("e"));

      setEndTime(endTime);

      // Find track index and switch to it
      const trackIndex = activePlaylist.findIndex(track => track.id === activeTrack.id);
      if (trackIndex >= 0 && trackIndex !== currentTrackIndex) {
        gaplessPlayerRef.current.gotoTrack(trackIndex, true);
        setCurrentTrackIndex(trackIndex);

        // Apply start time if specified
        if (startTime && startTime > 0) {
          setTimeout(() => {
            if (gaplessPlayerRef.current) {
              gaplessPlayerRef.current.seek(startTime);
            }
          }, 100);
        }
      }

      return () => clearTimeout(fadeOutTimer);
    }
  }, [activeTrack]);

  // Media session hooks
  useEffect(() => {
    if ('mediaSession' in navigator) {
      const handleNextTrack = () => {
        if (activeTrack) skipToNextTrack();
      };

      const handlePreviousTrack = () => {
        if (activeTrack) skipToPreviousTrack();
      };

      navigator.mediaSession.setActionHandler('previoustrack', handlePreviousTrack);
      navigator.mediaSession.setActionHandler('nexttrack', handleNextTrack);
      navigator.mediaSession.setActionHandler('play', togglePlayPause);
      navigator.mediaSession.setActionHandler('pause', togglePlayPause);
      navigator.mediaSession.setActionHandler('stop', togglePlayPause);
      navigator.mediaSession.setActionHandler('seekbackward', scrubBackward);
      navigator.mediaSession.setActionHandler('seekforward', scrubForward);
    }
  }, [activeTrack]);

  // Waveform image fade effect
  useEffect(() => {
    if (isFadeOutComplete && isImageLoaded && activeTrack) {
      scrubberRef.current.style.backgroundImage = `url(${activeTrack.waveform_image_url})`;
      progressBarRef.current.style.maskImage = `url(${activeTrack.waveform_image_url})`;
      setFadeClass("fade-in");
    }
  }, [isFadeOutComplete, isImageLoaded, activeTrack]);

  // Keyboard shortcuts
  useEffect(() => {
    const handleKeyDown = (e) => {
      if (typeof document !== "undefined" && ["INPUT", "TEXTAREA"].includes(document.activeElement.tagName) || document.activeElement.isContentEditable) return;

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
  }, []);

  // Handle end time checking
  useEffect(() => {
    if (endTime !== null && currentTime >= endTime) {
      skipToNextTrack();
    }
  }, [currentTime, endTime]);

  const updateProgressBar = (current, duration) => {
    if (duration > 0) {
      const progress = (current / duration) * 100;
      if (progressBarRef.current) {
        progressBarRef.current.style.background = `linear-gradient(to right, #03bbf2 ${progress}%, rgba(255,255,255,0) ${progress}%)`;
      }
    }
  };

  const handleScrubberClick = (e) => {
    if (gaplessPlayerRef.current && gaplessPlayerRef.current.currentTrack) {
      const clickPosition = e.nativeEvent.offsetX / e.target.offsetWidth;
      const newTime = clickPosition * (gaplessPlayerRef.current.currentTrack.duration || 0);
      gaplessPlayerRef.current.seek(newTime);
    }
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
        <div className="left-half">
          <CoverArt
            coverArtUrls={activeTrack?.show_cover_art_urls}
            albumCoverUrl={activeTrack?.show_album_cover_url}
            openAppModal={openAppModal}
            css="cover-art-small"
            size="medium"
          />
          <div className="track-details">
            <div className="track-title">
              <Link to={`/${activeTrack?.show_date}/${activeTrack?.slug}`}>
                {activeTrack?.title}
              </Link>
            </div>
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
                  <span className="hidden-phone">
                    {" "}•{" "}
                    <Link to={`/venues/${activeTrack?.venue_slug}`}>
                      {activeTrack?.venue_name}
                    </Link>
                  </span>
                </>
              )}
            </div>
          </div>
        </div>
        <div className="right-half">
          <div className="controls">
            <button
              className="skip-btn"
              onClick={skipToPreviousTrack}
            >
              <FontAwesomeIcon icon={faBackward} />
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
              {isPlaying ? <FontAwesomeIcon icon={faPause} /> : <FontAwesomeIcon icon={faPlay} className="play-icon" />}
            </button>
            <button
              className="scrub-btn scrub-forward"
              onClick={scrubForward}
            >
              <FontAwesomeIcon icon={faRotateRight} />
              <span>10</span>
            </button>
            <button
              className="skip-btn"
              onClick={skipToNextTrack}
            >
              <FontAwesomeIcon icon={faForward} />
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
    </div>
  );
};

export default GaplessPlayer;
