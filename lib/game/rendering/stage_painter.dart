import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../core/constants.dart';
import '../../data/models/stage_data.dart';

/// Procedurally painted arenas (960x540 virtual canvas). Shared between the
/// Flame [StageBackground] component and Flutter stage-select previews.
abstract final class StagePainter {
  static const double w = GameConstants.worldWidth;
  static const double h = GameConstants.worldHeight;
  static const double ground = GameConstants.groundY;

  /// Deterministic pseudo-random in [0,1) so the skyline doesn't flicker.
  static double _hash(int i) {
    final v = math.sin(i * 12.9898 + 78.233) * 43758.5453;
    return v - v.floorToDouble();
  }

  static void paint(Canvas canvas, StageData stage, double t) {
    switch (stage.theme) {
      case StageTheme.neonRooftop:
        _neon(canvas, t);
      case StageTheme.sunsetTemple:
        _temple(canvas, t);
      case StageTheme.frozenPeak:
        _frozen(canvas, t);
      case StageTheme.harborDocks:
        _harbor(canvas, t);
    }
  }

  static void _sky(Canvas canvas, List<Color> colors, List<double> stops) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, w, h),
      Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(0, ground), colors, stops),
    );
  }

  static void _glow(Canvas canvas, Offset c, double r, Color color) {
    canvas.drawCircle(
      c,
      r,
      Paint()..shader = ui.Gradient.radial(c, r, [color, color.withValues(alpha: 0)]),
    );
  }

  // ---------------------------------------------------------------------------
  static void _neon(Canvas canvas, double t) {
    _sky(canvas, const [Color(0xFF070720), Color(0xFF2B0B4A), Color(0xFF6A1B5A)], const [0, 0.6, 1]);
    _glow(canvas, const Offset(790, 95), 110, const Color(0x55E1BEE7));
    canvas.drawCircle(const Offset(790, 95), 36, Paint()..color = const Color(0xFFF3E5F5));

    // Far skyline
    for (var i = 0; i < 26; i++) {
      final bw = 30 + _hash(i) * 26;
      final bh = 110 + _hash(i + 50) * 170;
      final x = i * 38.0 - 10;
      final rect = Rect.fromLTWH(x, 430 - bh, bw, bh);
      canvas.drawRect(rect, Paint()..color = const Color(0xFF150A2E));
      // Windows
      for (var wy = rect.top + 8; wy < rect.bottom - 8; wy += 14) {
        for (var wx = rect.left + 5; wx < rect.right - 6; wx += 9) {
          final seed = (wx * 7 + wy * 13).toInt();
          if (_hash(seed) > 0.68) {
            final on = _hash(seed + (t * 0.5).floor()) > 0.15;
            if (on) {
              canvas.drawRect(Rect.fromLTWH(wx, wy, 4, 6),
                  Paint()..color = (_hash(seed + 3) > 0.5 ? const Color(0xAAFFE082) : const Color(0xAA80DEEA)));
            }
          }
        }
      }
    }

    // Flickering neon sign
    final flicker = _hash((t * 6).floor()) > 0.08 ? 1.0 : 0.25;
    final sign = RRect.fromRectAndRadius(const Rect.fromLTWH(120, 120, 170, 64), const Radius.circular(10));
    canvas.drawRRect(sign, Paint()..color = const Color(0xFF12061F));
    canvas.drawRRect(
      sign,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0xFFFF2BD6).withValues(alpha: flicker)
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 6),
    );
    final tp = TextPainter(
      text: TextSpan(
        text: 'FURY',
        style: TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w900,
          letterSpacing: 6,
          color: const Color(0xFF3DE1FF).withValues(alpha: flicker),
          shadows: const [Shadow(color: Color(0xFF3DE1FF), blurRadius: 12)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(205 - tp.width / 2, 152 - tp.height / 2));

    // Parapet + floor
    canvas.drawRect(const Rect.fromLTWH(0, 430, w, 38), Paint()..color = const Color(0xFF1C1030));
    canvas.drawLine(const Offset(0, 430), const Offset(w, 430),
        Paint()
          ..color = const Color(0xFF3DE1FF)
          ..strokeWidth = 3
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4));
    canvas.drawRect(const Rect.fromLTWH(0, ground, w, h - ground), Paint()..color = const Color(0xFF1A0E2A));
    final grid = Paint()
      ..color = const Color(0x55FF2BD6)
      ..strokeWidth = 1.5;
    for (var i = -12; i <= 12; i++) {
      canvas.drawLine(Offset(w / 2 + i * 40, ground), Offset(w / 2 + i * 110, h), grid);
    }
    for (var j = 1; j < 5; j++) {
      final y = ground + (h - ground) * (j * j) / 16;
      canvas.drawLine(Offset(0, y), Offset(w, y), grid);
    }
  }

  // ---------------------------------------------------------------------------
  static void _temple(Canvas canvas, double t) {
    _sky(canvas, const [Color(0xFF2D1B4E), Color(0xFFFF6B3D), Color(0xFFFFC46B)], const [0, 0.65, 1]);
    _glow(canvas, const Offset(480, 330), 220, const Color(0x66FFE0B2));
    canvas.drawCircle(const Offset(480, 330), 90, Paint()..color = const Color(0xFFFFE9A8));

    // Distant pyramids
    final pyr = Paint()..color = const Color(0xFF5A2E4A);
    for (final p in const [(180.0, 170.0), (330.0, 120.0), (720.0, 190.0), (860.0, 110.0)]) {
      canvas.drawPath(
        Path()
          ..moveTo(p.$1 - p.$2, 420)
          ..lineTo(p.$1, 420 - p.$2 * 0.8)
          ..lineTo(p.$1 + p.$2, 420)
          ..close(),
        pyr,
      );
    }

    // Dunes
    canvas.drawPath(
      Path()
        ..moveTo(0, 430)
        ..quadraticBezierTo(240, 380, 480, 425)
        ..quadraticBezierTo(720, 465, w, 410)
        ..lineTo(w, ground)
        ..lineTo(0, ground)
        ..close(),
      Paint()..color = const Color(0xFFC77A3A),
    );

    // Pillars
    for (final x in const [40.0, 130.0, 790.0, 880.0]) {
      final body = Rect.fromLTWH(x, 220, 42, ground - 220);
      canvas.drawRect(body, Paint()..color = const Color(0xFFB5651D));
      canvas.drawRect(Rect.fromLTWH(x + 28, 220, 14, ground - 220), Paint()..color = const Color(0xFF8D4A14));
      canvas.drawRect(Rect.fromLTWH(x - 8, 206, 58, 16), Paint()..color = const Color(0xFFD08A3C));
      for (var y = 240.0; y < ground; y += 46) {
        canvas.drawLine(Offset(x, y), Offset(x + 42, y), Paint()..color = const Color(0x55000000));
      }
    }

    // Sand floor + tiles
    canvas.drawRect(const Rect.fromLTWH(0, ground, w, h - ground), Paint()..color = const Color(0xFFD9A25F));
    final tile = Paint()
      ..color = const Color(0x40000000)
      ..strokeWidth = 1.5;
    canvas.drawLine(const Offset(0, ground), const Offset(w, ground), tile..strokeWidth = 3);
    for (var x = 0.0; x <= w; x += 80) {
      canvas.drawLine(Offset(x, ground), Offset(x + (x - w / 2) * 0.35, h), tile..strokeWidth = 1.5);
    }

    // Drifting dust
    final dust = Paint()..color = const Color(0x66FFF3E0);
    for (var i = 0; i < 30; i++) {
      final x = (_hash(i) * w + t * (20 + _hash(i + 9) * 30)) % w;
      final y = 250 + _hash(i + 30) * 200 + math.sin(t + i) * 6;
      canvas.drawCircle(Offset(x, y), 1.5 + _hash(i + 4) * 1.5, dust);
    }
  }

  // ---------------------------------------------------------------------------
  static void _frozen(Canvas canvas, double t) {
    _sky(canvas, const [Color(0xFF5FA8E0), Color(0xFF9AD0F5), Color(0xFFE3F4FF)], const [0, 0.5, 1]);

    void mountain(double cx, double peak, double half, Color color) {
      canvas.drawPath(
        Path()
          ..moveTo(cx - half, 430)
          ..lineTo(cx, peak)
          ..lineTo(cx + half, 430)
          ..close(),
        Paint()..color = color,
      );
      final capH = (430 - peak) * 0.28;
      final capW = half * 0.28;
      canvas.drawPath(
        Path()
          ..moveTo(cx - capW, peak + capH)
          ..lineTo(cx, peak)
          ..lineTo(cx + capW, peak + capH)
          ..lineTo(cx + capW * 0.3, peak + capH * 0.8)
          ..lineTo(cx - capW * 0.2, peak + capH * 1.05)
          ..close(),
        Paint()..color = const Color(0xFFFFFFFF),
      );
    }

    mountain(160, 140, 260, const Color(0xFF7B9CC4));
    mountain(560, 90, 320, const Color(0xFF6C8DB8));
    mountain(860, 170, 230, const Color(0xFF7B9CC4));
    mountain(330, 230, 200, const Color(0xFF4F6F9A));
    mountain(720, 250, 220, const Color(0xFF4F6F9A));

    // Pines
    final pine = Paint()..color = const Color(0xFF1F3B4D);
    for (var i = 0; i < 18; i++) {
      final x = i * 56.0 + _hash(i) * 20;
      final s = 26 + _hash(i + 7) * 22;
      canvas.drawPath(
        Path()
          ..moveTo(x - s * 0.45, 440)
          ..lineTo(x, 440 - s * 1.6)
          ..lineTo(x + s * 0.45, 440)
          ..close(),
        pine,
      );
    }

    // Ice floor
    canvas.drawRect(const Rect.fromLTWH(0, 430, w, h - 430), Paint()..color = const Color(0xFFCFE8F7));
    canvas.drawRect(const Rect.fromLTWH(0, ground, w, h - ground), Paint()..color = const Color(0xFFB3D9F0));
    final streak = Paint()
      ..color = const Color(0x88FFFFFF)
      ..strokeWidth = 2;
    for (var i = 0; i < 14; i++) {
      final x = _hash(i + 70) * w;
      final y = ground + 8 + _hash(i + 80) * 60;
      canvas.drawLine(Offset(x, y), Offset(x + 40 + _hash(i) * 50, y), streak);
    }

    // Snowfall
    final flake = Paint()..color = const Color(0xDDFFFFFF);
    for (var i = 0; i < 70; i++) {
      final speed = 30 + _hash(i + 7) * 40;
      final x = (_hash(i) * w + math.sin(t * 0.8 + i) * 18) % w;
      final y = (_hash(i + 99) * h + t * speed) % h;
      canvas.drawCircle(Offset(x, y), 1.2 + _hash(i + 3) * 2, flake);
    }
  }

  // ---------------------------------------------------------------------------
  static void _harbor(Canvas canvas, double t) {
    _sky(canvas, const [Color(0xFF1B2A49), Color(0xFFE76F51), Color(0xFFF4A261)], const [0, 0.6, 0.9]);
    _glow(canvas, const Offset(250, 330), 160, const Color(0x66FFE0B2));
    canvas.drawCircle(const Offset(250, 330), 55, Paint()..color = const Color(0xFFFFD6A0));

    // Sea
    canvas.drawRect(const Rect.fromLTWH(0, 330, w, 110), Paint()..color = const Color(0xFF1D3557));
    final wave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0x66A8DADC);
    for (var row = 0; row < 5; row++) {
      final y = 345.0 + row * 20;
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= w; x += 12) {
        path.lineTo(x, y + math.sin(x / 40 + t * (1.2 + row * 0.3)) * 2.5);
      }
      canvas.drawPath(path, wave);
    }

    // Ship silhouette (bobbing)
    final bob = math.sin(t * 1.3) * 3;
    final ship = Paint()..color = const Color(0xFF0F1A2E);
    canvas.drawPath(
      Path()
        ..moveTo(560, 330 + bob)
        ..lineTo(830, 330 + bob)
        ..lineTo(800, 360 + bob)
        ..lineTo(590, 360 + bob)
        ..close(),
      ship,
    );
    canvas.drawRect(Rect.fromLTWH(640, 290 + bob, 110, 40), ship);
    canvas.drawRect(Rect.fromLTWH(700, 255 + bob, 18, 35), ship);

    // Crane
    final crane = Paint()
      ..color = const Color(0xFF14213D)
      ..strokeWidth = 6;
    canvas.drawLine(const Offset(90, 440), const Offset(90, 150), crane);
    canvas.drawLine(const Offset(60, 160), const Offset(330, 160), crane);
    canvas.drawLine(const Offset(300, 160), const Offset(300, 250), crane..strokeWidth = 2);

    // Dock planks
    canvas.drawRect(const Rect.fromLTWH(0, 430, w, h - 430), Paint()..color = const Color(0xFF6D4C41));
    canvas.drawRect(const Rect.fromLTWH(0, 430, w, 10), Paint()..color = const Color(0xFF4E342E));
    final plank = Paint()
      ..color = const Color(0x55000000)
      ..strokeWidth = 2;
    for (var y = ground; y < h; y += 18) {
      canvas.drawLine(Offset(0, y), Offset(w, y), plank);
    }
    for (var i = 0; i < 24; i++) {
      final y = ground + ((i % 4) * 18);
      final x = (i * 97.0) % w;
      canvas.drawLine(Offset(x, y), Offset(x, y + 18), plank);
    }

    // Lamp posts
    for (final x in const [40.0, 920.0]) {
      canvas.drawLine(Offset(x, ground), Offset(x, 300), Paint()
        ..color = const Color(0xFF212121)
        ..strokeWidth = 6);
      _glow(canvas, Offset(x, 296), 60 + math.sin(t * 3 + x) * 4, const Color(0x88FFD54F));
      canvas.drawCircle(Offset(x, 296), 9, Paint()..color = const Color(0xFFFFF59D));
    }
  }
}
