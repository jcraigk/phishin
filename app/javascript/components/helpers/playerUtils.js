export const formatTime = (timeInSeconds) => {
  const minutes = Math.floor(timeInSeconds / 60);
  const seconds = Math.floor(timeInSeconds % 60).toString().padStart(2, "0");
  return `${minutes}:${seconds}`;
};

export const updateProgressBar = (progressBarRef, current, duration) => {
  if (duration > 0 && progressBarRef.current) {
    const progress = (current / duration) * 100;
    progressBarRef.current.style.background = `linear-gradient(to right, #03bbf2 ${progress}%, rgba(255,255,255,0) ${progress}%)`;
  }
};

export const getPlayerPosition = (gaplessPlayerRef) => {
  if (!gaplessPlayerRef.current) return 0;
  const position = gaplessPlayerRef.current.getPosition();
  return position >= 0 ? position / 1000 : 0;
};

export const resetLoadingState = (setIsPlaying, setIsLoading) => {
  setIsPlaying(false);
  setIsLoading(false);
};
