import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../core/constants.dart';
import '../../data/models/fighter_config.dart';
import '../../data/models/fighter_stats.dart';
import '../../data/models/moveset.dart';
import '../fight_game.dart';
import '../input/fighter_controller.dart';
import '../input/input_buffer.dart';
import '../rendering/fighter_painter.dart';
import '../rendering/pose.dart';
import '../rendering/pose_library.dart';
import 'attack_box.dart';

enum FighterState {
  idle,
  walk,
  crouch,
  jump,
  attack,
  hitstun,
  blockstun,
  launched,
  knockdown,
  getUp,
  ko,
  victory,
}

enum _HurtMode { standing, crouching, lying }

/// One fighter on the stage: a small state machine + physics body with a
/// passive hurtbox and an [AttackBox] that switches on during active frames.
class Fighter extends PositionComponent with HasGameReference<FightGame> {
  Fighter({
    required this.config,
    required this.isPlayerOne,
    required Vector2 position,
    this.face,
    this.controller,
  })  : stats = config.stats,
        moveset = config.moveset,
        facingRight = isPlayerOne,
        super(
          position: position,
          size: Vector2(90, 190),
          anchor: Anchor.bottomCenter,
          priority: 10,
        );

  final FighterConfig config;
  final FighterStats stats;
  final Moveset moveset;
  final bool isPlayerOne;
  final ui.Image? face;
  FighterController? controller;
  late Fighter opponent;

  // Resources
  double hp = GameConstants.maxHp;
  double meter = 0;

  // State
  FighterState state = FighterState.idle;
  double stateTime = 0;
  double animTime = 0;
  bool facingRight;
  bool onGround = true;
  bool isKo = false;
  final Vector2 velocity = Vector2.zero();
  double stunTimer = 0;
  double flash = 0;
  double sinceHit = 99;
  bool _pendingVictory = false;

  // Attack
  AttackData? currentAttack;
  AttackPhase attackPhase = AttackPhase.startup;
  double attackTime = 0;
  int _currentSlice = -1;
  bool _sliceConnected = false;
  bool empoweredCombo = false;

  // Combos
  int comboCount = 0;
  int comboDisplayCount = 0;
  double comboDisplayTimer = 0;

  // Input
  final InputBuffer inputBuffer = InputBuffer();
  FighterIntent _lastIntent = FighterIntent.none;
  InputToken? _lastDirToken;
  FighterButton? _queued;
  double _queuedAt = 0;
  double _clock = 0;

  late final RectangleHitbox hurtbox;
  late final AttackBox attackBox;
  _HurtMode _hurtMode = _HurtMode.standing;

  static final _shadowPaint = Paint()..color = const Color(0x55000000);

  double get facingSign => facingRight ? 1 : -1;
  bool get canAct =>
      state == FighterState.idle ||
      state == FighterState.walk ||
      state == FighterState.crouch ||
      state == FighterState.jump;
  bool get isInHitReaction =>
      state == FighterState.hitstun || state == FighterState.launched;
  bool get isInvulnerable =>
      isKo ||
      state == FighterState.knockdown ||
      state == FighterState.getUp ||
      state == FighterState.ko;
  bool get isThreatening =>
      state == FighterState.attack && attackPhase != AttackPhase.recovery;
  bool get meterFull => meter >= GameConstants.maxMeter;

  /// Tekken-style blocking: hold AWAY from the opponent while grounded.
  bool get isBlocking {
    if (!onGround) return false;
    final holdingBack = _lastIntent.moveX * facingSign < -0.3;
    return holdingBack &&
        (state == FighterState.idle ||
            state == FighterState.walk ||
            state == FighterState.crouch ||
            state == FighterState.blockstun);
  }

  @override
  Future<void> onLoad() async {
    hurtbox = RectangleHitbox(
      position: Vector2(22, 34),
      size: Vector2(46, 156),
      collisionType: CollisionType.passive,
    );
    attackBox = AttackBox(owner: this);
    await addAll([hurtbox, attackBox]);
  }

