import { useEffect } from "react";
import { enable, disable, setFetchMethod } from "darkreader";

const DARK_MODE_FIXES_ID = 'dark-mode-fixes';

const DARK_MODE_FIXES_CSS = `
  .select select,
  .input,
  .textarea {
    border-color: #4a4a4a !important;
  }
  .select select:focus,
  .select select:active,
  .input:focus,
  .input:active {
    border-color: #6d6f71 !important;
    box-shadow: none !important;
    outline: none !important;
  }
  .button {
    background-color: #515152 !important;
    border-color: #4a4a4a !important;
    color: #e0e0e0 !important;
  }
  .button:hover {
    background-color: #03BBF2 !important;
    border-color: #03BBF2 !important;
    color: white !important;
  }
  .button.is-active {
    background-color: #03BBF2 !important;
    border-color: #03BBF2 !important;
    color: white !important;
  }
  .context-dropdown .button {
    background-color: transparent !important;
    border-color: transparent !important;
    box-shadow: none !important;
    color: inherit !important;
  }
  .context-dropdown .button:hover {
    background-color: rgba(255, 255, 255, 0.1) !important;
    border-color: transparent !important;
    color: inherit !important;
  }
  .play-pause-btn {
    background: #404040 !important;
    background-color: #404040 !important;
    filter: none !important;
    -webkit-filter: none !important;
  }
  .play-pause-btn:hover:not(:disabled) {
    background: #353535 !important;
    background-color: #353535 !important;
  }
  .play-pause-btn.playing {
    background: #03bbf2 !important;
    background-color: #03bbf2 !important;
  }
  .play-pause-btn.playing:hover:not(:disabled) {
    background: #02a8da !important;
    background-color: #02a8da !important;
  }
  .play-pause-btn svg {
    color: white !important;
    fill: white !important;
  }
  .play-pause-btn .loading-spinner {
    border-color: rgba(255, 255, 255, 0.5) !important;
    border-top-color: white !important;
  }
  .scrubber-container,
  .progress-overlay {
    filter: none !important;
  }
  .controls button:hover:not(:disabled),
  .audio-player a:hover {
    color: #03BBF2 !important;
  }
`;

const injectDarkModeFixes = () => {
  if (document.getElementById(DARK_MODE_FIXES_ID)) return;
  const style = document.createElement('style');
  style.id = DARK_MODE_FIXES_ID;
  style.textContent = DARK_MODE_FIXES_CSS;
  document.head.appendChild(style);
};

const removeDarkModeFixes = () => {
  const style = document.getElementById(DARK_MODE_FIXES_ID);
  if (style) style.remove();
};

