import 'package:flutter_test/flutter_test.dart';
import 'package:hatch/shared/critters/critters.dart';
import 'package:hatch/shared/theme/app_colors.dart';
import 'package:mastery_core/mastery_core.dart';

void main() {
  const pack = MultiplicationPack();

  group('CritterSpec.of', () {
    test('is deterministic', () {
      final a = CritterSpec.of(const Fact(3, 8));
      final b = CritterSpec.of(const Fact(3, 8));
      expect(a.species, b.species);
      expect(a.hue, b.hue);
      expect(a.seed, b.seed);
      expect(a.accessory, b.accessory);
    });

    test('species follows the owning family', () {
      // 3x8: x3 unlocks before x8 -> sprout antenna.
      expect(
        CritterSpec.of(const Fact(3, 8)).species,
        CritterSpecies.sproutAntenna,
      );
      // Any fact containing 2 is owned by x2.
      expect(
        CritterSpec.of(const Fact(2, 9)).species,
        CritterSpecies.bouncyBlob,
      );
      expect(
        CritterSpec.of(const Fact(0, 2)).species,
        CritterSpecies.bouncyBlob,
      );
      // The lone double-decker is 8x8.
      expect(
        CritterSpec.of(const Fact(8, 8)).species,
        CritterSpecies.doubleDecker,
      );
      expect(
        CritterSpec.of(const Fact(0, 0)).species,
        CritterSpecies.bubbleGhost,
      );
      expect(
        CritterSpec.of(const Fact(9, 10)).species,
        CritterSpecies.tallStacker,
      );
    });

    test('species map covers every owning family across all 66 facts', () {
      for (final fact in pack.allFacts) {
        final spec = CritterSpec.of(fact);
        expect(spec.species, CritterSpec.speciesForFamily(pack.ownerOf(fact)));
      }
    });

    test('hue comes from the other factor via the critter palette', () {
      // 3x8 owned by x3 -> other factor 8 -> palette[8 % 6].
      expect(
        CritterSpec.of(const Fact(3, 8)).hue,
        AppColors.critterPalette[8 % AppColors.critterPalette.length],
      );
      // 2x7 owned by x2 -> other factor 7 -> palette[1].
      expect(
        CritterSpec.of(const Fact(2, 7)).hue,
        AppColors.critterPalette[7 % AppColors.critterPalette.length],
      );
      // Squares: both factors match the owner; hue from the same factor.
      expect(
        CritterSpec.of(const Fact(4, 4)).hue,
        AppColors.critterPalette[4 % AppColors.critterPalette.length],
      );
    });

    test('only squares are crowned', () {
      for (final fact in pack.allFacts) {
        expect(CritterSpec.of(fact).crowned, fact.isSquare, reason: fact.id);
      }
    });

    test('twins share body, hue, seed, and accessory; mirrored flag flips', () {
      final forward = CritterSpec.of(const Fact(3, 8));
      final twin = forward.twin;
      expect(twin.species, forward.species);
      expect(twin.hue, forward.hue);
      expect(twin.seed, forward.seed);
      expect(twin.accessory, forward.accessory);
      expect(twin.mirrored, isTrue);
      expect(twin.twin, forward);
    });

    test('squares family is rejected loudly', () {
      expect(
        () => CritterSpec.speciesForFamily(Family.squares),
        throwsArgumentError,
      );
    });

    test('accessories vary across the fact space', () {
      final kinds = {
        for (final fact in pack.allFacts) CritterSpec.of(fact).accessory,
      };
      expect(kinds, CritterAccessory.values.toSet());
    });
  });
}
