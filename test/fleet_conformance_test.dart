import 'package:oh_fleet_conformance/oh_fleet_conformance.dart';

/// Hatch's recorded fleet posture — every deliberate divergence from
/// fleet canon lives in this one config, enforced as tests.
void main() => runFleetConformance(
  const FleetAppConfig(
    appId: 'hatch',
    // Hatch bundles Lora + Nunito, so there is no web-font fallback to
    // catch a character they cannot draw — C7 sweeps lib/ for any.
    checks: FleetAppConfig.withBundledFonts,
    // Tier T: canonical openhearth_design tokens + text ladder; theme
    // construction stays local (signature accent is canonical hearth500,
    // no retyped literals).
    styleTier: StyleTier.tokens,
    // ZERO permissions is the point of this app: no INTERNET (ads/IAP/
    // tracking are architecturally impossible), no notifications (the nest
    // never nags), no vibrate (HapticFeedback needs no permission).
    androidPermissions: {},
    // C4 v2 — the release MERGED surface, verified against the built
    // artifact at v0.1 (aapt2 dump badging on the arm64 split APK shows
    // exactly this set): audioplayers, share_plus, file_picker and pdf
    // inject no permissions; the DYNAMIC_RECEIVER self-permission is
    // AndroidX's own and grants nothing.
    mergedAndroidPermissions: {
      'com.openhearth.hatch.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION',
    },
  ),
);
