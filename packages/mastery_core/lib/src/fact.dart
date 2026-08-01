/// Canonical folded multiplication fact: 0 <= a <= b <= 10. 66 facts total.
///
/// Folding halves the fact space (commutativity); retrieval is still tracked
/// per [AskDirection] by the engine so both orderings earn their own evidence.
class Fact {
  const Fact(this.a, this.b)
    : assert(0 <= a && a <= b && b <= 10, 'must be folded: 0 <= a <= b <= 10');

  /// Normalizes (x, y) into folded order; throws [RangeError] out of 0..10.
  factory Fact.folded(int x, int y) {
    RangeError.checkValueInInterval(x, 0, 10, 'x');
    RangeError.checkValueInInterval(y, 0, 10, 'y');
    return x <= y ? Fact(x, y) : Fact(y, x);
  }

  /// Parses the canonical [id] form 'axb'.
  factory Fact.parse(String id) {
    final parts = id.split('x');
    if (parts.length != 2) {
      throw FormatException('not a fact id: $id');
    }
    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    if (a == null || b == null) {
      throw FormatException('not a fact id: $id');
    }
    RangeError.checkValueInInterval(a, 0, 10, 'a');
    RangeError.checkValueInInterval(b, 0, 10, 'b');
    if (a > b) {
      throw RangeError('unfolded fact id: $id');
    }
    return Fact(a, b);
  }

  final int a;
  final int b;

  int get product => a * b;

  /// Canonical id, e.g. '3x8'.
  String get id => '${a}x$b';

  bool get isSquare => a == b;

  @override
  bool operator ==(Object other) =>
      other is Fact && other.a == a && other.b == b;

  @override
  int get hashCode => a * 11 + b;

  @override
  String toString() => id;
}

/// Which ordering the child was shown; the engine folds state but tracks
/// retrieval per direction (mirror confirmation, law 4).
enum AskDirection { forward, reversed }

/// Baroody's three phases: counting/modeling, deriving via strategies,
/// automatic retrieval.
enum Phase { counting, derived, automatic }

/// CPA weaning ladder rungs 1..4: full open grid, bundled row-strips,
/// labeled solid patch, bare symbolic tag.
enum Rung { grid, bundled, labeled, bare }

enum Family { x0, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, squares }

enum StrategyRoute {
  skipCount,
  foldDouble,
  addAGroup,
  trimAGroup,
  fiveAnchorSplit,
  nearSquare,
}
