/// Aggregate record. Stored on users/{uid} and mirrored to leaderboard/{uid}.
class PlayerStats {
  const PlayerStats({
    required this.uid,
    required this.displayName,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
  });

  final String uid;
  final String displayName;
  final int wins;
  final int losses;
  final int draws;

  int get matches => wins + losses + draws;
  double get winRate => matches == 0 ? 0 : wins / matches;

  factory PlayerStats.fromMap(String uid, Map<String, dynamic> m,
          {String fallbackName = 'Fighter'}) =>
      PlayerStats(
        uid: uid,
        displayName: (m['displayName'] as String?) ?? fallbackName,
        wins: (m['wins'] as num?)?.toInt() ?? 0,
        losses: (m['losses'] as num?)?.toInt() ?? 0,
        draws: (m['draws'] as num?)?.toInt() ?? 0,
      );

  PlayerStats copyWith({String? displayName, int? wins, int? losses, int? draws}) =>
      PlayerStats(
        uid: uid,
        displayName: displayName ?? this.displayName,
        wins: wins ?? this.wins,
        losses: losses ?? this.losses,
        draws: draws ?? this.draws,
      );
}
