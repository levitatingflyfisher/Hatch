import 'fact.dart';

/// Mutable per-fact learning state. Phase is derived, never stored: automatic
/// when confirmed; derived while the child works from structure (rung at or
/// above labeled); counting below that. Demotion therefore moves phase
/// downward automatically (law 5).
class ItemState {
  ItemState();

  bool started = false;
  Rung rung = Rung.grid;

  /// Index into EngineTuning.intervalsDays; 0 = same-session.
  int srIndex = 0;
  int? dueAtMs;

  /// Per-child-per-fact schedule multiplier (law 2).
  double speed = 1.0;

  /// Consecutive correct answers at the current rung (weaning evidence).
  int streak = 0;
  int consecutiveMisses = 0;

  /// Misses after the fact had ever reached derived (law 5 lapse counting;
  /// reset when the family vignette re-fires so it can fire again).
  int lapses = 0;

  /// Calendar-day keys (yyyymmdd) with a fast correct bare production.
  List<int> automaticDays = [];

  bool automatic = false;
  bool everAutomatic = false;
  bool everDerived = false;

  /// Automatic again after having lapsed out of automatic ("repaired" seam).
  bool repaired = false;

  /// Placement instantiated this fact at bare pending spaced confirmation
  /// (law 1); counts toward family-unlock credit until it either confirms
  /// into [automatic] or lapses below bare.
  bool probeInstantiated = false;
  bool probedCold = false;

  bool mirrorPlanted = false;
  bool mirrorConfirmed = false;

  /// After a lapse the next correct answer re-proves the shortened interval
  /// without advancing it (law 5: lapse shortens).
  bool relearning = false;

  int? lastDirectionIndex;
  double? latencyEwmaMs;

  Phase get phase => automatic
      ? Phase.automatic
      : (rung.index >= Rung.labeled.index ? Phase.derived : Phase.counting);

  /// Unlock-gate credit: confirmed automatic, or probe-instantiated and still
  /// holding at bare (law 1 fast-track).
  bool get automaticForUnlock =>
      automatic || (probeInstantiated && rung == Rung.bare);

  bool dueNow(DateTime now) =>
      started && (dueAtMs == null || now.millisecondsSinceEpoch >= dueAtMs!);

  Map<String, Object?> toMap() => {
    'started': started,
    'rung': rung.index,
    'srIndex': srIndex,
    'dueAtMs': dueAtMs,
    'speed': speed,
    'streak': streak,
    'consecutiveMisses': consecutiveMisses,
    'lapses': lapses,
    'automaticDays': automaticDays,
    'automatic': automatic,
    'everAutomatic': everAutomatic,
    'everDerived': everDerived,
    'repaired': repaired,
    'probeInstantiated': probeInstantiated,
    'probedCold': probedCold,
    'mirrorPlanted': mirrorPlanted,
    'mirrorConfirmed': mirrorConfirmed,
    'relearning': relearning,
    'lastDirectionIndex': lastDirectionIndex,
    'latencyEwmaMs': latencyEwmaMs,
  };

  factory ItemState.fromMap(Map<String, Object?> map) {
    final state = ItemState()
      ..started = map['started'] as bool? ?? false
      ..rung = Rung.values[(map['rung'] as num?)?.toInt() ?? 0]
      ..srIndex = (map['srIndex'] as num?)?.toInt() ?? 0
      ..dueAtMs = (map['dueAtMs'] as num?)?.toInt()
      ..speed = (map['speed'] as num?)?.toDouble() ?? 1.0
      ..streak = (map['streak'] as num?)?.toInt() ?? 0
      ..consecutiveMisses = (map['consecutiveMisses'] as num?)?.toInt() ?? 0
      ..lapses = (map['lapses'] as num?)?.toInt() ?? 0
      ..automaticDays = ((map['automaticDays'] as List<Object?>?) ?? const [])
          .map((e) => (e as num).toInt())
          .toList()
      ..automatic = map['automatic'] as bool? ?? false
      ..everAutomatic = map['everAutomatic'] as bool? ?? false
      ..everDerived = map['everDerived'] as bool? ?? false
      ..repaired = map['repaired'] as bool? ?? false
      ..probeInstantiated = map['probeInstantiated'] as bool? ?? false
      ..probedCold = map['probedCold'] as bool? ?? false
      ..mirrorPlanted = map['mirrorPlanted'] as bool? ?? false
      ..mirrorConfirmed = map['mirrorConfirmed'] as bool? ?? false
      ..relearning = map['relearning'] as bool? ?? false
      ..lastDirectionIndex = (map['lastDirectionIndex'] as num?)?.toInt()
      ..latencyEwmaMs = (map['latencyEwmaMs'] as num?)?.toDouble();
    return state;
  }
}
