import 'distractor_model.dart';
import 'events.dart';
import 'fact.dart';
import 'item_state.dart';
import 'knowledge_graph.dart';
import 'tuning.dart';
import 'views.dart';

/// Assembles rounds (law 7): requeue debts first, placement probes while
/// active, then ~60% due review interleaved across ALL open families /
/// ~25% frontier / ~15% recent-miss, at ~85% expected success. Pure: the
/// same state and `now` always yield the same round (law 9 depends on it).
class RoundAssembler {
  const RoundAssembler(this._tuning);

  final EngineTuning _tuning;

  static const _distractors = DistractorModel();

  RoundSpec assemble({
    required RoundIntent intent,
    required MultiplicationPack pack,
    required Map<Fact, ItemState> states,
    required Map<Family, FamilyStatus> statuses,
    required Set<Family> satisfied,
    required List<({Fact fact, AskDirection direction})> requeues,
    required List<Fact> probes,
    required bool placementActive,
    required DateTime now,
    required int seed,
  }) {
    final events = <RoundEventSpec>[];
    final used = <Fact>{};
    final size = intent == RoundIntent.piecing
        ? _tuning.piecingMinEvents +
              seed.abs() %
                  (_tuning.piecingMaxEvents - _tuning.piecingMinEvents + 1)
        : _tuning.beeMinEvents +
              seed.abs() % (_tuning.beeMaxEvents - _tuning.beeMinEvents + 1);
    final reAskKind = intent == RoundIntent.bee
        ? EventKind.bee
        : EventKind.review;

    // Requeue debts lead every round (law 8): re-retrieval before new work,
    // in the direction that was missed.
    for (final r in requeues) {
      if (events.length >= size) {
        break;
      }
      final state = states[r.fact]!;
      events.add(
        _spec(
          pack,
          r.fact,
          state,
          direction: r.direction,
          kind: reAskKind,
          rung: state.rung,
          seed: seed,
        ),
      );
      used.add(r.fact);
    }

    if (intent == RoundIntent.piecing) {
      _fillPiecing(
        events,
        used,
        pack,
        states,
        statuses,
        satisfied,
        probes,
        now,
        seed,
        size,
      );
    } else {
      _fillBee(events, used, pack, states, now, seed, size);
    }

    return RoundSpec(
      events: events,
      placementActive: placementActive,
      expectedSuccess: _expectedSuccess(events, states, requeues),
    );
  }

  void _fillPiecing(
    List<RoundEventSpec> events,
    Set<Fact> used,
    MultiplicationPack pack,
    Map<Fact, ItemState> states,
    Map<Family, FamilyStatus> statuses,
    Set<Family> satisfied,
    List<Fact> probes,
    DateTime now,
    int seed,
    int size,
  ) {
    for (final fact in probes.take(_tuning.probeCapPerRound)) {
      if (events.length >= size) {
        return;
      }
      events.add(
        _spec(
          pack,
          fact,
          states[fact]!,
          direction: AskDirection.forward,
          kind: EventKind.probe,
          rung: Rung.bare,
          seed: seed,
        ),
      );
      used.add(fact);
    }

    final remaining = size - events.length;
    if (remaining <= 0) {
      return;
    }
    final reviewTarget = (remaining * _tuning.reviewShare).round();
    final frontierTarget = (remaining * _tuning.frontierShare).ceil();

    final duePool = _duePoolInterleaved(pack, states, used, now);
    final frontierPool = _frontierPool(pack, states, statuses, satisfied, used);
    final recentPool = _recentMissPool(pack, states, used, now);

    var taken = 0;
    for (final fact in duePool) {
      if (taken >= reviewTarget || events.length >= size) {
        break;
      }
      events.add(
        _reviewSpec(pack, fact, states[fact]!, EventKind.review, seed),
      );
      used.add(fact);
      taken++;
    }
    taken = 0;
    for (final entry in frontierPool) {
      if (taken >= frontierTarget || events.length >= size) {
        break;
      }
      events.add(entry);
      used.add(entry.fact);
      taken++;
    }
    for (final fact in recentPool) {
      if (events.length >= size) {
        break;
      }
      events.add(
        _reviewSpec(pack, fact, states[fact]!, EventKind.review, seed),
      );
      used.add(fact);
    }
    // Shortfall: more due reviews, then more frontier work; a sparse engine
    // simply yields a shorter round (never filler-for-filler's-sake).
    for (final fact in duePool) {
      if (events.length >= size) {
        break;
      }
      if (used.add(fact)) {
        events.add(
          _reviewSpec(pack, fact, states[fact]!, EventKind.review, seed),
        );
      }
    }
    for (final entry in frontierPool) {
      if (events.length >= size) {
        break;
      }
      if (used.add(entry.fact)) {
        events.add(entry);
      }
    }
  }

