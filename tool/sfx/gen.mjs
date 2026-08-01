// Hatch SFX pipeline — fully offline, deterministic after first run.
// jsfxr presets are randomized per call, so the first run freezes every params
// set into params.json (committed); later runs re-render identical audio.
// Output: ../../assets/audio/*.ogg (22 kHz mono, quiet master volume — the miss
// sound must stay kinder than the win sound is loud).
import { sfxr } from 'jsfxr';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const OUT = path.resolve('../../assets/audio');
const BUILD = path.resolve('./build');
fs.mkdirSync(OUT, { recursive: true });
fs.mkdirSync(BUILD, { recursive: true });

// C-major pentatonic, two partial octaves — the skip-count voice. p_base_freq
// is jsfxr's normalized pitch where f ∝ p², so notes scale by sqrt(ratio).
const PENTA = [261.63, 293.66, 329.63, 392.0, 440.0, 523.25, 587.33, 659.25];

const SPECS = {
  snap: { preset: 'blipSelect', over: { sound_vol: 0.16, p_env_decay: 0.08 } },
  sew: { preset: 'pickupCoin', over: { sound_vol: 0.18 } },
  block: { preset: 'powerUp', over: { sound_vol: 0.2, p_env_decay: 0.32 } },
  // Soft inquisitive "hm?" — sine, low, short. Never a buzzer.
  miss: { preset: 'hitHurt', over: { sound_vol: 0.10, wave_type: 2, p_base_freq: 0.22, p_env_decay: 0.34, p_env_sustain: 0.05, p_env_punch: 0 } },
  rotate: { preset: 'click', over: { sound_vol: 0.14 } },
  fold: { preset: 'jump', over: { sound_vol: 0.15, p_base_freq: 0.30 } },
  slice: { preset: 'laserShoot', over: { sound_vol: 0.11, p_env_decay: 0.06, p_base_freq: 0.55 } },
  stamp: { preset: 'click', over: { sound_vol: 0.2, p_base_freq: 0.12 } },
  chime: { preset: 'synth', over: { sound_vol: 0.17 } },
  bee_start: { preset: 'jump', over: { sound_vol: 0.17, p_base_freq: 0.42 } },
  // Hatch-moment set. Every vol sits above miss (0.10) — kindness asymmetry.
  // Dry shell snap: noise burst, no tonal ring.
  crack: { preset: 'hitHurt', over: { sound_vol: 0.13, wave_type: 3, p_base_freq: 0.45, p_env_attack: 0, p_env_sustain: 0.05, p_env_punch: 0.3, p_env_decay: 0.22, p_lpf_freq: 0.9, p_hpf_freq: 0.2, p_freq_ramp: -0.3 } },
  // Bright two-note pop+chirp: positive arp mod jumps the pitch UP mid-note.
  hatch: { preset: 'pickupCoin', over: { sound_vol: 0.19, p_base_freq: 0.42, p_arp_mod: 0.55, p_arp_speed: 0.55, p_env_attack: 0, p_env_sustain: 0.10, p_env_punch: 0.4, p_env_decay: 0.35 } },
  // Tiny critter voices: sine peeps with a little vibrato, three pitches.
  chirp_1: { preset: 'blipSelect', over: { sound_vol: 0.12, wave_type: 2, p_base_freq: 0.52, p_vib_strength: 0.08, p_vib_speed: 0.55, p_env_attack: 0, p_env_sustain: 0.06, p_env_punch: 0, p_env_decay: 0.24 } },
  chirp_2: { preset: 'blipSelect', over: { sound_vol: 0.12, wave_type: 2, p_base_freq: 0.60, p_vib_strength: 0.08, p_vib_speed: 0.62, p_env_attack: 0, p_env_sustain: 0.06, p_env_punch: 0, p_env_decay: 0.24 } },
  chirp_3: { preset: 'blipSelect', over: { sound_vol: 0.12, wave_type: 2, p_base_freq: 0.68, p_vib_strength: 0.08, p_vib_speed: 0.70, p_env_attack: 0, p_env_sustain: 0.06, p_env_punch: 0, p_env_decay: 0.24 } },
};
// Root plink: short sine blip; notes derived by sqrt-ratio pitch scaling.
const PLINK_BASE = { preset: 'blipSelect', over: { sound_vol: 0.16, wave_type: 2, p_env_decay: 0.30, p_env_sustain: 0.06, p_base_freq: 0.33 } };

// Additive freeze: existing entries in params.json are never regenerated —
// only names new to SPECS get params rolled and appended.
const paramsPath = './params.json';
const frozen = fs.existsSync(paramsPath) ? JSON.parse(fs.readFileSync(paramsPath, 'utf8')) : {};
let dirty = false;
for (const [name, spec] of Object.entries(SPECS)) {
  if (!(name in frozen)) {
    frozen[name] = { ...sfxr.generate(spec.preset), ...spec.over };
    dirty = true;
  }
}
if (!('plink_1' in frozen)) {
  const root = { ...sfxr.generate(PLINK_BASE.preset), ...PLINK_BASE.over };
  PENTA.forEach((hz, i) => {
    frozen[`plink_${i + 1}`] = { ...root, p_base_freq: root.p_base_freq * Math.sqrt(hz / PENTA[0]) };
  });
  dirty = true;
}
if (dirty) {
  fs.writeFileSync(paramsPath, JSON.stringify(frozen, null, 1));
  console.log('froze params.json');
}

for (const [name, params] of Object.entries(frozen)) {
  const wav = sfxr.toWave(params).dataURI.split(',')[1];
  fs.writeFileSync(`${BUILD}/${name}.wav`, Buffer.from(wav, 'base64'));
}

const ff = (args) => execFileSync('ffmpeg', ['-y', '-loglevel', 'error', ...args]);

// Arpeggio sweep tiers: plinks butted at three tempos. Pre-rendered clips so the
// app never fires per-note audio (audioplayers trigger latency would stutter).
for (const [tier, ms] of [['slow', 150], ['med', 100], ['fast', 60]]) {
  const inputs = [];
  const filters = [];
  PENTA.forEach((_, i) => {
    inputs.push('-i', `${BUILD}/plink_${i + 1}.wav`);
    const slot = ms / 1000;
    filters.push(
      `[${i}:a]apad=whole_dur=${slot},atrim=0:${slot},afade=t=out:st=${slot - 0.02}:d=0.02,asetpts=PTS-STARTPTS[a${i}]`);
  });
  const concat = PENTA.map((_, i) => `[a${i}]`).join('') + `concat=n=${PENTA.length}:v=0:a=1[out]`;
  ff([...inputs, '-filter_complex', `${filters.join(';')};${concat}`, '-map', '[out]',
    '-ar', '22050', '-ac', '1', '-q:a', '3', `${OUT}/sweep_${tier}.ogg`]);
  console.log(`sweep_${tier}.ogg`);
}

for (const name of Object.keys(frozen)) {
  if (name.startsWith('plink_') && name !== 'plink_1') continue; // singles: only root plink ships
  const out = name === 'plink_1' ? 'plink' : name;
  ff(['-i', `${BUILD}/${name}.wav`, '-ar', '22050', '-ac', '1', '-q:a', '3', `${OUT}/${out}.ogg`]);
  console.log(`${out}.ogg`);
}

const total = fs.readdirSync(OUT).reduce((s, f) => s + fs.statSync(path.join(OUT, f)).size, 0);
console.log(`assets/audio total: ${(total / 1024).toFixed(1)} KB`);
