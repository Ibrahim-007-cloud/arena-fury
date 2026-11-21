import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/models/app_user.dart';
import '../../data/models/fighter_config.dart';
import '../../data/roster.dart';
import '../../game/match_setup.dart';
import '../../services/app_services.dart';
import '../../widgets/fighter_figure.dart';
import '../studio/character_studio_screen.dart';
import 'stage_select_screen.dart';

/// Roster grid (max 6 slots). With a [mode] it picks P1 + CPU for a match;
/// without one it's the roster manager opened from "Character Studio".
class FighterSelectScreen extends StatefulWidget {
  const FighterSelectScreen({super.key, required this.user, this.mode});

  final AppUser user;
  final GameMode? mode;

  @override
  State<FighterSelectScreen> createState() => _FighterSelectScreenState();
}

class _FighterSelectScreenState extends State<FighterSelectScreen> {
  late final Stream<List<FighterConfig>> _customs =
      AppServices.fighters.watchCustomFighters(widget.user.uid);

  String? _p1Id;
  String? _cpuId;
  bool _choosingCpu = false;
  BotDifficulty _difficulty = BotDifficulty.normal;
  FighterConfig? _focus;

  bool get _managing => widget.mode == null;

  FighterConfig? _find(List<FighterConfig> roster, String? id) {
    for (final f in roster) {
      if (f.id == id) return f;
    }
    return null;
  }

