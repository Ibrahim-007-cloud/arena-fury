import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../components/fighter.dart';
import '../fight_game.dart';

/// Health bar with a delayed red "damage trail", name, round markers and the
/// combo meter for one fighter.
class FighterHud extends PositionComponent with HasGameReference<FightGame> {
  FighterHud({required this.fighter, required this.leftSide})
      : super(
          position: Vector2(leftSide ? 24 : GameConstants.worldWidth - 24 - barWidth, 16),
          size: Vector2(barWidth, 90),
          priority: 50,
        );

  static const double barWidth = 360;
  static const double barHeight = 22;
  static const double meterWidth = 210;

  final Fighter fighter;
  final bool leftSide;

  double _trailHp = GameConstants.maxHp;
  double _lastHp = GameConstants.maxHp;
  double _trailDelay = 0;
  double _t = 0;

  late final TextPaint _name = TextPaint(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 15,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.5,
      shadows: [Shadow(blurRadius: 4)],
    ),
  );
  late final TextPaint _ready = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFFC233),
      fontSize: 11,
      fontWeight: FontWeight.w900,
      letterSpacing: 2,
    ),
  );

  @override
  void update(double dt) {
    _t += dt;
    if (fighter.hp < _lastHp) _trailDelay = 0.45;
    if (fighter.hp > _lastHp) _trailHp = fighter.hp; // new round refill
    _lastHp = fighter.hp;
    if (_trailDelay > 0) {
      _trailDelay -= dt;
    } else if (_trailHp > fighter.hp) {
      _trailHp = math.max(fighter.hp, _trailHp - 420 * dt);
    }
  }

  /// P1's bar shrinks toward the left edge, P2's toward the right edge.
  Rect _fill(double ratio, double width, double height, double y) {
    final w = width * clamp01(ratio);
    return leftSide
        ? Rect.fromLTWH(0, y, w, height)
        : Rect.fromLTWH(width - w, y, w, height);
  }

  @override
  void render(Canvas canvas) {
    const frame = Rect.fromLTWH(0, 0, barWidth, barHeight);
    final rrect = RRect.fromRectAndRadius(frame.inflate(3), const Radius.circular(4));
    canvas.drawRRect(rrect, Paint()..color = const Color(0xCC000000));

    final ratio = fighter.hp / GameConstants.maxHp;
    canvas.drawRect(_fill(_trailHp / GameConstants.maxHp, barWidth, barHeight, 0),
        Paint()..color = const Color(0xFFE53935));

    final low = ratio < 0.25;
    final blink = low && (math.sin(_t * 14) > 0);
    final hpRect = _fill(ratio, barWidth, barHeight, 0);
    canvas.drawRect(
      hpRect,
      Paint()
        ..shader = ui.Gradient.linear(
          hpRect.topLeft,
          hpRect.bottomLeft,
          blink
              ? const [Color(0xFFFFCDD2), Color(0xFFFF5252)]
              : const [Color(0xFFFFF176), Color(0xFFFFA000)],
        ),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white70,
    );

    // Name
    _name.render(
      canvas,
      fighter.config.name.toUpperCase(),
      Vector2(leftSide ? 2 : barWidth - 2, barHeight + 6),
      anchor: leftSide ? Anchor.topLeft : Anchor.topRight,
    );

    // Round win markers (near the timer)
    final wins = fighter.isPlayerOne ? game.p1Rounds : game.p2Rounds;
    for (var i = 0; i < GameConstants.roundsToWin; i++) {
      final cx = leftSide ? barWidth - 10 - i * 22.0 : 10 + i * 22.0;
      final c = Offset(cx, barHeight + 16);
      canvas.drawCircle(c, 7, Paint()..color = const Color(0xAA000000));
      canvas.drawCircle(
        c,
        6,
        Paint()
          ..color = i < wins ? const Color(0xFFFFC233) : const Color(0x33FFFFFF),
      );
    }

    // Combo meter
    const meterY = barHeight + 34;
    final meterX = leftSide ? 0.0 : barWidth - meterWidth;
    final meterFrame = Rect.fromLTWH(meterX, meterY, meterWidth, 10);
    canvas.drawRect(meterFrame.inflate(2), Paint()..color = const Color(0xCC000000));
    final m = fighter.meter / GameConstants.maxMeter;
    final mw = meterWidth * clamp01(m);
    final meterFill = leftSide
        ? Rect.fromLTWH(meterX, meterY, mw, 10)
        : Rect.fromLTWH(meterX + meterWidth - mw, meterY, mw, 10);
    final full = fighter.meterFull;
    final glow = 0.6 + math.sin(_t * 9) * 0.4;
    canvas.drawRect(
      meterFill,
      Paint()
        ..color = full
            ? Color.lerp(const Color(0xFFFFC233), Colors.white, glow * 0.5)!
            : const Color(0xFF3DE1FF),
    );
    // Half-meter tick (sequence combos cost 50)
    canvas.drawLine(
      Offset(meterX + meterWidth / 2, meterY),
      Offset(meterX + meterWidth / 2, meterY + 10),
      Paint()
        ..color = Colors.white54
        ..strokeWidth = 1.5,
    );
    if (full) {
      _ready.render(
        canvas,
        'COMBO READY',
        Vector2(leftSide ? meterWidth + 8 : barWidth - meterWidth - 8, meterY - 1),
        anchor: leftSide ? Anchor.topLeft : Anchor.topRight,
      );
    }
  }
}
