import { useState, useRef, useEffect } from "react";
import { Gapless5 } from "@regosen/gapless-5";
import { PLAYER_CONSTANTS } from "../helpers/playerConstants";

// iOS detection helper
const isIOS = () => {
  return /iPad|iPhone|iPod/.test(navigator.userAgent);
};

// iOS audio optimization notes:
// - WebAudio requires full file loading before playback, causing delays
// - HTML5 Audio can start playing immediately but has gaps between tracks
// - On iOS, using HTML5 Audio only provides faster startup at the cost of gapless playback
// - Disabling WebAudio also helps with background audio playback on iOS Safari

export const useGaplessPlayer = (activePlaylist, activeTrack, setActiveTrack, setNotice, setAlert, startTime, shouldAutoplay, setShouldAutoplay) => {
  const gaplessPlayerRef = useRef(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [currentTrackIndex, setCurrentTrackIndex] = useState(0);
  const [pendingStartTime, setPendingStartTime] = useState(null);
  const shouldContinuePlayingRef = useRef(false);

  const getPlayerPosition = () => {
    if (!gaplessPlayerRef.current) return 0;
    const position = gaplessPlayerRef.current.getPosition();
    return position >= 0 ? position / 1000 : 0;
  };

  useEffect(() => {
    if (startTime !== null && startTime !== undefined) {
      const trackDuration = activeTrack ? activeTrack.duration / 1000 : 0;

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

    try {
      // iOS fix: If still loading on first interaction, force it to stop loading and try to play
      if (isIOS() && isLoading) {
        console.log('iOS: User interaction while loading, forcing play attempt');
        setIsLoading(false);
        gaplessPlayerRef.current.play();
      } else {
        gaplessPlayerRef.current.playpause();
      }
    } catch (e) {
      console.error('Error in playpause:', e);
      // iOS fallback: if playpause fails, try direct play
      if (isIOS()) {
        try {
          gaplessPlayerRef.current.play();
        } catch (playError) {
          console.error('iOS play fallback also failed:', playError);
        }
      }
    }
  };

  const scrub = (seconds) => {
    if (!gaplessPlayerRef.current || !activeTrack) return;
    const currentPosition = getPlayerPosition();

    if (currentPosition >= 0) {
      const trackDuration = activeTrack.duration / 1000;

      if (seconds > 0 && currentPosition >= trackDuration - PLAYER_CONSTANTS.SCRUB_SECONDS) return;

      const newTime = currentPosition + seconds;
      const clampedTime = Math.max(0, Math.min(newTime, trackDuration));
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

    const currentPosition = getPlayerPosition();

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
    const currentPosition = getPlayerPosition();
    return currentPosition > PLAYER_CONSTANTS.PREVIOUS_TRACK_THRESHOLD;
  };

  const canSkipToNext = () => {
    if (!activePlaylist || !gaplessPlayerRef.current) return false;
    return currentTrackIndex < activePlaylist.length - 1;
  };

  const canScrubForward = () => {
    if (!activeTrack || !gaplessPlayerRef.current) return false;
    const currentPosition = getPlayerPosition();
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
                const iosDevice = isIOS();

        gaplessPlayerRef.current = new Gapless5({
          tracks: trackUrls,
          loop: false,
          singleMode: false,
          // iOS optimization: disable WebAudio for faster startup and better background playback
          useWebAudio: !iosDevice,
          useHTML5Audio: true,
          // iOS needs more aggressive preloading but limited to avoid memory issues
          loadLimit: iosDevice ? 2 : 1,
          volume: 1.0,
          startingTrack: validActiveIndex,
          // iOS-specific optimizations
          ...(iosDevice && {
            // Small crossfade to handle potential gaps on iOS
            crossfade: 25
          })
        });
      } catch (error) {
        console.error('Error initializing audio player');
        return;
      }

      gaplessPlayerRef.current.ontimeupdate = (current_track_time, current_track_index) => {
        const timeInSeconds = current_track_time / 1000;
        setCurrentTime(timeInSeconds);
        setCurrentTrackIndex(current_track_index);
      };

            gaplessPlayerRef.current.onloadstart = () => {
        setIsLoading(true);

        // iOS fix: Immediately attempt to play instead of waiting for onload
        if (isIOS() && (shouldAutoplay || shouldContinuePlayingRef.current)) {
          setTimeout(() => {
            if (gaplessPlayerRef.current) {
              console.log('iOS: Immediate play attempt on loadstart');
              setIsLoading(false);
              try {
                gaplessPlayerRef.current.play();
                if (setShouldAutoplay) setShouldAutoplay(false);
              } catch (e) {
                console.warn('iOS: Immediate play attempt failed:', e);
              }
            }
          }, 100); // Just a tiny delay to let the audio element initialize
        }
      };

                  gaplessPlayerRef.current.onload = () => {
        setIsLoading(false);
        if (gaplessPlayerRef.current) {
          if (pendingStartTime !== null) {
            gaplessPlayerRef.current.setPosition(pendingStartTime * 1000);
            setPendingStartTime(null);
          }

          // Autoplay if user clicked on a track, or if already playing (non-iOS or if iOS didn't already handle it)
          if ((shouldAutoplay || shouldContinuePlayingRef.current) && !isIOS()) {
            gaplessPlayerRef.current.play();
            if (setShouldAutoplay) setShouldAutoplay(false); // Reset after using
          }
        }
      };

      gaplessPlayerRef.current.onplay = () => {
        setTimeout(() => {
          setIsPlaying(true);
          setIsLoading(false);
          shouldContinuePlayingRef.current = true;
        }, 0);
      };

      gaplessPlayerRef.current.onpause = () => {
        setIsPlaying(false);
        shouldContinuePlayingRef.current = false;
      };

      gaplessPlayerRef.current.onstop = () => {
        setIsPlaying(false);
        setIsLoading(false);
        shouldContinuePlayingRef.current = false;
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
