import { useState, useEffect, useRef } from 'react';
import { useAudioFilter } from '../contexts/AudioFilterContext';

export const useAudioFilteredData = (initialData, fetchFunction, dependencies = [], initialFilter = null) => {
  const [data, setData] = useState(initialData);
  const [isLoading, setIsLoading] = useState(false);
  const { hideMissingAudio, getAudioStatusParam, setIsFilterLoading } = useAudioFilter();

  const initialFilterRef = useRef();
  const hasInitialized = useRef(false);
  const lastFetchedFilter = useRef();

  if (initialFilterRef.current === undefined) {
    initialFilterRef.current = initialFilter || getAudioStatusParam();
  }
  if (lastFetchedFilter.current === undefined) {
    lastFetchedFilter.current = initialFilter || getAudioStatusParam();
  }

  useEffect(() => {
    const currentAudioStatusFilter = getAudioStatusParam();

    if (!hasInitialized.current && initialData === null) {
      hasInitialized.current = true;
      initialFilterRef.current = currentAudioStatusFilter;
      lastFetchedFilter.current = currentAudioStatusFilter;

      const fetchData = async () => {
        setIsFilterLoading(true);
        const newData = await fetchFunction(currentAudioStatusFilter).catch(error => {
          console.error('Error fetching initial data:', error);
          return initialData;
        });
        setData(newData);
        setIsFilterLoading(false);
      };

      fetchData();
      return;
    }

    if (!hasInitialized.current) {
      hasInitialized.current = true;
      initialFilterRef.current = initialFilter || currentAudioStatusFilter;
      lastFetchedFilter.current = initialFilter || currentAudioStatusFilter;

      if (currentAudioStatusFilter === (initialFilter || currentAudioStatusFilter)) {
        return;
      }
    }

    if (currentAudioStatusFilter === lastFetchedFilter.current) {
      return;
    }

    const fetchData = async () => {
      setIsFilterLoading(true);
      const newData = await fetchFunction(currentAudioStatusFilter).catch(error => {
        console.error('Error fetching filtered data:', error);
        return data;
      });
      setData(newData);
      lastFetchedFilter.current = currentAudioStatusFilter;
      setIsFilterLoading(false);
    };

    fetchData();
  }, [hideMissingAudio, fetchFunction, setIsFilterLoading, ...dependencies]);

  useEffect(() => {
    if (initialData && lastFetchedFilter.current === (initialFilter || getAudioStatusParam())) {
      setData(initialData);
    }
  }, [initialData, initialFilter, getAudioStatusParam]);

  return { data, isLoading };
};

export const useClientSideAudioFilter = (data, filterFunction) => {
  const { hideMissingAudio } = useAudioFilter();

  return hideMissingAudio ? data.filter(filterFunction) : data;
};
