import 'dart:math' as math;

import '../../core/constants.dart';
import '../../data/models/moveset.dart';
import '../components/fighter.dart';
import '../input/fighter_controller.dart';
import '../match_setup.dart';

/// Simple utility-style AI: every [BotDifficulty.reaction] seconds it looks
/// at distance, the opponent's state and its own meter, then commits to a
/// short "plan" (walk, block, crouch, attack) until the next decision.
class BotController implements FighterController {
  BotController({required this.self, required this.difficulty, math.Random? rng})
      : _rng = rng ?? math.Random();

  final Fighter self;
  final BotDifficulty difficulty;
  final math.Random _rng;

  double _thinkTimer = 0.4;
  double _holdTimer = 0;
  double _moveX = 0;
  bool _down = false;
  bool _up = false;
  final List<FighterButton> _pending = [];

  Fighter get _opp => self.opponent;
  double get _dist => (_opp.position.x - self.position.x).abs();
  double get _toward => _opp.position.x > self.position.x ? 1 : -1;

  @override
  FighterIntent read(double dt) {
    _thinkTimer -= dt;
    _holdTimer -= dt;
    if (_holdTimer <= 0) {
      _moveX = 0;
      _down = false;
    }
    _up = false;

    // Reactive guard between decisions (harder bots react more often).
    final threatened = (_opp.isThreatening && _dist < 190) ||
        self.game.hasIncomingProjectile(self);
    if (threatened && self.canAct && _rng.nextDouble() < difficulty.blockChance * dt * 6) {
      _block();
    }

    if (_thinkTimer <= 0) {
      _decide();
      _thinkTimer = difficulty.reaction * (0.7 + _rng.nextDouble() * 0.6);
    }

    final out = FighterIntent(
      moveX: _moveX,
      up: _up,
      down: _down,
      pressed: List<FighterButton>.of(_pending),
    );
    _pending.clear();
    return out;
  }

  void _hold(double x, double seconds, {bool down = false}) {
    _moveX = x;
    _down = down;
    _holdTimer = seconds;
  }

  void _block() => _hold(-_toward, 0.45);

  void _press(FighterButton b) => _pending.add(b);

  void _decide() {
    if (!self.canAct) return;
    final r = _rng.nextDouble();
    final dist = _dist;

    if (_opp.isThreatening && dist < 200 && r < difficulty.blockChance) {
      _block();
      return;
    }

    if (self.meter >= GameConstants.meterComboCost &&
        dist < 160 &&
        _rng.nextDouble() < difficulty.comboUse) {
      _press(FighterButton.combo);
      return;
    }

    final special = self.moveset.special.special;

    // Far away: zone with projectiles or close the gap.
    if (dist > 260) {
      if (special == SpecialKind.projectile && r < 0.25 * difficulty.aggression + 0.05) {
        _press(FighterButton.special);
      } else {
        _hold(_toward, 0.4);
        if (r > 0.92) _up = true;
      }
      return;
    }

    // Close range: attack, back off or duck.
    if (dist < 140) {
      if (r < difficulty.aggression) {
        final pick = _rng.nextDouble();
        if (pick < 0.5) {
          _press(FighterButton.light);
        } else if (pick < 0.82) {
          _press(FighterButton.heavy);
        } else {
          _press(FighterButton.special);
        }
      } else if (r < difficulty.aggression + 0.15) {
        _hold(-_toward, 0.35);
      } else if (r < difficulty.aggression + 0.25) {
        _hold(0, 0.3, down: true);
      }
      return;
    }

    // Mid range: footsies.
    if (r < 0.65) {
      _hold(_toward, 0.3);
    } else if (r < 0.8 && special == SpecialKind.dash) {
      _press(FighterButton.special);
    } else if (r < 0.85 && _opp.state == FighterState.jump && special == SpecialKind.rising) {
      _press(FighterButton.special); // anti-air
    } else {
      _hold(-_toward, 0.2);
    }
  }
}
