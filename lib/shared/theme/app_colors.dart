import 'package:flutter/material.dart';
import 'package:openhearth_design/openhearth_design.dart';

class AppColors {
  AppColors._();

  // Hatch's signature accent, "yolk": the warm gold of the moment an egg
  // cracks. App-local by design (kid-bright register, see the reskin ADR
  // trail); checked against ohStyle canonicals — no retyped token (C1).
  static const yolk = Color(0xFFF2A93B);
  static const yolkDark = Color(0xFFC9862A);

  // Grown-up warmth for the parent corner only — canonical hearth by token.
  static const hearth = OhColors.hearth500;

  // Ground: warm cream in light, deep plum-brown in dark. Cream is app-local
  // (brighter than canonical linen50 on purpose); dark ink doubles as crack
  // lines on eggshells.
  static const cream = Color(0xFFFFF6E9);
  static const creamCard = Color(0xFFFFFDF7);
  static const ink = Color(0xFF3A2B25);
  static const plumDark = Color(0xFF2A1E2E);
  static const plumCard = Color(0xFF3A2C3F);

  // Eggshell.
  static const shell = Color(0xFFFDF1DC);
  static const speckle = Color(0xFFD9C4A5);

  // Canonical neutrals kept for type/dividers where the fleet ladder expects
  // them.
  static const linen900 = OhColors.linen900;

  // The critter palette: six saturated, kid-bright hues. Deliberately
  // app-local; each value is checked against ohStyle colors.dart — none
  // duplicates a canonical token (a duplicate would trip C1's sweep).
  static const coral = Color(0xFFFF6F61);
  static const sky = Color(0xFF4FA3D9);
  static const leaf = Color(0xFF6BBF59);
  static const grape = Color(0xFF9B6BD9);
  static const bubblegum = Color(0xFFF06FA4);
  static const tangerine = Color(0xFFF28C38);

  /// Critter/tray hues in paint order; painters index into this via seeded
  /// specs (avatars, critters, trays).
  static const critterPalette = [coral, sky, leaf, grape, bubblegum, tangerine];
}
