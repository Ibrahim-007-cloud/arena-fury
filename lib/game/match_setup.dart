import '../data/models/fighter_config.dart';
import '../data/models/match_record.dart';
import '../data/models/stage_data.dart';

enum GameMode {
  arcade('Arcade'),
  training('Training');

  const GameMode(this.label);
  final String label;
}

enum BotDifficulty {
  easy('Easy', reaction: 0.55, aggression: 0.35, blockChance: 0.15, comboUse: 0.3),
  normal('Normal', reaction: 0.35, aggression: 0.55, blockChance: 0.40, comboUse: 0.6),
  hard('Hard', reaction: 0.18, aggression: 0.75, blockChance: 0.70, comboUse: 0.9);

  const BotDifficulty(
    this.label, {
    required this.reaction,
    required this.aggression,
    required this.blockChance,
    required this.comboUse,
  });

  final String label;

  /// Seconds between AI decisions.
  final double reaction;

  /// Chance to attack when in range.
  final double aggression;

  /// Chance to block a visible attack.
  final double blockChance;

  /// Chance to spend a full meter on the combo attack.
  final double comboUse;
}

class MatchSetup {
  const MatchSetup({
    required this.player,
    required this.opponent,
    required this.stage,
    this.difficulty = BotDifficulty.normal,
    this.mode = GameMode.arcade,
  });

  final FighterConfig player;
  final FighterConfig opponent;
  final StageData stage;
  final BotDifficulty difficulty;
  final GameMode mode;
}

class MatchSummary {
  const MatchSummary({
    required this.outcome,
    required this.roundsWon,
    required this.roundsLost,
    required this.durationSeconds,
  });

  final MatchOutcome outcome;
  final int roundsWon;
  final int roundsLost;
  final double durationSeconds;
}
