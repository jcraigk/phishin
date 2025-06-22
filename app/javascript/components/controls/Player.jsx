import React, { useState, useEffect, useRef } from "react";
import { Link, useLocation } from "react-router-dom";
import { formatDate, parseTimeParam } from "../helpers/utils";
import { useFeedback } from "./FeedbackContext";
import CoverArt from "../CoverArt";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faPlay, faPause, faRotateRight, faRotateLeft, faForward, faBackward, faChevronUp, faChevronDown, faSpinner } from "@fortawesome/free-solid-svg-icons";
import { Gapless5 } from "@regosen/gapless-5";

const Player = ({ activePlaylist, activeTrack, setActiveTrack, customPlaylist, openAppModal }) => {
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
  const [isLoading, setIsLoading] = useState(false);
  const [loadingTrackPath, setLoadingTrackPath] = useState(null);
  const [currentTime, setCurrentTime] = useState(0);
  const [currentTrackIndex, setCurrentTrackIndex] = useState(0);

  const togglePlayerPosition = () => {
    setIsPlayerCollapsed(!isPlayerCollapsed);
  };

  const togglePlayPause = () => {
    if (!gaplessPlayerRef.current) return;
    gaplessPlayerRef.current.playpause();
  };

  const scrubForward = () => {
    if (!gaplessPlayerRef.current) return;
    const currentPosition = gaplessPlayerRef.current.getPosition() / 1000;
    if (currentPosition >= 0) {
      const newTime = currentPosition + 10;
      gaplessPlayerRef.current.setPosition(newTime * 1000);
    }
  };

  const scrubBackward = () => {
    if (!gaplessPlayerRef.current) return;
    const currentPosition = gaplessPlayerRef.current.getPosition() / 1000;
    if (currentPosition >= 0) {
      const newTime = Math.max(currentPosition - 10, 0);
      gaplessPlayerRef.current.setPosition(newTime * 1000);
    }
  };

  const skipToNextTrack = () => {
    if (!gaplessPlayerRef.current || !activePlaylist) return;
    const currentIndex = gaplessPlayerRef.current.getIndex();
    const nextIndex = currentIndex + 1;
    if (nextIndex >= activePlaylist.length) return;
    gaplessPlayerRef.current.next();
  };

  const skipToPreviousTrack = () => {
    if (!gaplessPlayerRef.current || !activePlaylist) return;

    const currentPosition = gaplessPlayerRef.current.getPosition() / 1000;

    if (currentPosition > 3) {
      // If more than 3 seconds into track, go back to beginning
      gaplessPlayerRef.current.setPosition(0);
    } else {
      // If less than 3 seconds, go to previous track
      const currentIndex = gaplessPlayerRef.current.getIndex();
      const previousIndex = currentIndex - 1;
      if (previousIndex >= 0) {
        gaplessPlayerRef.current.gotoTrack(previousIndex);
        const previousTrack = activePlaylist[previousIndex];
        if (previousTrack) {
          setActiveTrack(previousTrack);
          setCurrentTrackIndex(previousIndex);
        }
      }
    }
  };

  // Patch Audio prototype to prevent null duration errors when skipping tracks quickly
  useEffect(() => {
    const originalAddEventListener = Audio.prototype.addEventListener;
    Audio.prototype.addEventListener = function(type, listener, options) {
      if (type === 'loadedmetadata') {
        const wrappedListener = function(event) {
          try {
            // Check if 'this' (the audio element) has valid properties before calling listener
            if (this && this.duration !== undefined && this.duration !== null) {
              listener.call(this, event);
            }
          } catch (error) {
            // Silently handle duration-related errors that occur during rapid track changes
            // console.warn('Prevented audio duration error:', error.message);
          }
        };
        return originalAddEventListener.call(this, type, wrappedListener, options);
      }
      return originalAddEventListener.call(this, type, listener, options);
    };

    return () => {
      // Note: We're not restoring the Audio prototype as it might affect other components
    };
  }, []);

  // Initialize gapless player when activePlaylist changes
  useEffect(() => {
    if (activePlaylist && activePlaylist.length > 0) {
      // Clean up existing player
      if (gaplessPlayerRef.current) {
        gaplessPlayerRef.current.stop();
        gaplessPlayerRef.current.removeAllTracks();
        gaplessPlayerRef.current = null;
      }

      // Create track URLs array
      const trackUrls = activePlaylist.map(track => track.mp3_url);

      // Find the index of the active track
      const activeIndex = activePlaylist.findIndex(track => track.id === activeTrack?.id);
      const validActiveIndex = activeIndex >= 0 && activeIndex < activePlaylist.length ? activeIndex : 0;

      // Create new gapless player with optimized settings for immediate playback
      try {
        gaplessPlayerRef.current = new Gapless5({
          tracks: trackUrls,
          loop: false,
          singleMode: false,
          useWebAudio: true,
          useHTML5Audio: true, // This ensures immediate playback capability
          loadLimit: 3, // Limit concurrent loading to improve performance
          volume: 1.0,
          startingTrack: validActiveIndex
        });
      } catch (error) {
        console.error('Error creating Gapless5 player:', error);
        setAlert('Error initializing audio player');
        return;
      }

      // Set up callbacks
      gaplessPlayerRef.current.ontimeupdate = (current_track_time, current_track_index) => {
        try {
          const timeInSeconds = current_track_time / 1000;
          setCurrentTime(timeInSeconds);
          setCurrentTrackIndex(current_track_index);

          // Update progress bar with bounds checking
          if (current_track_index >= 0 && current_track_index < activePlaylist.length) {
            const currentTrack = activePlaylist[current_track_index];
            if (currentTrack && currentTrack.duration) {
              updateProgressBar(timeInSeconds, currentTrack.duration / 1000);
            }
          }
        } catch (error) {
          console.warn('Error in ontimeupdate callback:', error);
        }
      };

      gaplessPlayerRef.current.onloadstart = (track_path) => {
        try {
          setIsLoading(true);
          setLoadingTrackPath(track_path);
        } catch (error) {
          console.warn('Error in onloadstart callback:', error);
        }
      };

      gaplessPlayerRef.current.onload = (track_path, fully_loaded) => {
        try {
          setIsLoading(false);
          setLoadingTrackPath(null);
          setTimeout(() => {
            if (!gaplessPlayerRef.current) return;
            gaplessPlayerRef.current.play();
          }, 50);
        } catch (error) {
          console.warn('Error in onload callback:', error);
        }
      };

      gaplessPlayerRef.current.onplay = (track_path) => {
        try {
          // Use setTimeout to ensure state updates happen after the play event
          setTimeout(() => {
            setIsPlaying(true);
            setIsLoading(false);
            setLoadingTrackPath(null);
          }, 0);
        } catch (error) {
          console.warn('Error in onplay callback:', error);
        }
      };

      gaplessPlayerRef.current.onpause = (track_path) => {
        try {
          setIsPlaying(false);
        } catch (error) {
          console.warn('Error in onpause callback:', error);
        }
      };

      gaplessPlayerRef.current.onstop = (track_path) => {
        try {
          setIsPlaying(false);
          setIsLoading(false);
          setLoadingTrackPath(null);
        } catch (error) {
          console.warn('Error in onstop callback:', error);
        }
      };

      gaplessPlayerRef.current.onnext = (from_track, to_track) => {
        try {
          const newIndex = gaplessPlayerRef.current.getIndex();
          if (newIndex < 0 || newIndex >= activePlaylist.length) return;

          const newActiveTrack = activePlaylist[newIndex];
          if (newActiveTrack) {
            // Force update even if it's the same track ID
            setCurrentTrackIndex(newIndex);
            // Use a callback to ensure we're updating with the latest state
            setActiveTrack(prevTrack => {
              // If it's the same track, create a new object reference to force React to re-render
              if (prevTrack && prevTrack.id === newActiveTrack.id) {
                return { ...newActiveTrack };
              }
              return newActiveTrack;
            });
          }
        } catch (error) {
          console.warn('Error in onnext callback:', error);
        }
      };

      gaplessPlayerRef.current.onprev = (from_track, to_track) => {
        try {
          const newIndex = gaplessPlayerRef.current.getIndex();
          if (newIndex < 0 || newIndex >= activePlaylist.length) return;

          const newActiveTrack = activePlaylist[newIndex];
          if (newActiveTrack) {
            // Force update even if it's the same track ID
            setCurrentTrackIndex(newIndex);
            // Use a callback to ensure we're updating with the latest state
            setActiveTrack(prevTrack => {
              // If it's the same track, create a new object reference to force React to re-render
              if (prevTrack && prevTrack.id === newActiveTrack.id) {
                return { ...newActiveTrack };
              }
              return newActiveTrack;
            });
          }
        } catch (error) {
          console.warn('Error in onprev callback:', error);
        }
      };

      gaplessPlayerRef.current.onfinishedall = () => {
        try {
          setIsPlaying(false);
          setIsLoading(false);
          setLoadingTrackPath(null);
        } catch (error) {
          console.warn('Error in onfinishedall callback:', error);
        }
      };

      gaplessPlayerRef.current.onerror = (track_path, error) => {
        try {
          console.warn('Gapless player error:', error);
          setIsPlaying(false);
          setIsLoading(false);
          setLoadingTrackPath(null);
          // Only show user-facing errors for actual playback issues
          if (error && !error.message?.includes('duration')) {
            setAlert(`Error playing track: ${error}`);
          }
        } catch (err) {
          console.warn('Error in onerror callback:', err);
        }
      };

      if (validActiveIndex >= 0) {
        gaplessPlayerRef.current.gotoTrack(validActiveIndex);
        setCurrentTrackIndex(validActiveIndex);
      }
    }

    return () => {
      if (gaplessPlayerRef.current) {
        try {
          gaplessPlayerRef.current.stop();
          gaplessPlayerRef.current.removeAllTracks();
        } catch (error) {
          console.warn('Error cleaning up gapless player:', error);
        }
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

      // Waveform image transition
      setFadeClass("fade-out");
      setIsFadeOutComplete(false);
      setIsImageLoaded(false);

      const fadeOutTimer = setTimeout(() => {
        setIsFadeOutComplete(true);
      }, 500);

      const newImage = new Image();
      newImage.src = activeTrack.waveform_image_url;
      newImage.onload = () => setIsImageLoaded(true);

      // Start/end time parameters
      const startTime = activeTrack.starts_at_second ?? parseTimeParam(new URLSearchParams(location.search).get("t"));
      const endTime = activeTrack.ends_at_second ?? parseTimeParam(new URLSearchParams(location.search).get("e"));

      setEndTime(endTime);

      const trackIndex = activePlaylist.findIndex(track => track.id === activeTrack.id);
      if (trackIndex >= 0 && trackIndex !== currentTrackIndex) {
        gaplessPlayerRef.current.gotoTrack(trackIndex);
        setCurrentTrackIndex(trackIndex);

        if (startTime && startTime > 0) {
          setTimeout(() => {
            if (!gaplessPlayerRef.current) return;
            gaplessPlayerRef.current.setPosition(startTime * 1000);
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

  // End time checking
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
    if (gaplessPlayerRef.current && activeTrack) {
      // Check if the audio is ready for seeking
      try {
        const currentPosition = gaplessPlayerRef.current.getPosition();
        // If we can get the position, the audio is ready
        if (currentPosition >= 0) {
          const clickPosition = e.nativeEvent.offsetX / e.target.offsetWidth;
          const newTime = clickPosition * (activeTrack.duration / 1000);
          gaplessPlayerRef.current.setPosition(newTime * 1000);
        }
      } catch (error) {
        // Audio not ready for seeking yet, ignore the click
        console.warn('Audio not ready for seeking:', error);
      }
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
              disabled={isLoading}
            >
              <FontAwesomeIcon icon={faRotateLeft} />
              <span>10</span>
            </button>
            <button
              className="play-pause-btn"
              onClick={togglePlayPause}
              disabled={isLoading}
            >
              {isLoading ? (
                <FontAwesomeIcon icon={faSpinner} spin />
              ) : isPlaying ? (
                <FontAwesomeIcon icon={faPause} />
              ) : (
                <FontAwesomeIcon icon={faPlay} className="play-icon" />
              )}
            </button>
            <button
              className="scrub-btn scrub-forward"
              onClick={scrubForward}
              disabled={isLoading}
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

export default Player;
