import 'dart:math' as math;

import '../../data/models/fighter_stats.dart';
import '../../data/models/moveset.dart';

/// All damage / meter maths in one place so it can be unit-tested and
/// rebalanced without touching the engine.
abstract final class CombatRules {
  /// Damage dealt by ONE hit of [attack].
  ///
  /// This is the heart of the game's balance — feel free to redesign it.
  /// Current rules:
  ///  * base damage x attacker power x defender defense
  ///  * combo scaling: each extra hit in a combo does 10% less (min 50%)
  ///  * full-meter COMBO button gives a 25% bonus ("empowered")
  ///  * blocked hits deal 15% chip damage
  static double computeDamage({
    required AttackData attack,
    required FighterStats attacker,
    required FighterStats defender,
    required bool blocked,
    required int comboCount,
    bool empowered = false,
  }) {
    var dmg = attack.damage * attacker.damageMultiplier * defender.damageTakenMultiplier;
    if (comboCount > 1) dmg *= math.max(0.5, 1 - 0.1 * (comboCount - 1));
    if (empowered) dmg *= 1.25;
    if (blocked) dmg *= 0.15;
    return dmg.roundToDouble();
  }

  /// Meter the defender gains when taking [damage] (comeback mechanic).
  static double meterOnDamageTaken(double damage) => damage * 0.06;

  /// Meter the attacker gains when the hit connects.
  static double meterOnHit(AttackData attack, {required bool blocked}) =>
      blocked ? attack.meterGain * 0.4 : attack.meterGain;
}
