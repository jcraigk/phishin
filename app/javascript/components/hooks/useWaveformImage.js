import { useState, useEffect, useRef } from "react";
import { PLAYER_CONSTANTS } from "../helpers/playerConstants";

export const useWaveformImage = (activeTrack) => {
  const scrubberRef = useRef();
  const progressBarRef = useRef();
  const previousTrackRef = useRef(null);
  const [fadeClass, setFadeClass] = useState("fade-in");
  const [isFadeOutComplete, setIsFadeOutComplete] = useState(false);
  const [isImageLoaded, setIsImageLoaded] = useState(false);

  useEffect(() => {
    if (previousTrackRef.current && previousTrackRef.current !== activeTrack) {
      if (scrubberRef.current) {
        scrubberRef.current.style.backgroundImage = '';
      }
      if (progressBarRef.current) {
        progressBarRef.current.style.maskImage = '';
      }
    }

    if (activeTrack && activeTrack.waveform_image_url) {
      setFadeClass("fade-out");
      setIsFadeOutComplete(false);
      setIsImageLoaded(false);

      const fadeOutTimer = setTimeout(() => {
        setIsFadeOutComplete(true);
      }, PLAYER_CONSTANTS.WAV_FADE_DURATION);

      const newImage = new Image();
      newImage.src = activeTrack.waveform_image_url;
      newImage.onload = () => setIsImageLoaded(true);

      return () => {
        clearTimeout(fadeOutTimer);
        newImage.src = '';
        newImage.onload = null;
        newImage.onerror = null;
      };
    } else {
      setIsImageLoaded(false);
      setIsFadeOutComplete(true);
      previousTrackRef.current = activeTrack;
    }
  }, [activeTrack]);

  useEffect(() => {
    if (isFadeOutComplete && isImageLoaded && activeTrack) {
      if (scrubberRef.current && activeTrack.waveform_image_url) {
        scrubberRef.current.style.backgroundImage = `url(${activeTrack.waveform_image_url})`;
      }
      if (progressBarRef.current && activeTrack.waveform_image_url) {
        progressBarRef.current.style.maskImage = `url(${activeTrack.waveform_image_url})`;
      }
      setFadeClass("fade-in");
      previousTrackRef.current = activeTrack;
    }
  }, [isFadeOutComplete, isImageLoaded, activeTrack]);

  return {
    scrubberRef,
    progressBarRef,
    fadeClass,
  };
};
