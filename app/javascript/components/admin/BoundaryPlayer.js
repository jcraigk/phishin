const TICK_MS = 100;
const START_DELAY_S = 0.02;

// Plays two tracks back to back from fully decoded buffers on the AudioContext
// clock. An audio element seeks a VBR MP3 that has no seek table by estimate
// and can land seconds from the requested time while still reporting it, which
// would put a boundary somewhere other than where it was heard.
export class BoundaryPlayer {
  constructor({ urls, onTime, onPlayChange, onLoading, onError }) {
    this.urls = urls;
    this.onTime = onTime || (() => {});
    this.onPlayChange = onPlayChange || (() => {});
    this.onLoading = onLoading || (() => {});
    this.onError = onError || (() => {});
    this.ctx = null;
    this.buffers = null;
    this.loading = null;
    this.segments = [];
    this.paused = { index: 0, offset: 0 };
    this.token = 0;
    this.ticker = null;
  }

  context() {
    if (!this.ctx) {
      const Ctx = window.AudioContext || window.webkitAudioContext;
      this.ctx = new Ctx();
    }
    return this.ctx;
  }

  load() {
    if (!this.loading) {
      const ctx = this.context();
      this.onLoading(true);
      this.loading = Promise.all(
        this.urls.map((url) =>
          fetch(url)
            .then((response) => {
              if (!response.ok) throw new Error(`Failed to load ${url} (${response.status})`);
              return response.arrayBuffer();
            })
            .then((data) => ctx.decodeAudioData(data))
        )
      ).then(
        (buffers) => {
          this.buffers = buffers;
          this.onLoading(false);
          return buffers;
        },
        (error) => {
          this.loading = null;
          this.onLoading(false);
          this.onError(error);
          throw error;
        }
      );
    }
    return this.loading;
  }

  duration(index) {
    return this.buffers ? this.buffers[index].duration : null;
  }

  isPlaying() {
    return this.segments.length > 0;
  }

  play(index, offset) {
    // Resume inside the click so browsers that require a gesture allow sound.
    const ctx = this.context();
    if (ctx.state !== "running") ctx.resume();
    const token = ++this.token;
    this.stopSources();
    this.paused = { index, offset };
    this.load()
      .then(() => {
        if (token !== this.token) return;
        this.start(index, offset);
      })
      .catch(() => {});
  }

  pause() {
    this.token++;
    if (!this.isPlaying()) return;
    this.paused = this.position();
    this.stopSources();
    this.onTime(this.paused);
    this.onPlayChange(false);
  }

  start(index, offset) {
    const ctx = this.context();
    let when = ctx.currentTime + START_DELAY_S;
    for (let i = index; i < this.buffers.length; i += 1) {
      const buffer = this.buffers[i];
      const from = i === index ? Math.min(Math.max(offset, 0), buffer.duration) : 0;
      const length = buffer.duration - from;
      if (length <= 0) continue;
      const source = ctx.createBufferSource();
      source.buffer = buffer;
      source.connect(ctx.destination);
      source.start(when, from, length);
      this.segments.push({ index: i, source, startedAt: when, offset: from, length });
      when += length;
    }
    if (this.segments.length === 0) return;
    const last = this.segments[this.segments.length - 1];
    const token = this.token;
    last.source.onended = () => {
      if (token !== this.token) return;
      this.paused = { index: last.index, offset: last.offset + last.length };
      this.stopSources();
      this.onTime(this.paused);
      this.onPlayChange(false);
    };
    this.ticker = setInterval(() => this.onTime(this.position()), TICK_MS);
    this.onPlayChange(true);
    this.onTime(this.position());
  }

  position() {
    if (!this.isPlaying()) return this.paused;
    const now = this.ctx.currentTime;
    const current =
      this.segments.find((s) => now < s.startedAt + s.length) || this.segments[this.segments.length - 1];
    const elapsed = Math.min(Math.max(now - current.startedAt, 0), current.length);
    return { index: current.index, offset: current.offset + elapsed };
  }

  stopSources() {
    if (this.ticker) clearInterval(this.ticker);
    this.ticker = null;
    this.segments.forEach(({ source }) => {
      source.onended = null;
      try {
        source.stop();
      } catch (error) {
        // A source scheduled in the future can still be stopped; one that
        // already ended throws, and there is nothing left to clean up.
      }
      source.disconnect();
    });
    this.segments = [];
  }

  destroy() {
    this.token++;
    this.stopSources();
    if (this.ctx) this.ctx.close();
    this.ctx = null;
  }
}
