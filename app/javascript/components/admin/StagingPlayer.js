import { fetchAdminAudio } from "./adminApi";
import { locate, gainAt } from "./stagingMath";

export class StagingPlayer {
  constructor({ getSources, getFollowing, onTime, onStop, onTrackChange, onError, onLoading }) {
    this.getSources = getSources;
    this.getFollowing = getFollowing || (() => null);
    this.onTime = onTime || (() => {});
    this.onStop = onStop || (() => {});
    this.onLoading = onLoading || (() => {});
    this.onTrackChange = onTrackChange || (() => {});
    this.onError = onError || (() => {});
    this.chain = false;
    this.ctx = null;
    this.elements = new Map();
    this.loaded = new Map();
    this.gains = new Map();
    this.urls = new Map();
    this.track = null;
    this.stopAt = null;
    this.active = null;
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

  async element(source) {
    if (this.elements.has(source.id)) return this.elements.get(source.id);
    const promise = (async () => {
      // Build the element, MediaElementSource and GainNode synchronously,
      // before the fetch resolves: Safari only allows creating audio graph
      // nodes within the call stack of a user gesture, and the fetch below
      // yields well past that window.
      const audio = new Audio();
      audio.preload = "auto";
      const ctx = this.context();
      const gain = ctx.createGain();
      ctx.createMediaElementSource(audio).connect(gain);
      gain.connect(ctx.destination);
      this.loaded.set(source.id, audio);
      this.gains.set(source.id, gain);
      audio.addEventListener("ended", () => this.advance(source));
      const url = await fetchAdminAudio(source.audio_url);
      this.urls.set(source.id, url);
      audio.src = url;
      // A currentTime set before the metadata arrives is discarded and the
      // element plays from zero, so wait for it once here.
      await new Promise((resolve, reject) => {
        if (audio.readyState >= 1) return resolve();
        audio.addEventListener("loadedmetadata", resolve, { once: true });
        audio.addEventListener("error", () => reject(new Error("audio failed to load")), { once: true });
      });
      return audio;
    })();
    this.elements.set(source.id, promise);
    promise.catch(() => this.elements.delete(source.id));
    return promise;
  }

  async play(track, fromS, toS) {
    this.stop();
    const token = ++this.token;
    this.track = track;
    this.chain = toS == null;
    const from = fromS ?? Number(track.start_s);
    this.stopAt = toS ?? Number(track.end_s);
    // Resume synchronously, before any await, so Safari still counts this as
    // within the user gesture that triggered play().
    const ctx = this.context();
    ctx.resume();
    await this.startAt(from, token);
  }

  async startAt(t, token) {
    const hit = locate(this.getSources(), t);
    if (!hit) return;
    this.onLoading(true);
    let audio;
    try {
      audio = await this.element(hit.source);
    } catch (e) {
      if (token === this.token) {
        this.onLoading(false);
        this.onError(e);
      }
      return;
    }
    if (token !== this.token) return;
    this.active = hit.source;
    audio.currentTime = hit.localS;
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

  advance(source) {
    if (this.active?.id !== source.id || !this.track) return;
    const token = this.token;
    const next = this.getSources().find((s) => s.position === source.position + 1);
    const at = source.offset_s + source.duration_s;
    if (at >= this.stopAt && this.reachEnd(token)) return;
    if (!next || at >= this.stopAt) {
      this.stop();
      return;
    }
    this.startAt(at, token);
  }

  reachEnd(token) {
    if (!this.chain) return false;
    const follow = this.getFollowing(this.track);
    if (!follow) return false;
    this.track = follow.track;
    this.stopAt = Number(follow.track.end_s);
    this.onTrackChange(follow.track);
    if (follow.jumpTo != null) {
      this.pauseActive();
      this.startAt(follow.jumpTo, token);
    }
    return true;
  }

  tick(token) {
    const step = () => {
      if (token !== this.token || !this.active) return;
      const audio = this.loaded.get(this.active.id);
      const t = this.active.offset_s + audio.currentTime;
      if (t >= this.stopAt) {
        if (!this.reachEnd(token)) {
          this.stop();
          return;
        }
        if (!this.active) return;
      }
      this.applyGain(t);
      this.onTime(t);
      this.frame = requestAnimationFrame(step);
    };
    this.frame = requestAnimationFrame(step);
  }

  applyGain(t) {
    if (!this.active || !this.track) return;
    const gain = this.gains.get(this.active.id);
    gain.gain.setValueAtTime(gainAt(this.track, t), this.context().currentTime);
  }

  seek(t) {
    if (!this.track) return;
    const token = ++this.token;
    this.pauseActive();
    this.startAt(t, token);
  }

  pauseActive() {
    if (this.frame) cancelAnimationFrame(this.frame);
    this.frame = null;
    if (this.active) this.loaded.get(this.active.id)?.pause();
    this.active = null;
  }

  stop() {
    const wasPlaying = Boolean(this.track);
    const element = this.active ? this.loaded.get(this.active.id) : null;
    // Clear active before bumping the token, so an "ended" listener racing
    // this stop sees no active source once it checks the bumped token.
    this.active = null;
    this.token += 1;
    if (this.frame) cancelAnimationFrame(this.frame);
    this.frame = null;
    element?.pause();
    this.track = null;
    this.stopAt = null;
    this.onLoading(false);
    if (wasPlaying) this.onStop();
  }

  dispose() {
    this.stop();
    this.urls.forEach((url) => URL.revokeObjectURL(url));
    this.urls.clear();
    this.elements.clear();
    this.loaded.clear();
    this.gains.clear();
    if (this.ctx && this.ctx.state !== "closed") this.ctx.close();
    this.ctx = null;
  }
}