  void _fillBee(
    List<RoundEventSpec> events,
    Set<Fact> used,
    MultiplicationPack pack,
    Map<Fact, ItemState> states,
    DateTime now,
    int seed,
    int size,
  ) {
    // Bare-dominant pool: symbolic-ready facts first (bare, then labeled,
    // then bundled), due before not-due within each tier.
    final pool =
        states.entries
            .where((e) => e.value.started && e.value.rung != Rung.grid)
            .toList()
          ..sort((x, y) {
            final rung = y.value.rung.index.compareTo(x.value.rung.index);
            if (rung != 0) {
              return rung;
            }
            final dueX = x.value.dueNow(now) ? 0 : 1;
            final dueY = y.value.dueNow(now) ? 0 : 1;
            if (dueX != dueY) {
              return dueX.compareTo(dueY);
            }
            return x.key.id.compareTo(y.key.id);
          });
    if (pool.isEmpty) {
      return;
    }
    // Seed-rotated start keeps consecutive rounds from replaying the same
    // opening tags without introducing any randomness.
    final start = seed.abs() % pool.length;
    for (var i = 0; i < pool.length && events.length < size; i++) {
      final entry = pool[(start + i) % pool.length];
      if (!used.add(entry.key)) {
        continue;
      }
      events.add(
        _reviewSpec(pack, entry.key, entry.value, EventKind.bee, seed),
      );
    }
  }

  /// Due facts grouped by family, round-robined in sequence order: reviews
  /// interleave across ALL open families, never blocked by topic (law 7).
  List<Fact> _duePoolInterleaved(
    MultiplicationPack pack,
    Map<Fact, ItemState> states,
    Set<Fact> used,
    DateTime now,
  ) {
    final byFamily = <Family, List<Fact>>{};
    for (final entry in states.entries) {
      if (!entry.value.started ||
          used.contains(entry.key) ||
          !entry.value.dueNow(now)) {
        continue;
      }
      byFamily.putIfAbsent(pack.ownerOf(entry.key), () => []).add(entry.key);
    }
    for (final list in byFamily.values) {
      list.sort((x, y) {
        final due = (states[x]!.dueAtMs ?? 0).compareTo(
          states[y]!.dueAtMs ?? 0,
        );
        return due != 0 ? due : x.id.compareTo(y.id);
      });
    }
    final families = pack.sequence
        .where(byFamily.containsKey)
        .toList(growable: false);
    final result = <Fact>[];
    var index = 0;
    while (true) {
      var any = false;
      for (final family in families) {
        final list = byFamily[family]!;
        if (index < list.length) {
          result.add(list[index]);
          any = true;
        }
      }
      if (!any) {
        return result;
      }
      index++;
    }
  }

  /// Frontier work: finish the ladder on started facts, then introduce a
  /// couple of new patches — from the earliest open-but-unsatisfied family.
  List<RoundEventSpec> _frontierPool(
    MultiplicationPack pack,
    Map<Fact, ItemState> states,
    Map<Family, FamilyStatus> statuses,
    Set<Family> satisfied,
    Set<Fact> used,
  ) {
    Family? frontier;
    for (final family in pack.sequence) {
      if (statuses[family] == FamilyStatus.open &&
          !satisfied.contains(family) &&
          pack.ownedBy(family).isNotEmpty) {
        frontier = family;
        break;
      }
    }
    if (frontier == null) {
      return const [];
    }
    final owned = [...pack.ownedBy(frontier)]
      ..sort((x, y) => x.product.compareTo(y.product));
    final specs = <RoundEventSpec>[];
    for (final fact in owned) {
      final state = states[fact]!;
      if (used.contains(fact) || !state.started || state.rung == Rung.bare) {
        continue;
      }
      specs.add(_constructSpec(pack, fact, state));
    }
    var intros = 0;
    for (final fact in owned) {
      if (intros >= _tuning.newFactsPerRound) {
        break;
      }
      final state = states[fact]!;
      if (used.contains(fact) || state.started) {
        continue;
      }
      specs.add(_constructSpec(pack, fact, state));
      intros++;
    }
    return specs;
  }

