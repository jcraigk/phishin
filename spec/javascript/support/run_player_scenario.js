// Loads the player engine files the way WidgetCompiler does, replaces the
// browser audio objects with fakes that record what was asked of them, runs
// the scenario named on the command line and prints its result as JSON.
const fs = require("fs");
const path = require("path");

const [playerDir, scenarioName] = process.argv.slice(2);
const FILES = ["handoffPlan.js", "SessionKeeper.js", "ElementStream.js", "WebAudioBackend.js"];
const source = FILES
  .filter((name) => fs.existsSync(path.join(playerDir, name)))
  .map((name) => fs.readFileSync(path.join(playerDir, name), "utf8")
    .replace(/^import .*;\n/gm, "")
    .replace(/^export /gm, ""))
  .join("\n");

const log = [];
const elements = [];
const round = (n) => Math.round(n * 1000) / 1000;
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const streamElement = () => elements.find((el) => el.crossOrigin === "anonymous");

class FakeParam {
  constructor(value) { this.value = value; }
  setValueAtTime(value, time) { this.value = value; log.push(["gain.set", value, round(time)]); return this; }
  linearRampToValueAtTime(value, time) { this.value = value; log.push(["gain.ramp", value, round(time)]); return this; }
  cancelScheduledValues() { return this; }
}

class FakeNode {
  constructor() { this.gain = new FakeParam(1); }
  connect() {}
  disconnect() { log.push(["disconnect"]); }
}

class FakeSource extends FakeNode {
  constructor() { super(); this.buffer = null; this.onended = null; }
  start(when, offset, length) { log.push(["source.start", round(when), round(offset), round(length)]); }
  stop() { log.push(["source.stop"]); }
}

class FakeContext {
  constructor() { this.currentTime = 0; this.state = "running"; this.destination = new FakeNode(); }
  createGain() { return new FakeNode(); }
  createBufferSource() { return new FakeSource(); }
  createMediaElementSource(element) { log.push(["wrap", element.crossOrigin]); return new FakeNode(); }
  addEventListener() {}
  resume() { this.state = "running"; return Promise.resolve(); }
  close() {}
  decodeAudioData() { return Promise.resolve({ duration: 600 }); }
}

class FakeAudio {
  constructor(src) {
    this.src = src || "";
    this.currentTime = 0;
    this.paused = true;
    this.readyState = 0;
    this.seeking = false;
    this.loop = false;
    this.listeners = {};
    elements.push(this);
  }
  addEventListener(name, fn) { (this.listeners[name] ||= []).push(fn); }
  emit(name) { (this.listeners[name] || []).forEach((fn) => fn()); }
  play() { this.paused = false; log.push(["element.play", this.src, round(this.currentTime)]); return Promise.resolve(); }
  pause() { this.paused = true; log.push(["element.pause", this.src]); }
  removeAttribute() { this.src = ""; }
  load() {}
}

let releaseFetch;
const fetchGate = new Promise((resolve) => { releaseFetch = resolve; });
global.window = { AudioContext: FakeContext };
global.Audio = FakeAudio;
global.fetch = (url) => {
  log.push(["fetch", url]);
  return fetchGate.then(() => ({ ok: true, arrayBuffer: () => Promise.resolve(new ArrayBuffer(8)) }));
};

const { ElementStream, WebAudioBackend } = eval(
  source + "\n({ ElementStream, WebAudioBackend: typeof WebAudioBackend === 'undefined' ? null : WebAudioBackend })"
);

