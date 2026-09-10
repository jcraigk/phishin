// Where and when a decoded buffer takes over from the streaming element. All
// values are seconds: `now` is the AudioContext clock, `position` the
// element's playhead, `end` the excerpt end (null for the natural end of the
// file) and `duration` the decoded buffer's length. The buffer starts a short
// lead ahead so the source can be scheduled before the moment arrives.
export const HANDOFF_LEAD = 0.1;
export const HANDOFF_FADE = 0.05;

export const handoffPlan = ({ now, position, end, duration }) => {
  const at = now + HANDOFF_LEAD;
  const offset = position + HANDOFF_LEAD;
  const stop = end ? Math.min(end, duration) : duration;
  return { at, offset, length: Math.max(0, stop - offset), fade: HANDOFF_FADE };
};
