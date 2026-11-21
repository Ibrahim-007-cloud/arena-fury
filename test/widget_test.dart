// Pure-logic tests for the combat system. Run with: flutter test
import 'dart:ui';

import 'package:arena_fury/data/models/fighter_config.dart';
import 'package:arena_fury/data/models/fighter_stats.dart';
import 'package:arena_fury/data/models/moveset.dart';
import 'package:arena_fury/data/roster.dart';
import 'package:arena_fury/game/input/input_buffer.dart';
import 'package:arena_fury/game/logic/combat_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InputBuffer', () {
    test('detects down, forward, special with joystick noise in between', () {
      final b = InputBuffer()
        ..add(InputToken.down, 0.0)
        ..add(InputToken.back, 0.05) // noise
        ..add(InputToken.forward, 0.1)
        ..add(InputToken.special, 0.2);
      expect(b.matches(Movesets.striker.comboSequence, 0.2), isTrue);
    });

    test('an unrelated button breaks the sequence', () {
      final b = InputBuffer()
        ..add(InputToken.light, 0.0)
        ..add(InputToken.special, 0.1)
        ..add(InputToken.light, 0.2)
        ..add(InputToken.heavy, 0.3);
      expect(b.matches(Movesets.ninja.comboSequence, 0.3), isFalse);
    });

    test('sequence must be entered inside the time window', () {
      final b = InputBuffer()
        ..add(InputToken.light, 0.0)
        ..add(InputToken.light, 0.5)
        ..add(InputToken.heavy, 2.0);
      expect(b.matches(Movesets.ninja.comboSequence, 2.0), isFalse);
    });
  });

  group('CombatRules', () {
    const attack = AttackData(
      name: 'Test',
      slot: AttackSlot.light,
      pose: AttackPose.jab,
      startup: 0.1,
      active: 0.1,
      recovery: 0.1,
      damage: 100,
      knockback: 0,
      hitstun: 0.2,
      hitbox: Rect.fromLTWH(0, 0, 10, 10),
    );
    const neutral = FighterStats(power: 2, speed: 3, defense: 5);

    test('blocking reduces damage to chip', () {
      final hit = CombatRules.computeDamage(
          attack: attack, attacker: neutral, defender: neutral, blocked: false, comboCount: 1);
      final block = CombatRules.computeDamage(
          attack: attack, attacker: neutral, defender: neutral, blocked: true, comboCount: 1);
      expect(block, lessThan(hit * 0.2));
    });

    test('combo scaling never drops below half damage', () {
      final first = CombatRules.computeDamage(
          attack: attack, attacker: neutral, defender: neutral, blocked: false, comboCount: 1);
      final tenth = CombatRules.computeDamage(
          attack: attack, attacker: neutral, defender: neutral, blocked: false, comboCount: 10);
      expect(tenth, greaterThanOrEqualTo((first * 0.5).floorToDouble()));
    });
  });

  test('roster has exactly 6 slots with built-ins', () {
    expect(BuiltInRoster.fighters.length + BuiltInRoster.maxCustomSlots, 6);
    for (final f in BuiltInRoster.fighters) {
      expect(f.stats.isValid, isTrue, reason: f.name);
    }
  });

  test('FighterConfig survives a Firestore map round-trip', () {
    final original = FighterConfig.blank().copyWith(
      name: 'Iron Comet',
      costume: Costume.ninja,
      bodyType: BodyType.heavy,
      movesetId: 'tempest',
      stats: const FighterStats(power: 4, speed: 4, defense: 2),
      faceImagePath: 'users/u/faces/x.png',
    );
    final copy = FighterConfig.fromMap(original.id, original.toMap());
    expect(copy.name, original.name);
    expect(copy.costume, Costume.ninja);
    expect(copy.bodyType, BodyType.heavy);
    expect(copy.moveset.id, 'tempest');
    expect(copy.stats, original.stats);
    expect(copy.primaryColor.toARGB32(), original.primaryColor.toARGB32());
    expect(copy.faceImagePath, original.faceImagePath);
  });

  test('every moveset has 3 basics + a multi-hit combo', () {
    for (final m in Movesets.all) {
      expect(m.combo.hits, greaterThan(1), reason: m.name);
      expect(m.comboSequence, isNotEmpty);
      for (final slot in AttackSlot.values) {
        expect(m.attackFor(slot).totalTime, greaterThan(0));
      }
    }
  });
}
