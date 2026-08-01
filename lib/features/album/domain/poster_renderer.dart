import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mastery_core/mastery_core.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../shared/critters/critter_painter.dart';
import '../../../shared/critters/critter_spec.dart';
import '../../../shared/painters/egg_art.dart';
import '../../../shared/theme/app_colors.dart';

/// Renders the show-grandma poster: the full 11×11 critter grid, hatched
/// critters in color, everything else as pale eggs, titled and dated.
///
/// Pure — takes a [SamplerView], returns bytes; no I/O, no share sheet, no
/// providers, so tests can assert on the artifact directly. The poster shows
/// exactly what the Album shows (mastery states only): no percentages, no
/// counts, no latency — the picture IS the progress (refuse-list +
/// ADR-0004).
class PosterRenderer {
  const PosterRenderer();

  /// Poster edge in px — big enough to print, small enough to share.
  static const int posterSizePx = 2048;

  /// The poster PNG at [posterSizePx] square.
  Future<Uint8List> renderPng({
    required SamplerView view,
    required String childName,
    required DateTime date,
  }) async {
    const size = posterSizePx * 1.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));
    _paintPoster(canvas, view: view, childName: childName, date: date);
    final picture = recorder.endRecording();
    final image = await picture.toImage(posterSizePx, posterSizePx);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return bytes!.buffer.asUint8List();
    } finally {
      image.dispose();
      picture.dispose();
    }
  }

  /// One-page PDF wrapping the same poster image (pure-Dart `pdf` package;
  /// file-based sharing happens elsewhere — zero network by construction).
  Future<Uint8List> renderPdf({
    required SamplerView view,
    required String childName,
    required DateTime date,
  }) async {
    final png = await renderPng(view: view, childName: childName, date: date);
    final doc = pw.Document(title: 'Hatch');
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Center(
          child: pw.Image(pw.MemoryImage(png), fit: pw.BoxFit.contain),
        ),
      ),
    );
    return doc.save();
  }

  // ---- composition ---------------------------------------------------------

  void _paintPoster(
    Canvas canvas, {
    required SamplerView view,
    required String childName,
    required DateTime date,
  }) {
    const size = posterSizePx * 1.0;
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, size, size),
      Paint()..color = AppColors.cream,
    );
    // A thin yolk frame keeps the print feeling finished, not screenshot-y.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(48, 48, size - 96, size - 96),
        const Radius.circular(40),
      ),
      Paint()
        ..color = AppColors.yolk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10,
    );

    _text(
      canvas,
      'Hatch',
      center: const Offset(size / 2, 190),
      fontFamily: 'Lora',
      fontSize: 150,
      weight: FontWeight.w700,
      color: AppColors.ink,
    );
    if (childName.isNotEmpty) {
      _text(
        canvas,
        childName,
        center: const Offset(size / 2, 320),
        fontFamily: 'Nunito',
        fontSize: 68,
        weight: FontWeight.w600,
        color: AppColors.ink,
      );
    }
    _text(
      canvas,
      DateFormat.yMMMMd().format(date),
      center: const Offset(size / 2, size - 110),
      fontFamily: 'Nunito',
      fontSize: 46,
      weight: FontWeight.w500,
      color: AppColors.ink.withValues(alpha: 0.55),
    );

    // The grid: same folded 11×11 arrangement as the Album, so the poster is
    // the album a grandparent can hold.
    const gridTop = 420.0;
    const gridBottom = size - 190.0;
    const cell = (gridBottom - gridTop) / 11;
    const originX = (size - cell * 11) / 2;
    for (var row = 0; row <= 10; row++) {
      for (var col = 0; col <= 10; col++) {
        final rect = Rect.fromLTWH(
          originX + col * cell,
          gridTop + row * cell,
          cell,
          cell,
        ).deflate(cell * 0.06);
        _paintCell(canvas, rect, view, row, col);
      }
    }
  }

  void _paintCell(
    Canvas canvas,
    Rect rect,
    SamplerView view,
    int row,
    int col,
  ) {
    final fact = Fact.folded(row, col);
    final state = view[fact];
    final mirrorSide = row > col;
    final hatched = state != null && state.phase == Phase.automatic;
    // Hatched critters in color; everything not yet hatched — including a
    // hatched fact's unconfirmed twin — is a pale egg. Never a lock, never a
    // silhouette: an egg is a promise, not a tease.
    if (!hatched || (mirrorSide && !state.mirrorFilled)) {
      _paleEgg(canvas, rect, fact);
      return;
    }
    final spec = mirrorSide ? CritterSpec.of(fact).twin : CritterSpec.of(fact);
    canvas.save();
    canvas.translate(rect.left, rect.top);
    // Awake on the poster always — a print celebrates, it never nags about
    // due reviews (that is the Album's warm job, in the app, in the moment).
    CritterPainter(spec).paint(canvas, rect.size);
    canvas.restore();
  }

  void _paleEgg(Canvas canvas, Rect rect, Fact fact) {
    final egg = Rect.fromCenter(
      center: rect.center,
      width: rect.width * 0.46,
      height: rect.height * 0.62,
    );
    EggArt.paintEgg(
      canvas,
      egg,
      seed: fact.a * 11 + fact.b,
      shell: AppColors.shell.withValues(alpha: 0.85),
      speckle: AppColors.speckle.withValues(alpha: 0.5),
    );
  }

  void _text(
    Canvas canvas,
    String text, {
    required Offset center,
    required String fontFamily,
    required double fontSize,
    required FontWeight weight,
    required Color color,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: fontFamily,
          fontWeight: weight,
          fontSize: fontSize,
          color: color,
        ),
      ),
      // Qualified: package:intl also exports a TextDirection.
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: posterSizePx - 200.0);
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }
}
