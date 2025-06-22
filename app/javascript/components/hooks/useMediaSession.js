import { useEffect } from "react";
import { formatDate } from "../helpers/utils";
import { PLAYER_CONSTANTS } from "../helpers/playerConstants";

export const useMediaSession = (activeTrack, controls) => {
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

      const actionHandlers = {
        'previoustrack': controls.onPrevious,
        'nexttrack': controls.onNext,
        'play': controls.onPlayPause,
        'pause': controls.onPlayPause,
        'stop': controls.onPlayPause,
        'seekbackward': () => controls.onScrub(-PLAYER_CONSTANTS.SCRUB_SECONDS),
        'seekforward': () => controls.onScrub(PLAYER_CONSTANTS.SCRUB_SECONDS),
      };

      Object.entries(actionHandlers).forEach(([action, handler]) => {
        navigator.mediaSession.setActionHandler(action, handler);
      });
    }
  }, [activeTrack, controls]);
};
