// A silent, looping <audio> element that plays alongside WebAudio output.
// iOS Safari suspends an AudioContext when the screen locks or the tab goes
// to the background unless a media element is playing, and desktop browsers
// only route hardware media keys to a page with a playing media element.
// Must be started synchronously inside the user gesture that starts playback.
// The loop is an hour long because iOS rereads the lock screen timeline from
// this element each time it wraps, briefly replacing the media session's
// position state with the loop's own duration.
//
// One self-contained 36 byte MPEG-2 Layer III frame (16 kHz mono, 8 kbps, no
// bit reservoir) decodes to 36 ms of silence, so repeating it builds an hour
// of audio in 3.6 MB without encoding anything in the browser.
const SILENT_FRAME = new Uint8Array([0xff, 0xf3, 0x18, 0xc4, 0, 0, 0, 3, 0x48, ...new Array(27).fill(0)]);
const FRAME_SECONDS = 0.036;
const SECONDS = 3600;

const silentMp3Url = () => {
  const frames = Math.round(SECONDS / FRAME_SECONDS);
  return URL.createObjectURL(new Blob(new Array(frames).fill(SILENT_FRAME), { type: "audio/mpeg" }));
};

export class SessionKeeper {
  constructor() {
    this.element = null;
  }

  start() {
    if (!this.element) {
      this.element = new Audio(silentMp3Url());
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
