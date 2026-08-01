import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mastery_core/mastery_core.dart';

import '../../../core/engine/engine_providers.dart';
import '../../../core/engine/engine_service.dart';
import '../../../shared/critters/critter_painter.dart';
import '../../../shared/critters/critter_spec.dart';
import '../../../shared/painters/egg_art.dart';
import '../../../shared/theme/app_colors.dart';
import '../data/habitat_store.dart';
import '../domain/habitat_layout.dart';
import 'habitat_background_painter.dart';

/// Habitats: the child's own arrangement space. Hatched critters live in a
/// roster tray; she stands them wherever she likes in a painted biome.
///
/// Zero pedagogy, zero scoring, nothing to complete, nothing due — this
/// screen never touches the engine's ledger and never asks a question. It is
/// a shelf for what she has earned (compositional-agency law), and the only
/// verbs are "put here" and "pick up".
///
/// Reachable only through the active profile's home, so the arrangement —
/// like the album — is structurally private to its owner.
class HabitatsScreen extends ConsumerStatefulWidget {
  const HabitatsScreen({super.key, required this.profileId});

  final int profileId;

  @override
  ConsumerState<HabitatsScreen> createState() => _HabitatsScreenState();
}

class _HabitatsScreenState extends ConsumerState<HabitatsScreen> {
  HabitatLayout? _layout;
  String? _selectedFactId;

  @override
  void initState() {
    super.initState();
    ref.read(habitatStoreProvider).load(widget.profileId).then((layout) {
      if (mounted) setState(() => _layout = layout);
    });
  }

  void _apply(HabitatLayout next) {
    setState(() {
      _layout = next;
      _selectedFactId = null;
    });
    // Persist per change; a kill mid-arrangement loses at most one move.
    unawaited(ref.read(habitatStoreProvider).save(widget.profileId, next));
  }

  void _onSlotTap(int slot, String? occupant) {
    final layout = _layout;
    if (layout == null) return;
    final selected = _selectedFactId;
    if (selected != null) {
      _apply(layout.place(slot, selected));
    } else if (occupant != null) {
      // Tap a standing critter to send it back to the tray — picking up is
      // as easy as putting down (forgiveness over prevention).
      _apply(layout.clearSlot(slot));
    }
  }

