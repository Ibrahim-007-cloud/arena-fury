import 'package:flame/input.dart';

import 'fighter_controller.dart';

enum KeyDir { left, right, up, down }

/// Merges the on-screen joystick/buttons with a hardware keyboard (handy in
/// the emulator) into one [FighterIntent] per frame.
class PlayerInputController implements FighterController {
  JoystickComponent? joystick;
  final Set<KeyDir> keyboardDirs = {};
  final List<FighterButton> _pending = [];

  void press(FighterButton button) => _pending.add(button);

  void releaseAll() {
    keyboardDirs.clear();
    _pending.clear();
  }

  @override
  FighterIntent read(double dt) {
    var x = 0.0;
    var up = false;
    var down = false;

    final j = joystick;
    if (j != null) {
      final d = j.relativeDelta;
      if (d.length > 0.3) {
        if (d.x.abs() > 0.35) x = d.x.sign;
        up = d.y < -0.6;
        down = d.y > 0.55;
      }
    }

    if (keyboardDirs.contains(KeyDir.left)) x = -1;
    if (keyboardDirs.contains(KeyDir.right)) x = 1;
    if (keyboardDirs.contains(KeyDir.up)) up = true;
    if (keyboardDirs.contains(KeyDir.down)) down = true;

    final pressed = List<FighterButton>.of(_pending);
    _pending.clear();
    return FighterIntent(moveX: x, up: up, down: down, pressed: pressed);
  }
}
