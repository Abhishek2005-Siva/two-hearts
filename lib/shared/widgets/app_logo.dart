import 'package:flutter/material.dart';

class TwoHeartsLogo extends StatelessWidget {
  final double size;

  const TwoHeartsLogo({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _TwoHeartsPainter()),
    );
  }
}

class _TwoHeartsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Glow
    final glowPaint = Paint()
      ..color = const Color(0xFFFF6B8A).withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawPath(_heart(w * 0.55, h * 0.55, w * 0.08, h * 0.08), glowPaint);
    canvas.drawPath(_heart(w * 0.55, h * 0.55, w * 0.38, h * 0.38), glowPaint);

    // Back heart (coral)
    final backPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFF8C42), Color(0xFFFFB347)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(w * 0.3, h * 0.3, w * 0.7, h * 0.7))
      ..style = PaintingStyle.fill;
    canvas.drawPath(_heart(w * 0.55, h * 0.55, w * 0.38, h * 0.38), backPaint);

    // Front heart (rose)
    final frontPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFF6B8A), Color(0xFFC94B6D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w * 0.7, h * 0.7))
      ..style = PaintingStyle.fill;
    canvas.drawPath(_heart(w * 0.08, h * 0.08, w * 0.38, h * 0.38), frontPaint);
  }

  // Draws a heart at (cx, cy) filling into a bounding box of (bw x bh)
  Path _heart(double cx, double cy, double bw, double bh) {
    final path = Path();
    path.moveTo(cx + bw * 0.5, cy + bh * 0.25);
    path.cubicTo(cx + bw * 0.5, cy + bh * 0.225, cx + bw * 0.45, cy + bh * 0.1, cx + bw * 0.25, cy + bh * 0.1);
    path.cubicTo(cx, cy + bh * 0.1, cx, cy + bh * 0.4375, cx, cy + bh * 0.4375);
    path.cubicTo(cx, cy + bh * 0.625, cx + bw * 0.125, cy + bh * 0.7625, cx + bw * 0.5, cy + bh * 0.9);
    path.cubicTo(cx + bw * 0.875, cy + bh * 0.7625, cx + bw, cy + bh * 0.625, cx + bw, cy + bh * 0.4375);
    path.cubicTo(cx + bw, cy + bh * 0.4375, cx + bw, cy + bh * 0.1, cx + bw * 0.75, cy + bh * 0.1);
    path.cubicTo(cx + bw * 0.6, cy + bh * 0.1, cx + bw * 0.5, cy + bh * 0.225, cx + bw * 0.5, cy + bh * 0.25);
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AnimatedLogo extends StatefulWidget {
  final double size;
  const AnimatedLogo({super.key, this.size = 64});

  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: TwoHeartsLogo(size: widget.size),
    );
  }
}
