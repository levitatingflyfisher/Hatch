import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Marks prompt-shown and first-keypress times. Latency = prompt to FIRST
/// key (engine law 3): the think happens before the first tap, so later
/// keys never move the mark. Never rendered — no countdowns anywhere.
class AnswerStopwatch {
  DateTime? _shownAt;
  int? _firstKeyLatencyMs;

  void promptShown() {
    _shownAt = clock.now();
    _firstKeyLatencyMs = null;
  }

  void keyPressed() {
    final shown = _shownAt;
    if (shown == null || _firstKeyLatencyMs != null) return;
    _firstKeyLatencyMs = clock.now().difference(shown).inMilliseconds;
  }

  int? get firstKeyLatencyMs => _firstKeyLatencyMs;
}

/// Production answer surface: 0-9 grid + backspace + submit. No OS keyboard,
/// ever. Targets are >=64dp for small fingers; submit stays inert (not
/// disabled-looking, just quiet) while empty so a stray tap can't submit
/// nothing.
class HatchNumPad extends StatefulWidget {
  const HatchNumPad({
    super.key,
    required this.onFirstKey,
    required this.onSubmit,
    this.enabled = true,
  });

  final VoidCallback onFirstKey;
  final ValueChanged<int> onSubmit;
  final bool enabled;

  @override
  State<HatchNumPad> createState() => _HatchNumPadState();
}

class _HatchNumPadState extends State<HatchNumPad> {
  var _entry = '';
  var _keyedOnce = false;

  void _key(void Function() apply) {
    if (!widget.enabled) return;
    if (!_keyedOnce) {
      _keyedOnce = true;
      widget.onFirstKey();
    }
    setState(apply);
  }

  void _digit(int d) => _key(() {
    if (_entry.length < 3) _entry += '$d';
  });

  void _backspace() => _key(() {
    if (_entry.isNotEmpty) _entry = _entry.substring(0, _entry.length - 1);
  });

  void _submit() {
    if (_entry.isEmpty || !widget.enabled) return;
    final value = int.parse(_entry);
    setState(() {
      _entry = '';
      _keyedOnce = false;
    });
    widget.onSubmit(value);
  }

  Widget _pad(Widget child, {VoidCallback? onTap, Color? color}) => Padding(
    padding: const EdgeInsets.all(3),
    child: Material(
      color: color ?? Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 64, minHeight: 64),
          child: Center(child: child),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineSmall;
    Widget digit(int d) => Expanded(
      child: _pad(Text('$d', style: style), onTap: () => _digit(d)),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            _entry.isEmpty ? ' ' : _entry,
            style: Theme.of(context).textTheme.headlineMedium,
            semanticsLabel: _entry.isEmpty ? 'no answer yet' : 'answer $_entry',
          ),
        ),
        Row(children: [for (var d = 1; d <= 5; d++) digit(d)]),
        Row(children: [for (var d = 6; d <= 9; d++) digit(d), digit(0)]),
        Row(
          children: [
            Expanded(
              child: _pad(
                const Icon(Icons.backspace_outlined),
                onTap: _backspace,
              ),
            ),
            Expanded(
              flex: 2,
              child: _pad(
                const Icon(Icons.check_rounded, size: 32),
                color: AppColors.yolk,
                onTap: _submit,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Recognition answer surface for early rungs: three large numerals. The
/// engine supplies interference-aware distractors; recognition never earns
/// automaticity credit, so no latency subtleties matter here beyond the
/// first-key mark.
class ChoiceButtons extends StatelessWidget {
  const ChoiceButtons({
    super.key,
    required this.options,
    required this.onFirstKey,
    required this.onChoose,
  });

  final List<int> options;
  final VoidCallback onFirstKey;
  final ValueChanged<int> onChoose;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineSmall;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final option in options)
          Padding(
            padding: const EdgeInsets.all(4),
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  onFirstKey();
                  onChoose(option);
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 88,
                    minHeight: 72,
                  ),
                  child: Center(child: Text('$option', style: style)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
