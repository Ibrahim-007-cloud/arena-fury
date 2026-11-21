import 'dart:math' as math;

import '../../core/constants.dart';
import '../../data/models/moveset.dart';
import 'pose.dart';

double _easeOut(double t) => 1 - math.pow(1 - t, 3).toDouble();
double _easeInOut(double t) =>
    t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3).toDouble() / 2;

/// Keyframe poses + helpers that turn fighter state into a [Pose].
/// Shared by the fight engine and the Character Studio preview.
abstract final class PoseLibrary {
  static const stance = Pose(
    lean: 0.08,
    frontUpper: 0.55,
    frontFore: 2.45,
    backUpper: 0.25,
    backFore: 2.55,
    frontThigh: 0.42,
    frontShin: -0.05,
    backThigh: -0.30,
    backShin: -0.50,
  );

  static Pose idle(double t) {
    final b = math.sin(t * 3.2) * 0.05;
    return stance.copyWith(
      lean: stance.lean + b * 0.3,
      frontThigh: stance.frontThigh + b,
      backThigh: stance.backThigh - b * 0.5,
      frontFore: stance.frontFore + b,
      backFore: stance.backFore - b,
    );
  }

  static Pose walk(double t, {required bool forward}) {
    final s = math.sin(t * 9 * (forward ? 1 : -1));
    final ft = 0.35 + 0.30 * s;
    final bt = -0.25 - 0.30 * s;
    return stance.copyWith(
      frontThigh: ft,
      frontShin: ft - 0.35 - 0.2 * math.max(0.0, s),
      backThigh: bt,
      backShin: bt - 0.35 - 0.2 * math.max(0.0, -s),
      frontFore: stance.frontFore + s * 0.08,
      backFore: stance.backFore - s * 0.08,
    );
  }

  static const _crouch = Pose(
    lean: 0.25,
    frontUpper: 0.9,
    frontFore: 2.4,
    backUpper: 0.6,
    backFore: 2.5,
    frontThigh: 1.35,
    frontShin: -0.15,
    backThigh: 0.9,
    backShin: -0.75,
  );

  static Pose crouch(double t) => _crouch.copyWith(lean: 0.25 + math.sin(t * 3) * 0.03);

  static const _jumpRise = Pose(
    lean: 0.1,
    frontUpper: 0.9,
    frontFore: 2.6,
    backUpper: 0.5,
    backFore: 2.7,
    frontThigh: 1.0,
    frontShin: -0.2,
    backThigh: 0.3,
    backShin: -0.9,
  );

  static const _jumpFall = Pose(
    lean: 0.0,
    frontUpper: 0.7,
    frontFore: 2.3,
    backUpper: 0.3,
    backFore: 2.4,
    frontThigh: 0.6,
    frontShin: 0.1,
    backThigh: -0.2,
    backShin: -0.5,
  );

  static Pose jump(double vy) {
    final rise = clampDouble(-vy / GameConstants.jumpVelocity, -1, 1);
    return Pose.lerp(_jumpRise, _jumpFall, (1 - rise) / 2);
  }

  static const _hit = Pose(
    lean: -0.38,
    frontUpper: -0.3,
    frontFore: 0.6,
    backUpper: -0.5,
    backFore: 0.4,
    frontThigh: 0.3,
    frontShin: 0.0,
    backThigh: -0.4,
    backShin: -0.6,
  );

  static Pose hit(double t) => Pose.lerp(_hit, stance, clamp01(t / 0.35) * 0.6);

  static Pose block({bool crouching = false}) {
    final legs = crouching ? _crouch : stance;
    return legs.copyWith(
      lean: crouching ? 0.2 : -0.05,
      frontUpper: 1.0,
      frontFore: 2.75,
      backUpper: 0.85,
      backFore: 2.85,
    );
  }

  static const _launched = Pose(
    lean: -0.9,
    frontUpper: -1.2,
    frontFore: -0.8,
    backUpper: -1.5,
    backFore: -1.0,
    frontThigh: 0.9,
    frontShin: 0.6,
    backThigh: 0.5,
    backShin: 0.2,
  );

  static Pose launched(double vy) =>
      _launched.copyWith(lean: -0.9 + clampDouble(vy / 1500, -0.3, 0.4));

  static const knockdown = Pose(
    lean: -1.5,
    frontUpper: -1.3,
    frontFore: -1.6,
    backUpper: -1.6,
    backFore: -1.9,
    frontThigh: 1.5,
    frontShin: 1.55,
    backThigh: 1.4,
    backShin: 1.5,
  );

  static Pose getUp(double p) {
    final t = clamp01(p);
    if (t < 0.5) return Pose.lerp(knockdown, _crouch, _easeOut(t * 2));
    return Pose.lerp(_crouch, stance, _easeInOut((t - 0.5) * 2));
  }

  static Pose victory(double t) => Pose(
        lean: -0.05,
        frontUpper: 2.9,
        frontFore: 3.05 + math.sin(t * 6) * 0.08,
        backUpper: -0.4,
        backFore: 0.6,
        frontThigh: 0.25,
        frontShin: 0.2,
        backThigh: -0.25,
        backShin: -0.2,
        lift: math.max(0.0, math.sin(t * 6)) * 4,
      );

  // ----- Attacks ------------------------------------------------------------

