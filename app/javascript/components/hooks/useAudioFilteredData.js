import { useState, useEffect, useRef } from 'react';
import { useAudioFilter } from '../contexts/AudioFilterContext';

export const useAudioFilteredData = (initialData, fetchFunction, dependencies = [], initialFilter = null) => {
  const [data, setData] = useState(initialData);
  const [isLoading, setIsLoading] = useState(false);
  const { hideMissingAudio, getAudioStatusParam, setIsFilterLoading } = useAudioFilter();

  const lastFetchedFilter = useRef(initialFilter);
  const hasInitialized = useRef(false);

  useEffect(() => {
    const currentAudioStatusFilter = getAudioStatusParam();

    if (!hasInitialized.current) {
      hasInitialized.current = true;

      if (initialData && initialFilter && initialFilter === currentAudioStatusFilter) {
        setData(initialData);
        lastFetchedFilter.current = currentAudioStatusFilter;
        return;
      }

      lastFetchedFilter.current = currentAudioStatusFilter;
    }

    if (currentAudioStatusFilter === lastFetchedFilter.current) {
      return;
    }

    const fetchData = async () => {
      setIsFilterLoading(true);
      try {
        const newData = await fetchFunction(currentAudioStatusFilter);
        setData(newData);
        lastFetchedFilter.current = currentAudioStatusFilter;
      } catch (error) {
        console.error('Error fetching filtered data:', error);
      } finally {
        setIsFilterLoading(false);
      }
    };

    fetchData();
  }, [hideMissingAudio, fetchFunction, setIsFilterLoading, initialData, initialFilter, getAudioStatusParam, ...dependencies]);

  return { data, isLoading };
};

export const useClientSideAudioFilter = (data, filterFunction) => {
  const { hideMissingAudio } = useAudioFilter();

  return hideMissingAudio ? data.filter(filterFunction) : data;
};
