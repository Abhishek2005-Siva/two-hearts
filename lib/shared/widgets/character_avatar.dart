import 'package:flutter/material.dart';

/// Animated 3D-style character that represents one person in the couple.
/// Draws a floating person figure with a glowing sphere head, body, and arms.
class CharacterAvatar extends StatefulWidget {
  final Color color;
  final String name;
  final double size;

  const CharacterAvatar({
    super.key,
    required this.color,
    required this.name,
    this.size = 100,
  });

  @override
  State<CharacterAvatar> createState() => _CharacterAvatarState();
}

class _CharacterAvatarState extends State<CharacterAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _float = Tween<double>(begin: -6.0, end: 6.0).animate(
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
    final initial =
        widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '♡';
    return AnimatedBuilder(
      animation: _float,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _float.value),
        child: SizedBox(
          width: widget.size,
          height: widget.size * 1.45,
          child: CustomPaint(
            painter: _CharacterPainter(
              color: widget.color,
              initial: initial,
            ),
          ),
        ),
      ),
    );
  }
}

class _CharacterPainter extends CustomPainter {
  final Color color;
  final String initial;

  const _CharacterPainter({required this.color, required this.initial});

  // ── Colour helpers ──────────────────────────────────────────────────────

  int _ch(double v) => v.round().clamp(0, 255);

  Color _lighten(Color c, double t) => Color.fromARGB(
        _ch(c.a * 255),
        _ch(c.r * 255 + (255 - c.r * 255) * t),
        _ch(c.g * 255 + (255 - c.g * 255) * t),
        _ch(c.b * 255 + (255 - c.b * 255) * t),
      );

  Color _darken(Color c, double t) => Color.fromARGB(
        _ch(c.a * 255),
        _ch(c.r * 255 * (1 - t)),
        _ch(c.g * 255 * (1 - t)),
        _ch(c.b * 255 * (1 - t)),
      );

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // ── Ground shadow ──────────────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, h * 0.97), width: w * 0.52, height: h * 0.05),
      Paint()
        ..color = color.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // ── Body ───────────────────────────────────────────────────────────────
    final bodyW = w * 0.48;
    final bodyTop = h * 0.47;
    final bodyBot = h * 0.88;
    final bodyRect = Rect.fromCenter(
      center: Offset(cx, (bodyTop + bodyBot) / 2),
      width: bodyW,
      height: bodyBot - bodyTop,
    );

    final bodyPath = Path()
      ..moveTo(cx - bodyW * 0.38, bodyTop + 2)
      ..lineTo(cx - bodyW / 2, bodyBot - 10)
      ..quadraticBezierTo(cx - bodyW / 2, bodyBot, cx - bodyW / 2 + 10, bodyBot)
      ..lineTo(cx + bodyW / 2 - 10, bodyBot)
      ..quadraticBezierTo(cx + bodyW / 2, bodyBot, cx + bodyW / 2, bodyBot - 10)
      ..lineTo(cx + bodyW * 0.38, bodyTop + 2)
      ..quadraticBezierTo(cx, bodyTop - 2, cx - bodyW * 0.38, bodyTop + 2)
      ..close();

    canvas.drawPath(
      bodyPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_lighten(color, 0.28), color, _darken(color, 0.28)],
        ).createShader(bodyRect),
    );

    // Body highlight
    canvas.drawPath(
      bodyPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.22),
            Colors.transparent,
          ],
        ).createShader(bodyRect),
    );

    // ── Arms ───────────────────────────────────────────────────────────────
    final armPaint = Paint()
      ..color = _lighten(color, 0.12)
      ..strokeWidth = w * 0.085
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Left arm curves down and outward
    canvas.drawPath(
      Path()
        ..moveTo(cx - bodyW * 0.36, bodyTop + h * 0.05)
        ..cubicTo(
          cx - bodyW * 0.55, bodyTop + h * 0.10,
          cx - bodyW * 0.58, bodyTop + h * 0.19,
          cx - bodyW * 0.50, bodyTop + h * 0.27,
        ),
      armPaint,
    );

    // Right arm
    canvas.drawPath(
      Path()
        ..moveTo(cx + bodyW * 0.36, bodyTop + h * 0.05)
        ..cubicTo(
          cx + bodyW * 0.55, bodyTop + h * 0.10,
          cx + bodyW * 0.58, bodyTop + h * 0.19,
          cx + bodyW * 0.50, bodyTop + h * 0.27,
        ),
      armPaint,
    );

    // ── Neck ───────────────────────────────────────────────────────────────
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, bodyTop - h * 0.022), width: w * 0.12, height: h * 0.055),
      Paint()..color = _lighten(color, 0.18),
    );

    // ── Head ───────────────────────────────────────────────────────────────
    final headR = w * 0.265;
    final headC = Offset(cx, bodyTop - headR * 0.85);

    // Outer aura glow
    canvas.drawCircle(
      headC,
      headR + 10,
      Paint()
        ..color = color.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // Drop shadow under head
    canvas.drawCircle(
      headC + const Offset(2, 5),
      headR,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Head sphere — radial gradient for 3D depth
    canvas.drawCircle(
      headC,
      headR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.42),
          radius: 0.88,
          colors: [
            _lighten(color, 0.60),
            _lighten(color, 0.18),
            _darken(color, 0.12),
          ],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(Rect.fromCircle(center: headC, radius: headR)),
    );

    // Specular highlight — simulates light from upper-left
    canvas.drawCircle(
      headC,
      headR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.46, -0.52),
          radius: 0.52,
          colors: [
            Colors.white.withValues(alpha: 0.60),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: headC, radius: headR)),
    );

    // Thin rim light
    canvas.drawCircle(
      headC,
      headR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = Colors.white.withValues(alpha: 0.18),
    );

    // ── Initial letter ─────────────────────────────────────────────────────
    final tp = TextPainter(
      text: TextSpan(
        text: initial,
        style: TextStyle(
          fontSize: headR * 0.88,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: const [
            Shadow(color: Colors.black38, offset: Offset(1, 2), blurRadius: 4),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, headC - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _CharacterPainter old) =>
      old.color != color || old.initial != initial;
}
