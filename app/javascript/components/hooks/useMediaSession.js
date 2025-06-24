import { useEffect } from "react";
import { formatDate } from "../helpers/utils";
import { isIOS } from "../helpers/utils";

export const useMediaSession = (activeTrack, controls, isPlaying = false) => {
  useEffect(() => {
    if ('mediaSession' in navigator && activeTrack) {
      navigator.mediaSession.metadata = new MediaMetadata({
        title: activeTrack.title,
        artist: `Phish - ${formatDate(activeTrack.show_date)}`,
        album: `${formatDate(activeTrack.show_date)} - ${activeTrack.venue_name}`,
        artwork: [{
          src: activeTrack.show_cover_art_urls.medium,
          sizes: "256x256",
          type: "image/jpeg",
        }]
      });

      navigator.mediaSession.setActionHandler('play', controls.onPlayPause);
      navigator.mediaSession.setActionHandler('pause', controls.onPlayPause);
      navigator.mediaSession.setActionHandler('previoustrack', controls.onPrevious);
      navigator.mediaSession.setActionHandler('nexttrack', controls.onNext);

      // Don't set scrub buttons for iOS devices as they interfere with next/prev buttons
      if (!isIOS()) {
        navigator.mediaSession.setActionHandler('seekbackward', (details) => {
          controls.onScrub(-10);
        });
        navigator.mediaSession.setActionHandler('seekforward', (details) => {
          controls.onScrub(10);
        });
      }
    }
  }, [activeTrack, controls]);

  useEffect(() => {
    if ('mediaSession' in navigator) {
      navigator.mediaSession.playbackState = isPlaying ? 'playing' : 'paused';
    }
  }, [isPlaying]);
};

