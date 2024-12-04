(function(factory) {
  // Establish the root object, `window` (`self`) in the browser, or `global` on the server.
  // We use `self` instead of `window` for `WebWorker` support.
  var root = (typeof self == 'object' && self.self === self && self) ||
            (typeof global == 'object' && global.global === global && global);

  // Node.js, CommonJS, or ES6
  if (typeof module === "object" && typeof module.exports === "object") {
    module.exports = factory(root, exports);
  // Finally, as a browser global.
  } else {
    root.Gapless = factory(root, {});
  }
})(function(root, Gapless) {
  const PRELOAD_NUM_TRACKS = 2;

  const isBrowser = typeof window !== 'undefined';
  const audioContext = isBrowser ? new (window.AudioContext || window.webkitAudioContext)() : null;

  const GaplessPlaybackType = {
    HTML5: 'HTML5',
    WEBAUDIO: 'WEBAUDIO'
  };

  const GaplessPlaybackLoadingState = {
    NONE: 'NONE',
    LOADING: 'LOADING',
    LOADED: 'LOADED'
  };

  class Queue {
    constructor(props = {}) {
      const {
        tracks = [],
        onProgress,
        onEnded,
        onPlayNextTrack,
        onPlayPreviousTrack,
        onStartNewTrack,
        webAudioIsDisabled = false
      } = props;

      this.props = {
        onProgress,
        onEnded,
        onPlayNextTrack,
        onPlayPreviousTrack,
        onStartNewTrack
      };

      this.state = {
        volume: 1,
        currentTrackIdx: 0,
        webAudioIsDisabled
      };

      this.Track = Track;

      this.tracks = tracks.map((trackUrl, idx) =>
        new Track({
          trackUrl,
          idx,
          queue: this
        })
      );
    }

    addTrack({ trackUrl, metadata = {} }) {
      this.tracks.push(
        new Track({
          trackUrl,
          metadata,
          idx: this.tracks.length,
          queue: this
        })
      );
    }

    removeTrack(track) {
      const index = this.tracks.indexOf(track);
      return this.tracks.splice(index, 1);
    }

    togglePlayPause() {
      if (this.currentTrack) this.currentTrack.togglePlayPause();
    }

    play() {
      if (this.currentTrack) this.currentTrack.play();
    }

    pause() {
      if (this.currentTrack) this.currentTrack.pause();
    }

    playPrevious() {
      this.resetCurrentTrack();

      if (--this.state.currentTrackIdx < 0) this.state.currentTrackIdx = 0;

      this.resetCurrentTrack();

      this.play();

      if (this.props.onStartNewTrack) this.props.onStartNewTrack(this.currentTrack);
      if (this.props.onPlayPreviousTrack) this.props.onPlayPreviousTrack(this.currentTrack);
    }

    playNext() {
      this.resetCurrentTrack();

      this.state.currentTrackIdx++;

      this.resetCurrentTrack();

      this.play();

      if (this.props.onStartNewTrack) this.props.onStartNewTrack(this.currentTrack);
      if (this.props.onPlayNextTrack) this.props.onPlayNextTrack(this.currentTrack);
    }

    resetCurrentTrack() {
      if (this.currentTrack) {
        this.currentTrack.seek(0)
        this.currentTrack.pause();
      }
    }

    pauseAll() {
      Object.values(this.tracks).map(track => {
        track.pause();
      });
    }

    gotoTrack(idx, playImmediately = false) {
      this.pauseAll();
      this.state.currentTrackIdx = idx;

      this.resetCurrentTrack();

      if (playImmediately) {
        this.play();
        if (this.props.onStartNewTrack) this.props.onStartNewTrack(this.currentTrack);
      }
    }

    loadTrack(idx, loadHTML5) {
      // only preload if song is within the next 2
      if (this.state.currentTrackIdx + PRELOAD_NUM_TRACKS <= idx) return;
      const track = this.tracks[idx];

      if (track) track.preload(loadHTML5);
    }

    setProps(obj = {}) {
      this.props = Object.assign(this.props, obj);
    }

    onEnded() {
      if (this.props.onEnded) this.props.onEnded();
    }

    onProgress(track) {
      if (this.props.onProgress) this.props.onProgress(track);
    }

    get currentTrack() {
      return this.tracks[this.state.currentTrackIdx];
    }

    get nextTrack() {
      return this.tracks[this.state.currentTrackIdx + 1];
    }

    disableWebAudio() {
      this.state.webAudioIsDisabled = true;
    }

    setVolume(nextVolume) {
      if (nextVolume < 0) nextVolume = 0;
      else if (nextVolume > 1) nextVolume = 1;

      this.state.volume = nextVolume;

      this.tracks.map(track => track.setVolume(nextVolume));
    }
  }

  class Track {
    constructor({ trackUrl, queue, idx, metadata }) {
      // playback type state
      this.playbackType = GaplessPlaybackType.HTML5;
      this.webAudioLoadingState = GaplessPlaybackLoadingState.NONE;
      this.loadedHEAD = false;

      // basic inputs from Queue
      this.idx = idx;
      this.queue = queue;
      this.trackUrl = trackUrl;
      this.metadata = metadata;

      this.onEnded = this.onEnded.bind(this);
      this.onProgress = this.onProgress.bind(this);

      // HTML5 Audio
      this.audio = new Audio();
      this.audio.onerror = this.audioOnError;
      this.audio.onended = this.onEnded;
      this.audio.controls = false;
      this.audio.volume = queue.state.volume;
      this.audio.preload = 'none';
      this.audio.src = trackUrl;
      // this.audio.onprogress = () => this.debug(this.idx, this.audio.buffered)

      if (queue.state.webAudioIsDisabled) return;

      // WebAudio
      this.audioContext = audioContext;
      this.gainNode = this.audioContext.createGain();
      this.gainNode.gain.value = queue.state.volume;
      this.webAudioStartedPlayingAt = 0;
      this.webAudioPausedDuration = 0;
      this.webAudioPausedAt = 0;
      this.audioBuffer = null;

      this.bufferSourceNode = this.audioContext.createBufferSource();
      this.bufferSourceNode.onended = this.onEnded;
    }

    // private functions
    loadHEAD(cb) {
      if (this.loadedHEAD) return cb();

      const options = {
        method: 'HEAD'
      };

      fetch(this.trackUrl, options)
        .then(res => {
          if (res.redirected) {
            this.trackUrl = res.url;
          }

          this.loadedHEAD = true;

          cb();
        })
    }

    loadBuffer(cb) {
      if (this.webAudioLoadingState !== GaplessPlaybackLoadingState.NONE) return;

      this.webAudioLoadingState = GaplessPlaybackLoadingState.LOADING;

      fetch(this.trackUrl)
        .then(res => res.arrayBuffer())
        .then(res =>
          this.audioContext.decodeAudioData(res, buffer => {
            this.debug('finished downloading track');

            this.webAudioLoadingState = GaplessPlaybackLoadingState.LOADED;

            this.bufferSourceNode.buffer = this.audioBuffer = buffer;
            this.bufferSourceNode.connect(this.gainNode);

            // try to preload next track
            this.queue.loadTrack(this.idx + 1);

            // if we loaded the active track, switch to web audio
            if (this.isActiveTrack) this.switchToWebAudio();

            cb && cb(buffer);
          })
        )
        .catch(e => this.debug('caught fetch error', e));
    }

    switchToWebAudio() {
      // if we've switched tracks, don't switch to web audio
      if (!this.isActiveTrack) return;

      this.debug('switch to web audio', this.currentTime, this.isPaused, this.audio.duration - this.audioBuffer.duration);

      // if currentTime === 0, this is a new track, so play it
      // otherwise we're hitting this mid-track which may
      // happen in the middle of a paused track
      this.bufferSourceNode.playbackRate.value = this.currentTime !== 0 && this.isPaused ? 0 : 1;

      this.connectGainNode();

      this.webAudioStartedPlayingAt = this.audioContext.currentTime - this.currentTime;

      // slight blip, could be improved
      this.bufferSourceNode.start(0, this.currentTime);
      this.audio.pause();

      this.playbackType = GaplessPlaybackType.WEBAUDIO;
    }

    // public-ish functions
    pause() {
      if (this.isUsingWebAudio) {
        if (this.bufferSourceNode.playbackRate.value === 0) return;
        this.webAudioPausedAt = this.audioContext.currentTime;
        this.bufferSourceNode.playbackRate.value = 0;
        this.gainNode.disconnect(this.audioContext.destination);
      }
      else {
        this.audio.pause();
      }
    }

    play() {
      this.debug('play');
      if (this.audioBuffer) {
        // if we've already set up the buffer just set playbackRate to 1
        if (this.isUsingWebAudio) {
          if (this.bufferSourceNode.playbackRate.value === 1) return;

          if (this.webAudioPausedAt) {
            this.webAudioPausedDuration += this.audioContext.currentTime - this.webAudioPausedAt;
          }

          // use seek to avoid bug where track wouldn't play properly
          // if paused for longer than length of track
          // TODO: fix bug -- must be related to bufferSourceNode
          this.seek(this.currentTime);
          // was paused, now force play
          this.connectGainNode();
          this.bufferSourceNode.playbackRate.value = 1;

          this.webAudioPausedAt = 0;
        }
        // otherwise set the bufferSourceNode buffer and switch to WebAudio
        else {
          this.switchToWebAudio();
        }

        // Try to preload the next track
        this.queue.loadTrack(this.idx + 1);
      }
      else {
        this.audio.preload = 'auto';
        this.audio.play();
        if (!this.queue.state.webAudioIsDisabled) this.loadHEAD(() => this.loadBuffer());
      }

      this.onProgress();
    }

    togglePlayPause() {
      this.isPaused ? this.play() : this.pause();
    }

    preload(HTML5) {
      this.debug('preload', HTML5);
      if (HTML5 && this.audio.preload !== 'auto') {
        this.audio.preload = 'auto';
      }
      else if (!this.audioBuffer && !this.queue.state.webAudioIsDisabled) {
        this.loadHEAD(() => this.loadBuffer());
      }
    }

    // TODO: add checks for to > duration or null or negative (duration - to)
    seek(to = 0) {
      if (this.isUsingWebAudio) {
        this.seekBufferSourceNode(to);
      }
      else {
        this.audio.currentTime = to;
      }

      this.onProgress();
    }

    seekBufferSourceNode(to) {
      const wasPaused = this.isPaused;
      this.bufferSourceNode.onended = null;
      this.bufferSourceNode.stop();

      this.bufferSourceNode = this.audioContext.createBufferSource();

      this.bufferSourceNode.buffer = this.audioBuffer;
      this.bufferSourceNode.connect(this.gainNode);
      this.bufferSourceNode.onended = this.onEnded;

      this.webAudioStartedPlayingAt = this.audioContext.currentTime - to;
      this.webAudioPausedDuration = 0;

      this.bufferSourceNode.start(0, to);
      if (wasPaused) {
        this.connectGainNode();
        this.pause();
      }
    }

    connectGainNode() {
      this.gainNode.connect(this.audioContext.destination);
    }

    // basic event handlers
    audioOnError(e) {
      this.debug('audioOnError', e);
    }

    onEnded() {
      this.debug('onEnded');
      this.queue.playNext();
      this.queue.onEnded();
    }

    onProgress() {
      if (!this.isActiveTrack) return;

      const isWithinLastTwentyFiveSeconds = (this.duration - this.currentTime) <= 25;
      const nextTrack = this.queue.nextTrack;

      // if in last 25 seconds and next track hasn't loaded yet
      // start loading next track's HTML5
      if (isWithinLastTwentyFiveSeconds && nextTrack && !nextTrack.isLoaded) {
        this.queue.loadTrack(this.idx + 1, true);
      }

      this.queue.onProgress(this);

      // if we're paused, we still want to send one final onProgress call
      // and then bow out, hence this being at the end of the function
      if (this.isPaused) return;

      // this.debug(this.currentTime, this.duration);
      window.requestAnimationFrame(this.onProgress);
      // setTimeout(this.onProgress, 33.33); // 30fps
    }

    setVolume(nextVolume) {
      this.audio.volume = nextVolume;
      this.gainNode.gain.value = nextVolume;
    }

    // getter helpers
    get isUsingWebAudio() {
      return this.playbackType === GaplessPlaybackType.WEBAUDIO;
    }

    get isPaused() {
      if (this.isUsingWebAudio) {
        return this.bufferSourceNode.playbackRate.value === 0;
      }
      else {
        return this.audio.paused;
      }
    }

    get currentTime() {
      if (this.isUsingWebAudio) {
        return this.audioContext.currentTime - this.webAudioStartedPlayingAt - this.webAudioPausedDuration;
      }
      else {
        return this.audio.currentTime;
      }
    }

    get duration() {
      if (this.isUsingWebAudio) {
        return this.audioBuffer.duration;
      }
      else {
        return this.audio.duration;
      }
    }

    get isActiveTrack() {
      return this.queue.currentTrack === this;
    }

    get isLoaded() {
      return this.webAudioLoadingState === GaplessPlaybackLoadingState.LOADED;
    }

    get state() {
      return {
        playbackType: this.playbackType,
        webAudioLoadingState: this.webAudioLoadingState
      };
    }

    get completeState() {
      return {
        playbackType: this.playbackType,
        webAudioLoadingState: this.webAudioLoadingState,
        isPaused: this.isPaused,
        currentTime: this.currentTime,
        duration: this.duration,
        idx: this.idx
      };
    }

    // debug helper
    debug(first, ...args) {
      console.log(`${this.idx}:${first}`, ...args, this.state);
    }

    // just a helper to quick jump to the end of a track for testing
    seekToEnd() {
      if (this.isUsingWebAudio) {
        this.seekBufferSourceNode(this.audioBuffer.duration - 6);
      }
      else {
        this.audio.currentTime = this.audio.duration - 6;
      }
    }

  }

  Gapless.Queue = Queue;
  Gapless.Track = Track;

  return Gapless;
});
