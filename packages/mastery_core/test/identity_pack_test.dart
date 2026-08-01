import 'package:mastery_core/mastery_core.dart';
import 'package:test/test.dart';

void main() {
  group('Fact', () {
    test('carries product and canonical id', () {
      const f = Fact(3, 8);
      expect(f.a, 3);
      expect(f.b, 8);
      expect(f.product, 24);
      expect(f.id, '3x8');
    });

    test('folded factory normalizes ordering into 0 <= a <= b <= 10', () {
      expect(Fact.folded(8, 3), const Fact(3, 8));
      expect(Fact.folded(0, 0).id, '0x0');
      expect(Fact.folded(10, 10).id, '10x10');
    });

    test('folded factory rejects out-of-range factors', () {
      expect(() => Fact.folded(-1, 3), throwsRangeError);
      expect(() => Fact.folded(3, 11), throwsRangeError);
    });

    test('value equality on (a, b)', () {
      expect(const Fact(3, 8), const Fact(3, 8));
      expect(const Fact(3, 8).hashCode, const Fact(3, 8).hashCode);
      expect(const Fact(3, 8), isNot(const Fact(3, 9)));
    });

    test('isSquare marks the diagonal', () {
      expect(const Fact(7, 7).isSquare, isTrue);
      expect(const Fact(7, 8).isSquare, isFalse);
    });

    test('parse round-trips id', () {
      expect(Fact.parse('3x8'), const Fact(3, 8));
      expect(Fact.parse('10x10'), const Fact(10, 10));
      expect(() => Fact.parse('11x2'), throwsRangeError);
      expect(() => Fact.parse('junk'), throwsFormatException);
    });
  });

  group('MultiplicationPack', () {
    const pack = MultiplicationPack();

    test('66 folded facts, each owned by exactly one family', () {
      expect(pack.allFacts.length, 66);
      expect(pack.allFacts.toSet().length, 66);
      for (final fact in pack.allFacts) {
        expect(fact.a <= fact.b, isTrue);
        expect(
          pack.ownerOf(fact),
          isNot(Family.squares),
          reason: 'squares is cross-cutting, never a scheduling owner',
        );
      }
    });

    test('unlock sequence follows Kling & Bay-Williams practitioner order', () {
      expect(pack.sequence, const [
        Family.x2,
        Family.x10,
        Family.x5,
        Family.x1,
        Family.x0,
        Family.squares,
        Family.x4,
        Family.x3,
        Family.x9,
        Family.x6,
        Family.x7,
        Family.x8,
      ]);
    });

    test('diagonal facts are owned by their factor family, tagged square', () {
      expect(pack.ownerOf(const Fact(4, 4)), Family.x4);
      expect(pack.ownerOf(const Fact(2, 2)), Family.x2);
      expect(pack.ownerOf(const Fact(0, 0)), Family.x0);
      expect(pack.ownedBy(Family.squares), isEmpty);
    });

    test('off-diagonal facts are owned by the earlier family in sequence', () {
      expect(pack.ownerOf(const Fact(0, 2)), Family.x2);
      expect(pack.ownerOf(const Fact(3, 10)), Family.x10);
      expect(pack.ownerOf(const Fact(5, 9)), Family.x5);
      expect(pack.ownerOf(const Fact(3, 4)), Family.x4);
      expect(pack.ownerOf(const Fact(6, 9)), Family.x9);
      expect(pack.ownerOf(const Fact(7, 8)), Family.x7);
    });

    test('family ownership counts form the triangle', () {
      expect(pack.ownedBy(Family.x2).length, 11);
      expect(pack.ownedBy(Family.x10).length, 10);
      expect(pack.ownedBy(Family.x5).length, 9);
      expect(pack.ownedBy(Family.x1).length, 8);
      expect(pack.ownedBy(Family.x0).length, 7);
      expect(pack.ownedBy(Family.x4).length, 6);
      expect(pack.ownedBy(Family.x3).length, 5);
      expect(pack.ownedBy(Family.x9).length, 4);
      expect(pack.ownedBy(Family.x6).length, 3);
      expect(pack.ownedBy(Family.x7).length, 2);
      expect(pack.ownedBy(Family.x8).length, 1);
    });

    test('strategy routes per family', () {
      expect(pack.routesFor(Family.x2), const [StrategyRoute.skipCount]);
      expect(pack.routesFor(Family.x10), const [StrategyRoute.skipCount]);
      expect(pack.routesFor(Family.x5), const [StrategyRoute.skipCount]);
      expect(pack.routesFor(Family.x4), const [StrategyRoute.foldDouble]);
      expect(pack.routesFor(Family.x3), const [StrategyRoute.addAGroup]);
      expect(pack.routesFor(Family.x9), const [StrategyRoute.trimAGroup]);
      expect(pack.routesFor(Family.x6), const [
        StrategyRoute.foldDouble,
        StrategyRoute.addAGroup,
      ]);
      expect(pack.routesFor(Family.x7), const [StrategyRoute.fiveAnchorSplit]);
      expect(pack.routesFor(Family.x8), const [StrategyRoute.foldDouble]);
      expect(pack.routesFor(Family.squares), const [StrategyRoute.nearSquare]);
    });

    test('strategy source component facts', () {
      // foldDouble halves the strategy factor; addAGroup steps down a group;
      // trimAGroup steps up to the anchor; fiveAnchorSplit rests on the 5s.
      expect(pack.componentFact(const Fact(4, 6)), const Fact(2, 6));
      expect(pack.componentFact(const Fact(3, 7)), const Fact(2, 7));
      expect(pack.componentFact(const Fact(6, 9)), const Fact(6, 10));
      expect(pack.componentFact(const Fact(7, 8)), const Fact(5, 8));
      expect(pack.componentFact(const Fact(8, 8)), const Fact(4, 8));
      expect(pack.componentFact(const Fact(6, 7)), const Fact(3, 7));
      // Foundational skip-count families have no derivation component.
      expect(pack.componentFact(const Fact(2, 6)), isNull);
      expect(pack.componentFact(const Fact(0, 7)), isNull);
    });

    test('gates: ANDed OR-groups encode sequence plus strategy sources', () {
      bool open(Family f, Set<Family> satisfied) =>
          pack.gateSatisfied(f, satisfied);

      expect(open(Family.x2, {}), isTrue);
      expect(open(Family.x10, {}), isFalse);
      expect(open(Family.x10, {Family.x2}), isTrue);
      expect(open(Family.x5, {Family.x10}), isTrue);
      expect(open(Family.x1, {Family.x5}), isTrue);
      expect(open(Family.x0, {Family.x5}), isTrue);
      expect(open(Family.squares, {Family.x5}), isTrue);
      expect(
        open(Family.x4, {Family.x2}),
        isFalse,
        reason: 'x4 also waits for the squares step',
      );
      expect(open(Family.x4, {Family.x2, Family.squares}), isTrue);
      expect(open(Family.x3, {Family.x2, Family.x4}), isTrue);
      expect(open(Family.x9, {Family.x10, Family.x3}), isTrue);
      expect(open(Family.x7, {Family.x6, Family.x5, Family.x2}), isTrue);
      expect(open(Family.x8, {Family.x7, Family.x4}), isTrue);
    });
  });
}
