import React, { useState, useEffect, useRef } from "react";
import { Link, useLocation } from "react-router-dom";
import { formatDate, parseTimeParam } from "../helpers/utils";
import { useFeedback } from "./FeedbackContext";
import CoverArt from "../CoverArt";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faPlay, faPause, faRotateRight, faRotateLeft, faForward, faBackward, faChevronUp, faChevronDown } from "@fortawesome/free-solid-svg-icons";

const Player = ({ activePlaylist, activeTrack, setActiveTrack, customPlaylist, openAppModal }) => {
  const location = useLocation();
  const { setAlert, setNotice } = useFeedback();
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [endTime, setEndTime] = useState(null);
  const [fadeClass, setFadeClass] = useState("fade-in");
  const [isFadeOutComplete, setIsFadeOutComplete] = useState(false);
  const [isImageLoaded, setIsImageLoaded] = useState(false);
  const [isPlayerCollapsed, setIsPlayerCollapsed] = useState(false);
  const [firstLoad, setIsFirstLoad] = useState(true);

  const audioContext = useRef(null);
  const gainNode = useRef(null);
  const currentBuffer = useRef(null);
  const currentSource = useRef(null);
  const nextBuffer = useRef(null);
  const startedAt = useRef(0);
  const pausedAt = useRef(0);
  const scrubberRef = useRef();
  const progressBarRef = useRef();

  useEffect(() => {
    audioContext.current = new (window.AudioContext || window.webkitAudioContext)();
    gainNode.current = audioContext.current.createGain();
    gainNode.current.connect(audioContext.current.destination);

    return () => audioContext.current?.close();
  }, []);

  const loadTrack = async (url) => {
    try {
      const response = await fetch(url);
      const arrayBuffer = await response.arrayBuffer();
      return await audioContext.current.decodeAudioData(arrayBuffer);
    } catch (error) {
      console.error("Error loading track:", error);
      setAlert("Error loading track");
      return null;
    }
  };

  const playBuffer = (buffer, startTime = 0) => {
    const source = audioContext.current.createBufferSource();
    source.buffer = buffer;
    source.connect(gainNode.current);
    source.start(0, startTime);
    currentSource.current = source;
    startedAt.current = audioContext.current.currentTime - startTime;
    return source;
  };

  const togglePlayerPosition = () => {
    setIsPlayerCollapsed(!isPlayerCollapsed);
  };

  const togglePlayPause = () => {
    if (!currentBuffer.current) return;

    if (isPlaying) {
      pausedAt.current = audioContext.current.currentTime;
      currentSource.current?.stop();
      setIsPlaying(false);
      navigator.mediaSession.playbackState = "paused";
    } else {
      const elapsed = pausedAt.current - startedAt.current;
      playBuffer(currentBuffer.current, elapsed);
      setIsPlaying(true);
      navigator.mediaSession.playbackState = "playing";
    }
  };

  const scrubForward = () => {
    const elapsed = (audioContext.current.currentTime - startedAt.current) + 10;
    if (elapsed < currentBuffer.current.duration) {
      currentSource.current?.stop();
      playBuffer(currentBuffer.current, elapsed);
    }
  };

  const scrubBackward = () => {
    const elapsed = Math.max((audioContext.current.currentTime - startedAt.current) - 10, 0);
    currentSource.current?.stop();
    playBuffer(currentBuffer.current, elapsed);
  };

  const skipToNextTrack = () => {
    const currentIndex = activePlaylist.indexOf(activeTrack);
    const nextTrack = activePlaylist[currentIndex + 1];
    if (nextTrack) {
      setActiveTrack(nextTrack);
    } else {
      setAlert("This is the last track in the playlist");
    }
  };

  const skipToPreviousTrack = () => {
    const currentIndex = activePlaylist.indexOf(activeTrack);
    const elapsed = audioContext.current.currentTime - startedAt.current;

    if (elapsed > 10) {
      currentSource.current?.stop();
      playBuffer(currentBuffer.current, 0);
    } else {
      const previousTrack = activePlaylist[currentIndex - 1];
      if (previousTrack) {
        setActiveTrack(previousTrack);
      } else {
        setAlert("This is the first track in the playlist");
      }
    }
  };

  useEffect(() => {
    if (activeTrack) {
      document.title = `${activeTrack.title} - ${formatDate(activeTrack.show_date)} - Phish.in`;

      if ("mediaSession" in navigator) {
        navigator.mediaSession.metadata = new MediaMetadata({
          title: activeTrack.title,
          artist: `Phish - ${formatDate(activeTrack.show_date)}`,
          album: `${formatDate(activeTrack.show_date)} - ${activeTrack.venue_name}`,
          artwork: [{
            src: activeTrack.show_cover_art_urls.medium,
            sizes: "256x256",
            type: "image/jpeg"
          }]
        });
      }

      setFadeClass("fade-out");
      setIsFadeOutComplete(false);
      setIsImageLoaded(false);

      const loadCurrentAndNext = async () => {
        // Load current track
        currentBuffer.current = await loadTrack(activeTrack.mp3_url);
        if (currentBuffer.current) {
          const startTime = activeTrack.starts_at_second ??
            parseTimeParam(new URLSearchParams(location.search).get("t"));

          if (startTime && startTime <= currentBuffer.current.duration) {
            playBuffer(currentBuffer.current, startTime);
          } else {
            playBuffer(currentBuffer.current, 0);
          }

          setIsPlaying(true);
          setIsFirstLoad(false);

          // Preload next track
          const currentIndex = activePlaylist.indexOf(activeTrack);
          const nextTrack = activePlaylist[currentIndex + 1];
          if (nextTrack) {
            nextBuffer.current = await loadTrack(nextTrack.mp3_url);
          }
        }
      };

      loadCurrentAndNext();

      const fadeOutTimer = setTimeout(() => setIsFadeOutComplete(true), 500);
      const newImage = new Image();
      newImage.src = activeTrack.waveform_image_url;
      newImage.onload = () => setIsImageLoaded(true);

      return () => {
        clearTimeout(fadeOutTimer);
        currentSource.current?.stop();
      };
    }
  }, [activeTrack]);

  useEffect(() => {
    if (isFadeOutComplete && isImageLoaded) {
      scrubberRef.current.style.backgroundImage = `url(${activeTrack.waveform_image_url})`;
      progressBarRef.current.style.maskImage = `url(${activeTrack.waveform_image_url})`;
      setFadeClass("fade-in");
    }
  }, [isFadeOutComplete, isImageLoaded]);

  useEffect(() => {
    if ("mediaSession" in navigator) {
      navigator.mediaSession.setActionHandler("previoustrack", skipToPreviousTrack);
      navigator.mediaSession.setActionHandler("nexttrack", skipToNextTrack);
      navigator.mediaSession.setActionHandler("play", togglePlayPause);
      navigator.mediaSession.setActionHandler("pause", togglePlayPause);
      navigator.mediaSession.setActionHandler("stop", togglePlayPause);
      navigator.mediaSession.setActionHandler("seekbackward", scrubBackward);
      navigator.mediaSession.setActionHandler("seekforward", scrubForward);
    }
  }, [activeTrack]);

  useEffect(() => {
    const handleKeyDown = (e) => {
      if (["INPUT", "TEXTAREA"].includes(document.activeElement.tagName) ||
          document.activeElement.isContentEditable) return;

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

  useEffect(() => {
    const updateProgress = () => {
      if (currentBuffer.current && isPlaying) {
        const elapsed = audioContext.current.currentTime - startedAt.current;
        setCurrentTime(elapsed);

        const progress = (elapsed / currentBuffer.current.duration) * 100;
        if (progressBarRef.current) {
          progressBarRef.current.style.background =
            `linear-gradient(to right, #03bbf2 ${progress}%, rgba(255,255,255,0) ${progress}%)`;
        }

        if (endTime && elapsed >= endTime) {
          skipToNextTrack();
        }

        // Start loading next track when near the end
        if (elapsed >= currentBuffer.current.duration - 25) {
          const currentIndex = activePlaylist.indexOf(activeTrack);
          const nextTrack = activePlaylist[currentIndex + 1];
          if (nextTrack && !nextBuffer.current) {
            loadTrack(nextTrack.mp3_url).then(buffer => {
              nextBuffer.current = buffer;
            });
          }
        }

        // Switch to next track when current ends
        if (elapsed >= currentBuffer.current.duration) {
          skipToNextTrack();
        } else {
          requestAnimationFrame(updateProgress);
        }
      }
    };

    if (isPlaying) {
      requestAnimationFrame(updateProgress);
    }
  }, [isPlaying, activeTrack]);

  const handleScrubberClick = (e) => {
    const clickPosition = e.nativeEvent.offsetX / e.target.offsetWidth;
    const newTime = clickPosition * currentBuffer.current.duration;
    currentSource.current?.stop();
    playBuffer(currentBuffer.current, newTime);
    setIsPlaying(true);
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
                    {/* <span className="venue-location">
                      {" "}•{" "}
                      <Link to={`/map?term=${activeTrack?.venue_location}`}>
                        {activeTrack?.venue_location}
                      </Link>
                    </span> */}
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
            <button className="play-pause-btn" onClick={togglePlayPause}>
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

export default Player;
