/// Global tuning values for Arena Fury. Change numbers here to rebalance the
/// whole game without hunting through components.
abstract final class GameConstants {
  // Virtual resolution of the fight camera (16:9 landscape).
  static const double worldWidth = 960;
  static const double worldHeight = 540;

  // Arena geometry
  static const double groundY = 468;
  static const double stageLeft = 50;
  static const double stageRight = 910;

  // Physics
  static const double gravity = 2300;
  static const double jumpVelocity = 880;

  // Fighter resources
  static const double maxHp = 1000;
  static const double maxMeter = 100;
  static const double sequenceComboCost = 50; // input-sequence combo
  static const double meterComboCost = 100; // COMBO button (full meter)

  // Match flow
  static const int roundsToWin = 2;
  static const double roundSeconds = 60;

  // Fighters can't stand closer than this (push boxes).
  static const double minFighterGap = 58;

  // Roster: built-in + custom fighters share these slots.
  static const int maxRosterSlots = 6;

  // Input
  static const double comboInputWindow = 0.9; // seconds to enter a sequence
  static const double inputQueueWindow = 0.25; // buffered press while busy
}

double clampDouble(double v, double lo, double hi) =>
    v < lo ? lo : (v > hi ? hi : v);

double clamp01(double v) => clampDouble(v, 0, 1);
