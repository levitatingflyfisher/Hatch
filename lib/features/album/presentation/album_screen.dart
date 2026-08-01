import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mastery_core/mastery_core.dart';

import '../../../core/engine/engine_providers.dart';
import '../../../core/engine/engine_service.dart';
import '../../../core/providers/core_providers.dart';
import '../../../shared/critters/critter_painter.dart';
import '../../../shared/critters/critter_spec.dart';
import '../../../shared/painters/album_painter.dart';
import '../../../shared/painters/egg_art.dart';
import '../../../shared/painters/tray_painter.dart';
import '../../../shared/theme/app_colors.dart';
import '../../profiles/domain/profile_rules.dart';
import 'fact_detail_sheet.dart';
import 'poster_share.dart';

/// The Critter Album: the whole times table as one full-bleed 11×11 grid,
/// fully visible from minute one. The picture IS the progress — no locks, no
/// teasing, no percentages, ever (refuse-list law).
///
/// Per-profile privacy is structural, not policed here: this screen only
/// exists behind the active profile's home route, and [profileId] is that
/// profile's — a sibling's album is unreachable without switching profiles
/// at the picker, so there is no cross-child view to guard.
class AlbumScreen extends ConsumerWidget {
  const AlbumScreen({super.key, required this.profileId});

  final int profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serviceAsync = ref.watch(engineServiceProvider(profileId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('The Album'),
        actions: [
          IconButton(
            tooltip: 'Share poster',
            iconSize: 28,
            onPressed: serviceAsync.hasValue
                ? () => _sharePoster(ref, serviceAsync.requireValue)
                : null,
            icon: const Icon(Icons.ios_share_outlined),
          ),
        ],
      ),
      body: switch (serviceAsync) {
        AsyncData(:final value) => _AlbumBody(service: value),
        AsyncError() => const Center(
          child: Text(
            'The album fell asleep — '
            'close and reopen the app.',
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _sharePoster(WidgetRef ref, EngineService service) async {
    final profiles = ref.read(profilesProvider).valueOrNull ?? const [];
    final index = profiles.indexWhere((p) => p.id == profileId);
    final name = index >= 0 ? profileDisplayName(profiles[index], index) : '';
    await shareAlbumPoster(view: service.samplerView(), childName: name);
  }
}

class _AlbumBody extends StatelessWidget {
  const _AlbumBody({required this.service});

  final EngineService service;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // EngineService is a ChangeNotifier that fires on every record(): the
    // album repaints live while a Nursery/Rush session runs behind it.
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final view = service.samplerView();
        return SafeArea(
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) => _onGridTap(
                      context,
                      details.localPosition,
                      constraints.biggest,
                      view,
                    ),
                    child: CustomPaint(
                      key: const Key('album-grid'),
                      painter: AlbumPainter(view: view, dark: dark),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
              const _AlbumLegend(),
            ],
          ),
        );
      },
    );
  }

  /// Reverse of AlbumPainter's layout (a uniform 11×11 grid centered in the
  /// canvas): floor-divide the tap into a cell. Every point inside the grid
  /// resolves to SOME cell — zero dead space between cells, which is the
  /// forgiving hit behavior small fingers need on ~32dp cells.
  void _onGridTap(
    BuildContext context,
    Offset position,
    Size size,
    SamplerView view,
  ) {
    final cell = math.min(size.width, size.height) / 11;
    final origin = Offset(
      (size.width - cell * 11) / 2,
      (size.height - cell * 11) / 2,
    );
    final col = ((position.dx - origin.dx) / cell).floor();
    final row = ((position.dy - origin.dy) / cell).floor();
    if (row < 0 || row > 10 || col < 0 || col > 10) return;
    showFactDetailSheet(
      context,
      row: row,
      col: col,
      state: view[Fact.folded(row, col)],
    );
  }
}

/// One quiet row naming the four states a cell can be in. Informational
/// only — reading it is optional, the grid teaches itself.
class _AlbumLegend extends StatelessWidget {
  const _AlbumLegend();

  @override
  Widget build(BuildContext context) {
    final sample = CritterSpec.of(const Fact(2, 3));
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 4,
        children: [
          _LegendItem(
            label: 'egg',
            child: CustomPaint(painter: _LegendEggPainter()),
          ),
          _LegendItem(
            label: 'growing',
            child: CustomPaint(
              painter: TrayPainter(
                a: 2,
                b: 3,
                rung: Rung.grid,
                hue: sample.hue,
                seed: sample.seed,
              ),
            ),
          ),
          _LegendItem(
            label: 'hatched',
            child: CustomPaint(painter: CritterPainter(sample)),
          ),
          _LegendItem(
            label: 'sleepy — wants a visit',
            child: CustomPaint(painter: CritterPainter(sample, sleepy: true)),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(dimension: 28, child: child),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _LegendEggPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    EggArt.paintEgg(
      canvas,
      Rect.fromCenter(
        center: size.center(Offset.zero),
        width: size.width * 0.55,
        height: size.height * 0.72,
      ),
      seed: 3,
      speckle: AppColors.speckle,
    );
  }

  @override
  bool shouldRepaint(_LegendEggPainter oldDelegate) => false;
}