  Future<void> _openStudio({FighterConfig? existing, required int customCount}) async {
    if (existing == null && customCount >= BuiltInRoster.maxCustomSlots) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('All custom slots are full — edit or delete a custom fighter.')));
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CharacterStudioScreen(user: widget.user, existing: existing),
    ));
  }

  void _tapFighter(FighterConfig f, int customCount) {
    setState(() => _focus = f);
    if (_managing) {
      if (!f.isBuiltIn) _openStudio(existing: f, customCount: customCount);
      return;
    }
    setState(() {
      if (_choosingCpu) {
        _cpuId = f.id;
      } else {
        _p1Id = f.id;
        _choosingCpu = true;
      }
    });
  }

  void _next(List<FighterConfig> roster) {
    final p1 = _find(roster, _p1Id);
    if (p1 == null) return;
    final cpu = _find(roster, _cpuId) ?? roster[math.Random().nextInt(roster.length)];
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => StageSelectScreen(
        user: widget.user,
        player: p1,
        opponent: cpu,
        difficulty: _difficulty,
        mode: widget.mode!,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_managing
            ? 'CHARACTER STUDIO — ROSTER'
            : (_choosingCpu ? 'CHOOSE YOUR OPPONENT' : 'CHOOSE YOUR FIGHTER')),
      ),
      body: StreamBuilder<List<FighterConfig>>(
        stream: _customs,
        builder: (context, snap) {
          final customs = snap.data ?? const <FighterConfig>[];
          final roster = [...BuiltInRoster.fighters, ...customs]
              .take(GameConstants.maxRosterSlots)
              .toList();
          final empty = GameConstants.maxRosterSlots - roster.length;
          final focus = _find(roster, _focus?.id) ?? _find(roster, _p1Id) ?? roster.first;

          return Row(
            children: [
              Expanded(
                flex: 3,
                child: GridView.count(
                  padding: const EdgeInsets.all(12),
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.25,
                  children: [
                    for (final f in roster)
                      _SlotCard(
                        config: f,
                        isP1: f.id == _p1Id,
                        isCpu: f.id == _cpuId,
                        editable: !f.isBuiltIn,
                        onTap: () => _tapFighter(f, customs.length),
                        onEdit: f.isBuiltIn
                            ? null
                            : () => _openStudio(existing: f, customCount: customs.length),
                      ),
                    for (var i = 0; i < empty; i++)
                      _EmptySlot(onTap: () => _openStudio(customCount: customs.length)),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: _DetailPanel(
                  config: focus,
                  managing: _managing,
                  choosingCpu: _choosingCpu,
                  difficulty: _difficulty,
                  showDifficulty: widget.mode == GameMode.arcade,
                  onDifficulty: (d) => setState(() => _difficulty = d),
                  onBackToP1: () => setState(() => _choosingCpu = false),
                  onNext: (!_managing && _p1Id != null && _choosingCpu)
                      ? () => _next(roster)
                      : null,
                  nextLabel: _cpuId == null ? 'RANDOM CPU →' : 'SELECT STAGE →',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.config,
    required this.isP1,
    required this.isCpu,
    required this.editable,
    required this.onTap,
    this.onEdit,
  });

  final FighterConfig config;
  final bool isP1;
  final bool isCpu;
  final bool editable;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final border = isP1 ? AppColors.p1 : (isCpu ? AppColors.cpu : Colors.white12);
    return Material(
      color: AppColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: border, width: isP1 || isCpu ? 3 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [config.primaryColor.withValues(alpha: 0.35), Colors.transparent],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              top: 4,
              bottom: 22,
              child: FighterFigure(config: config),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 4,
              child: Text(
                config.name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ),
            Positioned(
              top: 6,
              left: 6,
              child: Row(children: [
                if (isP1) const _Tag('P1', AppColors.p1),
                if (isCpu) const _Tag('CPU', AppColors.cpu),
                if (!config.isBuiltIn) const _Tag('CUSTOM', Color(0xFF00B8D4)),
              ]),
            ),
            if (onEdit != null)
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: onEdit,
                  tooltip: 'Edit in Studio',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
      );
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.03),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Colors.white24),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_a_photo_outlined, size: 32, color: Colors.white54),
              SizedBox(height: 6),
              Text('CREATE FIGHTER',
                  style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.config,
    required this.managing,
    required this.choosingCpu,
    required this.difficulty,
    required this.showDifficulty,
    required this.onDifficulty,
    required this.onBackToP1,
    required this.onNext,
    required this.nextLabel,
  });

  final FighterConfig config;
  final bool managing;
  final bool choosingCpu;
  final BotDifficulty difficulty;
  final bool showDifficulty;
  final ValueChanged<BotDifficulty> onDifficulty;
  final VoidCallback onBackToP1;
  final VoidCallback? onNext;
  final String nextLabel;

  @override
  Widget build(BuildContext context) {
    final m = config.moveset;
    final s = config.stats;
    return Container(
      color: AppColors.panel,
      padding: const EdgeInsets.all(14),
      child: ListView(
        children: [
          Text(config.name.toUpperCase(), style: AppTheme.headingStyle),
          Text('${m.name} • ${config.costume.label} • ${config.bodyType.label}',
              style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 8),
          _statRow('POWER', s.power),
          _statRow('SPEED', s.speed),
          _statRow('DEFENSE', s.defense),
          const Divider(height: 18),
          _move('LP', m.light.name),
          _move('HK', m.heavy.name),
          _move('SP', m.special.name),
          _move('COMBO', '${m.combo.name}  (${m.combo.hits} hits)'),
          Text('Sequence: ${m.sequenceLabel}  (½ meter) or COMBO button (full meter)',
              style: const TextStyle(color: AppColors.gold, fontSize: 11)),
          const SizedBox(height: 12),
          if (managing)
            const Text('Tap a custom fighter to edit it, or an empty slot to create one.',
                style: TextStyle(color: Colors.white60))
          else ...[
            if (showDifficulty) ...[
              const Text('CPU DIFFICULTY', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(height: 4),
              SegmentedButton<BotDifficulty>(
                segments: [
                  for (final d in BotDifficulty.values)
                    ButtonSegment(value: d, label: Text(d.label)),
                ],
                selected: {difficulty},
                onSelectionChanged: (v) => onDifficulty(v.first),
              ),
              const SizedBox(height: 10),
            ],
            if (choosingCpu)
              TextButton.icon(
                onPressed: onBackToP1,
                icon: const Icon(Icons.undo),
                label: const Text('Change my fighter'),
              ),
            FilledButton(onPressed: onNext, child: Text(nextLabel)),
          ],
        ],
      ),
    );
  }

  Widget _statRow(String label, int value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(width: 70, child: Text(label, style: const TextStyle(fontSize: 11))),
          for (var i = 0; i < 5; i++)
            Container(
              width: 18,
              height: 8,
              margin: const EdgeInsets.only(right: 3),
              color: i < value ? AppColors.accent : Colors.white12,
            ),
        ]),
      );

  Widget _move(String button, String name) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(
            width: 56,
            child: Text(button,
                style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.cyan, fontSize: 12)),
          ),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 13))),
        ]),
      );
}
