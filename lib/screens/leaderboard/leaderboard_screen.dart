import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models/app_user.dart';
import '../../data/models/match_record.dart';
import '../../data/models/player_stats.dart';
import '../../services/app_services.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late final _board = AppServices.matches.watchLeaderboard();
  late final _stats = AppServices.matches.watchPlayerStats(widget.user);
  late final _recent = AppServices.matches.watchRecentMatches(widget.user.uid);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('LEADERBOARD'),
          bottom: const TabBar(tabs: [Tab(text: 'GLOBAL TOP 25'), Tab(text: 'MY RECORD')]),
        ),
        body: TabBarView(children: [_global(), _mine()]),
      ),
    );
  }

  Widget _global() {
    return StreamBuilder<List<PlayerStats>>(
      stream: _board,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final rows = snap.data!;
        if (rows.isEmpty) return const Center(child: Text('No matches yet — be the first!'));
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final r = rows[i];
            final me = r.uid == widget.user.uid;
            return ListTile(
              tileColor: me ? AppColors.accent.withValues(alpha: 0.15) : null,
              leading: CircleAvatar(
                backgroundColor: i < 3
                    ? [AppColors.gold, const Color(0xFFB0BEC5), const Color(0xFFCD7F32)][i]
                    : Colors.white12,
                child: Text('${i + 1}',
                    style: TextStyle(
                        fontWeight: FontWeight.w900, color: i < 3 ? Colors.black : Colors.white)),
              ),
              title: Text(r.displayName + (me ? '  (you)' : ''),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${r.wins}W  ${r.losses}L  ${r.draws}D'),
              trailing: Text('${(r.winRate * 100).round()}%',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            );
          },
        );
      },
    );
  }

  Widget _mine() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 260,
          child: StreamBuilder<PlayerStats>(
            stream: _stats,
            builder: (context, snap) {
              final s = snap.data;
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.user.displayName.toUpperCase(), style: AppTheme.headingStyle),
                    const SizedBox(height: 12),
                    _big('WINS', '${s?.wins ?? 0}', AppColors.gold),
                    _big('LOSSES', '${s?.losses ?? 0}', Colors.white70),
                    _big('WIN RATE', '${((s?.winRate ?? 0) * 100).round()}%', AppColors.cyan),
                  ],
                ),
              );
            },
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: StreamBuilder<List<MatchRecord>>(
            stream: _recent,
            builder: (context, snap) {
              if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
              final list = snap.data ?? const <MatchRecord>[];
              if (list.isEmpty) return const Center(child: Text('Play an Arcade match to start your record.'));
              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  for (final m in list)
                    ListTile(
                      leading: Icon(
                        m.outcome == MatchOutcome.win ? Icons.emoji_events : Icons.close,
                        color: m.outcome == MatchOutcome.win ? AppColors.gold : Colors.white38,
                      ),
                      title: Text('${m.playerFighterName} vs ${m.opponentFighterName}'),
                      subtitle: Text(
                          '${m.outcome.label} ${m.roundsWon}-${m.roundsLost} • ${m.difficulty} • ${m.durationSeconds}s'),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _big(String label, String value, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, letterSpacing: 2, color: Colors.white54)),
            Text(value, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      );
}
