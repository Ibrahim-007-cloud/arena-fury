/// A skeletal pose for the procedural fighter renderer.
///
/// Limb angles are ABSOLUTE radians where 0 = pointing straight down and
/// positive values rotate toward the direction the fighter faces
/// (pi/2 = straight forward, pi = straight up). Using absolute angles makes
/// poses easy to author and lerp. [lean] tilts the torso forward (+) or back.
class Pose {
  const Pose({
    this.lean = 0,
    this.frontUpper = 0,
    this.frontFore = 0,
    this.backUpper = 0,
    this.backFore = 0,
    this.frontThigh = 0,
    this.frontShin = 0,
    this.backThigh = 0,
    this.backShin = 0,
    this.lift = 0,
  });

  final double lean;
  final double frontUpper;
  final double frontFore;
  final double backUpper;
  final double backFore;
  final double frontThigh;
  final double frontShin;
  final double backThigh;
  final double backShin;

  /// Extra pixels to raise the whole body (hops, uppercuts).
  final double lift;

  Pose copyWith({
    double? lean,
    double? frontUpper,
    double? frontFore,
    double? backUpper,
    double? backFore,
    double? frontThigh,
    double? frontShin,
    double? backThigh,
    double? backShin,
    double? lift,
  }) =>
      Pose(
        lean: lean ?? this.lean,
        frontUpper: frontUpper ?? this.frontUpper,
        frontFore: frontFore ?? this.frontFore,
        backUpper: backUpper ?? this.backUpper,
        backFore: backFore ?? this.backFore,
        frontThigh: frontThigh ?? this.frontThigh,
        frontShin: frontShin ?? this.frontShin,
        backThigh: backThigh ?? this.backThigh,
        backShin: backShin ?? this.backShin,
        lift: lift ?? this.lift,
      );

  static Pose lerp(Pose a, Pose b, double t) {
    double l(double x, double y) => x + (y - x) * t;
    return Pose(
      lean: l(a.lean, b.lean),
      frontUpper: l(a.frontUpper, b.frontUpper),
      frontFore: l(a.frontFore, b.frontFore),
      backUpper: l(a.backUpper, b.backUpper),
      backFore: l(a.backFore, b.backFore),
      frontThigh: l(a.frontThigh, b.frontThigh),
      frontShin: l(a.frontShin, b.frontShin),
      backThigh: l(a.backThigh, b.backThigh),
      backShin: l(a.backShin, b.backShin),
      lift: l(a.lift, b.lift),
    );
  }
}
