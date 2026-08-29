import { fetchAdminAudio } from "./adminApi";
import { locate, gainAt } from "./stagingMath";

// One player for the whole staged show. Each source proxy is an <audio>
// element created on first use and routed through its own GainNode, so a fade
// is heard without re-rendering anything: every animation frame the gain is set
// from gainAt for the track being auditioned. Elements are never decoded into
// buffers; a twenty minute proxy would be hundreds of megabytes as float PCM.
//
// A track that spans two sources (a boundary moved into the next file) is
// followed across the seam by switching elements when the first one ends.
// There is a few milliseconds of silence at that switch in the preview only;
// the commit renders from the continuous timeline and has no seam.
export class StagingPlayer {
  constructor({ sources, onTime, onStop }) {
    this.sources = sources;
    this.onTime = onTime || (() => {});
    this.onStop = onStop || (() => {});
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
    // Cache in-flight promises by source ID so concurrent plays await the
    // same fetch and element construction instead of racing.
    if (this.elements.has(source.id)) return this.elements.get(source.id);
    const promise = (async () => {
      const url = await fetchAdminAudio(source.audio_url);
      this.urls.set(source.id, url);
      const audio = new Audio(url);
      audio.preload = "auto";
      const ctx = this.context();
      const gain = ctx.createGain();
      ctx.createMediaElementSource(audio).connect(gain);
      gain.connect(ctx.destination);
      this.loaded.set(source.id, audio);
      this.gains.set(source.id, gain);
      audio.addEventListener("ended", () => this.advance(source));
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
    const from = fromS ?? Number(track.start_s);
    this.stopAt = toS ?? Number(track.end_s);
    await this.context().resume();
    if (token !== this.token) return;
    await this.startAt(from, token);
  }

  async startAt(t, token) {
    const hit = locate(this.sources, t);
    if (!hit) return;
    const audio = await this.element(hit.source);
    if (token !== this.token) return;
    this.active = hit.source;
    audio.currentTime = hit.localS;
    this.applyGain(t);
    await audio.play();
    this.tick(token);
  }

  // Called when a source element runs out while a track still has time left.
  advance(source) {
    if (this.active?.id !== source.id || !this.track) return;
    const next = this.sources.find((s) => s.position === source.position + 1);
    const at = source.offset_s + source.duration_s;
    if (!next || at >= this.stopAt) {
      this.stop();
      return;
    }
    this.startAt(at, this.token);
  }

  tick(token) {
    const step = () => {
      if (token !== this.token || !this.active) return;
      const audio = this.loaded.get(this.active.id);
      const t = this.active.offset_s + audio.currentTime;
      if (t >= this.stopAt) {
        this.stop();
        return;
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
    this.token += 1;
    this.pauseActive();
    this.track = null;
    this.stopAt = null;
    if (wasPlaying) this.onStop();
  }

  dispose() {
    this.stop();
    this.urls.forEach((url) => URL.revokeObjectURL(url));
    this.urls.clear();
    this.elements.clear();
    this.loaded.clear();
    this.gains.clear();
    if (this.ctx) this.ctx.close();
    this.ctx = null;
  }
}
