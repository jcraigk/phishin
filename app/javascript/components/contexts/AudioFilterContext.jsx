import React, { createContext, useContext, useState, useEffect } from 'react';
import { getAudioStatusFilter } from '../helpers/utils';

const AudioFilterContext = createContext();

export const useAudioFilter = () => {
  const context = useContext(AudioFilterContext);
  if (!context) {
    throw new Error('useAudioFilter must be used within an AudioFilterProvider');
  }
  return context;
};

export const AudioFilterProvider = ({ children }) => {
  const [hideMissingAudio, setHideMissingAudio] = useState(() => getAudioStatusFilter() === 'complete_or_partial');
  const [isFilterLoading, setIsFilterLoading] = useState(false);

  const toggleHideMissingAudio = () => {
    const newValue = !hideMissingAudio;
    setHideMissingAudio(newValue);
    localStorage.setItem('hideMissingAudio', JSON.stringify(newValue));
  };

  const getAudioStatusParam = () => {
    return hideMissingAudio ? 'complete_or_partial' : 'any';
  };

  const value = {
    hideMissingAudio,
    toggleHideMissingAudio,
    getAudioStatusParam,
    isFilterLoading,
    setIsFilterLoading,
  };

  return (
    <AudioFilterContext.Provider value={value}>
      {children}
    </AudioFilterContext.Provider>
  );
};
