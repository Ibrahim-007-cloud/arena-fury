enum FighterButton { light, heavy, special, combo }

/// What a fighter wants to do this frame. Produced by the touch/keyboard
/// controller for the human player and by [BotController] for the CPU, so
/// the Fighter component never knows (or cares) who is driving it.
class FighterIntent {
  const FighterIntent({
    this.moveX = 0,
    this.up = false,
    this.down = false,
    this.pressed = const [],
  });

  /// -1 = hold left, 0 = neutral, +1 = hold right (screen space).
  final double moveX;
  final bool up;
  final bool down;

  /// Buttons pressed THIS frame (edge-triggered).
  final List<FighterButton> pressed;

  static const none = FighterIntent();
}

abstract interface class FighterController {
  FighterIntent read(double dt);
}

/// Training-mode dummy.
class IdleController implements FighterController {
  const IdleController();
  @override
  FighterIntent read(double dt) => FighterIntent.none;
}