  void resetForRound(double x) {
    hp = GameConstants.maxHp;
    position.setValues(x, GameConstants.groundY);
    velocity.setZero();
    onGround = true;
    isKo = false;
    _pendingVictory = false;
    currentAttack = null;
    comboCount = 0;
    comboDisplayTimer = 0;
    flash = 0;
    _queued = null;
    inputBuffer.clear();
    _lastIntent = FighterIntent.none;
    _setState(FighterState.idle);
    if (isLoaded) attackBox.disarm();
  }

  // ---------------------------------------------------------------------------
  // Update loop
  // ---------------------------------------------------------------------------

  @override
  void update(double dt) {
    super.update(dt);
    if (game.hitStopTimer > 0) return; // freeze-frame on impact

    _clock += dt;
    animTime += dt;
    stateTime += dt;
    sinceHit += dt;
    if (flash > 0) flash = math.max(0.0, flash - dt * 5);
    if (comboDisplayTimer > 0) comboDisplayTimer -= dt;
    if (comboCount > 0 && !opponent.isInHitReaction && opponent.onGround) {
      comboCount = 0;
    }

    final intent = (game.isFighting ? controller?.read(dt) : null) ?? FighterIntent.none;
    _lastIntent = intent;
    _trackDirection(intent);
    for (final b in intent.pressed) {
      _onButton(b);
    }

    _updateState(dt, intent);
    _applyPhysics(dt);
    _updateHurtbox();
    _updateAttackBox();
  }

  void _setState(FighterState s) {
    state = s;
    stateTime = 0;
  }

  void _faceOpponent() {
    final dx = opponent.position.x - position.x;
    if (dx.abs() > 4) facingRight = dx > 0;
  }

  void _updateState(double dt, FighterIntent intent) {
    switch (state) {
      case FighterState.idle:
      case FighterState.walk:
      case FighterState.crouch:
        _faceOpponent();
        if (intent.up && onGround) {
          velocity.setValues(intent.moveX * stats.walkSpeed * 1.05, -GameConstants.jumpVelocity);
          onGround = false;
          _setState(FighterState.jump);
          break;
        }
        if (intent.down) {
          if (state != FighterState.crouch) _setState(FighterState.crouch);
          velocity.x = 0;
        } else if (intent.moveX.abs() > 0.2) {
          final back = intent.moveX * facingSign < 0;
          velocity.x = intent.moveX.sign * stats.walkSpeed * (back ? 0.7 : 1.0);
          if (state != FighterState.walk) _setState(FighterState.walk);
        } else {
          velocity.x = 0;
          if (state != FighterState.idle) _setState(FighterState.idle);
        }
        _tryQueued();
      case FighterState.jump:
        break; // landing handled in _onLand
      case FighterState.attack:
        _updateAttack(dt);
      case FighterState.hitstun:
      case FighterState.blockstun:
        stunTimer -= dt;
        if (stunTimer <= 0) _setState(FighterState.idle);
      case FighterState.launched:
        break; // lands into knockdown
      case FighterState.knockdown:
        if (!isKo && stateTime > 0.7) _setState(FighterState.getUp);
      case FighterState.getUp:
        if (stateTime > 0.35) _setState(FighterState.idle);
      case FighterState.ko:
      case FighterState.victory:
        velocity.x = 0;
    }
  }

  void _applyPhysics(double dt) {
    if (!onGround) velocity.y += GameConstants.gravity * dt;

    final dashing = state == FighterState.attack &&
        currentAttack?.special == SpecialKind.dash &&
        attackPhase == AttackPhase.active;
    if (onGround && !dashing && state != FighterState.walk) {
      velocity.x *= math.max(0.0, 1 - 9 * dt);
    }

    position.x += velocity.x * dt;
    position.y += velocity.y * dt;

    if (position.y >= GameConstants.groundY) {
      position.y = GameConstants.groundY;
      if (!onGround) {
        onGround = true;
        velocity.y = 0;
        _onLand();
      }
    }
    position.x = clampDouble(position.x, GameConstants.stageLeft, GameConstants.stageRight);
  }

