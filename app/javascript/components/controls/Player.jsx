import React, { useState, useEffect, useRef } from "react";
import { Link, useLocation } from "react-router-dom";
import { formatDate, parseTimeParam } from "../helpers/utils";
import { useFeedback } from "./FeedbackContext";
import CoverArt from "../CoverArt";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faPlay, faPause, faRotateRight, faRotateLeft, faForward, faBackward, faChevronUp, faChevronDown } from "@fortawesome/free-solid-svg-icons";
import Gapless from './gapless';

const Player = ({ activePlaylist, activeTrack, setActiveTrack, customPlaylist, openAppModal }) => {
  const location = useLocation();
  const scrubberRef = useRef();
  const progressBarRef = useRef();
  const { setAlert, setNotice } = useFeedback();
  const [fadeClass, setFadeClass] = useState("fade-in");
  const [isFadeOutComplete, setIsFadeOutComplete] = useState(false);
  const [isImageLoaded, setIsImageLoaded] = useState(false);
  const [isPlayerCollapsed, setIsPlayerCollapsed] = useState(false);
  const [firstLoad, setIsFirstLoad] = useState(true);
  const [endTime, setEndTime] = useState(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const gaplessQueueRef = useRef(null);

  const togglePlayerPosition = () => {
    setIsPlayerCollapsed(!isPlayerCollapsed);
  };

  useEffect(() => {
    if (activePlaylist && activePlaylist.length > 0) {
      const trackUrls = activePlaylist.map(track => track.mp3_url);
      const queue = new Gapless.Queue({
        tracks: trackUrls,
        onProgress: (track) => {
          setCurrentTime(track.currentTime);
          updateProgressBar(track);
        },
        onStartNewTrack: (track) => {
          const newActiveTrack = activePlaylist[track.idx];
          setActiveTrack(newActiveTrack);

          if ('mediaSession' in navigator) {
            navigator.mediaSession.playbackState = 'playing';
          }
          setIsPlaying(true);
        },
        onEnded: () => {
          setAlert("Playlist finished");
          setIsPlaying(false);
          if ('mediaSession' in navigator) {
            navigator.mediaSession.playbackState = 'paused';
          }
        }
      });

      gaplessQueueRef.current = queue;

      if (activeTrack) {
        const initialTrackIndex = activePlaylist.indexOf(activeTrack);
        queue.gotoTrack(initialTrackIndex, true);
      }
    }

    return () => {
      if (gaplessQueueRef.current) {
        gaplessQueueRef.current.pauseAll();
      }
    };
  }, [activePlaylist]);

  useEffect(() => {
    if (activeTrack) {
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

      setFadeClass("fade-out");
      setIsFadeOutComplete(false);
      setIsImageLoaded(false);

      const fadeOutTimer = setTimeout(() => {
        setIsFadeOutComplete(true);
      }, 500);

      const newImage = new Image();
      newImage.src = activeTrack.waveform_image_url;
      newImage.onload = () => setIsImageLoaded(true);

      const startTime = activeTrack.starts_at_second ?? parseTimeParam(new URLSearchParams(location.search).get("t"));
      const endTime = activeTrack.ends_at_second ?? parseTimeParam(new URLSearchParams(location.search).get("e"));

      if (startTime && gaplessQueueRef.current?.currentTrack) {
        gaplessQueueRef.current.currentTrack.seek(startTime);
      }
      setEndTime(endTime);

      return () => clearTimeout(fadeOutTimer);
    }
  }, [activeTrack]);

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

  useEffect(() => {
    if ('mediaSession' in navigator) {
      navigator.mediaSession.setActionHandler('previoustrack', skipToPreviousTrack);
      navigator.mediaSession.setActionHandler('nexttrack', skipToNextTrack);
      navigator.mediaSession.setActionHandler('play', togglePlayPause);
      navigator.mediaSession.setActionHandler('pause', togglePlayPause);
      navigator.mediaSession.setActionHandler('stop', togglePlayPause);
      navigator.mediaSession.setActionHandler('seekbackward', scrubBackward);
      navigator.mediaSession.setActionHandler('seekforward', scrubForward);
    }
  }, [activeTrack]);

  const togglePlayPause = () => {
    if (gaplessQueueRef.current) {
      gaplessQueueRef.current.togglePlayPause();
      setIsPlaying(!isPlaying);
      if ('mediaSession' in navigator) {
        navigator.mediaSession.playbackState = !isPlaying ? 'playing' : 'paused';
      }
    }
  };

  const skipToNextTrack = () => {
    if (gaplessQueueRef.current) {
      gaplessQueueRef.current.playNext();
    }
  };

  const skipToPreviousTrack = () => {
    if (gaplessQueueRef.current) {
      const currentTrackIndex = activePlaylist.indexOf(activeTrack);

      if (gaplessQueueRef.current.currentTrack.currentTime > 10) {
        gaplessQueueRef.current.currentTrack.seek(0);
      } else {
        if (currentTrackIndex > 0) {
          gaplessQueueRef.current.playPrevious();
        } else {
          setAlert("This is the first track in the playlist");
        }
      }
    }
  };

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

  const updateProgressBar = (track) => {
    if (progressBarRef.current) {
      const progress = (track.currentTime / track.duration) * 100;
      progressBarRef.current.style.background = `linear-gradient(to right, #03bbf2 ${progress}%, rgba(255,255,255,0) ${progress}%)`;
    }
  };

  const handleScrubberClick = (e) => {
    if (gaplessQueueRef.current) {
      const currentTrack = gaplessQueueRef.current.currentTrack;
      const clickPosition = e.nativeEvent.offsetX / e.target.offsetWidth;
      const newTime = clickPosition * currentTrack.duration;
      currentTrack.seek(newTime);
    }
  };

  const formatTime = (timeInSeconds) => {
    const minutes = Math.floor(timeInSeconds / 60);
    const seconds = Math.floor(timeInSeconds % 60).toString().padStart(2, "0");
    return `${minutes}:${seconds}`;
  };

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
              {!isPlaying ? <FontAwesomeIcon icon={faPlay} className="play-icon" /> : <FontAwesomeIcon icon={faPause} />}
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
}

export default Player;
