/**
 * Centralized utilities for audio filter localStorage management
 * Used by both React Router loaders and React components
 */

export const getHideMissingAudioFromStorage = () => {
  const stored = localStorage.getItem('hideMissingAudio');
  return stored !== null ? JSON.parse(stored) : true; // Default to true (hide missing audio)
};

export const getAudioStatusFilterFromStorage = () => {
  return getHideMissingAudioFromStorage() ? 'complete_or_partial' : 'any';
};

export const getTrackAudioStatusFilterFromStorage = () => {
  return getHideMissingAudioFromStorage() ? 'complete' : 'any';
};
