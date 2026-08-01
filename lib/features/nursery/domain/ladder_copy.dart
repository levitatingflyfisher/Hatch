import 'package:mastery_core/mastery_core.dart';

/// The CPA weaning ladder, named.
///
/// grid → bundled → labeled → bare is a real four-stage progression: the
/// support falls away one rung at a time and the child is measurably more
/// capable at each step. Until this pass it had no name anywhere in the app,
/// for anyone — the tray simply looked different one day. A player who cannot
/// name the ladder cannot see herself climbing it, and a parent cannot see
/// that the climbing is the point.
String rungLabel(Rung rung) => switch (rung) {
  Rung.grid => 'Grid',
  Rung.bundled => 'Bundled',
  Rung.labeled => 'Labeled',
  Rung.bare => 'Bare',
};

/// What that rung asks of the child, in a parent's language.
String rungBlurb(Rung rung) => switch (rung) {
  Rung.grid => 'Every egg is there to be counted. The most support there is.',
  Rung.bundled => 'Eggs become rows, so she counts groups instead of ones.',
  Rung.labeled =>
    'The tray closes and wears the fact. She works from the shape.',
  Rung.bare => 'Numbers alone, nothing to lean on. This is the goal.',
};

/// How a family is written on a teaching surface.
String familyLabel(Family family) => switch (family) {
  Family.squares => 'squares',
  Family.x0 => '×0',
  Family.x1 => '×1',
  Family.x2 => '×2',
  Family.x3 => '×3',
  Family.x4 => '×4',
  Family.x5 => '×5',
  Family.x6 => '×6',
  Family.x7 => '×7',
  Family.x8 => '×8',
  Family.x9 => '×9',
  Family.x10 => '×10',
};

/// Which families are taught through [route], in unlock order — the answer to
/// "when would my child ever see this?"
List<Family> familiesUsing(StrategyRoute route) {
  const pack = MultiplicationPack();
  return [
    for (final family in Family.values)
      if (pack.routesFor(family).contains(route)) family,
  ];
}
