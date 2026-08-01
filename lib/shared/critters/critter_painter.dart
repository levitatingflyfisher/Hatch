import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../scene/seeded.dart';
import '../theme/app_colors.dart';
import 'critter_spec.dart';

/// Paints one critter from its [CritterSpec]. Flat geometric parts only
/// (circles / rounded rects / triangles) with ink dot eyes + white glints;
/// must read at 28px (album cell) and 96px (hatch moment), light and dark.
///
/// Pure painter: everything derives from the spec + [sleepy]; all jitter is
/// seeded. Layout happens in a 100×100 design space uniformly scaled into
/// the given size; eye/glint radii carry px floors so faces survive 28px.
class CritterPainter extends CustomPainter {
  const CritterPainter(this.spec, {this.sleepy = false});

  final CritterSpec spec;

  /// Due-review look: droopy lids + a zzz bubble (Album sleepy law).
  final bool sleepy;

  static const _design = 100.0;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height) / _design;
    canvas.save();
    canvas.translate(
      (size.width - _design * s) / 2,
      (size.height - _design * s) / 2,
    );
    canvas.scale(s);
    if (spec.mirrored) {
      canvas.translate(_design, 0);
      canvas.scale(-1, 1);
    }
    _CritterArt(spec, sleepy: sleepy, scale: s).paint(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(CritterPainter oldDelegate) =>
      oldDelegate.spec != spec || oldDelegate.sleepy != sleepy;
}

class _CritterArt {
  _CritterArt(this.spec, {required this.sleepy, required this.scale});

  final CritterSpec spec;
  final bool sleepy;
  final double scale;

  Color get hue => spec.hue;
  Color get _dark => Color.lerp(hue, AppColors.ink, 0.30)!;
  Color get _light => Color.lerp(hue, Colors.white, 0.42)!;
  int get seed => spec.seed;

  /// Design-space value with a px floor (keeps faces readable at 28px).
  double _atLeastPx(double units, double minPx) =>
      math.max(units, minPx / scale);

  void paint(Canvas canvas) {
    final anchors = switch (spec.species) {
      CritterSpecies.bubbleGhost => _bubbleGhost(canvas),
      CritterSpecies.pebble => _pebble(canvas),
      CritterSpecies.bouncyBlob => _bouncyBlob(canvas),
      CritterSpecies.sproutAntenna => _sproutAntenna(canvas),
      CritterSpecies.winged => _winged(canvas),
      CritterSpecies.starBellied => _starBellied(canvas),
      CritterSpecies.fuzzyOval => _fuzzyOval(canvas),
      CritterSpecies.zigzag => _zigzag(canvas),
      CritterSpecies.doubleDecker => _doubleDecker(canvas),
      CritterSpecies.spiky => _spiky(canvas),
      CritterSpecies.tallStacker => _tallStacker(canvas),
    };
    _accessory(canvas, anchors);
    _face(canvas, anchors);
    if (spec.crowned) _crown(canvas, anchors);
    if (sleepy) _zzz(canvas, anchors);
  }

  // ---- species bodies (each returns its face/crown/belly anchors) ---------

  _Anchors _bubbleGhost(Canvas canvas) {
    // Lightened before the alpha so the ghost stays airy over dark ground.
    final paint = Paint()
      ..color = Color.lerp(hue, Colors.white, 0.18)!.withValues(alpha: 0.9);
    final path = Path()
      ..moveTo(24, 46)
      ..arcTo(
        Rect.fromCircle(center: const Offset(50, 46), radius: 26),
        math.pi,
        math.pi,
        false,
      )
      ..lineTo(76, 68);
    // Three skirt scallops.
    for (var i = 0; i < 3; i++) {
      final x = 76 - i * (52 / 3);
      path.arcTo(Rect.fromLTRB(x - 52 / 3, 60, x, 78), 0, math.pi, false);
    }
    path.close();
    canvas.drawPath(path, paint);
    return const _Anchors(
      face: Offset(50, 46),
      headTop: Offset(50, 20),
      belly: Rect.fromLTRB(34, 52, 66, 66),
    );
  }

