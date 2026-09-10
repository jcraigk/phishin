// One audio element, reused for the life of the backend, that streams a track
// by range requests through the shared AudioContext so playback starts before
// the whole file has arrived. The element is wrapped in a media element source
// once, because wrapping the same element twice throws. Output goes through a
// gain node that stays at zero until the element is actually playing at the
// requested position, so nothing from before the seek is heard.
const OPEN_SECONDS = 0.02;

export class ElementStream {
  constructor(context) {
    this.ctx = context;
    this.element = new Audio();
    this.element.crossOrigin = "anonymous";
    this.element.preload = "auto";
    this.gain = context.createGain();
    this.gain.gain.value = 0;
    context.createMediaElementSource(this.element).connect(this.gain);
    this.gain.connect(context.destination);
    this.url = null;
    this.pendingSeek = null;
    this.active = false;
    this.opened = false;
    this.onPlaying = () => {};
    this.onWaiting = () => {};
    this.onTimeUpdate = () => {};
    this.onEnded = () => {};
    this.onError = () => {};
    this.listen();
  }

  listen() {
    const el = this.element;
    el.addEventListener("loadedmetadata", () => {
      if (this.pendingSeek === null) return;
      el.currentTime = this.pendingSeek;
      this.pendingSeek = null;
    });
    el.addEventListener("playing", () => this.open());
    el.addEventListener("seeked", () => this.open());
    el.addEventListener("waiting", () => {
      if (this.active) this.onWaiting();
    });
    el.addEventListener("timeupdate", () => {
      if (this.active) this.onTimeUpdate(el.currentTime);
    });
    el.addEventListener("ended", () => {
      if (this.active) this.onEnded();
    });
    el.addEventListener("error", () => {
      if (this.active) this.onError(new Error(`Failed to stream ${this.url}`));
    });
  }

  // Must be called synchronously inside the user gesture that starts playback.
  start(url, position) {
    this.active = true;
    this.opened = false;
    this.mute();
    if (url !== this.url) {
      this.url = url;
      this.element.src = url;
      this.pendingSeek = position;
    } else if (this.element.readyState >= 1) {
      this.pendingSeek = null;
      this.element.currentTime = position;
    } else {
      this.pendingSeek = position;
    }
    this.element.play().catch((error) => {
      if (this.active) this.onError(error);
    });
  }

  open() {
    const el = this.element;
    if (!this.active || this.opened || el.paused || el.seeking || this.pendingSeek !== null) return;
    this.opened = true;
    const now = this.ctx.currentTime;
    this.gain.gain.cancelScheduledValues(now);
    this.gain.gain.setValueAtTime(0, now);
    this.gain.gain.linearRampToValueAtTime(1, now + OPEN_SECONDS);
    this.onPlaying();
  }

  mute() {
    const now = this.ctx.currentTime;
    this.gain.gain.cancelScheduledValues(now);
    this.gain.gain.setValueAtTime(0, now);
  }

  position() {
    return this.element.currentTime;
  }

  pause() {
    this.active = false;
    this.mute();
    this.element.pause();
  }

  // Ramps to silence on the context clock while the decoded buffer ramps in,
  // then pauses the element once the ramp is over unless it was restarted.
  fadeOut(at, duration) {
    this.active = false;
    const gain = this.gain.gain;
    gain.cancelScheduledValues(at);
    gain.setValueAtTime(1, at);
    gain.linearRampToValueAtTime(0, at + duration);
    const wait = Math.max(0, at + duration - this.ctx.currentTime) * 1000 + 20;
    setTimeout(() => {
      if (!this.active) this.element.pause();
    }, wait);
  }

  destroy() {
    this.pause();
    this.element.removeAttribute("src");
    this.element.load();
    this.gain.disconnect();
  }
}
