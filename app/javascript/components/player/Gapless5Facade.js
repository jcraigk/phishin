import { GaplessEngine } from "./GaplessEngine";
import { WebAudioBackend } from "./WebAudioBackend";

// The MCP widgets are compiled to standalone HTML and were written against the
// gapless-5 API. This exposes that API's subset they use on top of
// GaplessEngine, so the widget scripts stay as they are. WidgetCompiler inlines
// this file with the engine files it depends on.
export class Gapless5 {
  constructor({ tracks = [], startingTrack = 0 } = {}) {
    this.ontimeupdate = () => {};
    this.onplay = () => {};
    this.onpause = () => {};
    this.onstop = () => {};
    this.onnext = () => {};
    this.onprev = () => {};
    this.onloadstart = () => {};
    this.onload = () => {};
    this.onfinishedall = () => {};
    this.onerror = () => {};
    this.lastAction = "end";

    this.engine = new GaplessEngine(new WebAudioBackend());
    this.engine.onTime = (seconds, index) => this.ontimeupdate(seconds * 1000, index);
    this.engine.onLoading = (loading) => (loading ? this.onloadstart() : this.onload());
    this.engine.onError = (error) => this.onerror(null, error);
    this.engine.onTrackChange = (index) => {
      const previous = this.lastIndex;
      this.lastIndex = index;
      if (previous !== undefined && index < previous) {
        this.onprev();
      } else {
        this.onnext();
      }
    };
    this.engine.onPlayChange = (playing) => {
      if (playing) {
        this.onplay();
      } else if (this.lastAction === "pause") {
        this.onpause();
      } else if (this.lastAction === "stop") {
        this.onstop();
      } else {
        this.onfinishedall();
      }
    };

    this.engine.load(tracks.map((url) => ({ url, offset: 0, end: null })), startingTrack);
    this.lastIndex = this.engine.index;
  }

  play() {
    this.lastAction = "end";
    this.engine.play();
  }

  pause() {
    this.lastAction = "pause";
    this.engine.pause();
  }

  playpause() {
    if (this.engine.playing) {
      this.pause();
    } else {
      this.play();
    }
  }

  stop() {
    this.lastAction = "stop";
    const wasPlaying = this.engine.playing;
    this.engine.pause();
    this.engine.pausedPosition = 0;
    if (!wasPlaying) this.onstop();
  }

  next() {
    this.engine.next();
  }

  prev() {
    this.engine.previous();
  }

  gotoTrack(index, forcePlay = false) {
    if (forcePlay) this.lastAction = "end";
    this.engine.goto(index, { play: forcePlay || this.engine.playing });
  }

  getIndex() {
    return this.engine.index;
  }

  getPosition() {
    return this.engine.position() * 1000;
  }

  setPosition(milliseconds) {
    this.engine.seek(milliseconds / 1000);
  }

  removeAllTracks() {
    this.engine.destroy();
  }
}
