import { useState, useEffect, useRef } from "react";
import { PLAYER_CONSTANTS } from "../helpers/playerConstants";

export const useWaveformImage = (activeTrack) => {
  const scrubberRef = useRef();
  const progressBarRef = useRef();
  const [fadeClass, setFadeClass] = useState("fade-in");
  const [isFadeOutComplete, setIsFadeOutComplete] = useState(false);
  const [isImageLoaded, setIsImageLoaded] = useState(false);

  useEffect(() => {
    if (activeTrack) {
      setFadeClass("fade-out");
      setIsFadeOutComplete(false);
      setIsImageLoaded(false);

      const fadeOutTimer = setTimeout(() => {
        setIsFadeOutComplete(true);
      }, PLAYER_CONSTANTS.WAV_FADE_DURATION);

      const newImage = new Image();
      newImage.src = activeTrack.waveform_image_url;
      newImage.onload = () => setIsImageLoaded(true);

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

  return {
    scrubberRef,
    progressBarRef,
    fadeClass,
  };
};