  void _onLand() {
    switch (state) {
      case FighterState.jump:
        _setState(_pendingVictory ? FighterState.victory : FighterState.idle);
        _faceOpponent();
      case FighterState.launched:
        game.shake(3, 0.12);
        _setState(isKo ? FighterState.ko : FighterState.knockdown);
      case FighterState.attack:
        velocity.x *= 0.4;
      default:
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Input -> attacks
  // ---------------------------------------------------------------------------

  void _trackDirection(FighterIntent intent) {
    InputToken? token;
    if (intent.down) {
      token = InputToken.down;
    } else if (intent.up) {
      token = InputToken.up;
    } else if (intent.moveX * facingSign > 0.5) {
      token = InputToken.forward;
    } else if (intent.moveX * facingSign < -0.5) {
      token = InputToken.back;
    }
    if (token != null && token != _lastDirToken) inputBuffer.add(token, _clock);
    _lastDirToken = token;
  }

  static InputToken? _tokenFor(FighterButton b) => switch (b) {
        FighterButton.light => InputToken.light,
        FighterButton.heavy => InputToken.heavy,
        FighterButton.special => InputToken.special,
        FighterButton.combo => null,
      };

  void _onButton(FighterButton b) {
    final token = _tokenFor(b);
    if (token != null) inputBuffer.add(token, _clock);

    if (canAct) {
      _perform(b);
      return;
    }
    // Busy: a sequence combo may cancel the recovery of a normal attack...
    if (state == FighterState.attack &&
        attackPhase == AttackPhase.recovery &&
        currentAttack?.slot != AttackSlot.combo &&
        _sequenceComboReady()) {
      _startSequenceCombo();
      return;
    }
    // ...otherwise buffer the press briefly so inputs feel responsive.
    _queued = b;
    _queuedAt = _clock;
  }

  void _tryQueued() {
    final q = _queued;
    if (q == null) return;
    _queued = null;
    if (_clock - _queuedAt <= GameConstants.inputQueueWindow) _perform(q);
  }

  bool _sequenceComboReady() =>
      meter >= GameConstants.sequenceComboCost &&
      inputBuffer.matches(moveset.comboSequence, _clock);

  void _startSequenceCombo() {
    meter -= GameConstants.sequenceComboCost;
    inputBuffer.clear();
    _startAttack(moveset.combo);
  }

  void _perform(FighterButton b) {
    if (b == FighterButton.combo) {
      if (meter >= GameConstants.meterComboCost && onGround) {
        meter -= GameConstants.meterComboCost;
        inputBuffer.clear();
        _startAttack(moveset.combo, empowered: true);
      }
      return;
    }
    if (onGround && _sequenceComboReady()) {
      _startSequenceCombo();
      return;
    }
    final slot = switch (b) {
      FighterButton.light => AttackSlot.light,
      FighterButton.heavy => AttackSlot.heavy,
      _ => AttackSlot.special,
    };
    if (slot == AttackSlot.special && !onGround) return; // no air specials
    _startAttack(moveset.attackFor(slot));
  }

  void _startAttack(AttackData a, {bool empowered = false}) {
    _faceOpponent();
    currentAttack = a;
    attackTime = 0;
    attackPhase = AttackPhase.startup;
    _currentSlice = -1;
    _sliceConnected = false;
    empoweredCombo = empowered;
    if (onGround) velocity.x = 0;
    _setState(FighterState.attack);
  }

  void _cancelAttack() {
    currentAttack = null;
    if (isLoaded) attackBox.disarm();
  }

  void _updateAttack(double dt) {
    final a = currentAttack;
    if (a == null) {
      _setState(FighterState.idle);
      return;
    }
    attackTime += dt * stats.frameSpeed;
    final phase = a.phaseAt(attackTime);
    if (phase == AttackPhase.active && attackPhase == AttackPhase.startup) {
      _onActiveStart(a);
    }
    attackPhase = phase;

    if (phase == AttackPhase.active) {
      final slice = a.sliceAt(attackTime);
      if (slice != _currentSlice) {
        _currentSlice = slice;
        _sliceConnected = false;
      }
      if (a.special == SpecialKind.dash) {
        velocity.x = facingSign * a.moveSpeed;
      } else if (a.slot == AttackSlot.combo && onGround) {
        velocity.x = facingSign * 70;
      }
    }

    if (attackTime >= a.totalTime) {
      currentAttack = null;
      _setState(onGround ? FighterState.idle : FighterState.jump);
    }
  }

  void _onActiveStart(AttackData a) {
    switch (a.special) {
      case SpecialKind.projectile:
        game.spawnProjectile(this, a);
      case SpecialKind.rising:
        velocity.setValues(facingSign * 140, -a.moveSpeed);
        onGround = false;
      case SpecialKind.dash:
      case SpecialKind.none:
        break;
    }
  }

  /// Called by [AttackBox] when the active hitbox overlaps [target]'s hurtbox.
  void onAttackContact(Fighter target, Set<Vector2> points) {
    final a = currentAttack;
    if (a == null ||
        _sliceConnected ||
        attackPhase != AttackPhase.active ||
        target != opponent) {
      return;
    }
    _sliceConnected = true; // one hit per slice; box disarms next frame
    Vector2 contact;
    if (points.isEmpty) {
      contact = attackBox.absoluteCenter;
    } else {
      contact = Vector2.zero();
      for (final p in points) {
        contact.add(p);
      }
      contact.scale(1 / points.length);
    }
    game.resolveHit(
      attacker: this,
      defender: target,
      attack: a,
      hitIndex: _currentSlice,
      contact: contact,
    );
  }

  // ---------------------------------------------------------------------------
  // Taking hits
  // ---------------------------------------------------------------------------

  void receiveHit({
    required AttackData attack,
    required double damage,
    required bool blocked,
    required double direction,
    required bool isFinalHit,
    bool allowKo = true,
  }) {
    hp = math.max(allowKo ? 0.0 : 1.0, hp - damage);
    sinceHit = 0;
    _cancelAttack();

    if (blocked) {
      _setState(FighterState.blockstun);
      stunTimer = attack.hitstun * 0.6;
      velocity.x = direction * attack.knockback * 0.6;
      return;
    }

    flash = 1;
    if (hp <= 0) {
      isKo = true;
      _launch(direction * 320, -560);
      return;
    }
    final shouldLaunch = isFinalHit && attack.launch > 0;
    if (shouldLaunch || !onGround) {
      _launch(
        direction * attack.knockback * (onGround ? 1 : 0.6),
        -(shouldLaunch ? attack.launch : 380.0),
      );
    } else {
      _setState(FighterState.hitstun);
      stunTimer = attack.hitstun;
      velocity.x = direction * attack.knockback;
    }
  }

  void _launch(double vx, double vy) {
    velocity.setValues(vx, vy);
    onGround = false;
    _setState(FighterState.launched);
  }

  void gainMeter(double amount) =>
      meter = math.min(GameConstants.maxMeter, meter + amount);

  void showCombo() {
    comboDisplayCount = comboCount;
    comboDisplayTimer = 1.2;
  }

  void celebrate() {
    if (isKo || state == FighterState.ko) return;
    _cancelAttack();
    if (onGround) {
      velocity.x = 0;
      _setState(FighterState.victory);
    } else {
      _pendingVictory = true;
    }
  }

  // ---------------------------------------------------------------------------
  // Hit/hurt boxes
  // ---------------------------------------------------------------------------

  void _updateHurtbox() {
    final crouching = state == FighterState.crouch ||
        (state == FighterState.blockstun && _lastIntent.down) ||
        (state == FighterState.attack && _lastIntent.down && onGround);
    final lying = state == FighterState.knockdown || state == FighterState.ko;
    final mode = lying
        ? _HurtMode.lying
        : (crouching ? _HurtMode.crouching : _HurtMode.standing);
    if (mode == _hurtMode) return;
    _hurtMode = mode;
    switch (mode) {
      case _HurtMode.standing:
        hurtbox.position.setValues(22, 34);
        hurtbox.size.setValues(46, 156);
      case _HurtMode.crouching:
        hurtbox.position.setValues(20, 100);
        hurtbox.size.setValues(50, 90);
      case _HurtMode.lying:
        hurtbox.position.setValues(5, 160);
        hurtbox.size.setValues(80, 30);
    }
  }

  void _updateAttackBox() {
    final a = currentAttack;
    final shouldArm = state == FighterState.attack &&
        a != null &&
        attackPhase == AttackPhase.active &&
        a.special != SpecialKind.projectile &&
        !_sliceConnected;
    if (shouldArm) {
      attackBox.arm(a.hitbox, facingRight: facingRight, fighterSize: size);
    } else {
      attackBox.disarm();
    }
  }

  // ---------------------------------------------------------------------------
  // Rendering
  // ---------------------------------------------------------------------------

  Pose currentPose() {
    switch (state) {
      case FighterState.idle:
        return PoseLibrary.idle(animTime);
      case FighterState.walk:
        return PoseLibrary.walk(animTime, forward: velocity.x * facingSign >= 0);
      case FighterState.crouch:
        return PoseLibrary.crouch(animTime);
      case FighterState.jump:
        return PoseLibrary.jump(velocity.y);
      case FighterState.attack:
        final a = currentAttack;
        return a == null ? PoseLibrary.stance : PoseLibrary.attack(a, attackTime);
      case FighterState.hitstun:
        return PoseLibrary.hit(stateTime);
      case FighterState.blockstun:
        return PoseLibrary.block(crouching: _lastIntent.down);
      case FighterState.launched:
        return PoseLibrary.launched(velocity.y);
      case FighterState.knockdown:
      case FighterState.ko:
        return PoseLibrary.knockdown;
      case FighterState.getUp:
        return PoseLibrary.getUp(stateTime / 0.35);
      case FighterState.victory:
        return PoseLibrary.victory(animTime);
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(size.x / 2, size.y);

    // Ground shadow (stays on the floor while jumping)
    final air = clampDouble(GameConstants.groundY - position.y, 0, 400);
    final s = clampDouble(1 - air / 500, 0.4, 1);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, air),
        width: 84 * config.bodyType.widthScale * s,
        height: 14 * s,
      ),
      _shadowPaint,
    );

    if (!facingRight) canvas.scale(-1, 1);

    Color? aura;
    if (state == FighterState.attack && currentAttack?.slot == AttackSlot.combo) {
      aura = currentAttack!.effectColor;
    } else if (meterFull && !isKo) {
      aura = const Color(0xFFFFC233).withValues(alpha: 0.6 + math.sin(animTime * 8) * 0.3);
    }

    FighterPainter.paint(canvas, config: config, pose: currentPose(), face: face, flash: flash, aura: aura);
    canvas.restore();

    if (game.showHitboxes) _renderDebugBoxes(canvas);
  }

  void _renderDebugBoxes(Canvas canvas) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(
      Rect.fromLTWH(hurtbox.position.x, hurtbox.position.y, hurtbox.size.x, hurtbox.size.y),
      stroke..color = const Color(0xFF00E676),
    );
    if (attackBox.isArmed) {
      canvas.drawRect(
        Rect.fromLTWH(attackBox.position.x, attackBox.position.y, attackBox.size.x, attackBox.size.y),
        Paint()..color = const Color(0x66FF1744),
      );
    }
  }
}
