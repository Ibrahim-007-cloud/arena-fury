import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/camera.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../data/models/fighter_config.dart';
import '../data/models/match_record.dart';
import '../data/models/moveset.dart';
import 'ai/bot_controller.dart';
import 'components/fighter.dart';
import 'components/hit_spark.dart';
import 'components/projectile.dart';
import 'components/stage_background.dart';
import 'hud/arcade_button.dart';
import 'hud/fighter_hud.dart';
import 'hud/match_hud.dart';
import 'input/fighter_controller.dart';
import 'input/player_input.dart';
import 'logic/combat_rules.dart';
import 'match_setup.dart';

enum MatchPhase { intro, fighting, roundOver, matchOver }

/// The combat loop: rounds, timer, hit resolution, hit-stop, camera shake,
/// push boxes and the on-screen controls.
class FightGame extends FlameGame with HasCollisionDetection {
  FightGame({
    required this.setup,
    this.faces = const {},
    this.onMatchFinished,
  }) : super(
          camera: CameraComponent.withFixedResolution(
            width: GameConstants.worldWidth,
            height: GameConstants.worldHeight,
          ),
        );

  final MatchSetup setup;

  /// Decoded selfie textures keyed by fighter id.
  final Map<String, ui.Image> faces;
  final void Function(MatchSummary summary)? onMatchFinished;

  final PlayerInputController playerInput = PlayerInputController();
  late final Fighter p1;
  late final Fighter p2;
  late final Announcer announcer;

  MatchPhase phase = MatchPhase.intro;
  int round = 1;
  int p1Rounds = 0;
  int p2Rounds = 0;
  double roundClock = GameConstants.roundSeconds;
  double elapsed = 0;
  double hitStopTimer = 0;
  bool showHitboxes = false;

  double _phaseTimer = 0;
  bool _fightCalled = false;
  bool _victoryPosed = false;
  bool _reported = false;
  bool _perfect = false;
  Fighter? _roundWinner;
  MatchSummary? summary;

  double _timeScale = 1;
  double _slowMoTimer = 0;
  double _shakeTimer = 0;
  double _shakeIntensity = 0;
  final _rng = math.Random();

  bool get isFighting => phase == MatchPhase.fighting;
  bool get isTraining => setup.mode == GameMode.training;

  @override
  Color backgroundColor() => const Color(0xFF000000);

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;

    world.add(StageBackground(stage: setup.stage));

    final mirror = setup.opponent.id == setup.player.id;
    p1 = Fighter(
      config: setup.player,
      isPlayerOne: true,
      position: Vector2(300, GameConstants.groundY),
      face: faces[setup.player.id],
      controller: playerInput,
    );
    p2 = Fighter(
      config: mirror ? _mirrorColors(setup.opponent) : setup.opponent,
      isPlayerOne: false,
      position: Vector2(660, GameConstants.groundY),
      face: faces[setup.opponent.id],
    );
    if (isTraining) {
      p2.controller = const IdleController();
    } else {
      p2.controller = BotController(self: p2, difficulty: setup.difficulty);
    }
    p1.opponent = p2;
    p2.opponent = p1;
    await world.addAll([p1, p2]);

