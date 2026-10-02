// The lock screen otherwise shows the SessionKeeper's one-second silent loop
// as the playing media, so the real track timeline is published explicitly.
// Returns null when there is no duration, since setPositionState rejects it.
export const mediaPositionState = ({ durationMs, currentTime }) => {
  const duration = durationMs / 1000;
  if (!(duration > 0) || !Number.isFinite(duration)) return null;
  const position = Math.min(Math.max(currentTime || 0, 0), duration);
  return { duration, position, playbackRate: 1 };
};
