import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../data/models/app_user.dart';
import '../../data/models/match_record.dart';
import '../../game/fight_game.dart';
import '../../game/input/fighter_controller.dart';
import '../../game/input/player_input.dart';
import '../../game/match_setup.dart';
import '../../services/app_services.dart';
import '../../services/face_cache.dart';

/// Hosts the Flame [FightGame] plus Flutter overlays (pause / results) and
/// keyboard support for emulators.
class FightScreen extends StatefulWidget {
  const FightScreen({super.key, required this.user, required this.setup});

  final AppUser user;
  final MatchSetup setup;

  @override
  State<FightScreen> createState() => _FightScreenState();
}

class _FightScreenState extends State<FightScreen> {
  FightGame? _game;
  MatchSummary? _summary;
  bool _saved = false;
  String? _saveError;
  final _focus = FocusNode();

  static final _dirKeys = <LogicalKeyboardKey, KeyDir>{
    LogicalKeyboardKey.arrowLeft: KeyDir.left,
    LogicalKeyboardKey.keyA: KeyDir.left,
    LogicalKeyboardKey.arrowRight: KeyDir.right,
    LogicalKeyboardKey.keyD: KeyDir.right,
    LogicalKeyboardKey.arrowUp: KeyDir.up,
    LogicalKeyboardKey.keyW: KeyDir.up,
    LogicalKeyboardKey.arrowDown: KeyDir.down,
    LogicalKeyboardKey.keyS: KeyDir.down,
  };

