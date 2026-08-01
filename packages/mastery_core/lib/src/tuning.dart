/// Every knob the engine's laws leave open, in one place, with the shipped
/// defaults. These are the values the law-10 simulated-learner gate was tuned
/// against; VISION states plainly they are unvalidated until real children
/// play. All are serialized into snapshots so a restored engine behaves
/// identically even if code defaults later change.
class EngineTuning {
  const EngineTuning({
    this.intervalsDays = const [0, 1, 3, 7, 14, 30],
    this.rungAdvanceStreak = 2,
    this.automaticityDays = 3,
    this.recallBudgetMs = 1700,
    this.defaultMotorMs = 800,
    this.motorClampMinMs = 350,
    this.motorClampMaxMs = 1400,
    this.motorMinSamples = 10,
    this.fastThresholdMinMs = 2000,
    this.fastThresholdMaxMs = 3200,
    this.speedUpStep = 0.15,
    this.speedDownStep = 0.30,
    this.speedMin = 0.5,
    this.speedMax = 2.0,
    this.lapseSrPenalty = 2,
    this.strategySwitchAtMisses = 3,
    this.prerequisiteProbeAtMisses = 5,
    this.vignetteReDueLapses = 4,
    this.unlockAutomaticShare = 0.8,
    this.piecingMinEvents = 6,
    this.piecingMaxEvents = 10,
    this.beeMinEvents = 10,
    this.beeMaxEvents = 16,
    this.reviewShare = 0.60,
    this.frontierShare = 0.25,
    this.recentMissShare = 0.15,
    this.probeCapPerRound = 6,
    this.newFactsPerRound = 2,
    this.probeSentinels = 3,
    this.coldFamilyStopStreak = 2,
  });

  /// Expanding schedule (law 2): index 0 is "same session" (due immediately),
  /// then calendar days. Expanding beats equal spacing for children's
  /// generalization (Vlach et al. 2014, research brief 2d).
  final List<int> intervalsDays;

  /// Consecutive correct answers at the current rung needed to wean one rung
  /// up. 2 keeps a session's worth of piecing per rung without stranding the
  /// child in pictures (both lingering and rushing are named CPA failure
  /// modes, research brief 2c).
  final int rungAdvanceStreak;

  /// Distinct calendar days of fast correct production needed for automatic
  /// (law 2: "3+ sessions on 3+ distinct days"; days proxy sessions).
  final int automaticityDays;

  /// Recall budget + motor baseline = fast threshold. 1700 + the 800ms
  /// default motor baseline lands on the contract's ~2500ms bound (law 3,
  /// "roughly <=2-3s recall" per research brief 2d).
  final int recallBudgetMs;

  /// Assumed keypress time before enough of the child's own latencies exist.
  final int defaultMotorMs;

  final int motorClampMinMs;
  final int motorClampMaxMs;
  final int motorMinSamples;

  /// The normalized bound may never leave [2000, 3200]ms: below 2s would
  /// demand adult reflexes; above 3.2s would credit counting as recall.
  final int fastThresholdMinMs;
  final int fastThresholdMaxMs;

  /// Per-child-per-fact schedule multiplier steps (Math Academy pattern,
  /// law 2): fast due reviews stretch intervals, lapses compress them.
  final double speedUpStep;
  final double speedDownStep;
  final double speedMin;
  final double speedMax;

  /// A lapse drops the interval index this many steps (law 5 "shortens").
  final int lapseSrPenalty;

  final int strategySwitchAtMisses;
  final int prerequisiteProbeAtMisses;
  final int vignetteReDueLapses;

  /// Share of a family's owned facts that must be automatic to satisfy an
  /// unlock gate; the remainder must be at least derived (law 6).
  final double unlockAutomaticShare;

  final int piecingMinEvents;
  final int piecingMaxEvents;
  final int beeMinEvents;
  final int beeMaxEvents;

  /// Round mix (law 7): due review / frontier / recent-miss.
  final double reviewShare;
  final double frontierShare;
  final double recentMissShare;

  final int probeCapPerRound;
  final int newFactsPerRound;

  /// Placement (law 1): sentinel probes per family before committing to a
  /// full-family sweep; consecutive cold families that end placement.
  final int probeSentinels;
  final int coldFamilyStopStreak;

