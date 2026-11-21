/// Stat points a player distributes in the Character Studio.
/// Each stat is 1..5 and the three together may not exceed [budget].
class FighterStats {
  const FighterStats({this.power = 3, this.speed = 3, this.defense = 3});

  final int power;
  final int speed;
  final int defense;

  static const int minStat = 1;
  static const int maxStat = 5;
  static const int budget = 10;

  int get total => power + speed + defense;
  int get remaining => budget - total;

  bool get isValid =>
      [power, speed, defense].every((s) => s >= minStat && s <= maxStat) &&
      total <= budget;

  /// Outgoing damage multiplier: 0.9 .. 1.3
  double get damageMultiplier => 0.8 + power * 0.1;

  /// Incoming damage multiplier: 1.08 .. 0.80
  double get damageTakenMultiplier => 1.15 - defense * 0.07;

  /// Walk speed in px/s: 175 .. 275
  double get walkSpeed => 150.0 + speed * 25.0;

  /// Attack animation speed multiplier: 0.94 .. 1.10
  double get frameSpeed => 0.9 + speed * 0.04;

  FighterStats copyWith({int? power, int? speed, int? defense}) => FighterStats(
        power: power ?? this.power,
        speed: speed ?? this.speed,
        defense: defense ?? this.defense,
      );

  Map<String, dynamic> toMap() =>
      {'power': power, 'speed': speed, 'defense': defense};

  factory FighterStats.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const FighterStats();
    int read(String key) {
      final v = (map[key] as num?)?.toInt() ?? 3;
      return v < minStat ? minStat : (v > maxStat ? maxStat : v);
    }

    return FighterStats(
      power: read('power'),
      speed: read('speed'),
      defense: read('defense'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FighterStats &&
      other.power == power &&
      other.speed == speed &&
      other.defense == defense;

  @override
  int get hashCode => Object.hash(power, speed, defense);
}
