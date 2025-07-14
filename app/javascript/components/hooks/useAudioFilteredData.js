import { useState, useEffect, useRef } from 'react';
import { useAudioFilter } from '../contexts/AudioFilterContext';

/**
 * Custom hook for handling data fetching with audio filter integration
 * Simplifies the pattern used across multiple components
 */
export const useAudioFilteredData = (initialData, fetchFunction, dependencies = []) => {
  const [data, setData] = useState(initialData);
  const [isLoading, setIsLoading] = useState(false);
  const { hideMissingAudio, getAudioStatusFilter, setIsFilterLoading } = useAudioFilter();
  const initialFilterRef = useRef(getAudioStatusFilter());
  const hasInitialized = useRef(false);

  useEffect(() => {
    const currentAudioStatusFilter = getAudioStatusFilter();

    // For initial load when no initialData is provided (like search), fetch data immediately
    if (!hasInitialized.current && initialData === null) {
      hasInitialized.current = true;
      initialFilterRef.current = currentAudioStatusFilter;

      const fetchData = async () => {
        setIsFilterLoading(true);
        try {
          const newData = await fetchFunction(currentAudioStatusFilter);
          setData(newData);
        } catch (error) {
          console.error('Error fetching initial data:', error);
        } finally {
          setIsFilterLoading(false);
        }
      };

      fetchData();
      return;
    }

    // Skip initial fetch if filter hasn't changed and we have initial data
    if (!hasInitialized.current) {
      initialFilterRef.current = currentAudioStatusFilter;
      hasInitialized.current = true;
      return;
    }

    // Skip if filter hasn't changed
    if (currentAudioStatusFilter === initialFilterRef.current) {
      return;
    }

    // Fetch new data with current filter
    const fetchData = async () => {
      setIsFilterLoading(true);
      try {
        const newData = await fetchFunction(currentAudioStatusFilter);
        setData(newData);
        initialFilterRef.current = currentAudioStatusFilter;
      } catch (error) {
        console.error('Error fetching filtered data:', error);
      } finally {
        setIsFilterLoading(false);
      }
    };

    fetchData();
  }, [hideMissingAudio, fetchFunction, setIsFilterLoading, initialData, ...dependencies]);

  // Update data when initial data changes (e.g., from loader)
  useEffect(() => {
    setData(initialData);
  }, [initialData]);

  return { data, isLoading };
};

/**
 * Simpler hook for client-side filtering of data
 * Used when no API calls are needed, just filtering existing data
 */
export const useClientSideAudioFilter = (data, filterFunction) => {
  const { hideMissingAudio } = useAudioFilter();

  return hideMissingAudio ? data.filter(filterFunction) : data;
};
