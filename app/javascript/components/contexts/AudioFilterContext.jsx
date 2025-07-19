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

export const AudioFilterProvider = ({ children, navigate = null }) => {
  const [hideMissingAudio, setHideMissingAudio] = useState(() => getAudioStatusFilter() === 'complete_or_partial');
  const [isFilterLoading, setIsFilterLoading] = useState(false);

  const toggleHideMissingAudio = () => {
    const newValue = !hideMissingAudio;
    setHideMissingAudio(newValue);
    localStorage.setItem('hideMissingAudio', JSON.stringify(newValue));

    // If navigation is available, trigger a reload by navigating to current URL with page=1
    if (navigate) {
      const currentUrl = new URL(window.location.href);
      const searchParams = new URLSearchParams(currentUrl.search);

      // Reset to page 1 if this is a paginated route
      if (searchParams.has('page')) {
        searchParams.set('page', '1');
      }

      // Navigate to the same route to trigger loader refresh
      navigate(`${currentUrl.pathname}?${searchParams.toString()}`);
    }
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
