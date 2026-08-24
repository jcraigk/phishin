// Playlist engine with no React or browser-audio dependency of its own. Owns
// the track list, the current index, and the paused position; a backend does
// the audio. Track shape: { url, offset, end } in seconds, end null for the
// natural end of the file.
const TICK_MS = 200;

export class GaplessEngine {
  constructor(backend) {
    this.backend = backend;
    this.tracks = [];
    this.index = 0;
    this.pausedPosition = 0;
    this.playing = false;
    this.ticker = null;
    this.onTrackChange = () => {};
    this.onPlayChange = () => {};
    this.onTime = () => {};
    this.onLoading = () => {};
    this.onError = () => {};

    backend.onAdvance = (index) => {
      this.index = index;
      this.onTrackChange(index);
    };
    backend.onEnd = () => {
      this.pausedPosition = this.track().offset;
      this.setPlaying(false);
    };
    backend.onLoading = (loading) => this.onLoading(loading);
    backend.onError = (error) => {
      this.setPlaying(false);
      this.onError(error);
    };
  }

  load(tracks, index = 0) {
    this.setPlaying(false);
    this.tracks = tracks;
    this.backend.load(tracks);
    this.index = tracks.length ? Math.min(Math.max(index, 0), tracks.length - 1) : 0;
    this.pausedPosition = tracks.length ? this.track().offset : 0;
    this.onTime(this.pausedPosition, this.index);
  }

  track() {
    return this.tracks[this.index];
  }

  position() {
    const live = this.backend.position();
    return live === null ? this.pausedPosition : live;
  }

  trackEnd() {
    return this.track()?.end || null;
  }

  play() {
    if (!this.tracks.length) return;
    this.setPlaying(true);
    this.backend.play(this.index, this.pausedPosition);
  }

  pause() {
    this.pausedPosition = this.position();
    this.backend.pause();
    this.setPlaying(false);
  }

  toggle() {
    if (this.playing) {
      this.pause();
    } else {
      this.play();
    }
  }

  seek(seconds) {
    const track = this.track();
    if (!track) return;
    const max = track.end || Infinity;
    const clamped = Math.max(track.offset, Math.min(seconds, max));
    if (this.playing) {
      this.backend.play(this.index, clamped);
    } else {
      this.pausedPosition = clamped;
    }
    this.onTime(clamped, this.index);
  }

  goto(index, { play = this.playing } = {}) {
    if (index < 0 || index >= this.tracks.length) return;
    this.index = index;
    this.pausedPosition = this.track().offset;
    this.onTrackChange(index);
    if (play) {
      this.play();
    } else {
      this.backend.pause();
      this.setPlaying(false);
      this.onTime(this.pausedPosition, this.index);
    }
  }

  next() {
    this.goto(this.index + 1);
  }

  previous() {
    this.goto(this.index - 1);
  }

  hasNext() {
    return this.index < this.tracks.length - 1;
  }

  hasPrevious() {
    return this.index > 0;
  }

  destroy() {
    this.stopTicker();
    this.backend.destroy();
  }

  setPlaying(playing) {
    if (playing === this.playing) return;
    this.playing = playing;
    if (playing) {
      this.startTicker();
    } else {
      this.stopTicker();
    }
    this.onPlayChange(playing);
  }

  startTicker() {
    this.stopTicker();
    this.ticker = setInterval(() => this.onTime(this.position(), this.index), TICK_MS);
  }

  stopTicker() {
    if (this.ticker) clearInterval(this.ticker);
    this.ticker = null;
  }
}
