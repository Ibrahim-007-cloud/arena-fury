import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../data/models/stage_data.dart';
import '../game/rendering/stage_painter.dart';

/// Paints a stage (cover-fit) in normal Flutter UI, optionally animated.
class StageCustomPainter extends CustomPainter {
  StageCustomPainter({required this.stage, this.animation}) : super(repaint: animation);

  final StageData stage;
  final Animation<double>? animation;

  @override
  void paint(Canvas canvas, Size size) {
    final t = (animation?.value ?? 0) * 60;
    const w = GameConstants.worldWidth, h = GameConstants.worldHeight;
    final scale = math.max(size.width / w, size.height / h);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate((size.width - w * scale) / 2, (size.height - h * scale) / 2);
    canvas.scale(scale);
    StagePainter.paint(canvas, stage, t);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant StageCustomPainter oldDelegate) => oldDelegate.stage != stage;
}

class StageBackdrop extends StatefulWidget {
  const StageBackdrop({super.key, required this.stage, this.animate = true, this.dim = 0});

  final StageData stage;
  final bool animate;
  final double dim;

  @override
  State<StageBackdrop> createState() => _StageBackdropState();
}

class _StageBackdropState extends State<StageBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 60));

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(painter: StageCustomPainter(stage: widget.stage, animation: _c)),
        ),
        if (widget.dim > 0) ColoredBox(color: Colors.black.withValues(alpha: widget.dim)),
      ],
    );
  }
}
