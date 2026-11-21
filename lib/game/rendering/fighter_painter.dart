import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../data/models/fighter_config.dart';
import 'pose.dart';

/// Colours for each body part, derived from costume + config colours.
class _Palette {
  _Palette({
    required this.torso,
    required this.trim,
    required this.sleeve,
    required this.forearm,
    required this.glove,
    required this.pants,
    required this.shin,
    required this.shoe,
    required this.skin,
    required this.hair,
    required this.belt,
    required this.outline,
  });

  final Color torso, trim, sleeve, forearm, glove, pants, shin, shoe, skin, hair, belt, outline;

  static Color _lighten(Color c, double t) => Color.lerp(c, const Color(0xFFFFFFFF), t)!;
  static Color _darken(Color c, double t) => Color.lerp(c, const Color(0xFF000000), t)!;

  factory _Palette.resolve(FighterConfig c, Color Function(Color) fx) {
    final p = c.primaryColor, s = c.secondaryColor, k = c.skinColor;
    late Color torso, trim, sleeve, forearm, glove, pants, shin, shoe, belt;
    switch (c.costume) {
      case Costume.gi:
        torso = p;
        trim = _lighten(p, 0.35);
        sleeve = p;
        forearm = k;
        glove = s;
        pants = p;
        shin = p;
        shoe = k;
        belt = s;
      case Costume.street:
        torso = p;
        trim = s;
        sleeve = p;
        forearm = p;
        glove = k;
        pants = const Color(0xFF2E3B55);
        shin = const Color(0xFF2E3B55);
        shoe = const Color(0xFFEEEEEE);
        belt = const Color(0xFF3E2723);
      case Costume.armor:
        torso = s;
        trim = p;
        sleeve = k;
        forearm = p;
        glove = _darken(p, 0.3);
        pants = s;
        shin = p;
        shoe = _darken(p, 0.35);
        belt = p;
      case Costume.ninja:
        torso = p;
        trim = s;
        sleeve = p;
        forearm = p;
        glove = _darken(p, 0.4);
        pants = p;
        shin = s;
        shoe = _darken(p, 0.4);
        belt = s;
    }
    return _Palette(
      torso: fx(torso),
      trim: fx(trim),
      sleeve: fx(sleeve),
      forearm: fx(forearm),
      glove: fx(glove),
      pants: fx(pants),
      shin: fx(shin),
      shoe: fx(shoe),
      skin: fx(k),
      hair: fx(c.hairColor),
      belt: fx(belt),
      outline: const Color(0xFF111118),
    );
  }

  _Palette shaded() => _Palette(
        torso: _darken(torso, 0.22),
        trim: _darken(trim, 0.22),
        sleeve: _darken(sleeve, 0.22),
        forearm: _darken(forearm, 0.22),
        glove: _darken(glove, 0.22),
        pants: _darken(pants, 0.22),
        shin: _darken(shin, 0.22),
        shoe: _darken(shoe, 0.22),
        skin: _darken(skin, 0.22),
        hair: hair,
        belt: belt,
        outline: outline,
      );
}

/// Draws a fighter from simple shapes, driven by a [Pose].
///
/// The canvas origin must be at the fighter's FEET, facing RIGHT (+x).
/// Callers mirror the canvas for left-facing fighters. Because this only
/// uses dart:ui, the same painter renders inside Flame components and inside
/// regular Flutter [CustomPainter]s (roster cards, studio preview).
abstract final class FighterPainter {
  static const double thighLen = 44;
  static const double shinLen = 42;
  static const double torsoLen = 58;
  static const double upperArmLen = 31;
  static const double foreArmLen = 30;
  static const double headRadius = 18;
  static const double neckLen = 5;

