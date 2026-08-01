/// Every sound in the game, referenced by name — features never touch asset
/// paths. Files live in assets/audio/; cues whose files have not shipped yet
/// (crack/hatch/chirps arrive with the reskin pass) simply no-op at runtime.
enum SoundCue {
  /// Egg drop — each row snap during STACK (pitched skip-count plink).
  plink('plink.ogg'),

  /// Verb commits.
  snap('snap.ogg'),
  fold('fold.ogg'),
  slice('slice.ogg'),
  rotate('rotate.ogg'),
  stamp('stamp.ogg'),

  /// Correct answer — the eggs settle (the sew.ogg asset, resurfaced).
  settle('sew.ogg'),

  /// Crack-cascade tiers (CellFillSweep tempo tiers).
  sweepSlow('sweep_slow.ogg'),
  sweepMedium('sweep_med.ogg'),
  sweepFast('sweep_fast.ogg'),

  /// Tray complete.
  trayDone('block.ogg'),

  /// Wrong answer — kinder than any win sound is loud (kindness asymmetry).
  miss('miss.ogg'),

  /// Vignette / unlock / hatch fanfare.
  chime('chime.ogg'),

  /// Hatch Rush round start.
  rushStart('bee_start.ogg'),

  /// Hatch choreography (assets land with the reskin pass).
  crack('crack.ogg'),
  hatch('hatch.ogg'),
  chirp1('chirp_1.ogg'),
  chirp2('chirp_2.ogg'),
  chirp3('chirp_3.ogg');

  const SoundCue(this.fileName);

  final String fileName;

  /// AssetSource path (audioplayers prefixes 'assets/').
  String get assetPath => 'audio/$fileName';
}
