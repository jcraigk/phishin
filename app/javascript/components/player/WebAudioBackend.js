import { SessionKeeper } from "./SessionKeeper";
import { ElementStream } from "./ElementStream";
import { handoffPlan } from "./handoffPlan";

// Plays decoded buffers on the AudioContext clock and starts the next track's
// AudioBufferSourceNode at the exact moment the current one ends, so joints are
// sample-accurate and unaffected by timer throttling in background tabs. A
// track that has not been decoded yet streams through an audio element first
// so playback starts before the whole file arrives; the decoded buffer takes
// over with a short crossfade once it lands.
export class WebAudioBackend {
  constructor() {
    this.ctx = null;
    this.keeper = new SessionKeeper();
    this.stream = null;
    this.tracks = [];
    this.buffers = new Map();
    this.decoded = new Map();
    this.current = null;
    this.scheduled = null;
    this.playToken = 0;
    this.streamStarted = null;
    this.onAdvance = () => {};
    this.onEnd = () => {};
    this.onLoading = () => {};
    this.onError = () => {};
  }

  load(tracks) {
    this.stopSources();
    this.tracks = tracks;
    this.buffers.clear();
    this.decoded.clear();
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

  streamer() {
    if (!this.stream) {
      const stream = new ElementStream(this.context());
      stream.onPlaying = () => {
        if (this.current?.streaming) this.onLoading(false);
        this.releaseStreamStarted();
      };
      stream.onWaiting = () => {
        if (this.current?.streaming) this.onLoading(true);
      };
      stream.onTimeUpdate = (seconds) => {
        const playing = this.current;
        if (!playing?.streaming) return;
        const { end } = this.tracks[playing.index];
        if (end && seconds >= end) this.handleEnded(playing);
      };
      stream.onEnded = () => {
        if (this.current?.streaming) this.handleEnded(this.current);
      };
      stream.onError = (error) => {
        if (!this.current?.streaming) return;
        this.playToken++;
        this.stopSources();
        this.onLoading(false);
        this.onError(error);
      };
      this.stream = stream;
    }
    return this.stream;
  }

  buffer(index) {
    if (!this.buffers.has(index)) {
      const { url } = this.tracks[index];
      const promise = fetch(url)
        .then((response) => {
          if (!response.ok) throw new Error(`Failed to load ${url} (${response.status})`);
          return response.arrayBuffer();
        })
        .then((data) => {
          if (!this.ctx) throw new Error("Player destroyed");
          return this.ctx.decodeAudioData(data);
        })
        .then((buffer) => {
          if (this.buffers.get(index) === promise) this.decoded.set(index, buffer);
          return buffer;
        });
      promise.catch(() => {
        if (this.buffers.get(index) === promise) this.buffers.delete(index);
      });
      this.buffers.set(index, promise);
    }
    return this.buffers.get(index);
  }

  releaseStreamStarted() {
    if (!this.streamStarted) return;
    this.streamStarted();
    this.streamStarted = null;
  }

  prune(keep) {
    for (const index of Array.from(this.buffers.keys())) {
      if (keep.includes(index)) continue;
      this.buffers.delete(index);
      this.decoded.delete(index);
    }
  }

  async play(index, position) {
    // The keeper, the context and the element's play() must all be called
    // synchronously inside the user gesture.
    this.keeper.start();
    const ctx = this.context();
    const token = ++this.playToken;
    this.stopSources();
    this.prune([index, index + 1]);

    const decoded = this.decoded.get(index);
    if (decoded) {
      if (ctx.state !== "running") await ctx.resume();
      if (token !== this.playToken) return;
      this.onLoading(false);
      this.startSource(index, decoded, position, ctx.currentTime);
      this.scheduleNext();
      return;
    }

    this.onLoading(true);
    this.current = { index, streaming: true };
    // Wait for the element to actually start playing before also fetching the
    // whole file for decode, so the two requests don't split the connection's
    // bandwidth and delay first audio.
    const started = new Promise((resolve) => { this.streamStarted = resolve; });
    this.streamer().start(this.tracks[index].url, position);
    if (ctx.state !== "running") ctx.resume();
    await started;
    if (token !== this.playToken || !this.current?.streaming) return;

    let buffer;
    try {
      buffer = await this.buffer(index);
    } catch (error) {
      if (token === this.playToken) console.warn("Decode failed; the joint into the next track will not be gapless", error);
      return;
    }
    if (token !== this.playToken || !this.current?.streaming) return;
    this.handoff(index, buffer);
  }

  handoff(index, buffer) {
    const ctx = this.context();
    const stream = this.streamer();
    const plan = handoffPlan({
      now: ctx.currentTime,
      position: stream.position(),
      end: this.tracks[index].end,
      duration: buffer.duration,
    });
    if (plan.length <= 0) return;

    const { source, gain } = this.makeSource(buffer);
    gain.gain.setValueAtTime(0, plan.at);
    gain.gain.linearRampToValueAtTime(1, plan.at + plan.fade);
    source.start(plan.at, plan.offset, plan.length);
    stream.fadeOut(plan.at, plan.fade);

    const playing = { index, source, gain, startedAt: plan.at, offset: plan.offset, length: plan.length };
    source.onended = () => this.handleEnded(playing);
    this.current = playing;
    this.onLoading(false);
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
    this.decoded.clear();
    if (this.stream) this.stream.destroy();
    this.stream = null;
    if (this.ctx) {
      this.ctx.close();
      this.ctx = null;
    }
  }

  position() {
    const playing = this.current;
    if (!playing) return null;
    if (playing.streaming) return this.stream.position();
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
    const { source, gain } = this.makeSource(buffer);
    const length = Math.max(0, this.trackEnd(index, buffer) - position);
    source.start(when, position, length);
    const playing = { index, source, gain, startedAt: when, offset: position, length };
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
    const { source, gain } = this.makeSource(buffer);
    const length = Math.max(0, this.trackEnd(nextIndex, buffer) - offset);
    source.start(when, offset, length);
    const scheduled = { index: nextIndex, source, gain, startedAt: when, offset, length };
    source.onended = () => this.handleEnded(scheduled);
    this.scheduled = scheduled;
  }

  handleEnded(ended) {
    if (this.current !== ended) return;
    if (ended.streaming) this.stream.pause();

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
    this.releaseStreamStarted();
    for (const playing of [this.current, this.scheduled]) {
      if (!playing) continue;
      if (playing.streaming) {
        this.stream.pause();
        continue;
      }
      playing.source.onended = null;
      try {
        playing.source.stop();
      } catch (error) {
        // Stopping a source that never started throws; nothing to clean up.
      }
      playing.source.disconnect();
      playing.gain.disconnect();
    }
    this.current = null;
    this.scheduled = null;
  }

  makeSource(buffer) {
    const ctx = this.context();
    const source = ctx.createBufferSource();
    const gain = ctx.createGain();
    source.buffer = buffer;
    source.connect(gain);
    gain.connect(ctx.destination);
    return { source, gain };
  }

  trackEnd(index, buffer) {
    const { end } = this.tracks[index];
    return end ? Math.min(end, buffer.duration) : buffer.duration;
  }
}
