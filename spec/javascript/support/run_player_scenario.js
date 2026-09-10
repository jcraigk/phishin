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
  setValueAtTime(value) { this.value = value; return this; }
  linearRampToValueAtTime(value) { this.value = value; return this; }
  cancelScheduledValues() { return this; }
  cancelAndHoldAtTime() { return this; }
}

class FakeNode {
  constructor() { this.gain = new FakeParam(1); }
  connect() {}
  disconnect() {}
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
global.fetch = () => fetchGate.then(() => ({ ok: true, arrayBuffer: () => Promise.resolve(new ArrayBuffer(8)) }));

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
    return { log, pausedImmediately, pausedLater: streamElement().paused, active: stream.active };
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
    return { log, paused: streamElement().paused };
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
};

const run = scenarios[scenarioName];
if (!run) {
  console.error(`unknown scenario: ${scenarioName}`);
  process.exit(1);
}
run().then((result) => console.log(JSON.stringify(result)));