    announcer = Announcer();
    camera.viewport.addAll([
      FighterHud(fighter: p1, leftSide: true),
      FighterHud(fighter: p2, leftSide: false),
      RoundTimerDisplay(),
      ComboCounterDisplay(fighter: p1, leftSide: true),
      ComboCounterDisplay(fighter: p2, leftSide: false),
      announcer,
    ]);
    _addTouchControls();
    _beginRound();
  }

  FighterConfig _mirrorColors(FighterConfig c) {
    Color shift(Color x) {
      final hsl = HSLColor.fromColor(x);
      return hsl.withHue((hsl.hue + 150) % 360).toColor();
    }

    return c.copyWith(primaryColor: shift(c.primaryColor), secondaryColor: shift(c.secondaryColor));
  }

  void _addTouchControls() {
    final joystick = JoystickComponent(
      knob: CircleComponent(radius: 26, paint: Paint()..color = const Color(0xCCFFFFFF)),
      background: CircleComponent(radius: 66, paint: Paint()..color = const Color(0x33FFFFFF)),
      position: Vector2(120, 412),
      anchor: Anchor.center,
      priority: 80,
    );
    playerInput.joystick = joystick;

    camera.viewport.addAll([
      joystick,
      ArcadeButton(
        label: 'LP',
        color: const Color(0xFF3D8BFF),
        position: Vector2(770, 468),
        onPressed: () => playerInput.press(FighterButton.light),
      ),
      ArcadeButton(
        label: 'HK',
        color: const Color(0xFFFF3D3D),
        position: Vector2(872, 440),
        onPressed: () => playerInput.press(FighterButton.heavy),
      ),
      ArcadeButton(
        label: 'SP',
        color: const Color(0xFFFF9800),
        position: Vector2(896, 342),
        onPressed: () => playerInput.press(FighterButton.special),
      ),
      ArcadeButton(
        label: 'COMBO',
        color: const Color(0xFFFFC233),
        radius: 34,
        position: Vector2(792, 372),
        isReady: () => p1.meterFull,
        onPressed: () => playerInput.press(FighterButton.combo),
      ),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Round flow
  // ---------------------------------------------------------------------------

  void _beginRound() {
    for (final p in world.children.whereType<Projectile>().toList()) {
      p.removeFromParent();
    }
    p1.resetForRound(300);
    p2.resetForRound(660);
    roundClock = GameConstants.roundSeconds;
    _fightCalled = false;
    _victoryPosed = false;
    _perfect = false;
    _roundWinner = null;
    _setPhase(MatchPhase.intro);
    final finalRound = p1Rounds == GameConstants.roundsToWin - 1 &&
        p2Rounds == GameConstants.roundsToWin - 1;
    announcer.show(
      isTraining ? 'TRAINING' : (finalRound ? 'FINAL ROUND' : 'ROUND $round'),
      duration: 1.0,
    );
  }

  void _setPhase(MatchPhase p) {
    phase = p;
    _phaseTimer = 0;
  }

  @override
  void update(double dt) {
    final clamped = math.min(dt, 1 / 30); // avoid tunnelling after a hitch
    if (_slowMoTimer > 0) {
      _slowMoTimer -= clamped;
      if (_slowMoTimer <= 0) _timeScale = 1;
    }
    final scaled = clamped * _timeScale;
    if (hitStopTimer > 0) hitStopTimer -= scaled;

    super.update(scaled);

    _separateFighters();
    _updateShake(scaled);
    _updatePhase(scaled);
  }

  void _updatePhase(double dt) {
    _phaseTimer += dt;
    switch (phase) {
      case MatchPhase.intro:
        if (!_fightCalled && _phaseTimer >= 1.0) {
          _fightCalled = true;
          announcer.show('FIGHT!', duration: 0.8, color: const Color(0xFFFFC233));
        }
        if (_phaseTimer >= 1.5) _setPhase(MatchPhase.fighting);
      case MatchPhase.fighting:
        elapsed += dt;
        if (isTraining) {
          _trainingUpkeep();
          return;
        }
        roundClock = math.max(0.0, roundClock - dt);
        if (p1.hp <= 0 || p2.hp <= 0) {
          _endRound(knockout: true);
        } else if (roundClock <= 0) {
          _endRound(knockout: false);
        }
      case MatchPhase.roundOver:
        if (!_victoryPosed && _phaseTimer > 1.3) {
          _victoryPosed = true;
          _roundWinner?.celebrate();
          if (_perfect) announcer.show('PERFECT!', color: const Color(0xFFFFC233));
        }
        if (_phaseTimer >= 3.2) {
          if (p1Rounds >= GameConstants.roundsToWin || p2Rounds >= GameConstants.roundsToWin) {
            _finishMatch();
          } else {
            round++;
            _beginRound();
          }
        }
      case MatchPhase.matchOver:
        if (!_reported && _phaseTimer > 1.6 && summary != null) {
          _reported = true;
          onMatchFinished?.call(summary!);
        }
    }
  }

  void _trainingUpkeep() {
    p1.meter = GameConstants.maxMeter;
    if (p2.hp < GameConstants.maxHp && p2.sinceHit > 1.5 && !p2.isInHitReaction) {
      p2.hp = GameConstants.maxHp;
    }
  }

  void _endRound({required bool knockout}) {
    Fighter? winner;
    if (knockout) {
      if (p1.hp > 0 && p2.hp <= 0) winner = p1;
      if (p2.hp > 0 && p1.hp <= 0) winner = p2;
    } else {
      if (p1.hp > p2.hp) winner = p1;
      if (p2.hp > p1.hp) winner = p2;
    }

    if (winner == null) {
      p1Rounds++;
      p2Rounds++;
      announcer.show(knockout ? 'DOUBLE K.O.' : 'DRAW', duration: 1.4);
    } else {
      if (winner == p1) {
        p1Rounds++;
      } else {
        p2Rounds++;
      }
      _perfect = winner.hp >= GameConstants.maxHp;
      announcer.show(knockout ? 'K.O.!' : 'TIME!', duration: 1.4, color: const Color(0xFFFF5252));
    }
    _roundWinner = winner;
    _setPhase(MatchPhase.roundOver);
  }

  void _finishMatch() {
    final MatchOutcome outcome;
    if (p1Rounds > p2Rounds) {
      outcome = MatchOutcome.win;
    } else if (p2Rounds > p1Rounds) {
      outcome = MatchOutcome.loss;
    } else {
      outcome = MatchOutcome.draw;
    }
    summary = MatchSummary(
      outcome: outcome,
      roundsWon: p1Rounds,
      roundsLost: p2Rounds,
      durationSeconds: elapsed,
    );
    announcer.show(
      switch (outcome) {
        MatchOutcome.win => 'YOU WIN!',
        MatchOutcome.loss => 'YOU LOSE',
        MatchOutcome.draw => 'DRAW GAME',
      },
      duration: 2.5,
      color: outcome == MatchOutcome.win ? const Color(0xFFFFC233) : Colors.white,
    );
    _setPhase(MatchPhase.matchOver);
  }

  // ---------------------------------------------------------------------------
  // Combat
  // ---------------------------------------------------------------------------

  /// Applies one hit. Returns false if the hit was ignored (e.g. the defender
  /// is invulnerable while getting up).
  bool resolveHit({
    required Fighter attacker,
    required Fighter defender,
    required AttackData attack,
    required int hitIndex,
    required Vector2 contact,
  }) {
    if (phase != MatchPhase.fighting || defender.isInvulnerable) return false;

    final isFinal = hitIndex >= attack.hits - 1;
    // Combo attacks are unblockable - that's what the meter buys you.
    final blocked = attack.slot != AttackSlot.combo && defender.isBlocking;

    if (!blocked) {
      attacker.comboCount = defender.isInHitReaction ? attacker.comboCount + 1 : 1;
    }

    final damage = CombatRules.computeDamage(
      attack: attack,
      attacker: attacker.stats,
      defender: defender.stats,
      blocked: blocked,
      comboCount: blocked ? 1 : attacker.comboCount,
      empowered: attack.slot == AttackSlot.combo && attacker.empoweredCombo,
    );

    final dir = attacker.position.x <= defender.position.x ? 1.0 : -1.0;
    defender.receiveHit(
      attack: attack,
      damage: damage,
      blocked: blocked,
      direction: dir,
      isFinalHit: isFinal,
      allowKo: !isTraining,
    );
    attacker.gainMeter(CombatRules.meterOnHit(attack, blocked: blocked));
    defender.gainMeter(CombatRules.meterOnDamageTaken(damage));
    if (!blocked && attacker.comboCount >= 2) attacker.showCombo();

    final heavy = attack.slot == AttackSlot.heavy ||
        attack.slot == AttackSlot.special ||
        (attack.slot == AttackSlot.combo && isFinal);
    hitStopTimer = blocked ? 0.035 : (heavy ? 0.11 : 0.06);
    if (!blocked) shake(heavy ? 7 : 3, heavy ? 0.22 : 0.1);

    world.add(HitSpark(
      position: contact.clone(),
      color: blocked ? const Color(0xFF80D8FF) : attack.effectColor,
      big: heavy,
      blocked: blocked,
    ));

    if (defender.hp <= 0) {
      _timeScale = 0.3; // dramatic K.O. slow-mo
      _slowMoTimer = 0.9;
      shake(10, 0.4);
    }
    return true;
  }

  void spawnProjectile(Fighter owner, AttackData attack) {
    final r = attack.hitbox;
    world.add(Projectile(
      owner: owner,
      attack: attack,
      direction: owner.facingSign,
      position: Vector2(
        owner.position.x + owner.facingSign * (r.left + r.width / 2),
        owner.position.y + r.top + r.height / 2,
      ),
    ));
  }

  bool hasIncomingProjectile(Fighter target) {
    for (final p in world.children.whereType<Projectile>()) {
      final dx = target.position.x - p.position.x;
      if (p.owner != target && dx * p.direction > 0 && dx.abs() < 320) return true;
    }
    return false;
  }

  /// Push boxes: fighters can't overlap while both are near the ground.
  void _separateFighters() {
    if ((p1.position.y - p2.position.y).abs() > 110) return; // jumping over
    final gap = GameConstants.minFighterGap *
        (p1.config.bodyType.widthScale + p2.config.bodyType.widthScale) /
        2;
    final dx = p2.position.x - p1.position.x;
    if (dx.abs() >= gap) return;
    final dir = dx == 0 ? (p1.facingRight ? 1.0 : -1.0) : dx.sign;
    final push = (gap - dx.abs()) / 2;
    p1.position.x -= dir * push;
    p2.position.x += dir * push;

    const lo = GameConstants.stageLeft, hi = GameConstants.stageRight;
    final p1Wall = p1.position.x <= lo || p1.position.x >= hi;
    p1.position.x = clampDouble(p1.position.x, lo, hi);
    p2.position.x = clampDouble(p2.position.x, lo, hi);
    if ((p2.position.x - p1.position.x).abs() < gap) {
      if (p1Wall) {
        p2.position.x = clampDouble(p1.position.x + dir * gap, lo, hi);
      } else {
        p1.position.x = clampDouble(p2.position.x - dir * gap, lo, hi);
      }
    }
  }

  void shake(double intensity, double duration) {
    _shakeIntensity = math.max(_shakeIntensity, intensity);
    _shakeTimer = math.max(_shakeTimer, duration);
  }

  void _updateShake(double dt) {
    final pos = camera.viewfinder.position;
    if (_shakeTimer > 0) {
      _shakeTimer -= dt;
      final i = _shakeIntensity * clamp01(_shakeTimer / 0.25);
      camera.viewfinder.position = Vector2(
        (_rng.nextDouble() * 2 - 1) * i,
        (_rng.nextDouble() * 2 - 1) * i,
      );
    } else if (pos.x != 0 || pos.y != 0) {
      camera.viewfinder.position = Vector2.zero();
      _shakeIntensity = 0;
    }
  }

  // Pause helpers used by the Flutter overlay.
  void pauseMatch() {
    playerInput.releaseAll();
    pauseEngine();
  }

  void resumeMatch() => resumeEngine();
}
