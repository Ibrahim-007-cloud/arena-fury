import 'dart:ui';

/// Which button an attack is mapped to.
enum AttackSlot { light, heavy, special, combo }

/// Which body animation the procedural renderer should play.
enum AttackPose { jab, kick, palm, flurry, uppercut, charge, flipKick }

/// Extra behaviour during the active frames of an attack.
enum SpecialKind { none, projectile, dash, rising }

/// Timeline of every attack: startup -> active (hitbox live) -> recovery.
enum AttackPhase { startup, active, recovery }

/// Tokens recorded by the input buffer to detect button sequences.
enum InputToken {
  up('↑'),
  down('↓'),
  forward('→'),
  back('←'),
  light('LP'),
  heavy('HK'),
  special('SP');

  const InputToken(this.label);
  final String label;

  bool get isButton => index >= InputToken.light.index;
}

/// Frame data for one attack.
///
/// [hitbox] is in "fighter space": x is measured FORWARD from the body centre
/// (so it mirrors automatically when the fighter turns around) and y is
/// measured from the feet, negative = up. For projectiles it is the spawn
/// offset + size of the projectile.
class AttackData {
  const AttackData({
    required this.name,
    required this.slot,
    required this.pose,
    required this.startup,
    required this.active,
    required this.recovery,
    required this.damage,
    required this.knockback,
    required this.hitstun,
    required this.hitbox,
    this.launch = 0,
    this.hits = 1,
    this.special = SpecialKind.none,
    this.moveSpeed = 0,
    this.meterGain = 8,
    this.effectColor = const Color(0xFFFFFFFF),
  });

  final String name;
  final AttackSlot slot;
  final AttackPose pose;
  final double startup;
  final double active;
  final double recovery;

  /// Base damage per hit (before stats, scaling and blocking).
  final double damage;

  /// Horizontal push applied to the defender (px/s).
  final double knockback;

  /// Vertical launch speed on the final hit (px/s). 0 = no launch.
  final double launch;

  final double hitstun;
  final Rect hitbox;
  final int hits;
  final SpecialKind special;

  /// Projectile speed, dash speed or rising speed depending on [special].
  final double moveSpeed;
  final double meterGain;
  final Color effectColor;

  double get totalTime => startup + active + recovery;

  AttackPhase phaseAt(double t) {
    if (t < startup) return AttackPhase.startup;
    if (t < startup + active) return AttackPhase.active;
    return AttackPhase.recovery;
  }

  /// 0..1 progress inside the current phase.
  double progressAt(double t) {
    double c(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
    switch (phaseAt(t)) {
      case AttackPhase.startup:
        return c(t / startup);
      case AttackPhase.active:
        return c((t - startup) / active);
      case AttackPhase.recovery:
        return c((t - startup - active) / recovery);
    }
  }

  /// Index of the current hit for multi-hit attacks.
  int sliceAt(double t) {
    final raw = ((t - startup) / (active / hits)).floor();
    return raw < 0 ? 0 : (raw >= hits ? hits - 1 : raw);
  }

  /// 0..1 progress inside the current hit slice.
  double sliceProgressAt(double t) {
    final v = (t - startup) / (active / hits);
    if (v <= 0) return 0;
    if (v >= hits) return 1;
    return v - v.floorToDouble();
  }
}

/// A complete fighting style: 3 basic attacks + 1 combo attack.
class Moveset {
  const Moveset({
    required this.id,
    required this.name,
    required this.description,
    required this.light,
    required this.heavy,
    required this.special,
    required this.combo,
    required this.comboSequence,
  });

  final String id;
  final String name;
  final String description;
  final AttackData light;
  final AttackData heavy;
  final AttackData special;
  final AttackData combo;

  /// Button sequence that triggers [combo] when the meter is at least half full.
  final List<InputToken> comboSequence;

  AttackData attackFor(AttackSlot slot) => switch (slot) {
        AttackSlot.light => light,
        AttackSlot.heavy => heavy,
        AttackSlot.special => special,
        AttackSlot.combo => combo,
      };

