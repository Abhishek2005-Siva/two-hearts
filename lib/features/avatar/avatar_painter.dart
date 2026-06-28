import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'avatar_model.dart';

// ── Color palettes ────────────────────────────────────────────────────────────

const List<Color> kSkinTones = [
  Color(0xFFFDE8D0), // porcelain
  Color(0xFFF5C9A0), // fair
  Color(0xFFE8A87C), // light
  Color(0xFFD4845A), // medium
  Color(0xFFA05C3A), // tan
  Color(0xFF6B3520), // deep
];

const List<Color> kHairColors = [
  Color(0xFF1A1A1A), // black
  Color(0xFF3B2314), // dark brown
  Color(0xFF7B3F00), // chestnut
  Color(0xFF922B21), // auburn
  Color(0xFFDAA520), // blonde
  Color(0xFFE8DCC8), // platinum
  Color(0xFF922B0A), // red
];

const List<Color> kEyeColors = [
  Color(0xFF3B1F0A), // dark brown
  Color(0xFF7B6914), // hazel
  Color(0xFF2D6A4F), // green
  Color(0xFF1A5276), // blue
  Color(0xFF5D6D7E), // grey
];

const List<Color> kOutfitColors = [
  Color(0xFFB8A4D4), // lavender
  Color(0xFFE8B49A), // peach
  Color(0xFFF0E8D8), // cream
  Color(0xFFD4849A), // dusty pink
  Color(0xFF94B4A4), // sage
];

// ── AvatarPainter ─────────────────────────────────────────────────────────────

class AvatarPainter extends CustomPainter {
  final AvatarConfig config;

  const AvatarPainter({required this.config});

  @override
  bool shouldRepaint(AvatarPainter old) => old.config != config;

  // ── Palette helpers ───────────────────────────────────────────────────────

  Color get _skin   => kSkinTones[config.skinTone.clamp(0, kSkinTones.length - 1)];
  Color get _hair   => kHairColors[config.hairColor.clamp(0, kHairColors.length - 1)];
  Color get _eye    => kEyeColors[config.eyeColor.clamp(0, kEyeColors.length - 1)];
  Color get _outfit => kOutfitColors[config.outfitColor.clamp(0, kOutfitColors.length - 1)];

  Color _lighten(Color c, double t) => Color.lerp(c, Colors.white, t)!;
  Color _darken(Color c, double t)  => Color.lerp(c, Colors.black, t)!;

  Paint _fill(Color c) => Paint()
    ..color = c
    ..style = PaintingStyle.fill;

  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round;

  // ── Hair gradient helper ──────────────────────────────────────────────────

