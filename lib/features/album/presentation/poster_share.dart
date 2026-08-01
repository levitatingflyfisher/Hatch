import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:mastery_core/mastery_core.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/poster_renderer.dart';

/// The thin share action over [PosterRenderer]: render PNG + PDF, hand both
/// to the system share sheet. File-based and offline — the OS decides where
/// the poster goes; the app has no network to send it anywhere itself
/// (ADR-0006).
///
/// Never called from tests (the share sheet is a platform surface); tests
/// cover [PosterRenderer] directly.
Future<void> shareAlbumPoster({
  required SamplerView view,
  required String childName,
}) async {
  final now = clock.now();
  const renderer = PosterRenderer();
  final png = await renderer.renderPng(
    view: view,
    childName: childName,
    date: now,
  );
  final pdf = await renderer.renderPdf(
    view: view,
    childName: childName,
    date: now,
  );

  final stamp = DateFormat('yyyy-MM-dd').format(now);
  final List<XFile> files;
  if (kIsWeb) {
    // No filesystem on web: share_plus takes the bytes directly (falls back
    // to a download where the browser has no share target).
    files = [
      XFile.fromData(
        png,
        mimeType: 'image/png',
        name: 'hatch-album-$stamp.png',
      ),
      XFile.fromData(
        pdf,
        mimeType: 'application/pdf',
        name: 'hatch-album-$stamp.pdf',
      ),
    ];
  } else {
    final dir = await getTemporaryDirectory();
    final pngFile = File(p.join(dir.path, 'hatch-album-$stamp.png'));
    await pngFile.writeAsBytes(png, flush: true);
    final pdfFile = File(p.join(dir.path, 'hatch-album-$stamp.pdf'));
    await pdfFile.writeAsBytes(pdf, flush: true);
    files = [
      XFile(pngFile.path, mimeType: 'image/png'),
      XFile(pdfFile.path, mimeType: 'application/pdf'),
    ];
  }
  await Share.shareXFiles(files, subject: 'Hatch album poster');
}
