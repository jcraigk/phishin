import { useState, useRef, useEffect, useMemo } from "react";
import { GaplessEngine } from "../player/GaplessEngine";
import { WebAudioBackend } from "../player/WebAudioBackend";
import { PLAYER_CONSTANTS } from "../helpers/playerConstants";

const toEngineTrack = (track) => ({
  url: track.mp3_url,
  offset: parseInt(track.starts_at_second) || 0,
  end: parseInt(track.ends_at_second) || null,
});

export const usePlayer = (activePlaylist, activeTrack, setActiveTrack, setNotice, setAlert, startTime, shouldAutoplay, setShouldAutoplay) => {
  const engineRef = useRef(null);
  const tracksRef = useRef([]);
  const startTimeAppliedRef = useRef(false);
  const [isPlaying, setIsPlaying] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [currentTrackIndex, setCurrentTrackIndex] = useState(0);

  const tracksWithAudio = useMemo(
    () => (activePlaylist || []).filter((track) => track.mp3_url),
    [activePlaylist]
  );
  tracksRef.current = tracksWithAudio;

  // A playlist can hold the same track twice with different excerpts, so
  // prefer the entry object itself and fall back to the id.
  const indexOfTrack = (track) => {
    if (!track) return -1;
    const byIdentity = tracksWithAudio.indexOf(track);
    return byIdentity >= 0 ? byIdentity : tracksWithAudio.findIndex((candidate) => candidate.id === track.id);
  };

  const engine = () => {
    if (!engineRef.current) {
      const backend = new WebAudioBackend();
      const instance = new GaplessEngine(backend);
      instance.onPlayChange = setIsPlaying;
      instance.onLoading = setIsLoading;
      instance.onTime = (seconds, index) => {
        setCurrentTime(seconds);
        setCurrentTrackIndex(index);
      };
      instance.onTrackChange = (index) => {
        setCurrentTrackIndex(index);
        const track = tracksRef.current[index];
        if (track) setActiveTrack(track);
      };
      instance.onError = (error) => {
        console.error("Playback failed", error);
        if (setAlert) setAlert("Audio failed to load");
      };
      engineRef.current = instance;
    }
    return engineRef.current;
  };

  useEffect(() => () => {
    if (engineRef.current) engineRef.current.destroy();
    engineRef.current = null;
  }, []);

  // A new playlist replaces the engine's track list. Layout sets the playlist,
  // the track and the autoplay flag together, so this is where a click on a
  // track in a different list starts playback.
  useEffect(() => {
    if (tracksWithAudio.length === 0) return;
    const index = Math.max(0, indexOfTrack(activeTrack));
    engine().load(tracksWithAudio.map(toEngineTrack), index);
    if (shouldAutoplay) {
      engine().play();
      if (setShouldAutoplay) setShouldAutoplay(false);
    }
  }, [tracksWithAudio]);

  // A new active track within the same playlist moves the engine to it.
  useEffect(() => {
    if (!activeTrack || tracksWithAudio.length === 0) return;
    const index = indexOfTrack(activeTrack);
    if (index < 0 || index === engine().index) return;
    engine().goto(index, { play: engine().playing || shouldAutoplay });
    if (shouldAutoplay && setShouldAutoplay) setShouldAutoplay(false);
  }, [activeTrack, tracksWithAudio]);

  // The start time belongs to the track named in the URL, so it is applied once.
  useEffect(() => {
    if (startTime === null || startTime === undefined || !activeTrack) return;
    if (startTimeAppliedRef.current || tracksWithAudio.length === 0) return;
    startTimeAppliedRef.current = true;

    const trackDuration = activeTrack.duration / 1000;
    if (startTime < 0 || (trackDuration > 0 && startTime > trackDuration)) {
      if (setAlert) setAlert("Invalid start time provided");
    } else if (startTime > 0) {
      engine().seek(startTime);
      if (setNotice) setNotice("Press the Play button to listen");
    }
  }, [startTime, activeTrack, tracksWithAudio]);

  const excerptRange = () => {
    const track = engine().track();
    const trackDuration = activeTrack ? activeTrack.duration / 1000 : 0;
    return {
      startTime: track?.offset || 0,
      endTime: track?.end || trackDuration,
    };
  };

  const togglePlayPause = () => engine().toggle();

  const scrub = (seconds) => {
    if (!activeTrack) return;
    const position = engine().position();
    const { endTime } = excerptRange();
    if (seconds > 0 && position >= endTime - seconds) return;
    engine().seek(position + seconds);
  };

  const skipToNextTrack = () => engine().next();

  const skipToPreviousTrack = () => {
    if (engine().position() - excerptRange().startTime > PLAYER_CONSTANTS.PREVIOUS_TRACK_THRESHOLD) {
      engine().seek(excerptRange().startTime);
    } else {
      engine().previous();
    }
  };

  const canSkipToPrevious = () => {
    if (tracksWithAudio.length === 0) return false;
    if (currentTrackIndex > 0) return true;
    return !isLoading && currentTime - excerptRange().startTime > PLAYER_CONSTANTS.PREVIOUS_TRACK_THRESHOLD;
  };

  const canSkipToNext = () => currentTrackIndex < tracksWithAudio.length - 1;

  const canScrubForward = () => {
    if (!activeTrack) return false;
    const { endTime } = excerptRange();
    return endTime > PLAYER_CONSTANTS.SCRUB_SECONDS &&
      currentTime < endTime - PLAYER_CONSTANTS.SCRUB_SECONDS;
  };

  const handleScrubberClick = (e) => {
    if (!activeTrack) return;
    const { startTime: excerptStart, endTime } = excerptRange();
    const fraction = e.nativeEvent.offsetX / e.target.offsetWidth;
    engine().seek(excerptStart + fraction * (endTime - excerptStart));
  };

  return {
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
