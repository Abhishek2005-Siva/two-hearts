import 'package:flutter/material.dart';
import 'avatar_model.dart';
import 'avatar_painter.dart';

class AvatarWidget extends StatelessWidget {
  final AvatarConfig config;
  final double size;

  const AvatarWidget({
    super.key,
    required this.config,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.45,
      child: CustomPaint(
        painter: AvatarPainter(config: config),
      ),
    );
  }
}
