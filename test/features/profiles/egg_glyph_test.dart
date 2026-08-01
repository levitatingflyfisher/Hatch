import 'package:flutter_test/flutter_test.dart';
import 'package:hatch/features/profiles/domain/egg_glyph.dart';

void main() {
  group('eggGlyphFor', () {
    test('produces the full speckle field, in shell-local range', () {
      final glyph = eggGlyphFor(42);
      expect(glyph.speckleX, hasLength(EggGlyph.speckleCount));
      expect(glyph.speckleY, hasLength(EggGlyph.speckleCount));
      expect(glyph.speckleR, hasLength(EggGlyph.speckleCount));
      for (final x in glyph.speckleX) {
        expect(x, inInclusiveRange(0.0, 1.0));
      }
      for (final y in glyph.speckleY) {
        expect(y, inInclusiveRange(0.0, 1.0));
      }
      for (final r in glyph.speckleR) {
        expect(
          r,
          inInclusiveRange(
            EggGlyph.minSpeckleRadius,
            EggGlyph.maxSpeckleRadius,
          ),
        );
      }
    });

    test('is deterministic for the same seed', () {
      final a = eggGlyphFor(7);
      final b = eggGlyphFor(7);
      expect(a.speckleX, b.speckleX);
      expect(a.speckleY, b.speckleY);
      expect(a.speckleR, b.speckleR);
      expect(a.crackJitter, b.crackJitter);
      expect(a.hasAntennae, b.hasAntennae);
      expect(a.eyeShift, b.eyeShift);
    });

    test('differs across seeds', () {
      final a = eggGlyphFor(1);
      final b = eggGlyphFor(2);
      expect(a.speckleX, isNot(equals(b.speckleX)));
    });

    test('crack jitter stays in the zigzag envelope across many seeds', () {
      for (var seed = 0; seed < 50; seed++) {
        final glyph = eggGlyphFor(seed);
        expect(glyph.crackJitter, hasLength(EggGlyph.crackToothCount));
        for (final j in glyph.crackJitter) {
          expect(j, inInclusiveRange(0.0, 1.0), reason: 'seed $seed');
        }
        expect(
          glyph.eyeShift,
          inInclusiveRange(-1.0, 1.0),
          reason: 'seed $seed',
        );
      }
    });

    test('antennae appear on some hatchers and not others', () {
      final flavors = {
        for (var seed = 0; seed < 50; seed++) eggGlyphFor(seed).hasAntennae,
      };
      expect(flavors, containsAll([true, false]));
    });
  });
}