  @override
  Widget build(BuildContext context) {
    final serviceAsync = ref.watch(engineServiceProvider(widget.profileId));
    final layout = _layout;
    return Scaffold(
      appBar: AppBar(title: const Text('Habitats')),
      body: switch (serviceAsync) {
        AsyncData(:final value) when layout != null => _buildBody(
          context,
          value,
          layout,
        ),
        AsyncError() => const Center(
          child: Text(
            'The habitat is napping — '
            'close and reopen the app.',
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    EngineService service,
    HabitatLayout layout,
  ) {
    // Live view: a critter hatched mid-session walks straight into the tray.
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final view = service.samplerView();
        final hatchedIds = [
          for (final cell in view.cells.values)
            if (cell.phase == Phase.automatic) cell.fact.id,
        ]..sort();
        // A fact can slip back out of `automatic` (downward transitions
        // exist): its critter quietly steps out of the scene and returns
        // when it re-hatches. The stored slot is kept — nothing she made is
        // ever deleted for her.
        final placed = <int, String>{
          for (final entry in layout.slots.entries)
            if (hatchedIds.contains(entry.value)) entry.key: entry.value,
        };
        final roster = [
          for (final id in hatchedIds)
            if (!placed.containsValue(id)) id,
        ];
        return SafeArea(
          child: Column(
            children: [
              _BiomeRow(
                selected: layout.biome,
                onSelect: (biome) => _apply(layout.withBiome(biome)),
              ),
              Expanded(child: _buildScene(context, layout, placed)),
              if (hatchedIds.isEmpty)
                const _EmptyRoster()
              else
                _RosterTray(
                  roster: roster,
                  selectedFactId: _selectedFactId,
                  onTap: (id) => setState(
                    () => _selectedFactId = _selectedFactId == id ? null : id,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScene(
    BuildContext context,
    HabitatLayout layout,
    Map<int, String> placed,
  ) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scene = constraints.biggest;
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: HabitatBackgroundPainter(
                      biome: layout.biome,
                      dark: dark,
                    ),
                  ),
                ),
                for (var slot = 0; slot < kHabitatSlotCount; slot++)
                  _positionedSlot(scene, slot, placed[slot]),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _positionedSlot(Size scene, int slot, String? occupant) {
    // 72dp slots centered on their anchor: comfortably over the 48dp floor,
    // and big enough that "put it there" needs no precision.
    const dimension = 72.0;
    final anchor = kHabitatSlotAnchors[slot];
    return Positioned(
      left: anchor.dx * scene.width - dimension / 2,
      top: anchor.dy * scene.height - dimension / 2,
      width: dimension,
      height: dimension,
      child: DragTarget<String>(
        onAcceptWithDetails: (details) {
          final layout = _layout;
          if (layout != null) _apply(layout.place(slot, details.data));
        },
        builder: (context, candidates, _) => _HabitatSlot(
          slot: slot,
          occupant: occupant,
          inviting: _selectedFactId != null || candidates.isNotEmpty,
          onTap: () => _onSlotTap(slot, occupant),
        ),
      ),
    );
  }
}

class _HabitatSlot extends StatelessWidget {
  const _HabitatSlot({
    required this.slot,
    required this.occupant,
    required this.inviting,
    required this.onTap,
  });

  final int slot;
  final String? occupant;

  /// True while a critter is selected or hovering — empty spots glow gently
  /// so she can see where it may stand. Affordance, not instruction.
  final bool inviting;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final id = occupant;
    return GestureDetector(
      key: Key('habitat-slot-$slot'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: id != null
          ? CustomPaint(
              key: Key('slot-critter-$id'),
              painter: CritterPainter(CritterSpec.of(Fact.parse(id))),
            )
          : Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 44,
                height: 26,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  color: AppColors.ink.withValues(alpha: 0.07),
                  border: inviting
                      ? Border.all(color: AppColors.yolk, width: 2)
                      : null,
                ),
              ),
            ),
    );
  }
}

/// Three biome swatches, each a live miniature of its scenery. 64dp targets.
class _BiomeRow extends StatelessWidget {
  const _BiomeRow({required this.selected, required this.onSelect});

  final HabitatBiome selected;
  final ValueChanged<HabitatBiome> onSelect;

  static const _labels = {
    HabitatBiome.meadow: 'Meadow',
    HabitatBiome.pond: 'Pond',
    HabitatBiome.hill: 'Hill',
  };

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final biome in HabitatBiome.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Semantics(
                button: true,
                selected: biome == selected,
                label: _labels[biome],
                child: GestureDetector(
                  key: Key('biome-${biome.name}'),
                  onTap: () => onSelect(biome),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: biome == selected
                            ? AppColors.yolk
                            : AppColors.speckle,
                        width: biome == selected ? 3 : 1.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: CustomPaint(
                        painter: HabitatBackgroundPainter(
                          biome: biome,
                          dark: dark,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The scrollable tray of hatched-but-unplaced critters. Tap to pick one up,
/// or drag it (vertical affinity, so the tray still scrolls sideways).
class _RosterTray extends StatelessWidget {
  const _RosterTray({
    required this.roster,
    required this.selectedFactId,
    required this.onTap,
  });

  final List<String> roster;
  final String? selectedFactId;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: roster.length,
        itemBuilder: (context, index) {
          final id = roster[index];
          final critter = SizedBox.square(
            dimension: 80,
            child: CustomPaint(
              painter: CritterPainter(CritterSpec.of(Fact.parse(id))),
            ),
          );
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Draggable<String>(
              data: id,
              affinity: Axis.vertical,
              feedback: critter,
              childWhenDragging: Opacity(opacity: 0.35, child: critter),
              child: GestureDetector(
                key: Key('roster-$id'),
                onTap: () => onTap(id),
                child: Container(
                  width: 88,
                  height: 88,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: id == selectedFactId
                          ? AppColors.yolk
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: CustomPaint(
                    painter: CritterPainter(CritterSpec.of(Fact.parse(id))),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// No critters yet: one friendly egg and the way forward. An invitation,
/// never a nag — there is no "0 of 66" here or anywhere.
class _EmptyRoster extends StatelessWidget {
  const _EmptyRoster();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox.square(
            dimension: 56,
            child: CustomPaint(painter: _FriendlyEggPainter()),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              'Hatch your first critter in the Nursery.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendlyEggPainter extends CustomPainter {
  const _FriendlyEggPainter();

  @override
  void paint(Canvas canvas, Size size) {
    EggArt.paintEgg(
      canvas,
      Rect.fromCenter(
        center: size.center(Offset.zero),
        width: size.width * 0.62,
        height: size.height * 0.8,
      ),
      seed: 11,
      // A first crack already showing: the egg is nearly ready, come help.
      crack: 0.35,
    );
  }

  @override
  bool shouldRepaint(_FriendlyEggPainter oldDelegate) => false;
}
