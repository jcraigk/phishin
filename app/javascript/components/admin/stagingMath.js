const clamp = (value, low, high) => Math.min(Math.max(value, low), high);

export const round1 = (value) => Math.round(value * 10) / 10;

export const locate = (sources, t) => {
  if (!sources || sources.length === 0) return null;
  const source =
    sources.find((s) => t >= s.offset_s && t < s.offset_s + s.duration_s) ||
    (t >= sources[sources.length - 1].offset_s ? sources[sources.length - 1] : null);
  if (!source) return null;
  return { source, localS: clamp(t - source.offset_s, 0, source.duration_s) };
};

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
  if (track.seam) {
    const { at, out, in: fadeIn2 } = track.seam;
    if (out > 0 && t <= at && t > at - out) gain = Math.min(gain, (at - t) / out);
    if (fadeIn2 > 0 && t >= at && t < at + fadeIn2) gain = Math.min(gain, (t - at) / fadeIn2);
  }
  return Math.max(0, Math.min(1, gain));
};
