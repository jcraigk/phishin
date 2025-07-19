import { useState, useRef, useEffect } from "react";
import { Gapless5 } from "@regosen/gapless-5";
import { PLAYER_CONSTANTS } from "../helpers/playerConstants";
import { isIOS } from "../helpers/utils";

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

  const getCurrentTrackExcerptTimes = () => {
    const tracksWithAudio = activePlaylist ? activePlaylist.filter(track => track.mp3_url) : [];

    if (!tracksWithAudio || currentTrackIndex < 0 || currentTrackIndex >= tracksWithAudio.length) {
      return { startTime: 0, endTime: null };
    }

    const track = tracksWithAudio[currentTrackIndex];
    const startSecond = parseInt(track.starts_at_second) || 0;
    const endSecond = parseInt(track.ends_at_second) || 0;

    return {
      startTime: startSecond > 0 ? startSecond : 0,
      endTime: endSecond > 0 ? endSecond : null
    };
  };

  const checkExcerptEndTime = () => {
    if (!activePlaylist || !gaplessPlayerRef.current) return;

    const tracksWithAudio = activePlaylist.filter(track => track.mp3_url);

    const playerTrackIndex = gaplessPlayerRef.current.getIndex();
    if (playerTrackIndex < 0 || playerTrackIndex >= tracksWithAudio.length) return;

    const currentTrack = tracksWithAudio[playerTrackIndex];
    const endSecond = parseInt(currentTrack.ends_at_second) || 0;
    if (!endSecond) return;

    const currentPosition = getPlayerPosition();
    if (currentPosition >= endSecond) {
      skipToNextTrack();
    }
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

    if (isIOS() && isLoading) {
      setIsLoading(false);
      gaplessPlayerRef.current.play();
    } else {
      gaplessPlayerRef.current.playpause();
    }
  };

  const scrub = (seconds) => {
    if (!gaplessPlayerRef.current || !activeTrack) return;
    const currentPosition = getPlayerPosition();
    const { startTime, endTime } = getCurrentTrackExcerptTimes();

    if (currentPosition >= 0) {
      const trackDuration = activeTrack.duration / 1000;
      const effectiveEndTime = endTime || trackDuration;

      // Prevent scrubbing forward if we're near the end of the excerpt
      if (seconds > 0 && currentPosition >= effectiveEndTime - PLAYER_CONSTANTS.SCRUB_SECONDS) return;

      const newTime = currentPosition + seconds;
      const clampedTime = Math.max(startTime, Math.min(newTime, effectiveEndTime));
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

    const tracksWithAudio = activePlaylist.filter(track => track.mp3_url);
    const currentPosition = getPlayerPosition();
    const { startTime } = getCurrentTrackExcerptTimes();

    if (currentPosition > PLAYER_CONSTANTS.PREVIOUS_TRACK_THRESHOLD) {
      // Reset to the start of the excerpt (or beginning if no excerpt)
      gaplessPlayerRef.current.setPosition(startTime * 1000);
    } else {
      const currentIndex = gaplessPlayerRef.current.getIndex();
      const previousIndex = currentIndex - 1;
      if (previousIndex >= 0) {
        gaplessPlayerRef.current.gotoTrack(previousIndex);
        const previousTrack = tracksWithAudio[previousIndex];
        if (previousTrack) {
          setActiveTrack(previousTrack);
          setCurrentTrackIndex(previousIndex);

          // Set excerpt start time for the previous track
          const prevStartSecond = parseInt(previousTrack.starts_at_second) || 0;
          if (prevStartSecond > 0) {
            setTimeout(() => {
              if (gaplessPlayerRef.current) {
                gaplessPlayerRef.current.setPosition(prevStartSecond * 1000);
              }
            }, 100);
          }
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
    const tracksWithAudio = activePlaylist.filter(track => track.mp3_url);
    return currentTrackIndex < tracksWithAudio.length - 1;
  };

  const canScrubForward = () => {
    if (!activeTrack || !gaplessPlayerRef.current) return false;
    const currentPosition = getPlayerPosition();
    const { startTime, endTime } = getCurrentTrackExcerptTimes();
    const trackDuration = activeTrack.duration / 1000;
    const effectiveEndTime = endTime || trackDuration;

    return effectiveEndTime > PLAYER_CONSTANTS.SCRUB_SECONDS &&
           currentPosition < effectiveEndTime - PLAYER_CONSTANTS.SCRUB_SECONDS;
  };

  const handleScrubberClick = (e) => {
    if (gaplessPlayerRef.current && activeTrack) {
      const currentPosition = gaplessPlayerRef.current.getPosition();
      const { startTime, endTime } = getCurrentTrackExcerptTimes();

      if (currentPosition >= 0) {
        const clickPosition = e.nativeEvent.offsetX / e.target.offsetWidth;
        const trackDuration = activeTrack.duration / 1000;
        const effectiveEndTime = endTime || trackDuration;

        // Calculate the new time within the excerpt range
        const excerptDuration = effectiveEndTime - startTime;
        const newTime = startTime + (clickPosition * excerptDuration);
        const clampedTime = Math.max(startTime, Math.min(newTime, effectiveEndTime));

        gaplessPlayerRef.current.setPosition(clampedTime * 1000);
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

      const tracksWithAudio = activePlaylist.filter(track => track.mp3_url);
      if (tracksWithAudio.length === 0) return;

      const trackUrls = tracksWithAudio.map(track => track.mp3_url);
      const activeIndex = tracksWithAudio.findIndex(track => track.id === activeTrack?.id);
      const validActiveIndex = activeIndex >= 0 && activeIndex < tracksWithAudio.length ? activeIndex : 0;

      const iosDevice = isIOS();
      gaplessPlayerRef.current = new Gapless5({
        tracks: trackUrls,
        loop: false,
        singleMode: false,
        useWebAudio: !iosDevice,
        useHTML5Audio: true,
        loadLimit: iosDevice ? 2 : 1,
        volume: 1.0,
        startingTrack: validActiveIndex
      });

      gaplessPlayerRef.current.ontimeupdate = (current_track_time, current_track_index) => {
        const timeInSeconds = current_track_time / 1000;
        setCurrentTime(timeInSeconds);
        setCurrentTrackIndex(current_track_index);

        // Check if we should auto-advance due to excerpt end time
        checkExcerptEndTime();
      };

      gaplessPlayerRef.current.onloadstart = () => {
        setIsLoading(true);

        if (isIOS() && (shouldAutoplay || shouldContinuePlayingRef.current)) {
          setTimeout(() => {
            if (gaplessPlayerRef.current) {
              setIsLoading(false);
              gaplessPlayerRef.current.play();
              if (setShouldAutoplay) setShouldAutoplay(false);
            }
          }, 100);
        }
      };

      gaplessPlayerRef.current.onload = () => {
        setIsLoading(false);
        if (gaplessPlayerRef.current) {
          // Handle excerpt start time or URL start time
          const { startTime: excerptStartTime } = getCurrentTrackExcerptTimes();
          const startTimeToUse = pendingStartTime !== null ? pendingStartTime : excerptStartTime;

          if (startTimeToUse > 0) {
            gaplessPlayerRef.current.setPosition(startTimeToUse * 1000);
          }

          if (pendingStartTime !== null) {
            setPendingStartTime(null);
          }

          if ((shouldAutoplay || shouldContinuePlayingRef.current) && !isIOS()) {
            gaplessPlayerRef.current.play();
            if (setShouldAutoplay) setShouldAutoplay(false);
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
        if (newIndex >= 0 && newIndex < tracksWithAudio.length) {
          setCurrentTrackIndex(newIndex);
          setActiveTrack(tracksWithAudio[newIndex]);

          // Set excerpt start time for the new track
          const track = tracksWithAudio[newIndex];
          const startSecond = parseInt(track.starts_at_second) || 0;
          if (startSecond > 0) {
            setTimeout(() => {
              if (gaplessPlayerRef.current) {
                gaplessPlayerRef.current.setPosition(startSecond * 1000);
              }
            }, 100);
          }
        }
      };

      gaplessPlayerRef.current.onprev = () => {
        const newIndex = gaplessPlayerRef.current.getIndex();
        if (newIndex >= 0 && newIndex < tracksWithAudio.length) {
          setCurrentTrackIndex(newIndex);
          setActiveTrack(tracksWithAudio[newIndex]);

          // Set excerpt start time for the new track
          const track = tracksWithAudio[newIndex];
          const startSecond = parseInt(track.starts_at_second) || 0;
          if (startSecond > 0) {
            setTimeout(() => {
              if (gaplessPlayerRef.current) {
                gaplessPlayerRef.current.setPosition(startSecond * 1000);
              }
            }, 100);
          }
        }
      };

      gaplessPlayerRef.current.onfinishedall = () => {
        setIsPlaying(false);
        setIsLoading(false);
      };

      gaplessPlayerRef.current.onerror = (track_path, error) => {
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
