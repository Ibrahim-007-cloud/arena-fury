enum StageTheme { neonRooftop, sunsetTemple, frozenPeak, harborDocks }

class StageData {
  const StageData({
    required this.id,
    required this.name,
    required this.description,
    required this.theme,
  });

  final String id;
  final String name;
  final String description;
  final StageTheme theme;
}

abstract final class Stages {
  static const neonRooftop = StageData(
    id: 'neon_rooftop',
    name: 'Neon Rooftop',
    description: 'A midnight brawl above a glowing city.',
    theme: StageTheme.neonRooftop,
  );
  static const sunsetTemple = StageData(
    id: 'sunset_temple',
    name: 'Sunset Temple',
    description: 'Ancient pillars, burning desert sky.',
    theme: StageTheme.sunsetTemple,
  );
  static const frozenPeak = StageData(
    id: 'frozen_peak',
    name: 'Frozen Peak',
    description: 'Snowfall on a mountain-top ice field.',
    theme: StageTheme.frozenPeak,
  );
  static const harborDocks = StageData(
    id: 'harbor_docks',
    name: 'Harbor Docks',
    description: 'Wooden piers as the sun sinks into the sea.',
    theme: StageTheme.harborDocks,
  );

  static const all = [neonRooftop, sunsetTemple, frozenPeak, harborDocks];

  static StageData byId(String? id) =>
      all.firstWhere((s) => s.id == id, orElse: () => neonRooftop);
}