const DARK_READER_CONFIG = {
  brightness: 100,
  contrast: 90,
  sepia: 10,
  css: `
    /* Preserve waveform scrubber and progress bar */
    .scrubber-container {
      filter: none !important;
      -webkit-filter: none !important;
      mix-blend-mode: normal !important;
      isolation: isolate !important;
    }
    .progress-overlay {
      filter: none !important;
      -webkit-filter: none !important;
      mix-blend-mode: normal !important;
      mask-mode: alpha !important;
    }
    
    /* Preserve play button colors */
    .play-pause-btn,
    .audio-player .play-pause-btn,
    .controls .play-pause-btn {
      background: #404040 !important;
      background-color: #404040 !important;
      filter: none !important;
      -webkit-filter: none !important;
    }
    .play-pause-btn:hover:not(:disabled),
    .audio-player .play-pause-btn:hover:not(:disabled),
    .controls .play-pause-btn:hover:not(:disabled) {
      background: #353535 !important;
      background-color: #353535 !important;
    }
    .play-pause-btn.playing,
    .audio-player .play-pause-btn.playing,
    .controls .play-pause-btn.playing {
      background: #03bbf2 !important;
      background-color: #03bbf2 !important;
      filter: none !important;
      -webkit-filter: none !important;
    }
    .play-pause-btn.playing:hover:not(:disabled),
    .audio-player .play-pause-btn.playing:hover:not(:disabled),
    .controls .play-pause-btn.playing:hover:not(:disabled) {
      background: #02a8da !important;
      background-color: #02a8da !important;
    }
    .play-pause-btn svg,
    .play-pause-btn .play-icon,
    .play-pause-btn .pause-icon {
      fill: white !important;
      color: white !important;
    }
    .play-pause-btn .loading-spinner {
      border-color: rgba(255, 255, 255, 0.5) !important;
      border-top-color: white !important;
      filter: none !important;
      -webkit-filter: none !important;
    }
    
    /* Preserve blue hover on control buttons */
    .controls button:hover:not(:disabled) {
      color: #03BBF2 !important;
    }
    
    /* Preserve link hover colors */
    .audio-player a:hover {
      color: #03BBF2 !important;
    }
    
    /* Fix form element borders - remove red outlines */
    .select select,
    .select:not(.is-multiple):not(.is-loading)::after,
    .input,
    .textarea {
      border-color: #4a4a4a !important;
      --darkreader-inline-border-top: #4a4a4a !important;
      --darkreader-inline-border-right: #4a4a4a !important;
      --darkreader-inline-border-bottom: #4a4a4a !important;
      --darkreader-inline-border-left: #4a4a4a !important;
    }
    .select select:focus,
    .select select:active,
    .input:focus,
    .input:active,
    .textarea:focus,
    .textarea:active {
      border-color: #6d6f71 !important;
      --darkreader-inline-border-top: #6d6f71 !important;
      --darkreader-inline-border-right: #6d6f71 !important;
      --darkreader-inline-border-bottom: #6d6f71 !important;
      --darkreader-inline-border-left: #6d6f71 !important;
      box-shadow: none !important;
      outline: none !important;
    }
    
    /* Sidebar styling */
    #sidebar {
      border-color: #4a4a4a !important;
    }
    
    /* Button styling */
    .button {
      background-color: #515152 !important;
      --darkreader-inline-bgcolor: #515152 !important;
      border-color: #4a4a4a !important;
      --darkreader-inline-border-top: #4a4a4a !important;
      --darkreader-inline-border-right: #4a4a4a !important;
      --darkreader-inline-border-bottom: #4a4a4a !important;
      --darkreader-inline-border-left: #4a4a4a !important;
      color: #e0e0e0 !important;
      --darkreader-inline-color: #e0e0e0 !important;
    }
    .button:hover {
      background-color: #03BBF2 !important;
      --darkreader-inline-bgcolor: #03BBF2 !important;
      border-color: #03BBF2 !important;
      --darkreader-inline-border-top: #03BBF2 !important;
      --darkreader-inline-border-right: #03BBF2 !important;
      --darkreader-inline-border-bottom: #03BBF2 !important;
      --darkreader-inline-border-left: #03BBF2 !important;
      color: white !important;
      --darkreader-inline-color: white !important;
    }
    .button.is-active {
      background-color: #03BBF2 !important;
      --darkreader-inline-bgcolor: #03BBF2 !important;
      border-color: #03BBF2 !important;
    }
    
    /* Context menu ellipsis buttons - transparent background */
    .context-dropdown .button {
      background-color: transparent !important;
      --darkreader-inline-bgcolor: transparent !important;
      border-color: transparent !important;
      --darkreader-inline-border-top: transparent !important;
      --darkreader-inline-border-right: transparent !important;
      --darkreader-inline-border-bottom: transparent !important;
      --darkreader-inline-border-left: transparent !important;
      box-shadow: none !important;
      color: inherit !important;
      --darkreader-inline-color: inherit !important;
    }
    .context-dropdown .button:hover {
      background-color: rgba(255, 255, 255, 0.1) !important;
      --darkreader-inline-bgcolor: rgba(255, 255, 255, 0.1) !important;
      border-color: transparent !important;
      --darkreader-inline-border-top: transparent !important;
      --darkreader-inline-border-right: transparent !important;
      --darkreader-inline-border-bottom: transparent !important;
      --darkreader-inline-border-left: transparent !important;
      color: inherit !important;
      --darkreader-inline-color: inherit !important;
    }
  `
};

const useDarkMode = () => {
  useEffect(() => {
    setFetchMethod(window.fetch);
    
    const applyTheme = (isDark) => {
      if (isDark) {
        enable(DARK_READER_CONFIG);
        setTimeout(injectDarkModeFixes, 100);
      } else {
        disable();
        removeDarkModeFixes();
      }
    };

    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
    applyTheme(mediaQuery.matches);

    const handleChange = (e) => applyTheme(e.matches);
    mediaQuery.addEventListener('change', handleChange);

    return () => {
      mediaQuery.removeEventListener('change', handleChange);
      disable();
      removeDarkModeFixes();
    };
  }, []);
};

export default useDarkMode;

