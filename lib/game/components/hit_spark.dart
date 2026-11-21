import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/animation.dart';

/// Short-lived impact burst drawn where a hit lands.
class HitSpark extends PositionComponent {
  HitSpark({
    required Vector2 position,
    required this.color,
    this.big = false,
    this.blocked = false,
  }) : super(position: position, anchor: Anchor.center, priority: 20);

  final Color color;
  final bool big;
  final bool blocked;
  double _t = 0;
  static const double life = 0.28;
  late final double _spin = math.Random().nextDouble() * math.pi;

  @override
  void update(double dt) {
    _t += dt;
    if (_t >= life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final p = (_t / life).clamp(0.0, 1.0).toDouble();
    final e = Curves.easeOutCubic.transform(p);
    final maxR = big ? 58.0 : 34.0;
    final alpha = 1 - p;

    if (blocked) {
      canvas.drawCircle(
        Offset.zero,
        maxR * 0.6 * e + 6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5 * (1 - p) + 1
          ..color = color.withValues(alpha: alpha),
      );
      return;
    }

    canvas.drawCircle(Offset.zero, maxR * 0.45 * (1 - p * 0.5),
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: alpha * 0.9));
    final rays = big ? 10 : 7;
    final ray = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = big ? 5 : 3.5
      ..color = color.withValues(alpha: alpha);
    for (var i = 0; i < rays; i++) {
      final a = _spin + i * math.pi * 2 / rays;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(d * (maxR * 0.3 * e), d * (maxR * e), ray);
    }
  }
}
