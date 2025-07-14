import { useState, useEffect, useRef } from 'react';
import { useAudioFilter } from '../contexts/AudioFilterContext';

export const useAudioFilteredData = (initialData, fetchFunction, dependencies = []) => {
  const [data, setData] = useState(initialData);
  const [isLoading, setIsLoading] = useState(false);
  const { hideMissingAudio, getAudioStatusParam, setIsFilterLoading } = useAudioFilter();
  const initialFilterRef = useRef(getAudioStatusParam());
  const hasInitialized = useRef(false);

  useEffect(() => {
    const currentAudioStatusFilter = getAudioStatusParam();

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

    if (!hasInitialized.current) {
      initialFilterRef.current = currentAudioStatusFilter;
      hasInitialized.current = true;
      return;
    }

    if (currentAudioStatusFilter === initialFilterRef.current) return;

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

  useEffect(() => {
    setData(initialData);
  }, [initialData]);

  return { data, isLoading };
};

export const useClientSideAudioFilter = (data, filterFunction) => {
  const { hideMissingAudio } = useAudioFilter();

  return hideMissingAudio ? data.filter(filterFunction) : data;
};