  String get sequenceLabel => comboSequence.map((t) => t.label).join(' ');
}

abstract final class Movesets {
  static const striker = Moveset(
    id: 'striker',
    name: 'Striker',
    description: 'Balanced all-rounder with a fireball special.',
    comboSequence: [InputToken.down, InputToken.forward, InputToken.special],
    light: AttackData(
      name: 'Flash Jab',
      slot: AttackSlot.light,
      pose: AttackPose.jab,
      startup: 0.07,
      active: 0.08,
      recovery: 0.14,
      damage: 45,
      knockback: 160,
      hitstun: 0.28,
      hitbox: Rect.fromLTWH(15, -150, 72, 30),
      meterGain: 6,
    ),
    heavy: AttackData(
      name: 'Blaze Roundhouse',
      slot: AttackSlot.heavy,
      pose: AttackPose.kick,
      startup: 0.16,
      active: 0.10,
      recovery: 0.28,
      damage: 85,
      knockback: 320,
      hitstun: 0.40,
      hitbox: Rect.fromLTWH(10, -125, 90, 45),
      meterGain: 10,
      effectColor: Color(0xFFFFB74D),
    ),
    special: AttackData(
      name: 'Blaze Orb',
      slot: AttackSlot.special,
      pose: AttackPose.palm,
      startup: 0.22,
      active: 0.10,
      recovery: 0.35,
      damage: 95,
      knockback: 260,
      hitstun: 0.45,
      hitbox: Rect.fromLTWH(40, -150, 40, 40),
      special: SpecialKind.projectile,
      moveSpeed: 520,
      meterGain: 8,
      effectColor: Color(0xFFFF7A1A),
    ),
    combo: AttackData(
      name: 'Inferno Rush',
      slot: AttackSlot.combo,
      pose: AttackPose.flurry,
      startup: 0.12,
      active: 0.70,
      recovery: 0.40,
      damage: 40,
      hits: 6,
      knockback: 220,
      launch: 650,
      hitstun: 0.35,
      hitbox: Rect.fromLTWH(10, -165, 95, 110),
      meterGain: 0,
      effectColor: Color(0xFFFF5722),
    ),
  );

  static const brawler = Moveset(
    id: 'brawler',
    name: 'Brawler',
    description: 'Slow but crushing hits and a charging shoulder rush.',
    comboSequence: [InputToken.back, InputToken.forward, InputToken.heavy],
    light: AttackData(
      name: 'Iron Hook',
      slot: AttackSlot.light,
      pose: AttackPose.jab,
      startup: 0.10,
      active: 0.08,
      recovery: 0.18,
      damage: 55,
      knockback: 180,
      hitstun: 0.30,
      hitbox: Rect.fromLTWH(15, -148, 74, 34),
      meterGain: 6,
    ),
    heavy: AttackData(
      name: 'Quake Kick',
      slot: AttackSlot.heavy,
      pose: AttackPose.kick,
      startup: 0.22,
      active: 0.10,
      recovery: 0.35,
      damage: 110,
      knockback: 380,
      hitstun: 0.45,
      hitbox: Rect.fromLTWH(10, -125, 92, 48),
      meterGain: 11,
      effectColor: Color(0xFFA5D6A7),
    ),
    special: AttackData(
      name: 'Bull Charge',
      slot: AttackSlot.special,
      pose: AttackPose.charge,
      startup: 0.20,
      active: 0.30,
      recovery: 0.35,
      damage: 105,
      knockback: 450,
      hitstun: 0.50,
      hitbox: Rect.fromLTWH(5, -160, 70, 110),
      special: SpecialKind.dash,
      moveSpeed: 700,
      meterGain: 9,
      effectColor: Color(0xFF66BB6A),
    ),
    combo: AttackData(
      name: 'Titan Breaker',
      slot: AttackSlot.combo,
      pose: AttackPose.flurry,
      startup: 0.18,
      active: 0.60,
      recovery: 0.45,
      damage: 75,
      hits: 3,
      knockback: 300,
      launch: 800,
      hitstun: 0.45,
      hitbox: Rect.fromLTWH(10, -165, 95, 110),
      meterGain: 0,
      effectColor: Color(0xFF00E676),
    ),
  );

