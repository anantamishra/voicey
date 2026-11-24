// Small synthesized UI sounds (Web Audio). No audio files.
// The AudioContext is only created after a user gesture, and every call is a
// no-op until then, so scrolling alone never triggers a blocked-autoplay error.

type Ctx = AudioContext;

let ctx: Ctx | null = null;
let master: GainNode | null = null;
let enabled = true;

const KEY = "voicey-sound";

export function soundEnabled() {
  return enabled;
}

export function initSoundPreference() {
  try {
    enabled = localStorage.getItem(KEY) !== "off";
  } catch {
    enabled = true;
  }
}

export function setSoundEnabled(on: boolean) {
  enabled = on;
  try {
    localStorage.setItem(KEY, on ? "on" : "off");
  } catch {}
}

/** Call from a real user gesture (click / key). Safe to call repeatedly. */
export function unlockAudio() {
  if (ctx) {
    if (ctx.state === "suspended") void ctx.resume();
    return;
  }
  const AC =
    window.AudioContext ||
    (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
  if (!AC) return;
  ctx = new AC();
  master = ctx.createGain();
  master.gain.value = 0.3; // overall volume (0 to 1)
  master.connect(ctx.destination);
}

function ready(): Ctx | null {
  if (!enabled || !ctx || !master || ctx.state !== "running") return null;
  return ctx;
}

type Tone = {
  freq: number;
  to?: number; // glide target
  dur: number;
  type?: OscillatorType;
  gain?: number;
  delay?: number;
  attack?: number;
};

function tone({ freq, to, dur, type = "sine", gain = 0.12, delay = 0, attack = 0.004 }: Tone) {
  const c = ready();
  if (!c || !master) return;
  const t0 = c.currentTime + delay;
  const osc = c.createOscillator();
  const g = c.createGain();
  osc.type = type;
  osc.frequency.setValueAtTime(freq, t0);
  if (to) osc.frequency.exponentialRampToValueAtTime(to, t0 + dur);
  g.gain.setValueAtTime(0.0001, t0);
  g.gain.exponentialRampToValueAtTime(gain, t0 + attack);
  g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
  osc.connect(g).connect(master);
  osc.start(t0);
  osc.stop(t0 + dur + 0.02);
}

function noise(dur: number, gain: number, lo: number, hi: number, delay = 0) {
  const c = ready();
  if (!c || !master) return;
  const len = Math.max(1, Math.floor(c.sampleRate * dur));
  const buf = c.createBuffer(1, len, c.sampleRate);
  const data = buf.getChannelData(0);
  for (let i = 0; i < len; i++) data[i] = Math.random() * 2 - 1;
  const src = c.createBufferSource();
  src.buffer = buf;
  const filter = c.createBiquadFilter();
  filter.type = "bandpass";
  const t0 = c.currentTime + delay;
  filter.frequency.setValueAtTime(lo, t0);
  filter.frequency.exponentialRampToValueAtTime(hi, t0 + dur);
  filter.Q.value = 0.9;
  const g = c.createGain();
  g.gain.setValueAtTime(0.0001, t0);
  g.gain.exponentialRampToValueAtTime(gain, t0 + dur * 0.25);
  g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
  src.connect(filter).connect(g).connect(master);
  src.start(t0);
}

export const sfx = {
  /** generic button / link press */
  click() {
    tone({ freq: 1100, to: 640, dur: 0.05, type: "triangle", gain: 0.1 });
    tone({ freq: 220, to: 120, dur: 0.06, gain: 0.05 });
  },
  /** the demo moves on: you start talking */
  select() {
    tone({ freq: 900, to: 520, dur: 0.05, type: "triangle", gain: 0.11 });
    tone({ freq: 1500, to: 900, dur: 0.035, type: "sine", gain: 0.05, delay: 0.012 });
  },
  /** the demo moves on: polishing */
  menu() {
    noise(0.14, 0.05, 700, 2600);
    tone({ freq: 420, to: 640, dur: 0.12, gain: 0.06 });
  },
  /** the demo moves on: the text is pasted */
  open() {
    tone({ freq: 523, dur: 0.18, gain: 0.07 });
    tone({ freq: 784, dur: 0.24, gain: 0.06, delay: 0.07 });
  },
  /** story rewinds */
  close() {
    tone({ freq: 640, to: 360, dur: 0.12, gain: 0.06 });
  },
  /** tab chip / small selection */
  tab() {
    tone({ freq: 760, to: 560, dur: 0.045, type: "triangle", gain: 0.09 });
  },
};