  Map<String, Object?> toMap() => {
    'intervalsDays': intervalsDays,
    'rungAdvanceStreak': rungAdvanceStreak,
    'automaticityDays': automaticityDays,
    'recallBudgetMs': recallBudgetMs,
    'defaultMotorMs': defaultMotorMs,
    'motorClampMinMs': motorClampMinMs,
    'motorClampMaxMs': motorClampMaxMs,
    'motorMinSamples': motorMinSamples,
    'fastThresholdMinMs': fastThresholdMinMs,
    'fastThresholdMaxMs': fastThresholdMaxMs,
    'speedUpStep': speedUpStep,
    'speedDownStep': speedDownStep,
    'speedMin': speedMin,
    'speedMax': speedMax,
    'lapseSrPenalty': lapseSrPenalty,
    'strategySwitchAtMisses': strategySwitchAtMisses,
    'prerequisiteProbeAtMisses': prerequisiteProbeAtMisses,
    'vignetteReDueLapses': vignetteReDueLapses,
    'unlockAutomaticShare': unlockAutomaticShare,
    'piecingMinEvents': piecingMinEvents,
    'piecingMaxEvents': piecingMaxEvents,
    'beeMinEvents': beeMinEvents,
    'beeMaxEvents': beeMaxEvents,
    'reviewShare': reviewShare,
    'frontierShare': frontierShare,
    'recentMissShare': recentMissShare,
    'probeCapPerRound': probeCapPerRound,
    'newFactsPerRound': newFactsPerRound,
    'probeSentinels': probeSentinels,
    'coldFamilyStopStreak': coldFamilyStopStreak,
  };

  factory EngineTuning.fromMap(Map<String, Object?> map) {
    const defaults = EngineTuning();
    int i(String key, int fallback) => (map[key] as num?)?.toInt() ?? fallback;
    double d(String key, double fallback) =>
        (map[key] as num?)?.toDouble() ?? fallback;
    return EngineTuning(
      intervalsDays:
          (map['intervalsDays'] as List<Object?>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          defaults.intervalsDays,
      rungAdvanceStreak: i('rungAdvanceStreak', defaults.rungAdvanceStreak),
      automaticityDays: i('automaticityDays', defaults.automaticityDays),
      recallBudgetMs: i('recallBudgetMs', defaults.recallBudgetMs),
      defaultMotorMs: i('defaultMotorMs', defaults.defaultMotorMs),
      motorClampMinMs: i('motorClampMinMs', defaults.motorClampMinMs),
      motorClampMaxMs: i('motorClampMaxMs', defaults.motorClampMaxMs),
      motorMinSamples: i('motorMinSamples', defaults.motorMinSamples),
      fastThresholdMinMs: i('fastThresholdMinMs', defaults.fastThresholdMinMs),
      fastThresholdMaxMs: i('fastThresholdMaxMs', defaults.fastThresholdMaxMs),
      speedUpStep: d('speedUpStep', defaults.speedUpStep),
      speedDownStep: d('speedDownStep', defaults.speedDownStep),
      speedMin: d('speedMin', defaults.speedMin),
      speedMax: d('speedMax', defaults.speedMax),
      lapseSrPenalty: i('lapseSrPenalty', defaults.lapseSrPenalty),
      strategySwitchAtMisses: i(
        'strategySwitchAtMisses',
        defaults.strategySwitchAtMisses,
      ),
      prerequisiteProbeAtMisses: i(
        'prerequisiteProbeAtMisses',
        defaults.prerequisiteProbeAtMisses,
      ),
      vignetteReDueLapses: i(
        'vignetteReDueLapses',
        defaults.vignetteReDueLapses,
      ),
      unlockAutomaticShare: d(
        'unlockAutomaticShare',
        defaults.unlockAutomaticShare,
      ),
      piecingMinEvents: i('piecingMinEvents', defaults.piecingMinEvents),
      piecingMaxEvents: i('piecingMaxEvents', defaults.piecingMaxEvents),
      beeMinEvents: i('beeMinEvents', defaults.beeMinEvents),
      beeMaxEvents: i('beeMaxEvents', defaults.beeMaxEvents),
      reviewShare: d('reviewShare', defaults.reviewShare),
      frontierShare: d('frontierShare', defaults.frontierShare),
      recentMissShare: d('recentMissShare', defaults.recentMissShare),
      probeCapPerRound: i('probeCapPerRound', defaults.probeCapPerRound),
      newFactsPerRound: i('newFactsPerRound', defaults.newFactsPerRound),
      probeSentinels: i('probeSentinels', defaults.probeSentinels),
      coldFamilyStopStreak: i(
        'coldFamilyStopStreak',
        defaults.coldFamilyStopStreak,
      ),
    );
  }
}
