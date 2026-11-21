import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';

/// Round on-screen action button. Fires on touch DOWN (not up) because
/// fighting games need instant response. Supports multi-touch alongside the
/// joystick.
class ArcadeButton extends PositionComponent with TapCallbacks {
  ArcadeButton({
    required this.label,
    required this.color,
    required this.onPressed,
    required Vector2 position,
    this.radius = 36,
    this.isReady,
  }) : super(
          position: position,
          size: Vector2.all(radius * 2),
          anchor: Anchor.center,
          priority: 80,
        );

  final String label;
  final Color color;
  final VoidCallback onPressed;
  final double radius;

  /// When provided, the button is dimmed unless this returns true and it
  /// pulses when ready (used for the COMBO button / full meter).
  final bool Function()? isReady;

  bool _down = false;
  double _t = 0;

  late final TextPaint _text = TextPaint(
    style: TextStyle(
      color: Colors.white,
      fontSize: radius * 0.42,
      fontWeight: FontWeight.w900,
      letterSpacing: 1,
    ),
  );

  @override
  bool containsLocalPoint(Vector2 point) {
    final dx = point.x - radius, dy = point.y - radius;
    return dx * dx + dy * dy <= radius * radius * 1.3; // slightly generous
  }

  @override
  void onTapDown(TapDownEvent event) {
    _down = true;
    onPressed();
  }

  @override
  void onTapUp(TapUpEvent event) => _down = false;

  @override
  void onTapCancel(TapCancelEvent event) => _down = false;

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    final ready = isReady?.call() ?? true;
    final c = Offset(radius, radius);
    final r = _down ? radius * 0.92 : radius;

    if (isReady != null && ready) {
      final pulse = 0.5 + math.sin(_t * 8) * 0.5;
      canvas.drawCircle(c, r + 6 + pulse * 4,
          Paint()..color = const Color(0xFFFFC233).withValues(alpha: 0.35 + pulse * 0.3));
    }
    canvas.drawCircle(
      c,
      r,
      Paint()..color = color.withValues(alpha: ready ? (_down ? 0.85 : 0.55) : 0.18),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white.withValues(alpha: ready ? 0.8 : 0.3),
    );
    _text.render(canvas, label, Vector2(radius, radius), anchor: Anchor.center);
  }
}
