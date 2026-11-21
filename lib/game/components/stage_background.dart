import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants.dart';
import '../../data/models/stage_data.dart';
import '../rendering/stage_painter.dart';

class StageBackground extends PositionComponent {
  StageBackground({required this.stage})
      : super(
          size: Vector2(GameConstants.worldWidth, GameConstants.worldHeight),
          priority: -10,
        );

  final StageData stage;
  double _t = 0;

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) => StagePainter.paint(canvas, stage, _t);
}
