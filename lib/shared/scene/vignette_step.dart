import 'dart:ui';

/// One step of a ghost-cursor vignette script. Coordinates are scene units
/// (the vignette engine is data, not bespoke code per family — spec law);
/// the painter maps to px through the screen's SceneViewport.
sealed class VignetteStep {
  const VignetteStep();

  Duration get duration;
}

/// Glide the cursor (unpressed) to [to].
class MoveTo extends VignetteStep {
  const MoveTo(this.to, {this.duration = const Duration(milliseconds: 500)});

  final Offset to;

  @override
  final Duration duration;
}

/// Tap at the current position: press dip + ripple.
class TapAt extends VignetteStep {
  const TapAt({this.duration = const Duration(milliseconds: 400)});

  @override
  final Duration duration;
}

/// Drag (pressed) from the current position to [to].
class DragTo extends VignetteStep {
  const DragTo(this.to, {this.duration = const Duration(milliseconds: 700)});

  final Offset to;

  @override
  final Duration duration;
}

/// Hold still.
class Pause extends VignetteStep {
  const Pause([this.duration = const Duration(milliseconds: 350)]);

  @override
  final Duration duration;
}
