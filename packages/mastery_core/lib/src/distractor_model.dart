import 'fact.dart';

/// Interference-aware wrong answers (design: "classic confusion pairs get
/// targeted treatment"). For a*b the child's plausible errors are one row or
/// column off — (a+-1)*b, a*(b+-1) — and, for the notorious middle of the
/// table, the classic confusion products (54/56/63 and friends). Distractors
/// are drawn from that space so a lucky guess still exercises discrimination.
class DistractorModel {
  const DistractorModel();

  /// For each confusable product, the products children actually swap it
  /// with (7x8=56 vs 6x9=54 vs 7x9=63, 6x8=48 vs 6x7=42, 8x8 vs 9x8, ...).
  static const _classicConfusions = <int, List<int>>{
    36: [42, 32, 48],
    42: [48, 36, 54],
    48: [54, 56, 42],
    49: [42, 56, 48],
    54: [56, 63, 48],
    56: [54, 63, 48],
    63: [56, 54, 72],
    64: [63, 72, 56],
    72: [63, 64, 81],
    81: [72, 64, 63],
  };

  /// Two distinct wrong answers, deterministic per (fact, seed).
  List<int> distractorsFor(Fact fact, {required int seed}) {
    final product = fact.product;
    final candidates = <int>[];
    void add(int? value) {
      if (value != null &&
          value >= 0 &&
          value != product &&
          !candidates.contains(value)) {
        candidates.add(value);
      }
    }

    int? tableProduct(int x, int y) =>
        (x < 0 || x > 10 || y < 0 || y > 10) ? null : x * y;

    add(tableProduct(fact.a - 1, fact.b));
    add(tableProduct(fact.a + 1, fact.b));
    add(tableProduct(fact.a, fact.b - 1));
    add(tableProduct(fact.a, fact.b + 1));
    for (final classic in _classicConfusions[product] ?? const <int>[]) {
      add(classic);
    }
    // Degenerate x0/x1 corner facts can run out of distinct neighbor
    // products; only then extend with generic near-misses.
    if (candidates.length < 2) {
      for (final filler in [product + 1, product + 2, product + 10]) {
        add(filler);
        if (candidates.length >= 2) {
          break;
        }
      }
    }
    final first = seed.abs() % candidates.length;
    final second =
        (first + 1 + (seed.abs() ~/ 7) % (candidates.length - 1)) %
        candidates.length;
    return [candidates[first], candidates[second]];
  }
}
