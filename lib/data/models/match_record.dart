enum MatchOutcome {
  win('Victory'),
  loss('Defeat'),
  draw('Draw');

  const MatchOutcome(this.label);
  final String label;

  static MatchOutcome fromName(String? name) => MatchOutcome.values
      .firstWhere((o) => o.name == name, orElse: () => MatchOutcome.loss);
}

/// One finished match, stored at users/{uid}/matches/{matchId}.
class MatchRecord {
  const MatchRecord({
    required this.id,
    required this.mode,
    required this.playerFighterId,
    required this.playerFighterName,
    required this.opponentFighterId,
    required this.opponentFighterName,
    required this.stageId,
    required this.outcome,
    required this.roundsWon,
    required this.roundsLost,
    required this.difficulty,
    required this.durationSeconds,
    this.playedAt,
  });

  final String id;
  final String mode;
  final String playerFighterId;
  final String playerFighterName;
  final String opponentFighterId;
  final String opponentFighterName;
  final String stageId;
  final MatchOutcome outcome;
  final int roundsWon;
  final int roundsLost;
  final String difficulty;
  final int durationSeconds;
  final DateTime? playedAt;

  Map<String, dynamic> toMap() => {
        'mode': mode,
        'playerFighterId': playerFighterId,
        'playerFighterName': playerFighterName,
        'opponentFighterId': opponentFighterId,
        'opponentFighterName': opponentFighterName,
        'stageId': stageId,
        'outcome': outcome.name,
        'roundsWon': roundsWon,
        'roundsLost': roundsLost,
        'difficulty': difficulty,
        'durationSeconds': durationSeconds,
        'playedAt': playedAt,
      };

  factory MatchRecord.fromMap(String id, Map<String, dynamic> m) => MatchRecord(
        id: id,
        mode: (m['mode'] as String?) ?? 'arcade',
        playerFighterId: (m['playerFighterId'] as String?) ?? '',
        playerFighterName: (m['playerFighterName'] as String?) ?? '?',
        opponentFighterId: (m['opponentFighterId'] as String?) ?? '',
        opponentFighterName: (m['opponentFighterName'] as String?) ?? '?',
        stageId: (m['stageId'] as String?) ?? '',
        outcome: MatchOutcome.fromName(m['outcome'] as String?),
        roundsWon: (m['roundsWon'] as num?)?.toInt() ?? 0,
        roundsLost: (m['roundsLost'] as num?)?.toInt() ?? 0,
        difficulty: (m['difficulty'] as String?) ?? 'normal',
        durationSeconds: (m['durationSeconds'] as num?)?.toInt() ?? 0,
        playedAt: m['playedAt'] is DateTime ? m['playedAt'] as DateTime : null,
      );
}