  static const _jabWindup = Pose(
    lean: 0.0,
    frontUpper: 0.3,
    frontFore: 2.2,
    backUpper: 0.3,
    backFore: 2.55,
    frontThigh: 0.45,
    frontShin: -0.05,
    backThigh: -0.35,
    backShin: -0.5,
  );

  static const _jabStrike = Pose(
    lean: 0.22,
    frontUpper: 1.62,
    frontFore: 1.58,
    backUpper: 0.3,
    backFore: 2.6,
    frontThigh: 0.55,
    frontShin: 0.05,
    backThigh: -0.45,
    backShin: -0.55,
  );

  static const _crossStrike = Pose(
    lean: 0.32,
    frontUpper: 0.35,
    frontFore: 2.4,
    backUpper: 1.62,
    backFore: 1.58,
    frontThigh: 0.6,
    frontShin: 0.05,
    backThigh: -0.5,
    backShin: -0.6,
  );

  static const _kickWindup = Pose(
    lean: -0.1,
    frontUpper: 0.8,
    frontFore: 2.4,
    backUpper: 0.2,
    backFore: 2.3,
    frontThigh: 1.3,
    frontShin: -0.3,
    backThigh: -0.1,
    backShin: -0.25,
  );

  static const _kickStrike = Pose(
    lean: -0.38,
    frontUpper: 0.9,
    frontFore: 2.3,
    backUpper: -0.4,
    backFore: 0.6,
    frontThigh: 1.62,
    frontShin: 1.62,
    backThigh: -0.12,
    backShin: -0.2,
  );

  static const _palmWindup = Pose(
    lean: -0.1,
    frontUpper: -0.5,
    frontFore: 0.9,
    backUpper: -0.6,
    backFore: 0.8,
    frontThigh: 0.45,
    frontShin: -0.05,
    backThigh: -0.35,
    backShin: -0.5,
  );

  static const _palmStrike = Pose(
    lean: 0.28,
    frontUpper: 1.52,
    frontFore: 1.55,
    backUpper: 1.42,
    backFore: 1.5,
    frontThigh: 0.6,
    frontShin: 0.0,
    backThigh: -0.5,
    backShin: -0.6,
  );

  static const _uppercutWindup = Pose(
    lean: 0.35,
    frontUpper: 0.1,
    frontFore: 0.6,
    backUpper: 0.5,
    backFore: 2.5,
    frontThigh: 1.0,
    frontShin: -0.3,
    backThigh: 0.5,
    backShin: -0.8,
  );

  static const _uppercutStrike = Pose(
    lean: -0.15,
    frontUpper: 2.85,
    frontFore: 3.0,
    backUpper: 0.2,
    backFore: 2.2,
    frontThigh: 0.2,
    frontShin: 0.1,
    backThigh: -0.2,
    backShin: -0.3,
    lift: 18,
  );

  static const _chargeStrike = Pose(
    lean: 0.65,
    frontUpper: 0.9,
    frontFore: 2.5,
    backUpper: -0.2,
    backFore: 1.2,
    frontThigh: 0.9,
    frontShin: 0.2,
    backThigh: -0.7,
    backShin: -0.4,
  );

  static const _flipStrike = Pose(
    lean: -0.85,
    frontUpper: -1.0,
    frontFore: -0.6,
    backUpper: -1.3,
    backFore: -0.9,
    frontThigh: 2.7,
    frontShin: 2.9,
    backThigh: 0.6,
    backShin: -0.1,
  );

  static Pose _windup(AttackPose p) => switch (p) {
        AttackPose.jab || AttackPose.flurry => _jabWindup,
        AttackPose.kick => _kickWindup,
        AttackPose.palm => _palmWindup,
        AttackPose.uppercut || AttackPose.charge || AttackPose.flipKick => _uppercutWindup,
      };

  static Pose _strike(AttackPose p) => switch (p) {
        AttackPose.jab => _jabStrike,
        AttackPose.kick => _kickStrike,
        AttackPose.palm => _palmStrike,
        AttackPose.flurry || AttackPose.uppercut => _uppercutStrike,
        AttackPose.charge => _chargeStrike,
        AttackPose.flipKick => _flipStrike,
      };

  /// Pose for attack [a] at [t] seconds into its timeline.
  static Pose attack(AttackData a, double t) {
    final phase = a.phaseAt(t);
    final p = a.progressAt(t);
    if (a.pose == AttackPose.flurry && phase == AttackPhase.active) {
      return _flurry(a, t);
    }
    final windup = _windup(a.pose);
    final strike = _strike(a.pose);
    switch (phase) {
      case AttackPhase.startup:
        return Pose.lerp(stance, windup, _easeOut(p));
      case AttackPhase.active:
        return Pose.lerp(windup, strike, clamp01(p / 0.25));
      case AttackPhase.recovery:
        return Pose.lerp(strike, stance, _easeInOut(p));
    }
  }

  static const _flurryCycle = [_jabStrike, _crossStrike, _kickStrike];

  static Pose _flurry(AttackData a, double t) {
    final i = a.sliceAt(t);
    final sp = a.sliceProgressAt(t);
    final isLast = i == a.hits - 1;
    if (isLast) return Pose.lerp(_uppercutWindup, _uppercutStrike, clamp01(sp / 0.3));
    final target = _flurryCycle[i % _flurryCycle.length];
    final k = sp < 0.45 ? sp / 0.45 : 1 - (sp - 0.45) / 0.55 * 0.6;
    return Pose.lerp(_jabWindup, target, clamp01(k));
  }
}