  _Anchors _pebble(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(20, 52, 80, 88),
        const Radius.circular(22),
      ),
      Paint()..color = hue,
    );
    return const _Anchors(
      face: Offset(50, 68),
      headTop: Offset(50, 52),
      belly: Rect.fromLTRB(30, 68, 70, 84),
    );
  }

  _Anchors _bouncyBlob(Canvas canvas) {
    canvas.drawCircle(const Offset(36, 88), 5, Paint()..color = _dark);
    canvas.drawCircle(const Offset(64, 88), 5, Paint()..color = _dark);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(16, 36, 84, 86),
        const Radius.circular(28),
      ),
      Paint()..color = hue,
    );
    return const _Anchors(
      face: Offset(50, 56),
      headTop: Offset(50, 36),
      belly: Rect.fromLTRB(28, 62, 72, 82),
    );
  }

  _Anchors _sproutAntenna(Canvas canvas) {
    final stem = Paint()
      ..color = _dark
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(50, 34), const Offset(50, 20), stem);
    // Two sprout leaves.
    _triangle(
      canvas,
      const Offset(50, 21),
      const Offset(36, 10),
      const Offset(47, 8),
      Paint()..color = AppColors.leaf,
    );
    _triangle(
      canvas,
      const Offset(50, 21),
      const Offset(64, 10),
      const Offset(53, 8),
      Paint()..color = AppColors.leaf,
    );
    canvas.drawCircle(const Offset(50, 60), 27, Paint()..color = hue);
    return const _Anchors(
      face: Offset(50, 54),
      headTop: Offset(50, 33),
      belly: Rect.fromLTRB(32, 64, 68, 84),
    );
  }

  _Anchors _winged(Canvas canvas) {
    final wing = Paint()..color = Color.lerp(hue, Colors.white, 0.30)!;
    _triangle(
      canvas,
      const Offset(32, 50),
      const Offset(6, 34),
      const Offset(26, 68),
      wing,
    );
    _triangle(
      canvas,
      const Offset(68, 50),
      const Offset(94, 34),
      const Offset(74, 68),
      wing,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 58), width: 46, height: 54),
      Paint()..color = hue,
    );
    return const _Anchors(
      face: Offset(50, 50),
      headTop: Offset(50, 31),
      belly: Rect.fromLTRB(36, 64, 64, 82),
    );
  }

  _Anchors _starBellied(Canvas canvas) {
    canvas.drawCircle(const Offset(50, 58), 28, Paint()..color = hue);
    canvas.drawPath(
      _starPath(const Offset(50, 69), 11.5, 5.2),
      Paint()..color = AppColors.shell,
    );
    return const _Anchors(
      face: Offset(50, 43),
      headTop: Offset(50, 30),
      // Star owns the belly; accessories move up beside the face.
      belly: Rect.fromLTRB(34, 37, 66, 49),
      bellyBusy: true,
    );
  }

  _Anchors _fuzzyOval(Canvas canvas) {
    final fuzz = Paint()..color = _light;
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi * 2 / 12 + 0.26;
      canvas.drawCircle(
        Offset(50 + math.cos(angle) * 27, 60 + math.sin(angle) * 23),
        4.6 + seededRange(seed, 40 + i, -0.8, 0.8),
        fuzz,
      );
    }
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 60), width: 54, height: 46),
      Paint()..color = hue,
    );
    return const _Anchors(
      face: Offset(50, 55),
      headTop: Offset(50, 32),
      belly: Rect.fromLTRB(32, 62, 68, 80),
    );
  }

  _Anchors _zigzag(Canvas canvas) {
    const teeth = 4;
    const left = 24.0, right = 76.0, hem = 72.0, drop = 86.0;
    final path = Path()
      ..moveTo(left, 52)
      ..arcTo(const Rect.fromLTRB(left, 34, right, 70), math.pi, math.pi, false)
      ..lineTo(right, hem);
    const step = (right - left) / teeth;
    for (var i = 0; i < teeth; i++) {
      path.lineTo(right - step * (i + 0.5), drop);
      path.lineTo(right - step * (i + 1), hem);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = hue);
    return const _Anchors(
      face: Offset(50, 52),
      headTop: Offset(50, 34),
      belly: Rect.fromLTRB(34, 58, 66, 72),
    );
  }

  _Anchors _doubleDecker(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(20, 60, 80, 88),
        const Radius.circular(13),
      ),
      Paint()..color = _dark,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(26, 32, 74, 62),
        const Radius.circular(14),
      ),
      Paint()..color = hue,
    );
    return const _Anchors(
      face: Offset(50, 46),
      headTop: Offset(50, 32),
      belly: Rect.fromLTRB(30, 66, 70, 84),
    );
  }

  _Anchors _spiky(Canvas canvas) {
    final spike = Paint()..color = _dark;
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi * 2 / 8 + math.pi / 8;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final base = const Offset(50, 58) + dir * 20;
      final tip = const Offset(50, 58) + dir * 34;
      final side = Offset(-dir.dy, dir.dx) * 6;
      _triangle(canvas, base + side, base - side, tip, spike);
    }
    canvas.drawCircle(const Offset(50, 58), 24, Paint()..color = hue);
    return const _Anchors(
      face: Offset(50, 53),
      headTop: Offset(50, 24),
      belly: Rect.fromLTRB(36, 60, 64, 76),
    );
  }

  _Anchors _tallStacker(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(30, 16, 70, 88),
        const Radius.circular(17),
      ),
      Paint()..color = hue,
    );
    final seam = Paint()
      ..color = _dark
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(34, 46), const Offset(66, 46), seam);
    canvas.drawLine(const Offset(34, 66), const Offset(66, 66), seam);
    // Accessory zone sits below both seams: a mark straddling a seam line
    // can read as a division glyph — wrong app.
    return const _Anchors(
      face: Offset(50, 32),
      headTop: Offset(50, 16),
      belly: Rect.fromLTRB(36, 70, 64, 84),
    );
  }

  // ---- shared parts -------------------------------------------------------

  void _face(Canvas canvas, _Anchors a) {
    final gap = 10.5 + seededRange(seed, 1, 0, 3);
    final eyeR = _atLeastPx(5.2 + seededRange(seed, 2, -0.6, 0.8), 1.7);
    final gaze = Offset(seededRange(seed, 3, -1.8, 1.8), 0);
    final leftEye = a.face + Offset(-gap, 0) + gaze;
    final rightEye = a.face + Offset(gap, 0) + gaze;
    final ink = Paint()..color = AppColors.ink;

    if (sleepy) {
      // Droopy lids: eyes as closed arcs, lid line low.
      final lid = Paint()
        ..color = AppColors.ink
        ..strokeWidth = _atLeastPx(2.2, 1.1)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      for (final eye in [leftEye, rightEye]) {
        canvas.drawArc(
          Rect.fromCircle(center: eye, radius: eyeR),
          math.pi * 0.15,
          math.pi * 0.7,
          false,
          lid,
        );
      }
      // Small yawn.
      canvas.drawOval(
        Rect.fromCenter(
          center: a.face + const Offset(0, 10),
          width: 5.5,
          height: 7,
        ),
        ink,
      );
      return;
    }

    final glintR = _atLeastPx(1.7, 0.7);
    for (final eye in [leftEye, rightEye]) {
      canvas.drawCircle(eye, eyeR, ink);
      canvas.drawCircle(
        eye + Offset(-eyeR * 0.32, -eyeR * 0.32),
        glintR,
        Paint()..color = Colors.white,
      );
    }
    // Smile.
    canvas.drawArc(
      Rect.fromCenter(
        center: a.face + const Offset(0, 8),
        width: 13,
        height: 9,
      ),
      math.pi * 0.15,
      math.pi * 0.7,
      false,
      Paint()
        ..color = AppColors.ink
        ..strokeWidth = _atLeastPx(2.2, 1.0)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  void _accessory(Canvas canvas, _Anchors a) {
    switch (spec.accessory) {
      case CritterAccessory.spots:
        final paint = Paint()..color = _dark;
        for (var i = 0; i < 3; i++) {
          final dx = seededRange(seed, 10 + i * 2, 0.15, 0.92);
          final dy = seededRange(seed, 11 + i * 2, 0.15, 0.9);
          canvas.drawCircle(
            Offset(
              a.belly.left + a.belly.width * dx,
              a.belly.top + a.belly.height * dy,
            ),
            2.6 + seededRange(seed, 16 + i, 0, 1.6),
            paint,
          );
        }
      case CritterAccessory.stripes:
        final paint = Paint()
          ..color = _dark
          ..strokeWidth = 4.2
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        // Three short hem stripes along the lower belly (a knit sweater
        // band, not scratch marks).
        final len = math.min(a.belly.height * 0.5, 9.0);
        final y1 = a.belly.bottom - 1;
        for (var i = 0; i < 3; i++) {
          final x = a.belly.left + a.belly.width * (0.28 + 0.22 * i);
          canvas.drawLine(Offset(x, y1 - len), Offset(x + 1.5, y1), paint);
        }
      case CritterAccessory.brows:
        final paint = Paint()
          ..color = AppColors.ink
          ..strokeWidth = _atLeastPx(2.4, 1.1)
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        final gap = 10.5 + seededRange(seed, 1, 0, 3);
        final browY = a.face.dy - 9.5;
        canvas.drawLine(
          Offset(a.face.dx - gap - 4, browY),
          Offset(a.face.dx - gap + 4, browY - 1),
          paint,
        );
        // The raised brow — the twins' shared joke, mirrored.
        canvas.drawLine(
          Offset(a.face.dx + gap - 4, browY - 1.5),
          Offset(a.face.dx + gap + 4, browY - 4.5),
          paint,
        );
      case CritterAccessory.blush:
        final paint = Paint()..color = const Color(0x70FFB3C0);
        final gap = 10.5 + seededRange(seed, 1, 0, 3) + 6.5;
        canvas.drawCircle(a.face + Offset(-gap, 5.5), 4.2, paint);
        canvas.drawCircle(a.face + Offset(gap, 5.5), 4.2, paint);
    }
  }

  void _crown(Canvas canvas, _Anchors a) {
    final base = a.headTop + const Offset(0, -1.5);
    const w = 21.0, h = 11.0;
    final path = Path()
      ..moveTo(base.dx - w / 2, base.dy)
      ..lineTo(base.dx - w / 2, base.dy - h * 0.62)
      ..lineTo(base.dx - w / 4, base.dy - h * 0.28)
      ..lineTo(base.dx, base.dy - h)
      ..lineTo(base.dx + w / 4, base.dy - h * 0.28)
      ..lineTo(base.dx + w / 2, base.dy - h * 0.62)
      ..lineTo(base.dx + w / 2, base.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = AppColors.yolk);
    canvas.drawCircle(
      base + const Offset(0, -h - 1.5),
      _atLeastPx(1.9, 0.9),
      Paint()..color = AppColors.yolk,
    );
  }

  void _zzz(Canvas canvas, _Anchors a) {
    final anchor = a.headTop + const Offset(15, 2);
    canvas.drawCircle(
      anchor,
      _atLeastPx(2.1, 1.0),
      Paint()..color = AppColors.speckle,
    );
    final paint = Paint()
      ..color = AppColors.ink
      ..strokeWidth = _atLeastPx(1.8, 0.9)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 2; i++) {
      final zSize = 5.0 + i * 2.5;
      final o = anchor + Offset(4.0 + i * 5.5, -6.0 - i * 7.5);
      canvas.drawPath(
        Path()
          ..moveTo(o.dx, o.dy)
          ..lineTo(o.dx + zSize, o.dy)
          ..lineTo(o.dx, o.dy + zSize * 0.8)
          ..lineTo(o.dx + zSize, o.dy + zSize * 0.8),
        paint,
      );
    }
  }

  static void _triangle(
    Canvas canvas,
    Offset p1,
    Offset p2,
    Offset p3,
    Paint paint,
  ) {
    canvas.drawPath(
      Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..close(),
      paint,
    );
  }

  static Path _starPath(Offset center, double outer, double inner) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outer : inner;
      final angle = -math.pi / 2 + i * math.pi / 5;
      final p = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    return path;
  }
}

/// Where the face, crown, and accessory zone sit for a species body.
class _Anchors {
  const _Anchors({
    required this.face,
    required this.headTop,
    required this.belly,
    this.bellyBusy = false,
  });

  final Offset face;
  final Offset headTop;
  final Rect belly;

  /// True when the belly already carries a species mark (star) — kept for
  /// future accessory placement rules.
  final bool bellyBusy;
}
