import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import '../../data/models/fighter_config.dart';
import '../../data/models/moveset.dart';
import '../rendering/fighter_painter.dart';
import '../rendering/pose_library.dart';

/// Small Flame game used inside the Character Studio. The selfie texture is
/// composited onto the procedural body here, live, every frame — the exact
/// same renderer the fight uses, so what you see is what you fight with.
class FighterPreviewGame extends FlameGame {
  FighterPreviewGame({required FighterConfig config})
      : _config = config,
        super(camera: CameraComponent.withFixedResolution(width: 360, height: 400));

  FighterConfig _config;
  ui.Image? _face;
  AttackData? _demo;
  double _demoTime = 0;

  FighterConfig get config => _config;
  ui.Image? get face => _face;

  void updateFighter(FighterConfig config, ui.Image? face) {
    _config = config;
    _face = face;
  }

  /// Plays one attack so players can preview a moveset.
  void demo(AttackSlot slot) {
    _demo = _config.moveset.attackFor(slot);
    _demoTime = 0;
  }

  @override
  Color backgroundColor() => const Color(0xFF15152A);

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    world.add(_Spotlight());
    world.add(_PreviewFighter()
      ..position = Vector2(180, 372)
      ..scale = Vector2.all(1.65));
  }

  @override
  void update(double dt) {
    super.update(dt);
    final d = _demo;
    if (d != null) {
      _demoTime += dt * _config.stats.frameSpeed;
      if (_demoTime > d.totalTime + 0.3) _demo = null;
    }
  }
}

class _Spotlight extends PositionComponent {
  _Spotlight() : super(size: Vector2(360, 400), priority: -1);

  @override
  void render(Canvas canvas) {
    const c = Offset(180, 200);
    canvas.drawCircle(
      c,
      230,
      Paint()
        ..shader = ui.Gradient.radial(c, 230, const [Color(0xFF3A2A6A), Color(0x0015152A)]),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(180, 375), width: 260, height: 40),
      Paint()..color = const Color(0x553DE1FF),
    );
  }
}

class _PreviewFighter extends PositionComponent with HasGameReference<FighterPreviewGame> {
  _PreviewFighter() : super(size: Vector2(90, 190), anchor: Anchor.bottomCenter);

  double _t = 0;

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(size.x / 2, size.y);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 84 * game.config.bodyType.widthScale, height: 14),
      Paint()..color = const Color(0x66000000),
    );

    final demo = game._demo;
    final pose = demo != null && game._demoTime <= demo.totalTime
        ? PoseLibrary.attack(demo, game._demoTime)
        : PoseLibrary.idle(_t);

    Color? aura;
    if (demo != null && demo.slot == AttackSlot.combo) aura = demo.effectColor;
    FighterPainter.paint(canvas, config: game.config, pose: pose, face: game.face, aura: aura);

    // Projectile preview
    if (demo != null &&
        demo.special == SpecialKind.projectile &&
        game._demoTime > demo.startup) {
      final travel = (game._demoTime - demo.startup) * demo.moveSpeed * 0.35;
      final r = demo.hitbox;
      final c = Offset(r.left + r.width / 2 + travel, r.top + r.height / 2);
      if (travel < 160) {
        final rad = math.max(r.width, r.height) * 0.9;
        canvas.drawCircle(
          c,
          rad,
          Paint()
            ..shader = ui.Gradient.radial(c, rad, [
              demo.effectColor.withValues(alpha: 0.85),
              demo.effectColor.withValues(alpha: 0),
            ]),
        );
        canvas.drawCircle(c, rad * 0.35, Paint()..color = const Color(0xFFFFFFFF));
      }
    }
    canvas.restore();
  }
}
