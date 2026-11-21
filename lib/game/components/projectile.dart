import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../core/constants.dart';
import '../../data/models/moveset.dart';
import '../fight_game.dart';
import 'fighter.dart';
import 'hit_spark.dart';

/// Energy orb fired by projectile specials (Blaze Orb, Volt Shot).
class Projectile extends PositionComponent
    with CollisionCallbacks, HasGameReference<FightGame> {
  Projectile({
    required this.owner,
    required this.attack,
    required Vector2 position,
    required this.direction,
  }) : super(
          position: position,
          size: Vector2(attack.hitbox.width, attack.hitbox.height),
          anchor: Anchor.center,
          priority: 15,
        );

  final Fighter owner;
  final AttackData attack;
  final double direction;
  bool _spent = false;
  double _t = 0;

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(size: size.clone(), collisionType: CollisionType.active));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.hitStopTimer > 0) return;
    _t += dt;
    position.x += direction * attack.moveSpeed * dt;
    if (_t > 3 || position.x < -60 || position.x > GameConstants.worldWidth + 60) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final c = Offset(size.x / 2, size.y / 2);
    final r = math.max(size.x, size.y) * 0.75;
    final pulse = 1 + math.sin(_t * 30) * 0.08;
    // Trail
    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(
        c - Offset(direction * i * 10.0, 0),
        r * 0.55 * (1 - i * 0.18),
        Paint()..color = attack.effectColor.withValues(alpha: 0.35 - i * 0.07),
      );
    }
    canvas.drawCircle(
      c,
      r * 1.4 * pulse,
      Paint()
        ..shader = ui.Gradient.radial(c, r * 1.4 * pulse, [
          attack.effectColor.withValues(alpha: 0.8),
          attack.effectColor.withValues(alpha: 0),
        ]),
    );
    canvas.drawCircle(c, r * 0.45, Paint()..color = const Color(0xFFFFFFFF));
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (_spent) return;
    if (other is Fighter && other != owner) {
      final hit = game.resolveHit(
        attacker: owner,
        defender: other,
        attack: attack,
        hitIndex: 0,
        contact: absoluteCenter,
      );
      if (hit) {
        _spent = true;
        removeFromParent();
      }
    } else if (other is Projectile && other.owner != owner && !other._spent) {
      // Two fireballs cancel each other out.
      _spent = true;
      other._spent = true;
      game.world.add(HitSpark(position: absoluteCenter, color: attack.effectColor, big: true));
      removeFromParent();
      other.removeFromParent();
    }
  }
}