  static const ninja = Moveset(
    id: 'ninja',
    name: 'Ninja',
    description: 'Lightning-fast strings and a flipping anti-air kick.',
    comboSequence: [InputToken.light, InputToken.light, InputToken.heavy],
    light: AttackData(
      name: 'Viper Strike',
      slot: AttackSlot.light,
      pose: AttackPose.jab,
      startup: 0.05,
      active: 0.07,
      recovery: 0.10,
      damage: 35,
      knockback: 140,
      hitstun: 0.26,
      hitbox: Rect.fromLTWH(15, -150, 70, 30),
      meterGain: 5,
    ),
    heavy: AttackData(
      name: 'Whirl Kick',
      slot: AttackSlot.heavy,
      pose: AttackPose.kick,
      startup: 0.12,
      active: 0.10,
      recovery: 0.22,
      damage: 70,
      knockback: 300,
      hitstun: 0.38,
      hitbox: Rect.fromLTWH(10, -125, 88, 45),
      meterGain: 9,
      effectColor: Color(0xFFE1BEE7),
    ),
    special: AttackData(
      name: 'Crescent Flip',
      slot: AttackSlot.special,
      pose: AttackPose.flipKick,
      startup: 0.10,
      active: 0.30,
      recovery: 0.40,
      damage: 90,
      knockback: 200,
      launch: 700,
      hitstun: 0.45,
      hitbox: Rect.fromLTWH(-10, -190, 80, 120),
      special: SpecialKind.rising,
      moveSpeed: 820,
      meterGain: 8,
      effectColor: Color(0xFFCE93D8),
    ),
    combo: AttackData(
      name: 'Shadow Storm',
      slot: AttackSlot.combo,
      pose: AttackPose.flurry,
      startup: 0.08,
      active: 0.80,
      recovery: 0.35,
      damage: 28,
      hits: 8,
      knockback: 180,
      launch: 600,
      hitstun: 0.30,
      hitbox: Rect.fromLTWH(10, -165, 95, 110),
      meterGain: 0,
      effectColor: Color(0xFFAB47BC),
    ),
  );

  static const tempest = Moveset(
    id: 'tempest',
    name: 'Tempest',
    description: 'Zoner with a fast low lightning shot.',
    comboSequence: [InputToken.down, InputToken.down, InputToken.special],
    light: AttackData(
      name: 'Spark Jab',
      slot: AttackSlot.light,
      pose: AttackPose.jab,
      startup: 0.07,
      active: 0.08,
      recovery: 0.14,
      damage: 42,
      knockback: 160,
      hitstun: 0.28,
      hitbox: Rect.fromLTWH(15, -150, 72, 30),
      meterGain: 6,
    ),
    heavy: AttackData(
      name: 'Thunder Kick',
      slot: AttackSlot.heavy,
      pose: AttackPose.kick,
      startup: 0.15,
      active: 0.10,
      recovery: 0.26,
      damage: 82,
      knockback: 320,
      hitstun: 0.40,
      hitbox: Rect.fromLTWH(10, -125, 90, 45),
      meterGain: 10,
      effectColor: Color(0xFF80DEEA),
    ),
    special: AttackData(
      name: 'Volt Shot',
      slot: AttackSlot.special,
      pose: AttackPose.palm,
      startup: 0.18,
      active: 0.10,
      recovery: 0.32,
      damage: 80,
      knockback: 240,
      hitstun: 0.40,
      // Low projectile: cannot be ducked under.
      hitbox: Rect.fromLTWH(40, -82, 36, 24),
      special: SpecialKind.projectile,
      moveSpeed: 760,
      meterGain: 7,
      effectColor: Color(0xFF00E5FF),
    ),
    combo: AttackData(
      name: 'Storm Hammer',
      slot: AttackSlot.combo,
      pose: AttackPose.flurry,
      startup: 0.12,
      active: 0.60,
      recovery: 0.40,
      damage: 60,
      hits: 4,
      knockback: 240,
      launch: 750,
      hitstun: 0.38,
      hitbox: Rect.fromLTWH(10, -165, 95, 110),
      meterGain: 0,
      effectColor: Color(0xFF18FFFF),
    ),
  );

  static const all = [striker, brawler, ninja, tempest];

  static Moveset byId(String? id) {
    for (final m in all) {
      if (m.id == id) return m;
    }
    return striker;
  }
}
