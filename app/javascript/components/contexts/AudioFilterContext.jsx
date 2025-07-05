import React, { createContext, useContext, useState, useEffect } from 'react';

const AudioFilterContext = createContext();

export const useAudioFilter = () => {
  const context = useContext(AudioFilterContext);
  if (!context) {
    throw new Error('useAudioFilter must be used within an AudioFilterProvider');
  }
  return context;
};

export const AudioFilterProvider = ({ children }) => {
  // Read localStorage synchronously during initialization to prevent double fetching
  const getInitialShowMissingAudio = () => {
    const stored = localStorage.getItem('showMissingAudio');
    return stored !== null ? JSON.parse(stored) : false;
  };

  const [showMissingAudio, setShowMissingAudio] = useState(getInitialShowMissingAudio);

  const toggleShowMissingAudio = () => {
    const newValue = !showMissingAudio;
    setShowMissingAudio(newValue);
    localStorage.setItem('showMissingAudio', JSON.stringify(newValue));
  };

  // Get the audio_status parameter for API calls
  const getAudioStatusFilter = () => {
    return showMissingAudio ? 'any' : 'complete_or_partial';
  };

  const value = {
    showMissingAudio,
    toggleShowMissingAudio,
    getAudioStatusFilter,
  };

  return (
    <AudioFilterContext.Provider value={value}>
      {children}
    </AudioFilterContext.Provider>
  );
};
