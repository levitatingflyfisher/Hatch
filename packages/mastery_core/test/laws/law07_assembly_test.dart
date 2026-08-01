import 'package:mastery_core/mastery_core.dart';
import 'package:test/test.dart';

import '../support/harness.dart';

void main() {
  const pack = MultiplicationPack();

  group('law 7', () {
    test('law 7: piecing rounds mix ~60% due review across families, '
        '~25% frontier, at ~85% expected success', () {
      final engine = matureEngine();
      final round = engine.assembleRound(RoundIntent.piecing, now: onDay(3));

      expect(round.events.length, inInclusiveRange(6, 10));
      expect(
        round.events.where((e) => e.kind == EventKind.probe),
        isEmpty,
        reason: 'placement ended after two cold families',
      );

      final reviews = round.events
          .where((e) => e.kind == EventKind.review)
          .toList();
      expect(reviews.length / round.events.length, greaterThanOrEqualTo(0.4));

      final reviewFamilies = reviews.map((e) => pack.ownerOf(e.fact)).toSet();
      expect(
        reviewFamilies.length,
        greaterThanOrEqualTo(3),
        reason: 'reviews interleave across ALL open families',
      );

      final frontier = round.events
          .where(
            (e) =>
                e.kind == EventKind.construct &&
                pack.ownerOf(e.fact) == Family.x4,
          )
          .toList();
      expect(
        frontier,
        isNotEmpty,
        reason: 'the frontier family supplies new learning',
      );

      expect(round.expectedSuccess, inInclusiveRange(0.70, 0.95));
      for (final event in round.events) {
        expect(event.choiceDistractors.length, 2);
        expect(event.choiceDistractors, isNot(contains(event.fact.product)));
      }
    });

    test(
      'law 7: assembly is a pure query — identical calls, identical round',
      () {
        final engine = matureEngine();
        final a = engine.assembleRound(RoundIntent.piecing, now: onDay(3));
        final b = engine.assembleRound(RoundIntent.piecing, now: onDay(3));
        expect(describeRound(a), describeRound(b));
      },
    );

    test('law 7: a missed fact requeues within the round', () {
      final engine = matureEngine();
      const missed = Fact(2, 7);
      engine.record(ev(missed, at: onDay(3), correct: false, latencyMs: 3000));
      final round = engine.assembleRound(
        RoundIntent.piecing,
        now: onDay(3, minute: 1),
      );
      expect(
        round.events.first.fact,
        missed,
        reason: 'requeued facts lead the next assembly',
      );
    });

    test('law 7: bee rounds are 10-16 fast events, bare-dominant', () {
      final engine = matureEngine();
      final round = engine.assembleRound(RoundIntent.bee, now: onDay(3));
      expect(round.events.length, inInclusiveRange(10, 16));
      for (final event in round.events) {
        expect(event.kind, EventKind.bee);
      }
      final bare = round.events.where((e) => e.rung == Rung.bare).length;
      expect(bare / round.events.length, greaterThanOrEqualTo(0.6));
    });
  });
}
