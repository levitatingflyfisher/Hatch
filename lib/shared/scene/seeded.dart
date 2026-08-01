/// Deterministic seeded randomness for painters and choreography.
///
/// All game-layer randomness must flow through these helpers: goldens pin
/// pixel output, so nothing may consult dart:math Random at paint time. The
/// mixing stays in exact 32-bit integer math (split multiplies) so results
/// are identical on the VM and on the web compiler.
library;

import 'dart:ui';

/// Low 32 bits of a * b without exceeding the web-safe integer range.
int mul32(int a, int b) {
  a &= 0xffffffff;
  b &= 0xffffffff;
  final aLo = a & 0xffff;
  final aHi = a >>> 16;
  final lo = aLo * b & 0xffffffff;
  final mid = (aHi * (b & 0xffff) & 0xffff) << 16;
  return (lo + mid) & 0xffffffff;
}

int _mix(int x) {
  x &= 0xffffffff;
  x ^= x >>> 16;
  x = mul32(x, 0x45d9f3b);
  x ^= x >>> 16;
  x = mul32(x, 0x45d9f3b);
  x ^= x >>> 16;
  return x;
}

/// Canonical seed for a fact (a, b); order-sensitive by design — callers fold
/// first when twins must share a seed.
int seedFor(int a, int b) => _mix(a * 0x1000 + b + 1);

/// Derives an independent stream value from [seed] at [index].
int seededInt(int seed, int index) => _mix(seed ^ mul32(index + 1, 0x9e3779b9));

/// Uniform double in [0, 1).
double seededUnit(int seed, int index) => seededInt(seed, index) / 0x100000000;

/// Uniform double in [min, max).
double seededRange(int seed, int index, double min, double max) =>
    min + seededUnit(seed, index) * (max - min);

/// Picks an index in [0, length).
int seededPick(int seed, int index, int length) =>
    seededInt(seed, index) % length;

/// Jitter offset with each component in [-magnitude, magnitude].
Offset seededOffset(int seed, int index, double magnitude) => Offset(
  seededRange(seed, index * 2, -magnitude, magnitude),
  seededRange(seed, index * 2 + 1, -magnitude, magnitude),
);
