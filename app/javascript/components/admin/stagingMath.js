// Pure helpers for the staging editor. gainAt is the browser's half of the
// fade contract with Admin::StagingRender; spec/javascript/staging_fade_parity_spec.rb
// reads it off this file.

export const clamp = (value, low, high) => Math.min(Math.max(value, low), high);

export const round1 = (value) => Math.round(value * 10) / 10;

// Which proxy plays a moment on the timeline, and where in that proxy. Sources
// are contiguous, so the one whose span holds t is the answer; the very end of
// the timeline belongs to the last source.
export const locate = (sources, t) => {
  if (!sources || sources.length === 0) return null;
  const source =
    sources.find((s) => t >= s.offset_s && t < s.offset_s + s.duration_s) ||
    (t >= sources[sources.length - 1].offset_s ? sources[sources.length - 1] : null);
  if (!source) return null;
  return { source, localS: clamp(t - source.offset_s, 0, source.duration_s) };
};

// Linear, to match ffmpeg afade's default triangular curve. 0 outside the
// track; a fade-out longer than the track is clipped to the track, as
// Admin::StagingRender does.
export const gainAt = (track, t) => {
  const start = Number(track.start_s);
  const end = Number(track.end_s);
  if (t < start || t > end) return 0;
  let gain = 1;
  const fadeIn = Number(track.fade_in_s) || 0;
  if (fadeIn > 0 && t < start + fadeIn) gain = Math.min(gain, (t - start) / fadeIn);
  const length = end - start;
  const fadeOut = Math.min(Number(track.fade_out_s) || 0, length);
  if (fadeOut > 0 && t > end - fadeOut) gain = Math.min(gain, (end - t) / fadeOut);
  return Math.max(0, Math.min(1, gain));
};
