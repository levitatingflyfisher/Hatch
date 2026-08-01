import 'package:flutter/material.dart';
import 'package:mastery_core/mastery_core.dart';

import '../../../shared/critters/critter_painter.dart';
import '../../../shared/critters/critter_spec.dart';
import '../../../shared/painters/egg_art.dart';
import '../../../shared/painters/tray_painter.dart';

/// Opens the detail sheet for one album cell, in the orientation the child
/// tapped ([row]×[col]; the mirror side shows the twin).
///
/// Refuse-list, structurally: no locks, no "X% done", no completion nags —
/// the art at its rung IS the whole progress display. Due = sleepy = a warm
/// invitation, never a debt.
Future<void> showFactDetailSheet(
  BuildContext context, {
  required int row,
  required int col,
  required SamplerCell? state,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => _FactDetailSheet(row: row, col: col, state: state),
  );
}

class _FactDetailSheet extends StatelessWidget {
  const _FactDetailSheet({
    required this.row,
    required this.col,
    required this.state,
  });

  final int row;
  final int col;
  final SamplerCell? state;

  Fact get fact => Fact.folded(row, col);
  bool get mirrorSide => row > col;
  bool get hatched => state != null && state!.phase == Phase.automatic;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      // Scrollable so the sheet survives short screens and large text
      // scales without clipping the twin row.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$row × $col', style: textTheme.displaySmall),
            const SizedBox(height: 16),
            SizedBox.square(dimension: 160, child: _bigArt(context)),
            const SizedBox(height: 16),
            Text(
              _copy(),
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (hatched && !fact.isSquare) ...[
              const SizedBox(height: 20),
              _TwinRow(fact: fact, state: state!, mirrorSide: mirrorSide),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _bigArt(BuildContext context) {
    final s = state;
    if (s == null || !s.started) {
      // An unstarted fact is an honest egg — a promise, never a lock.
      return const CustomPaint(painter: _EggCellPainter());
    }
    if (!hatched) {
      final spec = CritterSpec.of(fact);
      return CustomPaint(
        painter: TrayPainter(
          a: row,
          b: col,
          rung: s.rung,
          hue: spec.hue,
          seed: spec.seed,
        ),
      );
    }
    final spec = mirrorSide ? CritterSpec.of(fact).twin : CritterSpec.of(fact);
    return CustomPaint(painter: CritterPainter(spec, sleepy: s.dueNow));
  }

  String _copy() {
    final s = state;
    if (s == null || !s.started) {
      return 'Still an egg — its turn will come.';
    }
    if (!hatched) {
      return 'Growing in the Nursery.';
    }
    if (s.dueNow) {
      // The sleepy law: due review = the critter wants a visit. Warm, never
      // urgent, never a countdown.
      return "This one's sleepy — a visit to the Nursery will wake it up.";
    }
    return 'Hatched and wide awake!';
  }
}

/// The twin (b×a) beside its state: hatched twin once the mirrored ordering
/// is confirmed, a tinted egg while it still incubates (ADR-0005 semantics —
/// mastering a×b plants b×a; it never auto-hatches).
class _TwinRow extends StatelessWidget {
  const _TwinRow({
    required this.fact,
    required this.state,
    required this.mirrorSide,
  });

  final Fact fact;
  final SamplerCell state;
  final bool mirrorSide;

  @override
  Widget build(BuildContext context) {
    // The twin of whichever orientation is on screen.
    final twinLabel = mirrorSide
        ? '${fact.a} × ${fact.b}'
        : '${fact.b} × ${fact.a}';
    final twinSpec = mirrorSide
        ? CritterSpec.of(fact)
        : CritterSpec.of(fact).twin;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox.square(
          dimension: 56,
          child: state.mirrorFilled
              ? CustomPaint(painter: CritterPainter(twinSpec))
              : CustomPaint(painter: _EggCellPainter(tint: twinSpec.hue)),
        ),
        const SizedBox(width: 12),
        Text(
          state.mirrorFilled
              ? 'Its twin, $twinLabel, hatched too!'
              : 'Its twin, $twinLabel, is still in the egg.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}

/// A single egg centered in the cell; [tint] washes the twin's hue behind
/// the shell so the pair reads together.
class _EggCellPainter extends CustomPainter {
  const _EggCellPainter({this.tint});

  final Color? tint;

  @override
  void paint(Canvas canvas, Size size) {
    final egg = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.width * 0.5,
      height: size.height * 0.66,
    );
    if (tint != null) {
      canvas.drawOval(
        egg.inflate(size.shortestSide * 0.06),
        Paint()..color = tint!.withValues(alpha: 0.25),
      );
    }
    EggArt.paintEgg(canvas, egg, seed: 7);
  }

  @override
  bool shouldRepaint(_EggCellPainter oldDelegate) => oldDelegate.tint != tint;
}