  Paint _hairPaint(Color hair, Rect bounds) {
    final hi = _lighten(hair, 0.25);
    final sh = _darken(hair, 0.15);
    return Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [hi, hair, sh],
        stops: const [0.0, 0.50, 1.0],
      ).createShader(bounds);
  }

  // ── Main paint ────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    final w  = size.width;
    final h  = size.height;
    final cx = w / 2;

    // Layout constants
    final headR  = w * 0.285;
    final headCY = h * 0.30;
    final headC  = Offset(cx, headCY);

    final bodyTop = headCY + headR * 0.55;
    final bodyW   = w * 0.70;
    final bodyH   = h * 0.40;
    final bodyBot = bodyTop + bodyH;

    // ── Layer 1: Drop shadow ──────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, h * 0.96), width: w * 0.60, height: h * 0.04),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // ── Layers 2–3: Back hair (behind everything) ─────────────────────────
    _drawHairBack(canvas, headC, headR, cx, bodyBot, h);

    // ── Layer 4: Body / outfit ────────────────────────────────────────────
    _drawBody(canvas, cx, bodyTop, bodyBot, bodyW, h);

    // ── Layer 5: Neck ─────────────────────────────────────────────────────
    final neckW  = w * 0.14;
    final neckH  = headR * 0.40;
    final neckCY = bodyTop - neckH * 0.20;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, neckCY), width: neckW, height: neckH),
        Radius.circular(neckW * 0.40),
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_lighten(_skin, 0.08), _skin, _darken(_skin, 0.10)],
        ).createShader(Rect.fromCenter(
            center: Offset(cx, neckCY), width: neckW, height: neckH)),
    );

    // ── Layer 6: Ears ─────────────────────────────────────────────────────
    _drawEars(canvas, headC, headR);

    // ── Layer 7: Head ─────────────────────────────────────────────────────
    _drawHead(canvas, headC, headR);

    // ── Layer 8: Hair front ───────────────────────────────────────────────
    _drawHairFront(canvas, headC, headR, cx, bodyBot, h);

    // ── Layer 9: Blush ────────────────────────────────────────────────────
    final blushPaint = Paint()
      ..color = const Color(0xFFFF9BAA).withValues(alpha: 0.35)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, headR * 0.22);
    canvas.drawCircle(
        Offset(headC.dx - headR * 0.50, headC.dy + headR * 0.18),
        headR * 0.22, blushPaint);
    canvas.drawCircle(
        Offset(headC.dx + headR * 0.50, headC.dy + headR * 0.18),
        headR * 0.22, blushPaint);

    // ── Layer 10: Eyes ────────────────────────────────────────────────────
    _drawEyes(canvas, headC, headR);

    // ── Layer 11: Eyebrows ────────────────────────────────────────────────
    _drawEyebrows(canvas, headC, headR);

    // ── Layer 12: Nose ────────────────────────────────────────────────────
    final nostrilColor = _darken(_skin, 0.28);
    final nostrilPaint = Paint()
      ..color = nostrilColor.withValues(alpha: 0.70)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
    canvas.drawCircle(
        Offset(headC.dx - headR * 0.07, headC.dy + headR * 0.18),
        headR * 0.038, nostrilPaint);
    canvas.drawCircle(
        Offset(headC.dx + headR * 0.07, headC.dy + headR * 0.18),
        headR * 0.038, nostrilPaint);

    // ── Layer 13: Mouth ───────────────────────────────────────────────────
    final mouthPath = Path()
      ..moveTo(headC.dx - headR * 0.16, headC.dy + headR * 0.34)
      ..quadraticBezierTo(
          headC.dx, headC.dy + headR * 0.48,
          headC.dx + headR * 0.16, headC.dy + headR * 0.34);
    canvas.drawPath(
      mouthPath,
      Paint()
        ..color = _darken(_skin, 0.32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = headR * 0.058
        ..strokeCap = StrokeCap.round,
    );

    // ── Layer 14: Accessory ───────────────────────────────────────────────
    _drawAccessory(canvas, headC, headR, cx, bodyTop);
  }

  // ── Ears ──────────────────────────────────────────────────────────────────

  void _drawEars(Canvas canvas, Offset headC, double headR) {
    final earR  = headR * 0.20;
    final earY  = headC.dy + headR * 0.05;
    final skin  = _skin;
    final earPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.30, -0.30),
        radius: 0.90,
        colors: [_lighten(skin, 0.12), skin, _darken(skin, 0.12)],
      ).createShader(Rect.fromCircle(
          center: Offset(headC.dx - headR * 0.92, earY), radius: earR));

    // Left ear
    canvas.drawCircle(Offset(headC.dx - headR * 0.92, earY), earR, earPaint);
    // Right ear — re-create shader for correct offset
    canvas.drawCircle(
      Offset(headC.dx + headR * 0.92, earY),
      earR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.30, -0.30),
          radius: 0.90,
          colors: [_lighten(skin, 0.12), skin, _darken(skin, 0.12)],
        ).createShader(Rect.fromCircle(
            center: Offset(headC.dx + headR * 0.92, earY), radius: earR)),
    );
    // Inner ear blush
    final innerPaint = Paint()
      ..color = const Color(0xFFFFB8B8).withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(
        Offset(headC.dx - headR * 0.92, earY), earR * 0.58, innerPaint);
    canvas.drawCircle(
        Offset(headC.dx + headR * 0.92, earY), earR * 0.58, innerPaint);
  }

  // ── Head ──────────────────────────────────────────────────────────────────

  void _drawHead(Canvas canvas, Offset headC, double headR) {
    final skin  = _skin;
    final shape = config.faceShape;

    // Soft ambient shadow under head
    canvas.drawCircle(
      headC + Offset(headR * 0.04, headR * 0.08),
      headR + 3,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Build shaded skin paint
    final headRect = Rect.fromCircle(center: headC, radius: headR);
    final skinPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.38, -0.42),
        radius: 1.10,
        colors: [
          _lighten(skin, 0.22),
          skin,
          _darken(skin, 0.14),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(headRect);

    switch (shape) {
      case 1: // oval
        final ovalRect = Rect.fromCenter(
            center: headC, width: headR * 1.85, height: headR * 2.16);
        canvas.drawOval(ovalRect,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.38, -0.42),
              radius: 1.10,
              colors: [_lighten(skin, 0.22), skin, _darken(skin, 0.14)],
              stops: const [0.0, 0.55, 1.0],
            ).createShader(ovalRect));
      case 2: // soft square
        final sqRect = Rect.fromCenter(
            center: headC, width: headR * 2.0, height: headR * 1.96);
        canvas.drawRRect(
          RRect.fromRectAndRadius(sqRect, Radius.circular(headR * 0.75)),
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.38, -0.42),
              radius: 1.10,
              colors: [_lighten(skin, 0.22), skin, _darken(skin, 0.14)],
              stops: const [0.0, 0.55, 1.0],
            ).createShader(sqRect),
        );
      case 3: // heart
        final heartPath = _heartPath(headC, headR);
        canvas.drawPath(heartPath, skinPaint);
      default: // round
        canvas.drawCircle(headC, headR, skinPaint);
    }

    // Subsurface glow overlay — warm upper-left light
    canvas.drawCircle(
      headC,
      headR * 1.01,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.50, -0.55),
          radius: 0.72,
          colors: [
            Colors.white.withValues(alpha: 0.26),
            Colors.transparent,
          ],
        ).createShader(headRect)
        ..blendMode = BlendMode.overlay,
    );
  }

  Path _heartPath(Offset c, double r) {
    return Path()
      ..moveTo(c.dx, c.dy + r * 0.95)
      ..cubicTo(
          c.dx - r * 1.05, c.dy + r * 0.28,
          c.dx - r * 1.02, c.dy - r * 0.80,
          c.dx, c.dy - r * 0.65)
      ..cubicTo(
          c.dx + r * 1.02, c.dy - r * 0.80,
          c.dx + r * 1.05, c.dy + r * 0.28,
          c.dx, c.dy + r * 0.95)
      ..close();
  }

  // ── Body / Outfit ─────────────────────────────────────────────────────────

  void _drawBody(Canvas canvas, double cx, double bodyTop, double bodyBot,
      double bodyW, double h) {
    final outfit = _outfit;
    final style  = config.outfitStyle;

    // Main torso — rounded rectangle, slightly wider at bottom for chibi chubbiness
    final torsoRect = RRect.fromRectAndCorners(
      Rect.fromLTRB(cx - bodyW / 2, bodyTop, cx + bodyW / 2, bodyBot),
      topLeft:     Radius.circular(bodyW * 0.28),
      topRight:    Radius.circular(bodyW * 0.28),
      bottomLeft:  Radius.circular(bodyW * 0.22),
      bottomRight: Radius.circular(bodyW * 0.22),
    );

    final bodyRect = Rect.fromLTRB(cx - bodyW / 2, bodyTop, cx + bodyW / 2, bodyBot);
    canvas.drawRRect(
      torsoRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_lighten(outfit, 0.22), outfit, _darken(outfit, 0.22)],
          stops: const [0.0, 0.52, 1.0],
        ).createShader(bodyRect),
    );

    // Subtle form shadow on right side
    canvas.drawRRect(
      torsoRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.07)],
        ).createShader(bodyRect),
    );

    // Outfit-specific details
    switch (style) {
      case 0: _detailTshirt(canvas, cx, bodyTop, bodyBot, bodyW, outfit);
      case 1: _detailHoodie(canvas, cx, bodyTop, bodyBot, bodyW, outfit);
      case 2: _detailDress(canvas, cx, bodyTop, bodyBot, bodyW, outfit);
      case 3: _detailCollarShirt(canvas, cx, bodyTop, bodyBot, bodyW, outfit);
      case 4: _detailSweater(canvas, cx, bodyTop, bodyBot, bodyW, outfit);
      default: _detailJacket(canvas, cx, bodyTop, bodyBot, bodyW, outfit);
    }
  }

  void _detailTshirt(Canvas canvas, double cx, double bodyTop, double bodyBot,
      double bodyW, Color outfit) {
    _drawShortSleeves(canvas, cx, bodyTop, bodyBot, bodyW, outfit);
    // Round collar
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, bodyTop - 2),
          width: bodyW * 0.42, height: 14),
      _fill(_darken(outfit, 0.18)),
    );
  }

  void _detailHoodie(Canvas canvas, double cx, double bodyTop, double bodyBot,
      double bodyW, Color outfit) {
    _drawLongSleeves(canvas, cx, bodyTop, bodyBot, bodyW, outfit);
    // Hood rim — arc above collar
    final hoodPath = Path()
      ..moveTo(cx - bodyW * 0.38, bodyTop - 4)
      ..quadraticBezierTo(cx, bodyTop - 20, cx + bodyW * 0.38, bodyTop - 4);
    canvas.drawPath(
      hoodPath,
      Paint()
        ..color = _darken(outfit, 0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
    // Round collar
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, bodyTop - 2),
          width: bodyW * 0.42, height: 14),
      _fill(_darken(outfit, 0.18)),
    );
    // Kangaroo pocket
    final pocketH = (bodyBot - bodyTop) * 0.26;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, bodyTop + (bodyBot - bodyTop) * 0.60),
            width: bodyW * 0.52, height: pocketH),
        const Radius.circular(8),
      ),
      _fill(_darken(outfit, 0.14)),
    );
    // Drawstrings
    final dsp = _stroke(_darken(outfit, 0.32), 1.5);
    canvas.drawLine(Offset(cx - 5, bodyTop + 2), Offset(cx - 7, bodyTop + 30), dsp);
    canvas.drawLine(Offset(cx + 5, bodyTop + 2), Offset(cx + 7, bodyTop + 30), dsp);
  }

  void _detailDress(Canvas canvas, double cx, double bodyTop, double bodyBot,
      double bodyW, Color outfit) {
    // V-neck line
    final vPath = Path()
      ..moveTo(cx - bodyW * 0.14, bodyTop + 2)
      ..lineTo(cx, bodyTop + 24)
      ..lineTo(cx + bodyW * 0.14, bodyTop + 2);
    canvas.drawPath(vPath, _stroke(_darken(outfit, 0.26), 2.0));
    // Flared skirt suggestion
    final waistY = bodyTop + (bodyBot - bodyTop) * 0.42;
    final skirtPath = Path()
      ..moveTo(cx - bodyW * 0.49, waistY)
      ..lineTo(cx - bodyW * 0.64, bodyBot)
      ..lineTo(cx + bodyW * 0.64, bodyBot)
      ..lineTo(cx + bodyW * 0.49, waistY)
      ..close();
    canvas.drawPath(skirtPath, _fill(_lighten(outfit, 0.10)));
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, waistY), width: bodyW * 0.98, height: 5),
      _fill(_darken(outfit, 0.22)),
    );
  }

  void _detailCollarShirt(Canvas canvas, double cx, double bodyTop, double bodyBot,
      double bodyW, Color outfit) {
    _drawShortSleeves(canvas, cx, bodyTop, bodyBot, bodyW, outfit);
    // Left collar flap
    canvas.drawPath(
      Path()
        ..moveTo(cx - bodyW * 0.20, bodyTop - 4)
        ..lineTo(cx - bodyW * 0.10, bodyTop + 4)
        ..lineTo(cx, bodyTop + 22)
        ..lineTo(cx - bodyW * 0.22, bodyTop + 14)
        ..close(),
      _fill(_lighten(outfit, 0.22)),
    );
    // Right collar flap
    canvas.drawPath(
      Path()
        ..moveTo(cx + bodyW * 0.20, bodyTop - 4)
        ..lineTo(cx + bodyW * 0.10, bodyTop + 4)
        ..lineTo(cx, bodyTop + 22)
        ..lineTo(cx + bodyW * 0.22, bodyTop + 14)
        ..close(),
      _fill(_lighten(outfit, 0.22)),
    );
    // Buttons
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(
          Offset(cx, bodyTop + 30 + i * 18.0), 2.5,
          _fill(_darken(outfit, 0.36)));
    }
  }

  void _detailSweater(Canvas canvas, double cx, double bodyTop, double bodyBot,
      double bodyW, Color outfit) {
    _drawLongSleeves(canvas, cx, bodyTop, bodyBot, bodyW, outfit);
    // Round collar
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, bodyTop - 2),
          width: bodyW * 0.44, height: 16),
      _fill(_darken(outfit, 0.16)),
    );
    // Ribbed hem — horizontal lines at bottom
    final ribPaint = _stroke(_darken(outfit, 0.16), 2.0);
    for (int i = 0; i < 4; i++) {
      final ry = bodyBot - 18 + i * 4.5;
      canvas.drawLine(
          Offset(cx - bodyW * 0.46, ry), Offset(cx + bodyW * 0.46, ry),
          ribPaint);
    }
  }

  void _detailJacket(Canvas canvas, double cx, double bodyTop, double bodyBot,
      double bodyW, Color outfit) {
    _drawLongSleeves(canvas, cx, bodyTop, bodyBot, bodyW, outfit);
    // Center zipper line
    canvas.drawLine(
      Offset(cx, bodyTop + 10), Offset(cx, bodyBot - 10),
      _stroke(_darken(outfit, 0.30), 2.0),
    );
    // Left lapel
    canvas.drawPath(
      Path()
        ..moveTo(cx - bodyW * 0.22, bodyTop - 4)
        ..lineTo(cx - bodyW * 0.08, bodyTop + 10)
        ..lineTo(cx, bodyTop + 22)
        ..lineTo(cx - bodyW * 0.30, bodyTop + 38)
        ..lineTo(cx - bodyW * 0.46, bodyTop + 18)
        ..close(),
      _fill(_darken(outfit, 0.16)),
    );
    // Right lapel
    canvas.drawPath(
      Path()
        ..moveTo(cx + bodyW * 0.22, bodyTop - 4)
        ..lineTo(cx + bodyW * 0.08, bodyTop + 10)
        ..lineTo(cx, bodyTop + 22)
        ..lineTo(cx + bodyW * 0.30, bodyTop + 38)
        ..lineTo(cx + bodyW * 0.46, bodyTop + 18)
        ..close(),
      _fill(_darken(outfit, 0.16)),
    );
    // Buttons
    canvas.drawCircle(Offset(cx - 6, bodyTop + 44), 3, _fill(_darken(outfit, 0.42)));
    canvas.drawCircle(Offset(cx - 6, bodyTop + 60), 3, _fill(_darken(outfit, 0.42)));
  }

  void _drawShortSleeves(Canvas canvas, double cx, double bodyTop, double bodyBot,
      double bodyW, Color outfit) {
    final sc = _darken(outfit, 0.10);
    final sleeveH = (bodyBot - bodyTop) * 0.24;
    // Left
    canvas.drawPath(
      Path()
        ..moveTo(cx - bodyW * 0.28, bodyTop + 4)
        ..lineTo(cx - bodyW * 0.52, bodyTop + 4)
        ..quadraticBezierTo(
            cx - bodyW * 0.58, bodyTop + sleeveH * 0.5,
            cx - bodyW * 0.54, bodyTop + sleeveH)
        ..lineTo(cx - bodyW * 0.36, bodyTop + sleeveH)
        ..close(),
      _fill(sc),
    );
    // Right
    canvas.drawPath(
      Path()
        ..moveTo(cx + bodyW * 0.28, bodyTop + 4)
        ..lineTo(cx + bodyW * 0.52, bodyTop + 4)
        ..quadraticBezierTo(
            cx + bodyW * 0.58, bodyTop + sleeveH * 0.5,
            cx + bodyW * 0.54, bodyTop + sleeveH)
        ..lineTo(cx + bodyW * 0.36, bodyTop + sleeveH)
        ..close(),
      _fill(sc),
    );
  }

  void _drawLongSleeves(Canvas canvas, double cx, double bodyTop, double bodyBot,
      double bodyW, Color outfit) {
    final sc   = _darken(outfit, 0.10);
    final cuffY = bodyBot - (bodyBot - bodyTop) * 0.05;
    // Left
    canvas.drawPath(
      Path()
        ..moveTo(cx - bodyW * 0.28, bodyTop + 4)
        ..lineTo(cx - bodyW * 0.50, bodyTop + 4)
        ..quadraticBezierTo(
            cx - bodyW * 0.64, bodyTop + (cuffY - bodyTop) * 0.50,
            cx - bodyW * 0.58, cuffY)
        ..lineTo(cx - bodyW * 0.38, cuffY)
        ..close(),
      _fill(sc),
    );
    // Right
    canvas.drawPath(
      Path()
        ..moveTo(cx + bodyW * 0.28, bodyTop + 4)
        ..lineTo(cx + bodyW * 0.50, bodyTop + 4)
        ..quadraticBezierTo(
            cx + bodyW * 0.64, bodyTop + (cuffY - bodyTop) * 0.50,
            cx + bodyW * 0.58, cuffY)
        ..lineTo(cx + bodyW * 0.38, cuffY)
        ..close(),
      _fill(sc),
    );
  }

  // ── Eyes ──────────────────────────────────────────────────────────────────

  void _drawEyes(Canvas canvas, Offset headC, double headR) {
    final eyeW  = headR * 0.46;
    final eyeH  = headR * 0.36;
    final eyeY  = headC.dy + headR * 0.08;
    final eyeXL = headC.dx - headR * 0.38;
    final eyeXR = headC.dx + headR * 0.38;
    final ec    = _eye;

    _drawSingleEye(canvas, Offset(eyeXL, eyeY), eyeW, eyeH, headR, ec);
    _drawSingleEye(canvas, Offset(eyeXR, eyeY), eyeW, eyeH, headR, ec);
  }

  void _drawSingleEye(Canvas canvas, Offset c, double eyeW, double eyeH,
      double headR, Color eyeColor) {
    final irisR  = eyeH * 0.82 / 2;
    final pupilR = irisR * 0.45;

    // a) Warm-white sclera
    canvas.drawOval(
      Rect.fromCenter(center: c, width: eyeW, height: eyeH),
      _fill(const Color(0xFFFFF8F0)),
    );

    // b) Iris with radial gradient — lighter centre
    final irisRect = Rect.fromCircle(center: c, radius: irisR);
    canvas.drawCircle(
      c, irisR,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [_lighten(eyeColor, 0.28), eyeColor, _darken(eyeColor, 0.22)],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(irisRect),
    );

    // c) Pupil
    canvas.drawCircle(c, pupilR, _fill(const Color(0xFF1A1010)));

    // d) Iris shimmer — semi-transparent white, upper-left quadrant
    canvas.drawCircle(
      c, irisR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.60, -0.60),
          radius: 0.80,
          colors: [
            Colors.white.withValues(alpha: 0.30),
            Colors.transparent,
          ],
        ).createShader(irisRect),
    );

    // e) Primary catchlight
    canvas.drawCircle(
      c + Offset(irisR * 0.35, -irisR * 0.35),
      irisR * 0.18,
      _fill(Colors.white),
    );

    // f) Secondary catchlight
    canvas.drawCircle(
      c + Offset(-irisR * 0.28, irisR * 0.32),
      irisR * 0.10,
      _fill(Colors.white.withValues(alpha: 0.80)),
    );

    // g) Upper lash line
    canvas.drawArc(
      Rect.fromCenter(center: c, width: eyeW + 2, height: eyeH + 2),
      math.pi, math.pi, false,
      Paint()
        ..color = const Color(0xFF1A1010)
        ..style = PaintingStyle.stroke
        ..strokeWidth = headR * 0.06
        ..strokeCap = StrokeCap.round,
    );

    // h) 3 outer-corner lash marks
    final lashPaint = _stroke(const Color(0xFF1A1010), headR * 0.035);
    for (int i = 0; i < 3; i++) {
      final angle = math.pi * 1.65 + i * (math.pi * 0.09);
      final bx = c.dx + (eyeW / 2) * math.cos(angle);
      final by = c.dy + (eyeH / 2) * math.sin(angle);
      canvas.drawLine(
        Offset(bx, by),
        Offset(bx + math.cos(angle - math.pi / 2) * headR * 0.06,
               by + math.sin(angle - math.pi / 2) * headR * 0.06),
        lashPaint,
      );
    }

    // Sclera outline — very faint
    canvas.drawOval(
      Rect.fromCenter(center: c, width: eyeW, height: eyeH),
      Paint()
        ..color = const Color(0xFF1A1010).withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  // ── Eyebrows ──────────────────────────────────────────────────────────────

  void _drawEyebrows(Canvas canvas, Offset headC, double headR) {
    final browColor = _darken(_hair, 0.08);
    final browPaint = Paint()
      ..color = browColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = headR * 0.065
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final yBase = headC.dy - headR * 0.17;
    final xOff  = headR * 0.38;
    final hw    = headR * 0.22;

    // Left brow — gentle arch
    canvas.drawPath(
      Path()
        ..moveTo(headC.dx - xOff - hw, yBase + 2)
        ..quadraticBezierTo(
            headC.dx - xOff, yBase - 5,
            headC.dx - xOff + hw, yBase + 2),
      browPaint,
    );
    // Right brow
    canvas.drawPath(
      Path()
        ..moveTo(headC.dx + xOff - hw, yBase + 2)
        ..quadraticBezierTo(
            headC.dx + xOff, yBase - 5,
            headC.dx + xOff + hw, yBase + 2),
      browPaint,
    );
  }

  // ── Hair back layer (drawn before head) ───────────────────────────────────

  void _drawHairBack(Canvas canvas, Offset headC, double headR,
      double cx, double bodyBot, double totalH) {
    final hair  = _hair;
    final style = config.hairStyle;
    final bounds = Rect.fromCenter(
        center: headC, width: headR * 3, height: totalH);

    switch (style) {
      case 2: // wavy medium — wavy side strands
        _hairBackWavy(canvas, headC, headR, hair, bounds, bodyBot);
      case 3: // long straight — curtain strands
        _hairBackLongStraight(canvas, headC, headR, hair, bounds, bodyBot);
      case 6: // ponytail — tail behind head
        _hairBackPonytail(canvas, headC, headR, hair, bounds, bodyBot);
      default:
        break; // no back layer
    }
  }

  void _hairBackWavy(Canvas canvas, Offset h, double r, Color hair,
      Rect bounds, double bodyBot) {
    final hp = _hairPaint(hair, bounds);
    // Left wavy strand
    canvas.drawPath(
      Path()
        ..moveTo(h.dx - r * 0.88, h.dy - r * 0.05)
        ..cubicTo(h.dx - r * 1.14, h.dy + r * 0.30,
                  h.dx - r * 1.06, h.dy + r * 0.70,
                  h.dx - r * 1.20, h.dy + r * 1.05)
        ..cubicTo(h.dx - r * 0.96, h.dy + r * 0.82,
                  h.dx - r * 1.02, h.dy + r * 0.46,
                  h.dx - r * 0.76, h.dy - r * 0.05)
        ..close(),
      hp,
    );
    // Right wavy strand
    canvas.drawPath(
      Path()
        ..moveTo(h.dx + r * 0.88, h.dy - r * 0.05)
        ..cubicTo(h.dx + r * 1.14, h.dy + r * 0.30,
                  h.dx + r * 1.06, h.dy + r * 0.70,
                  h.dx + r * 1.20, h.dy + r * 1.05)
        ..cubicTo(h.dx + r * 0.96, h.dy + r * 0.82,
                  h.dx + r * 1.02, h.dy + r * 0.46,
                  h.dx + r * 0.76, h.dy - r * 0.05)
        ..close(),
      hp,
    );
  }

  void _hairBackLongStraight(Canvas canvas, Offset h, double r, Color hair,
      Rect bounds, double bodyBot) {
    final hp = _hairPaint(hair, bounds);
    // Left curtain
    canvas.drawPath(
      Path()
        ..moveTo(h.dx - r * 0.90, h.dy - r * 0.10)
        ..lineTo(h.dx - r * 1.08, bodyBot)
        ..lineTo(h.dx - r * 0.64, bodyBot)
        ..lineTo(h.dx - r * 0.72, h.dy - r * 0.10)
        ..close(),
      hp,
    );
    // Right curtain
    canvas.drawPath(
      Path()
        ..moveTo(h.dx + r * 0.90, h.dy - r * 0.10)
        ..lineTo(h.dx + r * 1.08, bodyBot)
        ..lineTo(h.dx + r * 0.64, bodyBot)
        ..lineTo(h.dx + r * 0.72, h.dy - r * 0.10)
        ..close(),
      hp,
    );
    // Hair shine lines
    final shinePaint = _stroke(_lighten(hair, 0.24), 1.0);
    canvas.drawLine(
        Offset(h.dx - r * 0.84, h.dy - r * 0.02),
        Offset(h.dx - r * 0.92, bodyBot * 0.88), shinePaint);
    canvas.drawLine(
        Offset(h.dx + r * 0.72, h.dy - r * 0.02),
        Offset(h.dx + r * 0.72, bodyBot * 0.88), shinePaint);
  }

  void _hairBackPonytail(Canvas canvas, Offset h, double r, Color hair,
      Rect bounds, double bodyBot) {
    final hp = _hairPaint(hair, bounds);
    // Tail shape going down-right
    canvas.drawPath(
      Path()
        ..moveTo(h.dx + r * 0.58, h.dy - r * 0.80)
        ..quadraticBezierTo(
            h.dx + r * 1.32, h.dy - r * 1.26,
            h.dx + r * 1.12, h.dy + r * 0.48)
        ..quadraticBezierTo(
            h.dx + r * 0.90, h.dy + r * 0.32,
            h.dx + r * 0.84, h.dy - r * 0.70)
        ..close(),
      hp,
    );
  }

  // ── Hair front layer (drawn after head) ───────────────────────────────────

  void _drawHairFront(Canvas canvas, Offset headC, double headR,
      double cx, double bodyBot, double totalH) {
    final hair  = _hair;
    final style = config.hairStyle;
    final bounds = Rect.fromCenter(
        center: headC, width: headR * 3, height: totalH);

    switch (style) {
      case 0: _hairFrontShortCrop(canvas, headC, headR, hair, bounds);
      case 1: _hairFrontSidePart(canvas, headC, headR, hair, bounds);
      case 2: _hairFrontDome(canvas, headC, headR, hair, bounds);
      case 3: _hairFrontDome(canvas, headC, headR, hair, bounds);
      case 4: _hairFrontCurlyAfro(canvas, headC, headR, hair, bounds);
      case 5: _hairFrontBun(canvas, headC, headR, hair, bounds);
      case 6: _hairFrontDome(canvas, headC, headR, hair, bounds);
      default: _hairFrontBuzzCut(canvas, headC, headR, hair, bounds);
    }
  }

  void _hairFrontDome(Canvas canvas, Offset h, double r, Color hair, Rect bounds) {
    canvas.drawPath(
      Path()
        ..moveTo(h.dx - r * 0.92, h.dy - r * 0.05)
        ..quadraticBezierTo(
            h.dx - r * 0.96, h.dy - r * 0.98, h.dx, h.dy - r * 1.10)
        ..quadraticBezierTo(
            h.dx + r * 0.96, h.dy - r * 0.98, h.dx + r * 0.92, h.dy - r * 0.05)
        ..close(),
      _hairPaint(hair, bounds),
    );
  }

  void _hairFrontShortCrop(Canvas canvas, Offset h, double r, Color hair, Rect bounds) {
    final hp = _hairPaint(hair, bounds);
    // Tight dome cap
    canvas.drawPath(
      Path()
        ..moveTo(h.dx - r * 0.92, h.dy - r * 0.06)
        ..quadraticBezierTo(
            h.dx - r * 0.96, h.dy - r * 0.98, h.dx, h.dy - r * 1.10)
        ..quadraticBezierTo(
            h.dx + r * 0.96, h.dy - r * 0.98, h.dx + r * 0.92, h.dy - r * 0.06)
        ..close(),
      hp,
    );
    // Flat fringe
    canvas.drawPath(
      Path()
        ..moveTo(h.dx - r * 0.50, h.dy - r * 0.56)
        ..quadraticBezierTo(h.dx, h.dy - r * 0.76, h.dx + r * 0.50, h.dy - r * 0.56)
        ..quadraticBezierTo(h.dx + r * 0.24, h.dy - r * 0.38, h.dx, h.dy - r * 0.36)
        ..quadraticBezierTo(h.dx - r * 0.24, h.dy - r * 0.38, h.dx - r * 0.50, h.dy - r * 0.56)
        ..close(),
      Paint()
        ..color = _darken(hair, 0.08)
        ..shader = _hairPaint(hair, bounds).shader,
    );
  }

  void _hairFrontSidePart(Canvas canvas, Offset h, double r, Color hair, Rect bounds) {
    final hp = _hairPaint(hair, bounds);
    // Cap
    canvas.drawPath(
      Path()
        ..moveTo(h.dx - r * 0.92, h.dy - r * 0.06)
        ..quadraticBezierTo(
            h.dx - r * 0.95, h.dy - r * 0.94, h.dx - r * 0.08, h.dy - r * 1.07)
        ..quadraticBezierTo(
            h.dx + r * 0.95, h.dy - r * 0.94, h.dx + r * 0.92, h.dy - r * 0.06)
        ..close(),
      hp,
    );
    // Swept bangs — path sweeping from left to right
    canvas.drawPath(
      Path()
        ..moveTo(h.dx - r * 0.62, h.dy - r * 0.54)
        ..quadraticBezierTo(
            h.dx - r * 0.08, h.dy - r * 0.28, h.dx + r * 0.70, h.dy - r * 0.44)
        ..quadraticBezierTo(
            h.dx + r * 0.38, h.dy - r * 0.18, h.dx - r * 0.08, h.dy - r * 0.24)
        ..quadraticBezierTo(
            h.dx - r * 0.52, h.dy - r * 0.30, h.dx - r * 0.62, h.dy - r * 0.54)
        ..close(),
      Paint()
        ..color = _lighten(hair, 0.10)
        ..shader = _hairPaint(_lighten(hair, 0.08), bounds).shader,
    );
  }

  void _hairFrontCurlyAfro(Canvas canvas, Offset h, double r, Color hair, Rect bounds) {
    final cloudPaint = _hairPaint(hair, bounds);
    final offsets = [
      Offset(h.dx, h.dy - r * 1.30),
      Offset(h.dx - r * 0.72, h.dy - r * 1.12),
      Offset(h.dx + r * 0.72, h.dy - r * 1.12),
      Offset(h.dx - r * 1.04, h.dy - r * 0.62),
      Offset(h.dx + r * 1.04, h.dy - r * 0.62),
      Offset(h.dx - r * 1.10, h.dy - r * 0.12),
      Offset(h.dx + r * 1.10, h.dy - r * 0.12),
      Offset(h.dx - r * 0.56, h.dy - r * 1.34),
      Offset(h.dx + r * 0.56, h.dy - r * 1.34),
    ];
    for (final p in offsets) {
      canvas.drawCircle(p, r * 0.44, cloudPaint);
    }
    // Texture — slightly darker small circles
    final texturePaint = _fill(_darken(hair, 0.18));
    for (final p in offsets) {
      canvas.drawCircle(p + Offset(r * 0.10, -r * 0.08), r * 0.14, texturePaint);
    }
    // Highlight blob on afro
    canvas.drawCircle(
      offsets[0] + Offset(-r * 0.12, -r * 0.12),
      r * 0.18,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  void _hairFrontBun(Canvas canvas, Offset h, double r, Color hair, Rect bounds) {
    final hp = _hairPaint(hair, bounds);
    // Cap
    canvas.drawPath(
      Path()
        ..moveTo(h.dx - r * 0.88, h.dy - r * 0.06)
        ..quadraticBezierTo(
            h.dx - r * 0.90, h.dy - r * 0.84, h.dx, h.dy - r * 0.94)
        ..quadraticBezierTo(
            h.dx + r * 0.90, h.dy - r * 0.84, h.dx + r * 0.88, h.dy - r * 0.06)
        ..close(),
      hp,
    );
    // Bun circle
    canvas.drawCircle(Offset(h.dx, h.dy - r * 1.14), r * 0.33,
        _fill(_darken(hair, 0.06)));
    canvas.drawCircle(Offset(h.dx, h.dy - r * 1.14), r * 0.33,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.35),
            radius: 0.90,
            colors: [_lighten(hair, 0.20), hair, _darken(hair, 0.20)],
          ).createShader(Rect.fromCircle(
              center: Offset(h.dx, h.dy - r * 1.14), radius: r * 0.33)));
    // Bun ring
    canvas.drawCircle(Offset(h.dx, h.dy - r * 1.14), r * 0.33,
        _stroke(_darken(hair, 0.28), 2.0));
    // Hair tie
    canvas.drawCircle(Offset(h.dx, h.dy - r * 1.14), r * 0.10,
        _fill(_darken(hair, 0.48)));
  }

  void _hairFrontBuzzCut(Canvas canvas, Offset h, double r, Color hair, Rect bounds) {
    // Very thin skullcap
    canvas.drawCircle(h, r + 2.5, _hairPaint(hair, bounds));
    // Fade on temples
    final fadePaint = Paint()
      ..color = _lighten(hair, 0.30).withValues(alpha: 0.50)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(h.dx - r * 0.72, h.dy),
          width: r * 0.38, height: r * 0.58),
      fadePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(h.dx + r * 0.72, h.dy),
          width: r * 0.38, height: r * 0.58),
      fadePaint,
    );
  }

  // ── Accessories ───────────────────────────────────────────────────────────

  void _drawAccessory(Canvas canvas, Offset headC, double headR,
      double cx, double bodyTop) {
    switch (config.accessory) {
      case 1: _drawGlasses(canvas, headC, headR, false);
      case 2: _drawGlasses(canvas, headC, headR, true);
      case 3: _drawHeadband(canvas, headC, headR);
      case 4: _drawCrown(canvas, headC, headR);
      default: break;
    }
  }

  void _drawGlasses(Canvas canvas, Offset headC, double headR, bool isSunglasses) {
    final frameColor = isSunglasses
        ? const Color(0xFF2C2C2C)
        : _darken(_outfit, 0.28);
    final lensColor = isSunglasses
        ? Colors.black.withValues(alpha: 0.70)
        : Colors.white.withValues(alpha: 0.16);

    final eyeW  = headR * 0.46;
    final eyeH  = headR * 0.36;
    final eyeY  = headC.dy + headR * 0.08;
    final lCx   = Offset(headC.dx - headR * 0.38, eyeY);
    final rCx   = Offset(headC.dx + headR * 0.38, eyeY);

    final lensW = eyeW * 1.10;
    final lensH = eyeH * 1.08;

    canvas.drawOval(Rect.fromCenter(center: lCx, width: lensW, height: lensH),
        _fill(lensColor));
    canvas.drawOval(Rect.fromCenter(center: rCx, width: lensW, height: lensH),
        _fill(lensColor));
    canvas.drawOval(Rect.fromCenter(center: lCx, width: lensW, height: lensH),
        _stroke(frameColor, isSunglasses ? 2.5 : 1.8));
    canvas.drawOval(Rect.fromCenter(center: rCx, width: lensW, height: lensH),
        _stroke(frameColor, isSunglasses ? 2.5 : 1.8));
    // Bridge
    canvas.drawLine(
        Offset(lCx.dx + lensW / 2, lCx.dy),
        Offset(rCx.dx - lensW / 2, rCx.dy),
        _stroke(frameColor, 1.8));
    // Arms
    canvas.drawLine(
        Offset(lCx.dx - lensW / 2, lCx.dy),
        Offset(lCx.dx - lensW / 2 - 14, lCx.dy - 2),
        _stroke(frameColor, 1.8));
    canvas.drawLine(
        Offset(rCx.dx + lensW / 2, rCx.dy),
        Offset(rCx.dx + lensW / 2 + 14, rCx.dy - 2),
        _stroke(frameColor, 1.8));
  }

  void _drawHeadband(Canvas canvas, Offset headC, double headR) {
    final bandColor = _lighten(_outfit, 0.28);
    // Main arc
    canvas.drawPath(
      Path()
        ..moveTo(headC.dx - headR * 0.88, headC.dy - headR * 0.30)
        ..quadraticBezierTo(
            headC.dx, headC.dy - headR * 1.24,
            headC.dx + headR * 0.88, headC.dy - headR * 0.30),
      Paint()
        ..color = bandColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = headR * 0.17
        ..strokeCap = StrokeCap.round,
    );
    // Bow on left
    final bx = headC.dx - headR * 0.72;
    final by = headC.dy - headR * 0.80;
    canvas.drawPath(
      Path()
        ..moveTo(bx, by)
        ..quadraticBezierTo(bx - 12, by - 10, bx - 8, by + 5)
        ..close(),
      _fill(bandColor),
    );
    canvas.drawPath(
      Path()
        ..moveTo(bx, by)
        ..quadraticBezierTo(bx + 12, by - 10, bx + 8, by + 5)
        ..close(),
      _fill(bandColor),
    );
    canvas.drawCircle(Offset(bx, by), 4, _fill(_darken(bandColor, 0.16)));
  }

  void _drawCrown(Canvas canvas, Offset headC, double headR) {
    const crownGold = Color(0xFFFFD700);
    const gemPink   = Color(0xFFFF4488);
    final baseY  = headC.dy - headR * 1.00;
    final crownW = headR * 0.88;

    // Base band with gradient
    final baseRect = Rect.fromCenter(
        center: Offset(headC.dx, baseY + 5), width: crownW, height: 10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(baseRect, const Radius.circular(3)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_lighten(crownGold, 0.28), crownGold, _darken(crownGold, 0.20)],
        ).createShader(baseRect),
    );

    // Three-point crown
    final crownPath = Path()
      ..moveTo(headC.dx - crownW / 2, baseY + 10)
      ..lineTo(headC.dx - crownW * 0.38, baseY)
      ..lineTo(headC.dx - crownW * 0.12, baseY + 2)
      ..lineTo(headC.dx, baseY - 15)
      ..lineTo(headC.dx + crownW * 0.12, baseY + 2)
      ..lineTo(headC.dx + crownW * 0.38, baseY)
      ..lineTo(headC.dx + crownW / 2, baseY + 10)
      ..close();
    final crownRect = Rect.fromLTRB(headC.dx - crownW / 2, baseY - 15,
        headC.dx + crownW / 2, baseY + 10);
    canvas.drawPath(
      crownPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_lighten(crownGold, 0.28), crownGold, _darken(crownGold, 0.20)],
        ).createShader(crownRect),
    );
    canvas.drawPath(crownPath, _stroke(_darken(crownGold, 0.24), 1.2));

    // Gems
    canvas.drawCircle(Offset(headC.dx, baseY - 13), 3.8, _fill(gemPink));
    canvas.drawCircle(Offset(headC.dx, baseY - 13), 1.5,
        _fill(Colors.white.withValues(alpha: 0.60)));
    canvas.drawCircle(
        Offset(headC.dx - crownW * 0.34, baseY - 1), 2.8, _fill(gemPink));
    canvas.drawCircle(
        Offset(headC.dx + crownW * 0.34, baseY - 1), 2.8, _fill(gemPink));
  }
}
