import 'dart:ui';

import '../core/constants.dart';
import 'models/fighter_config.dart';
import 'models/fighter_stats.dart';

/// The original built-in fighters. Custom fighters fill the remaining slots
/// up to [GameConstants.maxRosterSlots].
abstract final class BuiltInRoster {
  static const fighters = <FighterConfig>[
    FighterConfig(
      id: 'builtin_kaito',
      name: 'Kaito Blaze',
      isBuiltIn: true,
      costume: Costume.gi,
      bodyType: BodyType.standard,
      primaryColor: Color(0xFFD32F2F),
      secondaryColor: Color(0xFF212121),
      skinColor: Color(0xFFE0AC69),
      hairColor: Color(0xFF1B1B1B),
      movesetId: 'striker',
      stats: FighterStats(power: 4, speed: 3, defense: 3),
    ),
    FighterConfig(
      id: 'builtin_mira',
      name: 'Mira Volt',
      isBuiltIn: true,
      costume: Costume.ninja,
      bodyType: BodyType.slim,
      primaryColor: Color(0xFF4A148C),
      secondaryColor: Color(0xFFFFD600),
      skinColor: Color(0xFFF1C27D),
      hairColor: Color(0xFF311B92),
      movesetId: 'ninja',
      stats: FighterStats(power: 2, speed: 5, defense: 3),
    ),
    FighterConfig(
      id: 'builtin_brutus',
      name: 'Brutus Stone',
      isBuiltIn: true,
      costume: Costume.armor,
      bodyType: BodyType.heavy,
      primaryColor: Color(0xFF558B2F),
      secondaryColor: Color(0xFF455A64),
      skinColor: Color(0xFF8D5524),
      hairColor: Color(0xFF3E2723),
      movesetId: 'brawler',
      stats: FighterStats(power: 5, speed: 1, defense: 4),
    ),
    FighterConfig(
      id: 'builtin_zara',
      name: 'Zara Storm',
      isBuiltIn: true,
      costume: Costume.street,
      bodyType: BodyType.standard,
      primaryColor: Color(0xFF0277BD),
      secondaryColor: Color(0xFFFFFFFF),
      skinColor: Color(0xFFC68642),
      hairColor: Color(0xFFECEFF1),
      movesetId: 'tempest',
      stats: FighterStats(power: 3, speed: 4, defense: 3),
    ),
  ];

  static int get maxCustomSlots => GameConstants.maxRosterSlots - fighters.length;
}
