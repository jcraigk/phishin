import React, { createContext, useContext, useState, useEffect } from 'react';
import { getHideMissingAudioFromStorage } from '../utils/audioFilter';

const AudioFilterContext = createContext();

export const useAudioFilter = () => {
  const context = useContext(AudioFilterContext);
  if (!context) {
    throw new Error('useAudioFilter must be used within an AudioFilterProvider');
  }
  return context;
};

export const AudioFilterProvider = ({ children }) => {
  const [hideMissingAudio, setHideMissingAudio] = useState(getHideMissingAudioFromStorage);

  const toggleHideMissingAudio = () => {
    const newValue = !hideMissingAudio;
    setHideMissingAudio(newValue);
    localStorage.setItem('hideMissingAudio', JSON.stringify(newValue));
  };

  // Get the audio_status parameter for API calls
  const getAudioStatusFilter = () => {
    return hideMissingAudio ? 'complete_or_partial' : 'any';
  };

  const value = {
    hideMissingAudio,
    toggleHideMissingAudio,
    getAudioStatusFilter,
  };

  return (
    <AudioFilterContext.Provider value={value}>
      {children}
    </AudioFilterContext.Provider>
  );
};
