import { SessionKeeper } from "./SessionKeeper";

// Decodes the current and next track only and starts the next
// AudioBufferSourceNode on the AudioContext clock at the exact moment the
// current one ends, so joints are sample-accurate and unaffected by timer
// throttling in background tabs.
export class WebAudioBackend {
  constructor() {
    this.ctx = null;
    this.keeper = new SessionKeeper();
    this.tracks = [];
    this.buffers = new Map();
    this.current = null;
    this.scheduled = null;
    this.playToken = 0;
    this.onAdvance = () => {};
    this.onEnd = () => {};
    this.onLoading = () => {};
    this.onError = () => {};
  }

  load(tracks) {
    this.stopSources();
    this.tracks = tracks;
    this.buffers.clear();
  }

  context() {
    if (!this.ctx) {
      const Ctx = window.AudioContext || window.webkitAudioContext;
      this.ctx = new Ctx();
      // iOS moves the context to "interrupted" after a call or Siri; pick
      // playback back up when the interruption ends.
      this.ctx.addEventListener("statechange", () => {
        if (this.current && this.ctx && this.ctx.state !== "running") this.ctx.resume();
      });
    }
    return this.ctx;
  }

  buffer(index) {
    if (!this.buffers.has(index)) {
      const { url } = this.tracks[index];
      const promise = fetch(url)
        .then((response) => {
          if (!response.ok) throw new Error(`Failed to load ${url} (${response.status})`);
          return response.arrayBuffer();
        })
        .then((data) => this.context().decodeAudioData(data));
      promise.catch(() => this.buffers.delete(index));
      this.buffers.set(index, promise);
    }
    return this.buffers.get(index);
  }

  prune(keep) {
    for (const index of Array.from(this.buffers.keys())) {
      if (!keep.includes(index)) this.buffers.delete(index);
    }
  }

  async play(index, position) {
    // Both of these must happen synchronously inside the user gesture.
    this.keeper.start();
    const ctx = this.context();
    if (ctx.state !== "running") await ctx.resume();

    const token = ++this.playToken;
    this.stopSources();
    this.onLoading(true);

    let buffer;
    try {
      buffer = await this.buffer(index);
    } catch (error) {
      if (token === this.playToken) {
        this.onLoading(false);
        this.onError(error);
      }
      return;
    }
    if (token !== this.playToken) return;

    this.onLoading(false);
    this.prune([index, index + 1]);
    this.startSource(index, buffer, position, ctx.currentTime);
    this.scheduleNext();
  }

  pause() {
    this.playToken++;
    this.stopSources();
    this.keeper.stop();
    this.onLoading(false);
  }

  destroy() {
    this.pause();
    this.keeper.destroy();
    this.buffers.clear();
    if (this.ctx) {
      this.ctx.close();
      this.ctx = null;
    }
  }

  position() {
    const playing = this.current;
    if (!playing) return null;
    const elapsed = this.context().currentTime - playing.startedAt;
    return playing.offset + Math.min(Math.max(elapsed, 0), playing.length);
  }

  index() {
    return this.current ? this.current.index : null;
  }

  isPlaying() {
    return this.current !== null;
  }

  startSource(index, buffer, position, when) {
    const source = this.makeSource(buffer);
    const length = Math.max(0, this.trackEnd(index, buffer) - position);
    source.start(when, position, length);
    const playing = { index, source, startedAt: when, offset: position, length };
    source.onended = () => this.handleEnded(playing);
    this.current = playing;
    return playing;
  }

  async scheduleNext() {
    const current = this.current;
    if (!current) return;
    const nextIndex = current.index + 1;
    if (nextIndex >= this.tracks.length) return;

    let buffer;
    try {
      buffer = await this.buffer(nextIndex);
    } catch (error) {
      return;
    }
    if (this.current !== current || this.scheduled) return;

    const when = current.startedAt + current.length;
    const offset = this.tracks[nextIndex].offset;
    const source = this.makeSource(buffer);
    const length = Math.max(0, this.trackEnd(nextIndex, buffer) - offset);
    source.start(when, offset, length);
    const scheduled = { index: nextIndex, source, startedAt: when, offset, length };
    source.onended = () => this.handleEnded(scheduled);
    this.scheduled = scheduled;
  }

  handleEnded(ended) {
    if (this.current !== ended) return;

    if (this.scheduled) {
      this.current = this.scheduled;
      this.scheduled = null;
      this.prune([this.current.index, this.current.index + 1]);
      this.onAdvance(this.current.index);
      this.scheduleNext();
      return;
    }

    this.current = null;
    const nextIndex = ended.index + 1;
    if (nextIndex < this.tracks.length) {
      this.onAdvance(nextIndex);
      this.play(nextIndex, this.tracks[nextIndex].offset);
    } else {
      this.keeper.stop();
      this.onEnd();
    }
  }

  stopSources() {
    for (const playing of [this.current, this.scheduled]) {
      if (!playing) continue;
      playing.source.onended = null;
      try {
        playing.source.stop();
      } catch (error) {
        // Stopping a source that never started throws; nothing to clean up.
      }
      playing.source.disconnect();
    }
    this.current = null;
    this.scheduled = null;
  }

  makeSource(buffer) {
    const source = this.context().createBufferSource();
    source.buffer = buffer;
    source.connect(this.context().destination);
    return source;
  }

  trackEnd(index, buffer) {
    const { end } = this.tracks[index];
    return end ? Math.min(end, buffer.duration) : buffer.duration;
  }
}
