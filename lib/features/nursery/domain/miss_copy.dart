import '../../../shared/painters/shortfall_overflow.dart';

/// What the miss choreography is showing, in the child's words, said while it
/// plays.
///
/// The house pattern is `vignetteLabel`: name the move as it happens. The
/// shortfall/overflow moment is the engine's stated teaching moment and was
/// the one choreography the pattern had never been applied to — its meaning
/// lived only in the painter's comments, which are addressed to whoever reads
/// the source, not to the child watching the eggs move.
///
/// Descriptive, never corrective: she is told what the tray is doing, not
/// that she was wrong. Null when there is nothing to narrate.
String? missLabel(ShortfallOverflowKind kind) => switch (kind) {
  ShortfallOverflowKind.shortfall => 'Room for more!',
  ShortfallOverflowKind.overflow => 'Too many to fit!',
  ShortfallOverflowKind.exact => null,
};
