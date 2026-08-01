import 'package:flutter/material.dart';
import 'package:openhearth_design/openhearth_design.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  // Fonts are BUNDLED (assets/fonts/, declared in pubspec) and referenced by
  // family — never fetched at runtime. The ladder is the shared Material
  // scale from openhearth_design (Tier T: canonical tokens + text ladder,
  // theme construction local).
  static const TextTheme _textTheme = OhTypography.materialTextTheme;

  static final light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.yolk,
      brightness: Brightness.light,
      surface: AppColors.cream,
      onSurface: AppColors.ink,
    ),
    scaffoldBackgroundColor: AppColors.cream,
    shadowColor: AppColors.ink.withValues(alpha: 0.15),
    textTheme: _textTheme,
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: AppColors.creamCard,
      shadowColor: AppColors.ink.withValues(alpha: 0.1),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );

  static final dark = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.yolk,
      brightness: Brightness.dark,
      surface: AppColors.plumDark,
    ),
    scaffoldBackgroundColor: AppColors.plumDark,
    shadowColor: Colors.black.withValues(alpha: 0.3),
    textTheme: _textTheme,
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: AppColors.plumCard,
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
