/// How a finished rush compares to the profile's stored best for the same
/// event count. Every outcome is warm: slower runs are still good runs, and
/// no numeric comparison is ever shown (refuse-list: no shame, no clocks).
enum RushOutcome { firstRush, personalBest, goodRush }

/// Tally-card copy. Never negative, never comparative beyond the celebration
/// itself; the celebration line only appears on a genuine improvement.
String rushTallyCopy(RushOutcome outcome) => switch (outcome) {
  RushOutcome.firstRush => 'Your first rush is in the book!',
  RushOutcome.personalBest => 'Your quickest rush yet!',
  RushOutcome.goodRush => 'A good rush!',
};

/// Shown when the engine cannot assemble a big-enough round yet. Friendly
/// redirection, not a locked-content tease.
const rushEmptyCopy = 'More eggs need hatching in the Nursery first.';

/// What the second marker on the track actually is.
///
/// "What am I racing?" had no answer anywhere on screen: the ghost is drawn
/// as a translucent shadow and nothing ever named it. With no run on record
/// the honest answer is *nothing yet* — said in a way that makes this run
/// worth finishing. Still no clocks and no numbers, per the refuse-list.
String rushGhostCopy({required bool hasGhost}) => hasGhost
    ? 'The shadow is your last rush.'
    : 'First rush! The next one races this one.';
