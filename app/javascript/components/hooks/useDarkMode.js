import { useEffect } from "react";
import { enable, disable, setFetchMethod } from "darkreader";

const DARK_MODE_FIXES_ID = 'dark-mode-fixes';

const DARK_MODE_CSS = `
  /* Fix form element borders - remove red outlines */
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
  
  /* Button styling */
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
  
  /* Audio player play button */
  .play-pause-btn {
    background: #515152 !important;
    background-color: #515152 !important;
  }
  .play-pause-btn.playing {
    background: #03BBF2 !important;
    background-color: #03BBF2 !important;
  }
  .play-pause-btn svg {
    color: white !important;
  }
  
  /* Progress bar */
  .scrubber-bar,
  .progress-bar {
    filter: none !important;
  }
  
  /* Blue hover colors */
  .controls button:hover:not(:disabled),
  .audio-player a:hover {
    color: #03BBF2 !important;
  }
`;

const injectDarkModeCSS = () => {
  if (document.getElementById(DARK_MODE_FIXES_ID)) return;
  
  const style = document.createElement('style');
  style.id = DARK_MODE_FIXES_ID;
  style.textContent = DARK_MODE_CSS;
  document.head.appendChild(style);
};

const removeDarkModeCSS = () => {
  const style = document.getElementById(DARK_MODE_FIXES_ID);
  if (style) style.remove();
};

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
  `
};

const useDarkMode = () => {
  useEffect(() => {
    setFetchMethod(window.fetch);
    
    const applyTheme = (isDark) => {
      if (isDark) {
        enable(DARK_READER_CONFIG);
        setTimeout(injectDarkModeCSS, 100);
      } else {
        disable();
        removeDarkModeCSS();
      }
    };

    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
    applyTheme(mediaQuery.matches);

    const handleChange = (e) => applyTheme(e.matches);
    mediaQuery.addEventListener('change', handleChange);

    return () => {
      mediaQuery.removeEventListener('change', handleChange);
      disable();
      removeDarkModeCSS();
    };
  }, []);
};

export default useDarkMode;

