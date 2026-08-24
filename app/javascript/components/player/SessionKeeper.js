// A silent, looping <audio> element that plays alongside WebAudio output.
// iOS Safari suspends an AudioContext when the screen locks or the tab goes
// to the background unless a media element is playing, and desktop browsers
// only route hardware media keys to a page with a playing media element.
// Must be started synchronously inside the user gesture that starts playback.
const SAMPLE_RATE = 8000;
const SECONDS = 1;

const silentWavUrl = () => {
  const samples = SAMPLE_RATE * SECONDS;
  const buffer = new ArrayBuffer(44 + samples * 2);
  const view = new DataView(buffer);
  const ascii = (offset, text) => {
    for (let i = 0; i < text.length; i++) view.setUint8(offset + i, text.charCodeAt(i));
  };
  ascii(0, "RIFF");
  view.setUint32(4, 36 + samples * 2, true);
  ascii(8, "WAVE");
  ascii(12, "fmt ");
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, 1, true);
  view.setUint32(24, SAMPLE_RATE, true);
  view.setUint32(28, SAMPLE_RATE * 2, true);
  view.setUint16(32, 2, true);
  view.setUint16(34, 16, true);
  ascii(36, "data");
  view.setUint32(40, samples * 2, true);
  return URL.createObjectURL(new Blob([buffer], { type: "audio/wav" }));
};

export class SessionKeeper {
  constructor() {
    this.element = null;
  }

  start() {
    if (!this.element) {
      this.element = new Audio(silentWavUrl());
      this.element.loop = true;
    }
    this.element.play().catch(() => {});
  }

  stop() {
    if (this.element) this.element.pause();
  }

  destroy() {
    this.stop();
    if (this.element) URL.revokeObjectURL(this.element.src);
    this.element = null;
  }
}
