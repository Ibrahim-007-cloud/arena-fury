import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import 'fighter.dart';

/// The fighter's strike hitbox. It is a child of the [Fighter] and is only
/// "active" (colliding) during an attack's active frames. Hurtboxes are
/// passive, so they only ever collide with active attack boxes/projectiles.
class AttackBox extends PositionComponent with CollisionCallbacks {
  AttackBox({required this.owner}) : super(size: Vector2.all(1));

  final Fighter owner;
  late final RectangleHitbox hitbox;

  bool get isArmed => isLoaded && hitbox.collisionType == CollisionType.active;

  @override
  Future<void> onLoad() async {
    hitbox = RectangleHitbox(size: size.clone(), collisionType: CollisionType.inactive);
    add(hitbox);
  }

  /// Positions the box from a fighter-space rect (x forward, y up from feet).
  void arm(Rect r, {required bool facingRight, required Vector2 fighterSize}) {
    if (!isLoaded) return;
    final localX = fighterSize.x / 2 + (facingRight ? r.left : -r.right);
    final localY = fighterSize.y + r.top;
    if (position.x != localX || position.y != localY) position.setValues(localX, localY);
    if (size.x != r.width || size.y != r.height) {
      size.setValues(r.width, r.height);
      hitbox.size.setValues(r.width, r.height);
    }
    if (hitbox.collisionType != CollisionType.active) {
      hitbox.collisionType = CollisionType.active;
    }
  }

  void disarm() {
    if (isLoaded && hitbox.collisionType != CollisionType.inactive) {
      hitbox.collisionType = CollisionType.inactive;
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    // `other` is the hitbox's parent: a Fighter for hurtboxes.
    if (other is Fighter && other != owner) {
      owner.onAttackContact(other, intersectionPoints);
    }
  }
}
