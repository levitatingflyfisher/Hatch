import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hatch/features/profiles/domain/egg_glyph.dart';
import 'package:hatch/shared/theme/app_colors.dart';
import 'package:hatch/shared/theme/app_theme.dart';
import 'package:openhearth_design/openhearth_design.dart';

void main() {
  test('the critter palette matches the size the glyph math assumes', () {
    expect(AppColors.critterPalette.length, kCritterPaletteSize);
  });

  test(
    'critter hues are distinct and none restates a canonical token value',
    () {
      // C1 forbids retyped canonical hex; the palette must be its own hue set.
      final canonical = <Color>{
        OhColors.hearth500,
        OhColors.linen50,
        OhColors.linen900,
        OhColors.sage500,
        OhColors.darkSurfaceBase,
      };
      final appLocal = <Color>[
        ...AppColors.critterPalette,
        AppColors.yolk,
        AppColors.cream,
        AppColors.ink,
        AppColors.plumDark,
        AppColors.shell,
      ];
      expect(
        AppColors.critterPalette.toSet().length,
        AppColors.critterPalette.length,
      );
      for (final hue in appLocal) {
        expect(
          canonical.contains(hue),
          isFalse,
          reason: '$hue duplicates a canonical token',
        );
      }
    },
  );

  test('the parent-corner hearth is the canonical token, Tier T', () {
    expect(AppColors.hearth, OhColors.hearth500);
  });

  test('both themes carry the shared type ladder and the yolk seed', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      expect(theme.textTheme.displaySmall?.fontFamily, 'Lora');
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Nunito');
    }
    expect(AppTheme.light.scaffoldBackgroundColor, AppColors.cream);
    expect(AppTheme.dark.scaffoldBackgroundColor, AppColors.plumDark);
    expect(AppTheme.light.brightness, Brightness.light);
    expect(AppTheme.dark.brightness, Brightness.dark);
  });
}
