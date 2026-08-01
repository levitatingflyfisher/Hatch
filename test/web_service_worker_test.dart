import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/patch_service_worker.dart';

/// The offline guard for the PWA.
///
/// Hatch is a local-first app whose web build is served from a GitHub Pages
/// sub-path (`/Hatch/`). Flutter's generated service worker keys its cache off
/// `self.location.origin`, so under a sub-path every lookup misses and the
/// worker hands every request to the network — the PWA installs, reports a
/// controller, caches its five CORE files, and still cannot open in a dead
/// zone. `tool/patch_service_worker.dart` fixes that; this is what stops a
/// deploy from skipping it. See docs/adr/0008-service-worker-subpath.md.
void main() {
  group('the sub-path patch', () {
    // The shape Flutter 3.38 emits, trimmed to the parts the patch touches.
    const generated = '''
'use strict';
const RESOURCES = {"main.dart.js": "abc", "/": "def"};
self.addEventListener("activate", function(event) {
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
      }
});
self.addEventListener("fetch", (event) => {
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  if (!RESOURCES[key]) { return; }
});
async function downloadOffline() {
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
  }
}
''';

    test('rebases every origin-keyed lookup on the worker directory', () {
      final patched = patchServiceWorkerSource(generated)!;
      expect(patched, contains('const SCOPE_BASE = self.location.href'));
      // Only the explanatory preamble may still say the words: no *code* may
      // key a lookup off the origin.
      expect(patched, isNot(contains('var origin = self.location.origin;')));
      // downloadOffline's lookup read a bare `origin` global that no rewrite
      // of the two `var origin =` lines would have reached.
      expect(
        'request.url.substring(SCOPE_BASE.length + 1)'.allMatches(patched),
        hasLength(2),
      );
    });

    test("leaves 'use strict' as the first statement", () {
      // A const declaration in front of the directive would demote the whole
      // worker to sloppy mode — a real behaviour change smuggled in by a
      // cosmetic choice about where to paste.
      expect(patchServiceWorkerSource(generated)!, startsWith("'use strict';"));
    });

    test('is idempotent — a second run changes nothing', () {
      final once = patchServiceWorkerSource(generated)!;
      expect(patchServiceWorkerSource(once), isNull);
    });

    test('refuses to no-op when the generator changes shape', () {
      // A Flutter upgrade that renames or drops an anchor must stop the
      // deploy: an unpatched worker fails silently and only in a dead zone.
      expect(
        () => patchServiceWorkerSource(
          generated.replaceAll('var origin = self.location.origin;', ''),
        ),
        throwsA(isA<ServiceWorkerShapeChanged>()),
      );
    });
  });

  test('the built worker on disk is patched', () {
    // Artifact-conditional, like the C3 size ratchet: a plain `flutter test`
    // with no web build present must pass. This bites exactly where it
    // matters — a machine that just built the thing it is about to publish.
    final worker = File('build/web/flutter_service_worker.js');
    if (!worker.existsSync()) return;
    expect(
      worker.readAsStringSync(),
      contains('const SCOPE_BASE = self.location.href'),
      reason:
          'build/web/flutter_service_worker.js is unpatched — run '
          '`dart run tool/patch_service_worker.dart` after `flutter build '
          'web`, or the deployed PWA cannot open offline',
    );
  });
}