  List<Fact> _recentMissPool(
    MultiplicationPack pack,
    Map<Fact, ItemState> states,
    Set<Fact> used,
    DateTime now,
  ) {
    final pool =
        states.entries
            .where(
              (e) =>
                  e.value.started &&
                  !used.contains(e.key) &&
                  (e.value.consecutiveMisses > 0 || e.value.lapses > 0) &&
                  e.value.dueNow(now),
            )
            .map((e) => e.key)
            .toList()
          ..sort((x, y) {
            final due = (states[x]!.dueAtMs ?? 0).compareTo(
              states[y]!.dueAtMs ?? 0,
            );
            return due != 0 ? due : x.id.compareTo(y.id);
          });
    return pool;
  }

  RoundEventSpec _constructSpec(
    MultiplicationPack pack,
    Fact fact,
    ItemState state,
  ) {
    final rung = state.started ? state.rung : Rung.grid;
    return _spec(
      pack,
      fact,
      state,
      direction: AskDirection.forward,
      kind: EventKind.construct,
      rung: rung,
      seed: 0,
    );
  }

  RoundEventSpec _reviewSpec(
    MultiplicationPack pack,
    Fact fact,
    ItemState state,
    EventKind kind,
    int seed,
  ) {
    final direction = _directionFor(state, fact);
    // Law 4: an unconfirmed mirror enters rotation at rung labeled.
    final rung = direction == AskDirection.reversed && !state.mirrorConfirmed
        ? Rung.labeled
        : state.rung;
    return _spec(
      pack,
      fact,
      state,
      direction: direction,
      kind: kind,
      rung: rung,
      seed: seed,
    );
  }

  AskDirection _directionFor(ItemState state, Fact fact) {
    if (fact.isSquare) {
      return AskDirection.forward;
    }
    if (state.mirrorPlanted && !state.mirrorConfirmed) {
      return AskDirection.reversed;
    }
    if (state.automatic && state.mirrorConfirmed) {
      // Bee alternates orderings so both directions keep earning evidence.
      return state.lastDirectionIndex == AskDirection.forward.index
          ? AskDirection.reversed
          : AskDirection.forward;
    }
    return AskDirection.forward;
  }

  RoundEventSpec _spec(
    MultiplicationPack pack,
    Fact fact,
    ItemState state, {
    required AskDirection direction,
    required EventKind kind,
    required Rung rung,
    required int seed,
  }) => RoundEventSpec(
    fact: fact,
    direction: direction,
    kind: kind,
    rung: rung,
    choiceDistractors: _distractors.distractorsFor(
      fact,
      seed: seed + fact.hashCode,
    ),
    strategyHint: kind == EventKind.construct && rung == Rung.labeled
        ? pack.routesFor(pack.ownerOf(fact)).first
        : null,
  );

  /// Per-event success estimate; the mix targets ~85% (law 7). Numbers are
  /// coarse priors, not measurements — they only steer composition.
  double _expectedSuccess(
    List<RoundEventSpec> events,
    Map<Fact, ItemState> states,
    List<({Fact fact, AskDirection direction})> requeues,
  ) {
    if (events.isEmpty) {
      return 1;
    }
    final requeued = requeues.map((r) => r.fact).toSet();
    var total = 0.0;
    for (final event in events) {
      final state = states[event.fact]!;
      if (event.kind == EventKind.probe) {
        total += 0.5; // diagnosis, not practice
      } else if (requeued.contains(event.fact)) {
        total += 0.75; // just missed; re-retrieval is harder
      } else if (event.kind == EventKind.construct) {
        total += event.rung == Rung.labeled ? 0.80 : 0.87;
      } else if (state.automatic) {
        total += 0.97;
      } else if (state.phase == Phase.derived) {
        total += 0.85;
      } else {
        total += 0.70;
      }
    }
    return total / events.length;
  }
}
