import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../components/fighter.dart';
import '../fight_game.dart';

/// Round timer in the top-centre.
class RoundTimerDisplay extends PositionComponent with HasGameReference<FightGame> {
  RoundTimerDisplay()
      : super(position: Vector2(GameConstants.worldWidth / 2, 30), anchor: Anchor.center, priority: 50);

  final _normal = TextPaint(
    style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900),
  );
  final _danger = TextPaint(
    style: const TextStyle(color: Color(0xFFFF5252), fontSize: 34, fontWeight: FontWeight.w900),
  );

  @override
  void render(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 64, height: 48),
          const Radius.circular(6)),
      Paint()..color = const Color(0xCC000000),
    );
    final text = game.isTraining ? '∞' : game.roundClock.ceil().toString();
    final paint = (!game.isTraining && game.roundClock <= 10) ? _danger : _normal;
    paint.render(canvas, text, Vector2.zero(), anchor: Anchor.center);
  }
}

/// Big centre-screen callouts: ROUND 1, FIGHT!, K.O.!, YOU WIN...
class Announcer extends PositionComponent {
  Announcer()
      : super(
          position: Vector2(GameConstants.worldWidth / 2, GameConstants.worldHeight * 0.4),
          anchor: Anchor.center,
          priority: 100,
        );

  String? _text;
  double _t = 0;
  double _duration = 1;
  TextPaint? _paint;

  void show(String text, {double duration = 1.2, Color color = Colors.white}) {
    _text = text;
    _t = 0;
    _duration = duration;
    _paint = TextPaint(
      style: TextStyle(
        color: color,
        fontSize: 76,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
        letterSpacing: 4,
        shadows: const [
          Shadow(color: Colors.black, blurRadius: 0, offset: Offset(4, 4)),
          Shadow(color: Color(0xFFFF3D3D), blurRadius: 24),
        ],
      ),
    );
  }

  @override
  void update(double dt) {
    if (_text == null) return;
    _t += dt;
    if (_t >= _duration) _text = null;
  }

  @override
  void render(Canvas canvas) {
    final text = _text;
    final paint = _paint;
    if (text == null || paint == null) return;
    final pop = clamp01(_t / 0.18);
    final scale = 1 + 0.6 * (1 - Curves.easeOutBack.transform(pop));
    final fadeStart = _duration - 0.25;
    final alpha = _t > fadeStart ? clamp01(1 - (_t - fadeStart) / 0.25) : 1.0;
    canvas.save();
    canvas.scale(scale);
    canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    paint.render(canvas, text, Vector2.zero(), anchor: Anchor.center);
    canvas.restore();
    canvas.restore();
  }
}

/// "5 HITS" counter that pops up on the attacker's side.
class ComboCounterDisplay extends PositionComponent {
  ComboCounterDisplay({required this.fighter, required this.leftSide})
      : super(
          position: Vector2(leftSide ? 30 : GameConstants.worldWidth - 30, 160),
          anchor: leftSide ? Anchor.topLeft : Anchor.topRight,
          priority: 60,
        );

  final Fighter fighter;
  final bool leftSide;

  final _big = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFFC233),
      fontSize: 44,
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.italic,
      shadows: [Shadow(color: Colors.black, offset: Offset(3, 3))],
    ),
  );
  final _small = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.w900,
      letterSpacing: 3,
      shadows: [Shadow(color: Colors.black, offset: Offset(2, 2))],
    ),
  );

  @override
  void render(Canvas canvas) {
    if (fighter.comboDisplayTimer <= 0 || fighter.comboDisplayCount < 2) return;
    final wobble = math.sin(fighter.comboDisplayTimer * 30) * 2;
    final anchor = leftSide ? Anchor.topLeft : Anchor.topRight;
    _big.render(canvas, '${fighter.comboDisplayCount}', Vector2(0, wobble), anchor: anchor);
    _small.render(canvas, 'HITS!', Vector2(0, 50), anchor: anchor);
  }
}