  static void paint(
    Canvas canvas, {
    required FighterConfig config,
    required Pose pose,
    ui.Image? face,
    double flash = 0,
    Color? aura,
  }) {
    final w = config.bodyType.widthScale;
    final hs = config.bodyType.heightScale;
    final tl = thighLen * hs, sl = shinLen * hs, tor = torsoLen * hs;
    final ua = upperArmLen * hs, fa = foreArmLen * hs;
    const hr = headRadius;

    Color fx(Color c) =>
        flash > 0 ? Color.lerp(c, const Color(0xFFFFFFFF), flash * 0.75)! : c;
    final pal = _Palette.resolve(config, fx);
    final back = pal.shaded();

    double legExtent(double thigh, double shin) =>
        tl * math.cos(thigh) + sl * math.cos(shin);

    // Auto-grounding: the lower of the two feet touches y = 0.
    final hipHeight = math.max(
          12.0,
          math.max(legExtent(pose.frontThigh, pose.frontShin),
              legExtent(pose.backThigh, pose.backShin)),
        ) +
        pose.lift;

    final hip = Offset(0, -hipHeight);
    final up = Offset(math.sin(pose.lean), -math.cos(pose.lean));
    final side = Offset(math.cos(pose.lean), math.sin(pose.lean));
    final shoulder = hip + up * tor;
    final neck = shoulder + up * neckLen;
    final headC = neck + up * (hr * 1.05);

    Offset dir(double a) => Offset(math.sin(a), math.cos(a));

    final frontHip = hip + side * (5 * w);
    final backHip = hip - side * (5 * w);
    final frontShoulder = shoulder + side * (5 * w);
    final backShoulder = shoulder - side * (7 * w);

    final bKnee = backHip + dir(pose.backThigh) * tl;
    final bFoot = bKnee + dir(pose.backShin) * sl;
    final fKnee = frontHip + dir(pose.frontThigh) * tl;
    final fFoot = fKnee + dir(pose.frontShin) * sl;
    final bElbow = backShoulder + dir(pose.backUpper) * ua;
    final bHand = bElbow + dir(pose.backFore) * fa;
    final fElbow = frontShoulder + dir(pose.frontUpper) * ua;
    final fHand = fElbow + dir(pose.frontFore) * fa;

    if (aura != null) {
      final center = Offset.lerp(hip, shoulder, 0.4)!;
      canvas.drawCircle(
        center,
        95,
        Paint()
          ..shader = ui.Gradient.radial(center, 95, [
            aura.withValues(alpha: 0.45),
            aura.withValues(alpha: 0.0),
          ]),
      );
    }

    // Back limbs first (darker), then torso, front leg, head, front arm.
    _arm(canvas, backShoulder, bElbow, bHand, back, w);
    _leg(canvas, backHip, bKnee, bFoot, pose.backShin, back, w);
    _torso(canvas, hip, shoulder, side, up, pal, w, config.costume);
    _leg(canvas, frontHip, fKnee, fFoot, pose.frontShin, pal, w);
    _limb(canvas, shoulder, neck, pal.skin, 10 * w, pal.outline);
    _head(canvas, headC, hr, pal, config, face, flash, pose.lean);
    _arm(canvas, frontShoulder, fElbow, fHand, pal, w);
  }

  static void _limb(Canvas canvas, Offset a, Offset b, Color color, double width, Color outline) {
    final p = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(a, b, p
      ..color = outline
      ..strokeWidth = width + 3.5);
    canvas.drawLine(a, b, p
      ..color = color
      ..strokeWidth = width);
  }

  static void _arm(Canvas canvas, Offset sh, Offset el, Offset hand, _Palette pal, double w) {
    _limb(canvas, sh, el, pal.sleeve, 13 * w, pal.outline);
    _limb(canvas, el, hand, pal.forearm, 11 * w, pal.outline);
    final r = 8.5 * math.sqrt(w);
    canvas.drawCircle(hand, r + 1.8, Paint()..color = pal.outline);
    canvas.drawCircle(hand, r, Paint()..color = pal.glove);
  }

  static void _leg(Canvas canvas, Offset hip, Offset knee, Offset foot, double shinAngle,
      _Palette pal, double w) {
    _limb(canvas, hip, knee, pal.pants, 17 * w, pal.outline);
    _limb(canvas, knee, foot, pal.shin, 14 * w, pal.outline);
    // Foot points perpendicular to the shin, toward the front.
    final tip = foot + Offset(math.cos(shinAngle), -math.sin(shinAngle)) * 13;
    _limb(canvas, foot, tip, pal.shoe, 9 * w, pal.outline);
  }

  static void _torso(Canvas canvas, Offset hip, Offset shoulder, Offset side, Offset up,
      _Palette pal, double w, Costume costume) {
    final hipL = hip - side * (14 * w), hipR = hip + side * (14 * w);
    final shL = shoulder - side * (19 * w), shR = shoulder + side * (19 * w);
    final body = Path()
      ..moveTo(hipL.dx, hipL.dy)
      ..lineTo(shL.dx, shL.dy)
      ..lineTo(shR.dx, shR.dy)
      ..lineTo(hipR.dx, hipR.dy)
      ..close();
    canvas.drawPath(body, Paint()..color = pal.torso);
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..color = pal.outline,
    );

    final chest = Offset.lerp(shoulder, hip, 0.55)!;
    final waist = hip + up * 6;
    final detail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    switch (costume) {
      case Costume.gi:
        canvas.drawPath(
          Path()
            ..moveTo((shoulder - side * (10 * w)).dx, (shoulder - side * (10 * w)).dy)
            ..lineTo(chest.dx, chest.dy)
            ..lineTo((shoulder + side * (10 * w)).dx, (shoulder + side * (10 * w)).dy),
          detail
            ..color = pal.trim
            ..strokeWidth = 4,
        );
      case Costume.street:
        final shirt = Path()
          ..moveTo((hip - side * (6 * w)).dx, (hip - side * (6 * w)).dy)
          ..lineTo((shoulder - side * (7 * w)).dx, (shoulder - side * (7 * w)).dy)
          ..lineTo((shoulder + side * (7 * w)).dx, (shoulder + side * (7 * w)).dy)
          ..lineTo((hip + side * (6 * w)).dx, (hip + side * (6 * w)).dy)
          ..close();
        canvas.drawPath(shirt, Paint()..color = pal.trim);
      case Costume.armor:
        final plateTop = Offset.lerp(shoulder, hip, 0.1)!;
        final plateBottom = Offset.lerp(shoulder, hip, 0.6)!;
        canvas.drawLine(plateTop, plateBottom, detail
          ..color = pal.trim
          ..strokeWidth = 22 * w);
        for (final s in [shL, shR]) {
          canvas.drawCircle(s, 12 * w, Paint()..color = pal.outline);
          canvas.drawCircle(s, 10 * w, Paint()..color = pal.trim);
        }
      case Costume.ninja:
        canvas.drawLine(shL, hipR, detail
          ..color = pal.trim
          ..strokeWidth = 6);
    }

