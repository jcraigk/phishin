import { gainAt } from "./stagingMath";

// Plays the staged show from one continuous preview of the whole timeline, so
// a track that spans two source files still plays without a gap where they meet.
export class StagingPlayer {
  constructor({ getPreviewUrl, getTrack, getTrackAt, getFollowing, onTime, onStop, onTrackChange, onError, onLoading }) {
    this.getPreviewUrl = getPreviewUrl;
    this.getTrack = getTrack || (() => null);
    this.getTrackAt = getTrackAt || (() => null);
    this.getFollowing = getFollowing || (() => null);
    this.onTime = onTime || (() => {});
    this.onStop = onStop || (() => {});
    this.onLoading = onLoading || (() => {});
    this.onTrackChange = onTrackChange || (() => {});
    this.onError = onError || (() => {});
    this.ctx = null;
    this.audio = null;
    this.gain = null;
    this.ready = null;
    this.chain = false;
    this.track = null;
    this.toS = null;
    this.frame = null;
    this.token = 0;
  }

  context() {
    if (!this.ctx) {
      const Ctx = window.AudioContext || window.webkitAudioContext;
      this.ctx = new Ctx();
    }
    return this.ctx;
  }

  element() {
    if (this.ready) return this.ready;
    const url = this.getPreviewUrl();
    if (!url) return Promise.reject(new Error("This show has no preview audio yet"));
    // Build the element, MediaElementSource and GainNode synchronously:
    // Safari only allows creating audio graph nodes within the call stack of
    // a user gesture.
    const audio = new Audio();
    audio.preload = "auto";
    const ctx = this.context();
    const gain = ctx.createGain();
    ctx.createMediaElementSource(audio).connect(gain);
    gain.connect(ctx.destination);
    audio.addEventListener("ended", () => this.stop());
    audio.src = url;
    this.audio = audio;
    this.gain = gain;
    // A currentTime set before the metadata arrives is discarded and the
    // element plays from zero, so wait for it once here.
    this.ready = new Promise((resolve, reject) => {
      if (audio.readyState >= 1) return resolve(audio);
      audio.addEventListener("loadedmetadata", () => resolve(audio), { once: true });
      audio.addEventListener("error", () => reject(new Error("audio failed to load")), { once: true });
    });
    this.ready.catch(() => {
      this.ready = null;
    });
    return this.ready;
  }

  // The editor's copy of the track, so edges moved mid-play take effect
  // without restarting playback.
  current() {
    if (!this.track) return null;
    return (this.track.id != null && this.getTrack(this.track.id)) || this.track;
  }

  stopAt() {
    return this.toS ?? Number(this.current().end_s);
  }

  async play(track, fromS, toS) {
    this.stop();
    const token = ++this.token;
    this.track = track;
    this.toS = toS ?? null;
    this.chain = toS == null;
    const from = fromS ?? Number(track.start_s);
    // Resume synchronously, before any await, so Safari still counts this as
    // within the user gesture that triggered play().
    this.context().resume();
    await this.startAt(from, token);
  }

  async startAt(t, token) {
    this.onLoading(true);
    let audio;
    try {
      audio = await this.element();
    } catch (e) {
      if (token === this.token) {
        this.onLoading(false);
        this.onError(e);
      }
      return;
    }
    if (token !== this.token) return;
    audio.currentTime = t;
    this.applyGain(t);
    try {
      await audio.play();
    } catch (e) {
      if (token === this.token) {
        this.onLoading(false);
        this.onError(e);
      }
      return;
    }
    if (token !== this.token) return;
    this.onLoading(false);
    this.tick(token);
  }

  reachEnd() {
    if (!this.chain) return false;
    const follow = this.getFollowing(this.current());
    if (!follow) return false;
    this.track = follow.track;
    this.onTrackChange(follow.track);
    if (follow.jumpTo != null) this.audio.currentTime = follow.jumpTo;
    return true;
  }

  tick(token) {
    const step = () => {
      if (token !== this.token || !this.track) return;
      let t = this.audio.currentTime;
      this.rewindTrack(t);
      if (t >= this.stopAt()) {
        if (!this.reachEnd()) {
          this.stop();
          return;
        }
        t = this.audio.currentTime;
      }
      this.applyGain(t);
      this.onTime(t);
      this.frame = requestAnimationFrame(step);
    };
    if (this.frame) cancelAnimationFrame(this.frame);
    this.frame = requestAnimationFrame(step);
  }

  // A seam moved later than the playhead hands the audio back to the
  // earlier track instead of muting it until the new seam.
  rewindTrack(t) {
    if (!this.chain || t >= Number(this.current().start_s)) return;
    const back = this.getTrackAt(t);
    if (!back) return;
    this.track = back;
    this.onTrackChange(back);
  }

  applyGain(t) {
    if (!this.gain || !this.track) return;
    this.gain.gain.setValueAtTime(gainAt(this.current(), t), this.context().currentTime);
  }

  seek(t) {
    if (!this.track) return;
    this.startAt(t, ++this.token);
  }

  stop() {
    const wasPlaying = Boolean(this.track);
    this.token += 1;
    if (this.frame) cancelAnimationFrame(this.frame);
    this.frame = null;
    this.audio?.pause();
    this.track = null;
    this.toS = null;
    this.onLoading(false);
    if (wasPlaying) this.onStop();
  }

  dispose() {
    this.stop();
    if (this.audio) this.audio.removeAttribute("src");
    this.audio = null;
    this.gain = null;
    this.ready = null;
    if (this.ctx && this.ctx.state !== "closed") this.ctx.close();
    this.ctx = null;
  }
}
