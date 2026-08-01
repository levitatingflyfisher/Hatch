// Make Flutter's generated service worker work when the app is served from a
// sub-path (GitHub Pages project sites: /Hatch/).
//
// The generated worker resolves every cache key against `self.location.origin`
// while its RESOURCES map is keyed *relative to the worker's own directory*.
// At the origin root the two coincide and nobody notices. Under `--base-href
// "/Hatch/"` they diverge: a request for `/Hatch/main.dart.js` yields the key
// `Hatch/main.dart.js`, `RESOURCES[key]` is undefined, and the fetch handler
// returns early to "let the browser take over" — i.e. it goes to the network.
// Every request. Forever. The PWA installs, registers a worker, reports
// `controller` set, caches the five CORE files, and still cannot open with the
// network gone. See docs/adr/0008-service-worker-subpath.md.
//
// The fix is one line of arithmetic: base the keys on the worker's own
// directory instead of the origin. At the root the two are identical, so this
// is a strict generalisation, not a fork.
//
// Run after every `flutter build web`:
//   dart run tool/patch_service_worker.dart [path/to/flutter_service_worker.js]
//
// Idempotent, and loud: if Flutter's generator changes shape the anchors stop
// matching and this throws rather than silently leaving the app online-only.
import 'dart:io';

/// Marker for "already patched" — also the constant the patch introduces.
const scopeBaseIdentifier = 'SCOPE_BASE';

/// Prepended to the worker. `self.location.href` is the worker's own URL, so
/// trimming the last segment gives the directory its RESOURCES keys are
/// relative to — `https://host/Hatch` deployed, `https://host` at the root.
const _preamble =
    '''
// PATCHED (tool/patch_service_worker.dart): Flutter's generator keys the cache
// off self.location.origin, which is wrong whenever the app is served from a
// sub-path — see docs/adr/0008-service-worker-subpath.md. This is the worker's
// own directory, which is what the RESOURCES keys are actually relative to.
const $scopeBaseIdentifier = self.location.href.substring(
    0, self.location.href.lastIndexOf('/'));
''';

/// (anchor, replacement, exact number of occurrences required).
const _rewrites = <(String, String, int)>[
  (
    'var origin = self.location.origin;',
    'var origin = $scopeBaseIdentifier;',
    2,
  ),
  (
    'var key = request.url.substring(origin.length + 1);',
    'var key = request.url.substring($scopeBaseIdentifier.length + 1);',
    2,
  ),
];

/// Flutter's generator no longer emits the worker this patch knows how to fix.
///
/// Deliberately fatal. The failure it guards against is invisible — an
/// unpatched worker serves a perfectly healthy-looking PWA that simply never
/// works offline — so a shape change must stop a deploy, not warn during one.
class ServiceWorkerShapeChanged implements Exception {
  final String message;
  const ServiceWorkerShapeChanged(this.message);
  @override
  String toString() => message;
}

/// Returns [source] with origin-keyed lookups rebased on the worker's own
/// directory, or `null` if it is already patched.
///
/// Throws [ServiceWorkerShapeChanged] if any anchor is missing or repeated an
/// unexpected number of times.
String? patchServiceWorkerSource(String source) {
  if (source.contains(scopeBaseIdentifier)) return null;

  for (final (anchor, _, expected) in _rewrites) {
    final found = anchor.allMatches(source).length;
    if (found != expected) {
      throw ServiceWorkerShapeChanged(
        'Expected $expected occurrence(s) of:\n  $anchor\nbut found $found.\n\n'
        "Flutter's service-worker generator has changed shape. Read the new "
        'worker, confirm whether it still keys the cache off the origin, and '
        'update this tool (and docs/adr/0008) to match — do NOT skip the '
        'patch: the PWA silently loses offline support.',
      );
    }
  }

  var patched = source;
  for (final (anchor, replacement, _) in _rewrites) {
    patched = patched.replaceAll(anchor, replacement);
  }
  // Below the directive, never above it: `'use strict'` only applies when it
  // is the first statement in the script, and a const declaration in front of
  // it would silently drop the whole worker back into sloppy mode.
  const directive = "'use strict';\n";
  if (patched.startsWith(directive)) {
    return directive + _preamble + patched.substring(directive.length);
  }
  return _preamble + patched;
}

void main(List<String> args) {
  final path = args.isNotEmpty
      ? args.first
      : 'build/web/flutter_service_worker.js';
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('$path not found — run `flutter build web` first.');
    exit(1);
  }

  final String? patched;
  try {
    patched = patchServiceWorkerSource(file.readAsStringSync());
  } on ServiceWorkerShapeChanged catch (e) {
    stderr.writeln('$path: $e');
    exit(1);
  }

  if (patched == null) {
    stdout.writeln('$path already patched — nothing to do.');
    return;
  }
  file.writeAsStringSync(patched);
  stdout.writeln(
    "Patched $path — cache keys now resolve against the worker's own "
    'directory, so the PWA opens with the network gone.',
  );
}