    // Belt
    canvas.drawLine(waist - side * (14 * w), waist + side * (14 * w), detail
      ..color = pal.belt
      ..strokeWidth = 7);
    if (costume == Costume.gi || costume == Costume.ninja) {
      canvas.drawLine(waist + side * (4 * w), waist + side * (8 * w) + const Offset(0, 16),
          detail..strokeWidth = 5);
    }
  }

  static void _head(Canvas canvas, Offset c, double r, _Palette pal, FighterConfig config,
      ui.Image? face, double flash, double lean) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(lean * 0.4);
    canvas.translate(-c.dx, -c.dy);

    final rect = Rect.fromCenter(center: c, width: r * 2 * 0.92, height: r * 2 * 1.1);
    final oval = Path()..addOval(rect);
    canvas.drawOval(rect.inflate(1.8), Paint()..color = pal.outline);
    canvas.drawOval(rect, Paint()..color = pal.skin);

    if (face != null) {
      // ---- Selfie compositing: crop-to-cover and clip into the head oval ----
      final iw = face.width.toDouble(), ih = face.height.toDouble();
      final dstAspect = rect.width / rect.height;
      Rect src;
      if (iw / ih > dstAspect) {
        final sw = ih * dstAspect;
        src = Rect.fromLTWH((iw - sw) / 2, 0, sw, ih);
      } else {
        final sh = iw / dstAspect;
        src = Rect.fromLTWH(0, (ih - sh) * 0.4, iw, sh);
      }
      canvas.save();
      canvas.clipPath(oval);
      final paint = Paint()..filterQuality = FilterQuality.medium;
      if (flash > 0) {
        paint.colorFilter = ColorFilter.mode(
          const Color(0xFFFFFFFF).withValues(alpha: flash * 0.7),
          BlendMode.srcATop,
        );
      }
      canvas.drawImageRect(face, src, rect, paint);
      canvas.restore();
    } else {
      _defaultFace(canvas, c, r, pal, config.costume);
    }

    // Costume headwear drawn on top of the face.
    switch (config.costume) {
      case Costume.gi:
        _headband(canvas, c, r, rect, config.secondaryColor, pal.outline);
      case Costume.ninja:
        canvas.save();
        canvas.clipPath(oval);
        canvas.drawRect(
          Rect.fromLTRB(rect.left, c.dy + r * 0.2, rect.right, rect.bottom),
          Paint()..color = pal.torso,
        );
        canvas.restore();
        _headband(canvas, c, r, rect, config.secondaryColor, pal.outline);
      case Costume.armor:
        canvas.drawArc(rect.inflate(2), math.pi * 1.05, math.pi * 0.9, false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 5
              ..color = pal.trim);
      case Costume.street:
        break;
    }
    canvas.restore();
  }

  static void _headband(Canvas canvas, Offset c, double r, Rect rect, Color color, Color outline) {
    final y = c.dy - r * 0.45;
    final p = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5
      ..color = color;
    canvas.drawLine(Offset(rect.left + 1, y + 1), Offset(rect.right - 1, y - 1), p);
    // Tails flowing behind the head.
    canvas.drawLine(Offset(rect.left + 2, y), Offset(rect.left - 14, y + 8), p..strokeWidth = 4);
    canvas.drawLine(Offset(rect.left + 2, y), Offset(rect.left - 11, y + 15), p);
  }

  static void _defaultFace(Canvas canvas, Offset c, double r, _Palette pal, Costume costume) {
    // Hair cap
    final hairRect = Rect.fromCenter(center: c + Offset(-1, -r * 0.25), width: r * 2, height: r * 1.7);
    canvas.drawArc(hairRect, math.pi * 0.95, math.pi * 1.15, true, Paint()..color = pal.hair);
    // Eyes looking forward (to the right)
    final eyeWhite = Paint()..color = const Color(0xFFFFFFFF);
    final pupil = Paint()..color = const Color(0xFF111111);
    for (final dx in [2.0, 10.0]) {
      final e = c + Offset(dx, -1);
      canvas.drawOval(Rect.fromCenter(center: e, width: 6, height: 5), eyeWhite);
      canvas.drawCircle(e + const Offset(1.2, 0.3), 1.6, pupil);
    }
    final brow = Paint()
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = pal.outline;
    canvas.drawLine(c + const Offset(-1, -6), c + const Offset(5, -4.5), brow);
    canvas.drawLine(c + const Offset(8, -4.5), c + const Offset(13, -6), brow);
    if (costume != Costume.ninja) {
      canvas.drawLine(c + const Offset(5, 9), c + const Offset(11, 8.5), brow..strokeWidth = 1.8);
    }
  }
}
