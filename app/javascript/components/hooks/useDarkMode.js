import { useEffect } from "react";
import { enable, disable, auto, setFetchMethod } from "darkreader";

const DARK_READER_CONFIG = {
  brightness: 100,
  contrast: 90,
  sepia: 10,
  css: `
    /* Preserve waveform scrubber and progress bar */
    .scrubber-bar {
      filter: none !important;
      -webkit-filter: none !important;
      mix-blend-mode: normal !important;
      isolation: isolate !important;
    }
    .progress-bar {
      filter: none !important;
      -webkit-filter: none !important;
      mix-blend-mode: normal !important;
      mask-mode: alpha !important;
    }
    
    /* Preserve play button colors */
    .play-pause-btn {
      background: #515152 !important;
      background-color: #515152 !important;
      filter: none !important;
      -webkit-filter: none !important;
    }
    .play-pause-btn:hover:not(:disabled) {
      background: #424243 !important;
      background-color: #424243 !important;
    }
    .play-pause-btn.playing {
      background: #03BBF2 !important;
      background-color: #03BBF2 !important;
    }
    .play-pause-btn.playing:hover:not(:disabled) {
      background: #02a8da !important;
      background-color: #02a8da !important;
    }
    .play-pause-btn:disabled {
      background: #6a6a6b !important;
      background-color: #6a6a6b !important;
    }
    .play-pause-btn.playing:disabled {
      background: #3dcbf5 !important;
      background-color: #3dcbf5 !important;
    }
    .play-pause-btn svg {
      color: white !important;
    }
    
    /* Preserve blue hover on control buttons */
    .controls button:hover:not(:disabled) {
      color: #03BBF2 !important;
    }
    
    /* Preserve link hover colors */
    .audio-player a:hover {
      color: #03BBF2 !important;
    }
  `
};

const useDarkMode = () => {
  useEffect(() => {
    setFetchMethod(window.fetch);
    auto(DARK_READER_CONFIG);

    return () => {
      auto(false);
      disable();
    };
  }, []);
};

export default useDarkMode;