  static final _buttonKeys = <LogicalKeyboardKey, FighterButton>{
    LogicalKeyboardKey.keyJ: FighterButton.light,
    LogicalKeyboardKey.keyK: FighterButton.heavy,
    LogicalKeyboardKey.keyL: FighterButton.special,
    LogicalKeyboardKey.space: FighterButton.combo,
  };

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final faces = await FaceCache.instance.loadAll([widget.setup.player, widget.setup.opponent]);
    if (!mounted) return;
    setState(() {
      _game = FightGame(setup: widget.setup, faces: faces, onMatchFinished: _onFinished);
    });
  }

  void _onFinished(MatchSummary summary) {
    setState(() => _summary = summary);
    _game?.overlays.add('result');
    if (widget.setup.mode == GameMode.arcade) _record(summary);
  }

  Future<void> _record(MatchSummary s) async {
    final setup = widget.setup;
    final user = AppServices.auth.currentUser ?? widget.user;
    try {
      await AppServices.matches.recordMatch(
        user,
        MatchRecord(
          id: '',
          mode: setup.mode.name,
          playerFighterId: setup.player.id,
          playerFighterName: setup.player.name,
          opponentFighterId: setup.opponent.id,
          opponentFighterName: setup.opponent.name,
          stageId: setup.stage.id,
          outcome: s.outcome,
          roundsWon: s.roundsWon,
          roundsLost: s.roundsLost,
          difficulty: setup.difficulty.name,
          durationSeconds: s.durationSeconds.round(),
          playedAt: DateTime.now(),
        ),
      );
      if (mounted) setState(() => _saved = true);
    } catch (e) {
      if (mounted) setState(() => _saveError = e.toString());
    }
  }

  void _togglePause() {
    final g = _game;
    if (g == null || _summary != null) return;
    if (g.paused) {
      g.overlays.remove('pause');
      g.resumeMatch();
    } else {
      g.pauseMatch();
      g.overlays.add('pause');
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final g = _game;
    if (g == null) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final down = event is KeyDownEvent || event is KeyRepeatEvent;
    final dir = _dirKeys[key];
    if (dir != null) {
      if (down) {
        g.playerInput.keyboardDirs.add(dir);
      } else if (event is KeyUpEvent) {
        g.playerInput.keyboardDirs.remove(dir);
      }
      return KeyEventResult.handled;
    }
    final button = _buttonKeys[key];
    if (button != null) {
      if (event is KeyDownEvent) g.playerInput.press(button);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape && event is KeyDownEvent) {
      _togglePause();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _rematch() => Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) => FightScreen(user: widget.user, setup: widget.setup),
      ));

  void _quitToMenu() => Navigator.of(context).popUntil((r) => r.isFirst);

  @override
  Widget build(BuildContext context) {
    final game = _game;
    return Scaffold(
      backgroundColor: Colors.black,
      body: game == null
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('GET READY...', style: AppTheme.headingStyle),
                ],
              ),
            )
          : Focus(
              focusNode: _focus,
              autofocus: true,
              onKeyEvent: _onKey,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GameWidget<FightGame>(
                      game: game,
                      overlayBuilderMap: {
                        'pause': (context, g) => _PauseMenu(
                              game: g,
                              onResume: _togglePause,
                              onQuit: _quitToMenu,
                            ),
                        'result': (context, g) => _ResultPanel(
                              summary: _summary,
                              setup: widget.setup,
                              saved: _saved,
                              saveError: _saveError,
                              onRematch: _rematch,
                              onNewStage: () => Navigator.of(context).pop(),
                              onMenu: _quitToMenu,
                            ),
                      },
                    ),
                  ),
                  Positioned(
                    bottom: 6,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: IconButton.filledTonal(
                        onPressed: _togglePause,
                        icon: const Icon(Icons.pause),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _PauseMenu extends StatefulWidget {
  const _PauseMenu({required this.game, required this.onResume, required this.onQuit});

  final FightGame game;
  final VoidCallback onResume;
  final VoidCallback onQuit;

  @override
  State<_PauseMenu> createState() => _PauseMenuState();
}

class _PauseMenuState extends State<_PauseMenu> {
  @override
  Widget build(BuildContext context) {
    final m = widget.game.p1.moveset;
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Card(
          color: AppColors.panel,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('PAUSED', style: AppTheme.headingStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  Text(
                    'Move: joystick / WASD • Block: hold away • Jump/Crouch: up/down\n'
                    'LP ${m.light.name} (J) • HK ${m.heavy.name} (K) • SP ${m.special.name} (L)\n'
                    'COMBO ${m.combo.name}: ${m.sequenceLabel} with ½ meter, '
                    'or COMBO button (Space) with full meter',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  SwitchListTile(
                    title: const Text('Show hitboxes'),
                    value: widget.game.showHitboxes,
                    onChanged: (v) => setState(() => widget.game.showHitboxes = v),
                  ),
                  FilledButton(onPressed: widget.onResume, child: const Text('RESUME')),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: widget.onQuit, child: const Text('QUIT TO MENU')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.summary,
    required this.setup,
    required this.saved,
    required this.saveError,
    required this.onRematch,
    required this.onNewStage,
    required this.onMenu,
  });

  final MatchSummary? summary;
  final MatchSetup setup;
  final bool saved;
  final String? saveError;
  final VoidCallback onRematch;
  final VoidCallback onNewStage;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    if (s == null) return const SizedBox.shrink();
    final win = s.outcome == MatchOutcome.win;
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              s.outcome.label.toUpperCase(),
              style: AppTheme.titleStyle.copyWith(color: win ? AppColors.gold : Colors.white),
            ),
            Text(
              '${setup.player.name}  ${s.roundsWon} – ${s.roundsLost}  ${setup.opponent.name}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              saveError != null
                  ? 'Could not save result: $saveError'
                  : (saved ? 'Result saved to your record ✓' : 'Saving result...'),
              style: TextStyle(color: saveError != null ? const Color(0xFFFF8A80) : Colors.white60),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              children: [
                FilledButton(onPressed: onRematch, child: const Text('REMATCH')),
                OutlinedButton(onPressed: onNewStage, child: const Text('CHANGE STAGE')),
                OutlinedButton(onPressed: onMenu, child: const Text('MAIN MENU')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
