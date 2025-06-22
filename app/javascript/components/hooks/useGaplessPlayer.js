import { useState, useRef, useEffect } from "react";
import { Gapless5 } from "@regosen/gapless-5";
import { PLAYER_CONSTANTS } from "../helpers/playerConstants";
import { getPlayerPosition } from "../helpers/playerUtils";

export const useGaplessPlayer = (activePlaylist, activeTrack, setActiveTrack, setNotice, setAlert, startTime) => {
  const gaplessPlayerRef = useRef(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [currentTrackIndex, setCurrentTrackIndex] = useState(0);
  const [pendingStartTime, setPendingStartTime] = useState(null);

  // Set pending start time when startTime prop changes
  useEffect(() => {
    if (startTime !== null && startTime !== undefined) {
      const trackDuration = activeTrack ? activeTrack.duration / 1000 : 0;

      // Check if startTime is valid
      if (startTime === null || startTime < 0 || (trackDuration > 0 && startTime > trackDuration)) {

        if (setAlert) {
          setAlert('Invalid start time provided');
        }
        setPendingStartTime(null);
      } else if (startTime > 0) {

        setPendingStartTime(startTime);
        if (setNotice) {
          setNotice('Press the Play button to listen');
        }
      }
    }
  }, [startTime, activeTrack, setNotice, setAlert]);

  // Patch Audio prototype to prevent null duration errors when skipping tracks quickly
  useEffect(() => {
    const originalAddEventListener = Audio.prototype.addEventListener;
    Audio.prototype.addEventListener = function(type, listener, options) {
      if (type === 'loadedmetadata') {
        const wrappedListener = function(event) {
          try {
            if (this && this.duration !== undefined && this.duration !== null) {
              listener.call(this, event);
            }
          } catch (error) {
            console.warn('Error in Audio.addEventListener', error);
          }
        };
        return originalAddEventListener.call(this, type, wrappedListener, options);
      }
      return originalAddEventListener.call(this, type, listener, options);
    };
  }, []);

          const togglePlayPause = () => {
    if (!gaplessPlayerRef.current) return;

        // If we have a pending start time and we're about to play, apply it first
    if (!isPlaying && pendingStartTime !== null) {
      gaplessPlayerRef.current.setPosition(pendingStartTime * 1000);
      setPendingStartTime(null);
    }

    gaplessPlayerRef.current.playpause();
  };

  const scrub = (seconds) => {
    if (!gaplessPlayerRef.current || !activeTrack) return;
    const currentPosition = getPlayerPosition(gaplessPlayerRef);

    if (currentPosition >= 0) {
      const newTime = currentPosition + seconds;
      const trackDuration = activeTrack.duration / 1000;

      if (seconds > 0 && newTime >= trackDuration - PLAYER_CONSTANTS.SCRUB_SECONDS) return;

      const clampedTime = Math.max(newTime, 0);
      gaplessPlayerRef.current.setPosition(clampedTime * 1000);
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

    const currentPosition = getPlayerPosition(gaplessPlayerRef);

    if (currentPosition > PLAYER_CONSTANTS.PREVIOUS_TRACK_THRESHOLD) {
      gaplessPlayerRef.current.setPosition(0);
    } else {
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

  const canSkipToPrevious = () => {
    if (!activePlaylist) return false;
    if (currentTrackIndex > 0) return true;
    if (!gaplessPlayerRef.current || isLoading) return false;
    const currentPosition = getPlayerPosition(gaplessPlayerRef);
    return currentPosition > PLAYER_CONSTANTS.PREVIOUS_TRACK_THRESHOLD;
  };

  const canSkipToNext = () => {
    if (!activePlaylist || !gaplessPlayerRef.current) return false;
    return currentTrackIndex < activePlaylist.length - 1;
  };

  const canScrubForward = () => {
    if (!activeTrack || !gaplessPlayerRef.current) return false;
    const currentPosition = getPlayerPosition(gaplessPlayerRef);
    const trackDuration = activeTrack.duration / 1000;

    return trackDuration > PLAYER_CONSTANTS.SCRUB_SECONDS &&
           currentPosition < trackDuration - PLAYER_CONSTANTS.SCRUB_SECONDS;
  };

  const handleScrubberClick = (e) => {
    if (gaplessPlayerRef.current && activeTrack) {
      const currentPosition = gaplessPlayerRef.current.getPosition();
      if (currentPosition >= 0) {
        const clickPosition = e.nativeEvent.offsetX / e.target.offsetWidth;
        const newTime = clickPosition * (activeTrack.duration / 1000);
        gaplessPlayerRef.current.setPosition(newTime * 1000);
      }
    }
  };

  // Initialize gapless player when activePlaylist changes
  useEffect(() => {

    if (activePlaylist && activePlaylist.length > 0) {
      if (gaplessPlayerRef.current) {
        gaplessPlayerRef.current.stop();
        gaplessPlayerRef.current.removeAllTracks();
        gaplessPlayerRef.current = null;
      }

      const trackUrls = activePlaylist.map(track => track.mp3_url);
      const activeIndex = activePlaylist.findIndex(track => track.id === activeTrack?.id);
      const validActiveIndex = activeIndex >= 0 && activeIndex < activePlaylist.length ? activeIndex : 0;

      try {
        gaplessPlayerRef.current = new Gapless5({
          tracks: trackUrls,
          loop: false,
          singleMode: false,
          useWebAudio: true,
          useHTML5Audio: true,
          loadLimit: 1,
          volume: 1.0,
          startingTrack: validActiveIndex
        });
      } catch (error) {
        console.error('Error initializing audio player');
        return;
      }

      // Setup player callbacks
      gaplessPlayerRef.current.ontimeupdate = (current_track_time, current_track_index) => {
        const timeInSeconds = current_track_time / 1000;
        setCurrentTime(timeInSeconds);
        setCurrentTrackIndex(current_track_index);
      };

      gaplessPlayerRef.current.onloadstart = () => {
        setIsLoading(true);
      };

      gaplessPlayerRef.current.onload = () => {
        setIsLoading(false);
        if (gaplessPlayerRef.current) {
          if (pendingStartTime !== null) {
            gaplessPlayerRef.current.setPosition(pendingStartTime * 1000);
            setPendingStartTime(null);
          }
          gaplessPlayerRef.current.play();
        }
      };

      gaplessPlayerRef.current.onplay = () => {
        setTimeout(() => {
          setIsPlaying(true);
          setIsLoading(false);
        }, 0);
      };

      gaplessPlayerRef.current.onpause = () => {
        setIsPlaying(false);
      };

      gaplessPlayerRef.current.onstop = () => {
        setIsPlaying(false);
        setIsLoading(false);
      };

      gaplessPlayerRef.current.onnext = () => {
        const newIndex = gaplessPlayerRef.current.getIndex();
        if (newIndex >= 0 && newIndex < activePlaylist.length) {
          setCurrentTrackIndex(newIndex);
          setActiveTrack(activePlaylist[newIndex]);
        }
      };

      gaplessPlayerRef.current.onprev = () => {
        const newIndex = gaplessPlayerRef.current.getIndex();
        if (newIndex >= 0 && newIndex < activePlaylist.length) {
          setCurrentTrackIndex(newIndex);
          setActiveTrack(activePlaylist[newIndex]);
        }
      };

      gaplessPlayerRef.current.onfinishedall = () => {
        setIsPlaying(false);
        setIsLoading(false);
      };

      gaplessPlayerRef.current.onerror = (track_path, error) => {
        const isDurationError = error?.message?.includes('duration') ||
                               error?.message?.includes('Cannot read properties of null');

        if (!isDurationError) {
          console.warn('Gapless player error:', error);
          console.error(`Error playing track: ${error}`);
        }

        setIsPlaying(false);
        setIsLoading(false);
      };

      if (validActiveIndex >= 0) {
        gaplessPlayerRef.current.gotoTrack(validActiveIndex);
        setCurrentTrackIndex(validActiveIndex);
      }
    }

    return () => {
      if (gaplessPlayerRef.current) {
        gaplessPlayerRef.current.stop();
        gaplessPlayerRef.current.removeAllTracks();
        gaplessPlayerRef.current = null;
      }
    };
  }, [activePlaylist, pendingStartTime]);

  return {
    gaplessPlayerRef,
    isPlaying,
    isLoading,
    currentTime,
    currentTrackIndex,
    togglePlayPause,
    scrub,
    skipToNextTrack,
    skipToPreviousTrack,
    canSkipToPrevious,
    canSkipToNext,
    canScrubForward,
    handleScrubberClick,
  };
};