const scenarios = {
  async "stream starts muted and opens on playing"() {
    const ctx = new FakeContext();
    const stream = new ElementStream(ctx);
    const events = [];
    stream.onPlaying = () => events.push("playing");
    stream.start("a.mp3", 42);
    const el = streamElement();
    const gainBeforePlaying = stream.gain.gain.value;
    el.readyState = 1;
    el.emit("loadedmetadata");
    const seekApplied = el.currentTime;
    el.emit("playing");
    return { log, events, gainBeforePlaying, seekApplied, gainAfterPlaying: stream.gain.gain.value };
  },

  async "stream seeks in place for the same url"() {
    const stream = new ElementStream(new FakeContext());
    stream.start("a.mp3", 0);
    const el = streamElement();
    el.readyState = 1;
    el.emit("loadedmetadata");
    stream.start("a.mp3", 30);
    return { log, currentTime: el.currentTime, src: el.src };
  },

  async "stream fade out pauses the element after the ramp"() {
    const ctx = new FakeContext();
    const stream = new ElementStream(ctx);
    stream.start("a.mp3", 0);
    const el = streamElement();
    el.readyState = 1;
    el.emit("loadedmetadata");
    el.emit("playing");
    ctx.currentTime = 1;
    stream.fadeOut(1.1, 0.05);
    const pausedImmediately = streamElement().paused;
    await sleep(250);
    return { log, pausedImmediately, pausedLater: streamElement().paused, active: stream.active, src: streamElement().src };
  },

  async "stream fade out then restart keeps playing"() {
    const ctx = new FakeContext();
    const stream = new ElementStream(ctx);
    stream.start("a.mp3", 0);
    const el = streamElement();
    el.readyState = 1;
    el.emit("loadedmetadata");
    el.emit("playing");
    ctx.currentTime = 1;
    stream.fadeOut(1.1, 0.05);
    stream.pause();
    stream.start("a.mp3", 5);
    el.emit("seeked");
    el.emit("playing");
    await sleep(250);
    return { log, paused: streamElement().paused, active: stream.active, gain: stream.gain.gain.value };
  },

  async "stream fade out before opening pauses immediately"() {
    const stream = new ElementStream(new FakeContext());
    stream.start("a.mp3", 0);
    stream.fadeOut(1.1, 0.05);
    return { log, paused: streamElement().paused, src: streamElement().src };
  },

  async "stream ignores events once paused"() {
    const stream = new ElementStream(new FakeContext());
    const events = [];
    stream.onEnded = () => events.push("ended");
    stream.onTimeUpdate = (seconds) => events.push(["time", seconds]);
    stream.start("a.mp3", 0);
    stream.pause();
    streamElement().emit("ended");
    streamElement().emit("timeupdate");
    return { log, events };
  },

  async "backend streams an undecoded track"() {
    const backend = new WebAudioBackend();
    const loading = [];
    backend.onLoading = (value) => loading.push(value);
    backend.load([{ url: "a.mp3", offset: 0, end: null }]);
    backend.play(0, 12);
    const el = streamElement();
    el.readyState = 1;
    el.emit("loadedmetadata");
    el.currentTime = 12;
    el.emit("playing");
    el.currentTime = 15;
    return { log, loading, position: backend.position(), playing: backend.isPlaying() };
  },

  async "backend hands off to the buffer when decoded"() {
    const backend = new WebAudioBackend();
    backend.load([{ url: "a.mp3", offset: 0, end: null }, { url: "b.mp3", offset: 0, end: null }]);
    const playing = backend.play(0, 0);
    const el = streamElement();
    el.readyState = 1;
    el.emit("loadedmetadata");
    el.emit("playing");
    backend.ctx.currentTime = 2;
    el.currentTime = 7;
    releaseFetch();
    await playing;
    const afterHandoff = { streaming: backend.current.streaming === true, position: round(backend.position()) };
    await sleep(250);
    return { log, afterHandoff, pausedLater: el.paused };
  },

  async "backend skips the element for a decoded track"() {
    const backend = new WebAudioBackend();
    backend.load([{ url: "a.mp3", offset: 0, end: null }]);
    const playing = backend.play(0, 0);
    const el = streamElement();
    el.readyState = 1;
    el.emit("loadedmetadata");
    el.emit("playing");
    releaseFetch();
    await playing;
    const trackPlays = () => log.filter((entry) => entry[0] === "element.play" && entry[1] === "a.mp3").length;
    const playsBefore = trackPlays();
    await backend.play(0, 100);
    const playsAfter = trackPlays();
    return { log, playsBefore, playsAfter };
  },

  async "backend pause while streaming stops the element"() {
    const backend = new WebAudioBackend();
    backend.load([{ url: "a.mp3", offset: 0, end: null }]);
    backend.play(0, 0);
    backend.pause();
    return { log, paused: streamElement().paused, position: backend.position() };
  },

  async "backend advances when the element ends before decode"() {
    const backend = new WebAudioBackend();
    const advances = [];
    backend.onAdvance = (index) => advances.push(index);
    backend.load([{ url: "a.mp3", offset: 0, end: null }, { url: "b.mp3", offset: 3, end: null }]);
    backend.play(0, 0);
    streamElement().emit("ended");
    return { log, advances };
  },

  async "backend ends a streamed excerpt at its end"() {
    const backend = new WebAudioBackend();
    const advances = [];
    backend.onAdvance = (index) => advances.push(index);
    backend.load([{ url: "a.mp3", offset: 0, end: 50 }, { url: "b.mp3", offset: 0, end: null }]);
    backend.play(0, 0);
    const el = streamElement();
    el.currentTime = 49;
    el.emit("timeupdate");
    const advancesBeforeEnd = advances.slice();
    el.currentTime = 50.2;
    el.emit("timeupdate");
    return { log, advancesBeforeEnd, advances };
  },

  async "backend reports an element error"() {
    const backend = new WebAudioBackend();
    const errors = [];
    backend.onError = (error) => errors.push(error.message);
    backend.load([{ url: "a.mp3", offset: 0, end: null }]);
    backend.play(0, 0);
    streamElement().emit("error");
    return { log, errors, playing: backend.isPlaying() };
  },

  async "backend clears loading at handoff"() {
    const backend = new WebAudioBackend();
    const loading = [];
    backend.onLoading = (value) => loading.push(value);
    backend.load([{ url: "a.mp3", offset: 0, end: null }]);
    const playing = backend.play(0, 0);
    const el = streamElement();
    el.readyState = 1;
    el.emit("loadedmetadata");
    el.emit("playing");
    el.emit("waiting");
    releaseFetch();
    await playing;
    return { loading };
  },

  async "backend destroy before decode leaves no context"() {
    const backend = new WebAudioBackend();
    backend.load([{ url: "a.mp3", offset: 0, end: null }]);
    backend.play(0, 0);
    const el = streamElement();
    el.readyState = 1;
    el.emit("loadedmetadata");
    el.emit("playing");
    backend.destroy();
    releaseFetch();
    await sleep(20);
    return { ctx: backend.ctx === null };
  },

  async "backend defers the decode fetch until the element is playing"() {
    const backend = new WebAudioBackend();
    backend.load([{ url: "a.mp3", offset: 0, end: null }]);
    backend.play(0, 0);
    const fetchCount = () => log.filter((entry) => entry[0] === "fetch").length;
    const fetchesBeforePlaying = fetchCount();
    const el = streamElement();
    el.readyState = 1;
    el.emit("loadedmetadata");
    el.emit("playing");
    await sleep(0);
    const fetchesAfterPlaying = fetchCount();
    return { fetchesBeforePlaying, fetchesAfterPlaying };
  },

  async "backend pause before playing abandons the decode"() {
    const backend = new WebAudioBackend();
    backend.load([{ url: "a.mp3", offset: 0, end: null }]);
    backend.play(0, 0);
    backend.pause();
    streamElement().emit("playing");
    await sleep(0);
    const fetches = log.filter((entry) => entry[0] === "fetch").length;
    return { fetches };
  },
};

const run = scenarios[scenarioName];
if (!run) {
  console.error(`unknown scenario: ${scenarioName}`);
  process.exit(1);
}
run().then((result) => console.log(JSON.stringify(result))).catch((error) => {
  console.error(error.stack);
  process.exit(1);
});
