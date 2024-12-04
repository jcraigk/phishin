import React, { useState, useEffect, useRef, useCallback, useMemo } from "react";
import { Link, useLocation } from "react-router-dom";
import { formatDate, parseTimeParam } from "../helpers/utils";
import { useFeedback } from "./FeedbackContext";
import CoverArt from "../CoverArt";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faPlay, faPause, faRotateRight, faRotateLeft, faForward, faBackward, faChevronUp, faChevronDown } from "@fortawesome/free-solid-svg-icons";
import Gapless from './gapless'; // Assuming you'll save the Gapless plugin in a separate file

const Player = ({ activePlaylist, activeTrack, setActiveTrack, customPlaylist, openAppModal }) => {
  const location = useLocation();
  const scrubberRef = useRef();
  const progressBarRef = useRef();
  const { setAlert, setNotice } = useFeedback();
  const [fadeClass, setFadeClass] = useState("fade-in");
  const [isFadeOutComplete, setIsFadeOutComplete] = useState(false);
  const [isImageLoaded, setIsImageLoaded] = useState(false);
  const [isPlayerCollapsed, setIsPlayerCollapsed] = useState(false);
  const [endTime, setEndTime] = useState(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const gaplessQueueRef = useRef(null);

  // Initialize Gapless Queue
  useEffect(() => {
    if (activePlaylist && activePlaylist.length > 0) {
      // Extract track URLs
      const trackUrls = activePlaylist.map(track => track.mp3_url);

      // Create Gapless Queue
      const queue = new Gapless.Queue({
        tracks: trackUrls,
        onProgress: (track) => {
          setCurrentTime(track.currentTime);
          updateProgressBar(track);
        },
        onStartNewTrack: (track) => {
          const newActiveTrack = activePlaylist[track.idx];
          setActiveTrack(newActiveTrack);
        },
        onEnded: () => {
          // Handle playlist end if needed
          setAlert("Playlist finished");
        }
      });

      gaplessQueueRef.current = queue;

      // Set initial track and play if appropriate
      if (activeTrack) {
        const initialTrackIndex = activePlaylist.indexOf(activeTrack);
        queue.gotoTrack(initialTrackIndex, true);
      }
    }

    return () => {
      // Cleanup
      if (gaplessQueueRef.current) {
        gaplessQueueRef.current.pauseAll();
      }
    };
  }, [activePlaylist]);

  // Update active track and media session when track changes
  useEffect(() => {
    if (activeTrack) {
      // Update document title
      if (typeof window !== "undefined") {
        document.title = `${activeTrack.title} - ${formatDate(activeTrack.show_date)} - Phish.in`;
      }

      // Update Media Session
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

      // Handle fade and image loading
      setFadeClass("fade-out");
      setIsFadeOutComplete(false);
      setIsImageLoaded(false);

      const fadeOutTimer = setTimeout(() => {
        setIsFadeOutComplete(true);
      }, 500);

      const newImage = new Image();
      newImage.src = activeTrack.waveform_image_url;
      newImage.onload = () => setIsImageLoaded(true);

      return () => clearTimeout(fadeOutTimer);
    }
  }, [activeTrack]);

  // Update waveform when fade and image are ready
  useEffect(() => {
    if (isFadeOutComplete && isImageLoaded && activeTrack) {
      if (scrubberRef.current) {
        scrubberRef.current.style.backgroundImage = `url(${activeTrack.waveform_image_url})`;
      }
      if (progressBarRef.current) {
        progressBarRef.current.style.maskImage = `url(${activeTrack.waveform_image_url})`;
      }
      setFadeClass("fade-in");
    }
  }, [isFadeOutComplete, isImageLoaded, activeTrack]);

  // Toggle play/pause
  const togglePlayPause = () => {
    if (gaplessQueueRef.current) {
      gaplessQueueRef.current.togglePlayPause();
      setIsPlaying(!isPlaying);
    }
  };

  // Skip to next track
  const skipToNextTrack = () => {
    if (gaplessQueueRef.current) {
      gaplessQueueRef.current.playNext();
    }
  };

  // Skip to previous track
  const skipToPreviousTrack = () => {
    if (gaplessQueueRef.current) {
      const currentTrackIndex = activePlaylist.indexOf(activeTrack);

      if (gaplessQueueRef.current.currentTrack.currentTime > 10) {
        // If more than 10 seconds into the track, reset to beginning
        gaplessQueueRef.current.currentTrack.seek(0);
      } else {
        // Otherwise go to previous track
        gaplessQueueRef.current.playPrevious();
      }
    }
  };

  // Scrub forward/backward
  const scrubForward = () => {
    if (gaplessQueueRef.current) {
      const currentTrack = gaplessQueueRef.current.currentTrack;
      currentTrack.seek(Math.min(currentTrack.currentTime + 10, currentTrack.duration));
    }
  };

  const scrubBackward = () => {
    if (gaplessQueueRef.current) {
      const currentTrack = gaplessQueueRef.current.currentTrack;
      currentTrack.seek(Math.max(currentTrack.currentTime - 10, 0));
    }
  };

  // Update progress bar
  const updateProgressBar = (track) => {
    if (progressBarRef.current) {
      const progress = (track.currentTime / track.duration) * 100;
      progressBarRef.current.style.background = `linear-gradient(to right, #03bbf2 ${progress}%, rgba(255,255,255,0) ${progress}%)`;
    }
  };

  // Handle scrubber click
  const handleScrubberClick = (e) => {
    if (gaplessQueueRef.current) {
      const currentTrack = gaplessQueueRef.current.currentTrack;
      const clickPosition = e.nativeEvent.offsetX / e.target.offsetWidth;
      const newTime = clickPosition * currentTrack.duration;
      currentTrack.seek(newTime);
    }
  };

  // Format time
  const formatTime = (timeInSeconds) => {
    const minutes = Math.floor(timeInSeconds / 60);
    const seconds = Math.floor(timeInSeconds % 60).toString().padStart(2, "0");
    return `${minutes}:${seconds}`;
  };

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
  }, [togglePlayPause, scrubBackward, scrubForward, skipToPreviousTrack, skipToNextTrack]);

  // Player UI remains largely the same
  return (
    <div className={`audio-player ${activeTrack ? 'visible' : ''} ${isPlayerCollapsed ? 'collapsed' : ''}`}>
      {/* ... rest of the existing UI implementation ... */}
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
