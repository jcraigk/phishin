import { useState, useEffect, useRef } from 'react';
import { useAudioFilter } from '../contexts/AudioFilterContext';

export const useServerFilteredData = (loaderData, refetchFunction, dependencies = []) => {
  const [data, setData] = useState(loaderData);
  const { getAudioStatusParam } = useAudioFilter();
  const [isRefetching, setIsRefetching] = useState(false);
  const hasInitialized = useRef(false);

  useEffect(() => {
    const currentAudioStatusFilter = getAudioStatusParam();

    if (!hasInitialized.current) {
      hasInitialized.current = true;
      return;
    }

    const handleFilterChange = async () => {
      setIsRefetching(true);
      try {
        const newData = await refetchFunction(currentAudioStatusFilter);
        setData(newData);
      } catch (error) {
        console.error('Error refetching data:', error);
      } finally {
        setIsRefetching(false);
      }
    };

    handleFilterChange();
  }, [getAudioStatusParam(), refetchFunction, ...dependencies]);

  return { data, isRefetching };
};
