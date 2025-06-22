import { useState, useRef, useEffect } from "react";
import { Gapless5 } from "@regosen/gapless-5";
import { PLAYER_CONSTANTS } from "../helpers/playerConstants";
import { getPlayerPosition, resetLoadingState, updateProgressBar } from "../helpers/playerUtils";

export const useGaplessPlayer = (activePlaylist, activeTrack, setActiveTrack, setAlert) => {
  const gaplessPlayerRef = useRef(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [userIntentToPlay, setUserIntentToPlay] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [currentTrackIndex, setCurrentTrackIndex] = useState(0);

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
            // Silently handle duration-related errors that occur during rapid track changes
          }
        };
        return originalAddEventListener.call(this, type, wrappedListener, options);
      }
      return originalAddEventListener.call(this, type, listener, options);
    };
    // Note: We're not restoring the Audio prototype as it might affect other components
  }, []);

  const togglePlayPause = () => {
    if (!gaplessPlayerRef.current) return;

    if (isPlaying) {
      // User wants to pause
      setUserIntentToPlay(false);
      gaplessPlayerRef.current.pause();
    } else {
      // User wants to play
      setUserIntentToPlay(true);
      gaplessPlayerRef.current.play();
    }
  };

  const scrub = (seconds) => {
    if (!gaplessPlayerRef.current || !activeTrack) return;
    const currentPosition = getPlayerPosition(gaplessPlayerRef);

    if (currentPosition >= 0) {
      const newTime = currentPosition + seconds;
      const trackDuration = activeTrack.duration / 1000;

      if (seconds > 0 && newTime >= trackDuration - PLAYER_CONSTANTS.PRELOAD_THRESHOLD) return;

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

    return currentPosition < trackDuration - PLAYER_CONSTANTS.PRELOAD_THRESHOLD;
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
        console.error('Error creating Gapless5 player:', error);
        setAlert('Error initializing audio player');
        return;
      }

      // Set user intent to play when a new track is loaded
      setUserIntentToPlay(true);

      // Setup player callbacks
      gaplessPlayerRef.current.ontimeupdate = (current_track_time, current_track_index) => {
        const timeInSeconds = current_track_time / 1000;
        setCurrentTime(timeInSeconds);
        // Ignore -1 values that occur during track transitions
        if (current_track_index >= 0) {
          setCurrentTrackIndex(current_track_index);
        }
      };

      gaplessPlayerRef.current.onloadstart = () => {
        setIsLoading(true);
      };

      gaplessPlayerRef.current.onload = () => {
        setIsLoading(false);
        // Let Gapless5 handle its own playback logic
        setTimeout(() => {
          if (!gaplessPlayerRef.current) return;
          gaplessPlayerRef.current.play();
        }, PLAYER_CONSTANTS.PLAY_DELAY);
      };

      gaplessPlayerRef.current.onplay = () => {
        setTimeout(() => {
          setIsPlaying(true);
          setIsLoading(false);
        }, 0);
      };

      gaplessPlayerRef.current.onpause = () => {
        // Only update isPlaying if user explicitly paused
        if (!userIntentToPlay) {
          setIsPlaying(false);
        }
      };

      gaplessPlayerRef.current.onstop = () => {
        setIsPlaying(false);
        setIsLoading(false);
        setUserIntentToPlay(false);
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
        setUserIntentToPlay(false);
      };

      gaplessPlayerRef.current.onerror = (track_path, error) => {
        const isDurationError = error?.message?.includes('duration') ||
                               error?.message?.includes('Cannot read properties of null');

        if (!isDurationError) {
          console.warn('Gapless player error:', error);
          setAlert(`Error playing track: ${error}`);
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
      setUserIntentToPlay(false);
    };
  }, [activePlaylist, activeTrack, setActiveTrack, setAlert]);

  return {
    gaplessPlayerRef,
    isPlaying: userIntentToPlay,
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
