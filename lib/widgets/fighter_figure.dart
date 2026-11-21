import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/models/fighter_config.dart';
import '../game/rendering/fighter_painter.dart';
import '../game/rendering/pose.dart';
import '../game/rendering/pose_library.dart';
import '../services/face_cache.dart';

class FighterFigurePainter extends CustomPainter {
  FighterFigurePainter({required this.config, this.face, this.pose = PoseLibrary.stance});

  final FighterConfig config;
  final ui.Image? face;
  final Pose pose;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.height / 215;
    canvas.save();
    canvas.translate(size.width / 2, size.height - 6);
    canvas.scale(scale);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 84 * config.bodyType.widthScale, height: 12),
      Paint()..color = const Color(0x66000000),
    );
    FighterPainter.paint(canvas, config: config, pose: pose, face: face);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FighterFigurePainter old) =>
      old.config != config || old.face != face || old.pose != pose;
}

/// Static fighter portrait that loads the selfie texture (if any) on demand.
class FighterFigure extends StatefulWidget {
  const FighterFigure({super.key, required this.config});

  final FighterConfig config;

  @override
  State<FighterFigure> createState() => _FighterFigureState();
}

class _FighterFigureState extends State<FighterFigure> {
  ui.Image? _face;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant FighterFigure oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) _load();
  }

  Future<void> _load() async {
    final cfg = widget.config;
    _face = FaceCache.instance.peek(cfg);
    if (_face != null || !cfg.hasFace) {
      if (mounted) setState(() {});
      return;
    }
    final img = await FaceCache.instance.load(cfg);
    if (mounted && widget.config == cfg) setState(() => _face = img);
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: FighterFigurePainter(config: widget.config, face: _face),
      size: Size.infinite,
    );
  }
}
