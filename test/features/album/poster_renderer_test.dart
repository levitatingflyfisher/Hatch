import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hatch/features/album/domain/poster_renderer.dart';
import 'package:mastery_core/mastery_core.dart';

/// A hand-built SamplerView: the renderer is pure over the view, so the
/// engine is not needed to test composition output.
SamplerView viewWith({
  Set<String> hatched = const {},
  Set<String> mirrorFilled = const {},
}) {
  const pack = MultiplicationPack();
  final cells = <Fact, SamplerCell>{};
  for (var a = 0; a <= 10; a++) {
    for (var b = a; b <= 10; b++) {
      final fact = Fact(a, b);
      final isHatched = hatched.contains(fact.id);
      cells[fact] = SamplerCell(
        fact: fact,
        family: pack.ownerOf(fact),
        started: isHatched,
        rung: isHatched ? Rung.bare : Rung.grid,
        phase: isHatched ? Phase.automatic : Phase.counting,
        dueNow: false,
        mirrorFilled: mirrorFilled.contains(fact.id),
        repaired: false,
      );
    }
  }
  return SamplerView(cells: cells);
}

void main() {
  const renderer = PosterRenderer();
  final date = DateTime(2026, 8, 7);

  test('renders a plausible 2048px PNG with the PNG signature', () async {
    final png = await renderer.renderPng(
      view: viewWith(hatched: {'2x2', '2x3', '2x5'}, mirrorFilled: {'2x3'}),
      childName: 'Hatcher 1',
      date: date,
    );
    // PNG magic bytes.
    expect(
      png.sublist(0, 8),
      equals(Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10])),
    );
    // 121 painted cells + title on a 2048px canvas: tens of KB at minimum,
    // and comfortably under any share-sheet ceiling.
    expect(png.length, greaterThan(20 * 1024));
    expect(png.length, lessThan(8 * 1024 * 1024));
  });

  test('hatched critters change the picture (not a constant poster)', () async {
    final empty = await renderer.renderPng(
      view: viewWith(),
      childName: 'Hatcher 1',
      date: date,
    );
    final some = await renderer.renderPng(
      view: viewWith(hatched: {'2x2', '2x3', '2x5', '5x5'}),
      childName: 'Hatcher 1',
      date: date,
    );
    expect(empty, isNot(equals(some)));
  });

  test('renders a one-page PDF wrapping the poster', () async {
    final pdf = await renderer.renderPdf(
      view: viewWith(hatched: {'2x2'}),
      childName: 'Hatcher 1',
      date: date,
    );
    expect(String.fromCharCodes(pdf.sublist(0, 5)), '%PDF-');
    expect(pdf.length, greaterThan(20 * 1024));
    // A well-formed PDF ends with %%EOF (allow trailing newline).
    final tail = String.fromCharCodes(pdf.sublist(pdf.length - 16));
    expect(tail, contains('%%EOF'));
  });
}
