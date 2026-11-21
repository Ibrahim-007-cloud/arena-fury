import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models/app_user.dart';
import '../../data/models/fighter_config.dart';
import '../../data/models/stage_data.dart';
import '../../game/match_setup.dart';
import '../../widgets/stage_backdrop.dart';
import '../fight/fight_screen.dart';

class StageSelectScreen extends StatefulWidget {
  const StageSelectScreen({
    super.key,
    required this.user,
    required this.player,
    required this.opponent,
    required this.difficulty,
    required this.mode,
  });

  final AppUser user;
  final FighterConfig player;
  final FighterConfig opponent;
  final BotDifficulty difficulty;
  final GameMode mode;

  @override
  State<StageSelectScreen> createState() => _StageSelectScreenState();
}

class _StageSelectScreenState extends State<StageSelectScreen> {
  StageData _stage = Stages.all.first;

  void _fight() {
    final setup = MatchSetup(
      player: widget.player,
      opponent: widget.opponent,
      stage: _stage,
      difficulty: widget.difficulty,
      mode: widget.mode,
    );
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => FightScreen(user: widget.user, setup: setup),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.player.name.toUpperCase()}  VS  ${widget.opponent.name.toUpperCase()}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _fight,
              icon: const Icon(Icons.sports_mma),
              label: const Text('FIGHT!'),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    StageBackdrop(key: ValueKey(_stage.id), stage: _stage),
                    Positioned(
                      left: 16,
                      bottom: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_stage.name.toUpperCase(), style: AppTheme.headingStyle),
                          Text(_stage.description, style: const TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: 240,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
              children: [
                for (final s in Stages.all)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => setState(() => _stage = s),
                      child: Container(
                        height: 92,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: s.id == _stage.id ? AppColors.gold : Colors.white12,
                            width: s.id == _stage.id ? 3 : 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            StageBackdrop(stage: s, animate: false),
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: Container(
                                width: double.infinity,
                                color: Colors.black54,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: Text(s.name,
                                    style: const TextStyle(fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
