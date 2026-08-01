import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Hatch was rethemed from an earlier quilt skin (see docs/superpowers/
/// RESKIN_SPEC.md). Comments may reference the old register to explain a
/// mapping ("the retheme of the running stitch"); STRINGS may not — a quilt
/// word in a string literal is one tap from a child's screen. This guard
/// exists because one leaked ("Stitch snaps and skip-count chimes" survived
/// in Settings until a screenshot pass caught it).
void main() {
  test('no quilt-register words in any lib string literal', () {
    final banned = RegExp(
      r'\b(quilt\w*|stitch\w*|patchwork)\b',
      caseSensitive: false,
    );
    final quoted = RegExp("'([^']*)'|\"([^\"]*)\"");
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        // Strip comment tails so mapping notes stay legal.
        final line = lines[i].split('//').first;
        for (final m in quoted.allMatches(line)) {
          final s = m.group(1) ?? m.group(2) ?? '';
          if (banned.hasMatch(s)) {
            offenders.add('${file.path}:${i + 1}: $s');
          }
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'quilt-register words leaked into string literals:\n'
          '${offenders.join('\n')}',
    );
  });

  /// "Ghost" is what the code calls the stored pace curve. A child has no
  /// referent for it, so "race your ghost" told a first-time player nothing
  /// about what Hatch Rush is — the second marker on the track is a shadow,
  /// and the copy now says so. Widget keys are not shown to anyone.
  test('no engine jargon in any child-facing string', () {
    final banned = RegExp(r'\bghosts?\b', caseSensitive: false);
    final quoted = RegExp("'([^']*)'|\"([^\"]*)\"");
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].split('//').first;
        if (line.contains('Key(')) continue;
        for (final m in quoted.allMatches(line)) {
          final s = m.group(1) ?? m.group(2) ?? '';
          if (banned.hasMatch(s)) {
            offenders.add('${file.path}:${i + 1}: $s');
          }
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'engine jargon leaked into a string a child can read:\n'
          '${offenders.join('\n')}',
    );
  });
}
