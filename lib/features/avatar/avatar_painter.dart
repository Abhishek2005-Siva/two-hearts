import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'avatar_model.dart';

// ── Color palettes ────────────────────────────────────────────────────────

const List<Color> kSkinTones = [
  Color(0xFFFFDBAC), // very fair
  Color(0xFFF1C27D), // fair
  Color(0xFFE0AC69), // light
  Color(0xFFC68642), // medium
  Color(0xFF8D5524), // tan
  Color(0xFF4A2912), // deep
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
  Color(0xFFE8896A), // rose
  Color(0xFF9B7FD4), // lavender
  Color(0xFF4CAF82), // sage
  Color(0xFF4A90D9), // sky
  Color(0xFF3A3A4A), // charcoal
];

// ── AvatarPainter ─────────────────────────────────────────────────────────

class AvatarPainter extends CustomPainter {
  final AvatarConfig config;

  const AvatarPainter({required this.config});

  @override
  bool shouldRepaint(AvatarPainter old) => old.config != config;

  // ── helpers ──────────────────────────────────────────────────────────────

  Color get _skin => kSkinTones[config.skinTone.clamp(0, kSkinTones.length - 1)];
  Color get _hair => kHairColors[config.hairColor.clamp(0, kHairColors.length - 1)];
  Color get _eye  => kEyeColors[config.eyeColor.clamp(0, kEyeColors.length - 1)];
  Color get _outfit => kOutfitColors[config.outfitColor.clamp(0, kOutfitColors.length - 1)];

  Color _lighten(Color c, double t) => Color.lerp(c, Colors.white, t)!;
  Color _darken(Color c, double t)  => Color.lerp(c, Colors.black, t)!;

  Paint _fill(Color c) => Paint()..color = c..style = PaintingStyle.fill;
  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round;

  // ── main paint ───────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // Layout constants — chibi proportions
    // Head occupies top 55% of height
    final headR   = w * 0.30;          // large chibi head
    final headCy  = h * 0.32;          // center y of head
    final headC   = Offset(cx, headCy);

    final neckTop = headCy + headR * 0.70;
    final neckBot = headCy + headR * 0.95;
    final bodyTop = neckBot;
    final bodyBot = h * 0.88;
    final bodyW   = w * 0.52;

    // 1. BODY / OUTFIT
    _drawBody(canvas, cx, bodyTop, bodyBot, bodyW, h);

    // 2. NECK
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, (neckTop + neckBot) / 2), width: w * 0.13, height: neckBot - neckTop + 2),
        const Radius.circular(4),
      ),
      _fill(_darken(_skin, 0.06)),
    );

    // 3. HEAD
    _drawHead(canvas, headC, headR);

    // 4. FACE DETAILS (blush, nose)
    _drawFaceDetails(canvas, headC, headR);

    // 5. EYES
    _drawEyes(canvas, headC, headR);

    // 6. EYEBROWS
    _drawEyebrows(canvas, headC, headR);

    // 7. MOUTH
    _drawMouth(canvas, headC, headR);

    // 8. HAIR (over head)
    _drawHair(canvas, headC, headR, cx, h);

    // 9. ACCESSORY
    _drawAccessory(canvas, headC, headR, cx, bodyTop);
  }

  // ── 1. Body / Outfit ─────────────────────────────────────────────────────

  void _drawBody(Canvas canvas, double cx, double bodyTop, double bodyBot,
      double bodyW, double h) {
    final outfit = _outfit;
    final style  = config.outfitStyle;

    // Torso path — trapezoid with rounded top
    final torsoPath = Path()
      ..moveTo(cx - bodyW * 0.30, bodyTop)
      ..quadraticBezierTo(cx - bodyW / 2, bodyTop + 4, cx - bodyW / 2, bodyTop + 14)
      ..lineTo(cx - bodyW / 2, bodyBot - 10)
      ..quadraticBezierTo(cx - bodyW / 2, bodyBot, cx - bodyW / 2 + 10, bodyBot)
      ..lineTo(cx + bodyW / 2 - 10, bodyBot)
      ..quadraticBezierTo(cx + bodyW / 2, bodyBot, cx + bodyW / 2, bodyBot - 10)
      ..lineTo(cx + bodyW / 2, bodyTop + 14)
      ..quadraticBezierTo(cx + bodyW / 2, bodyTop + 4, cx + bodyW * 0.30, bodyTop)
      ..quadraticBezierTo(cx, bodyTop - 6, cx - bodyW * 0.30, bodyTop)
      ..close();

    // Base outfit color with gradient shading
    final bodyRect = Rect.fromLTRB(
        cx - bodyW / 2, bodyTop, cx + bodyW / 2, bodyBot);
    canvas.drawPath(
      torsoPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_lighten(outfit, 0.18), outfit, _darken(outfit, 0.22)],
        ).createShader(bodyRect),
    );

    // Outfit-specific details
    switch (style) {
      case 0: // t-shirt — simple collar + short sleeves
        _drawShortSleeves(canvas, cx, bodyTop, bodyW, outfit);
        _drawRoundCollar(canvas, cx, bodyTop, bodyW, outfit);
      case 1: // hoodie — pocket + drawstrings
        _drawShortSleeves(canvas, cx, bodyTop, bodyW, outfit);
        _drawHoodieDetail(canvas, cx, bodyTop, bodyBot, bodyW, outfit);
      case 2: // dress — flared bottom, no sleeves
        _drawDress(canvas, cx, bodyTop, bodyBot, bodyW, outfit);
      case 3: // collared shirt — V collar + buttons
        _drawShortSleeves(canvas, cx, bodyTop, bodyW, outfit);
        _drawCollarShirt(canvas, cx, bodyTop, bodyBot, bodyW, outfit);
      case 4: // sweater — ribbed collar + long sleeves
        _drawLongSleeves(canvas, cx, bodyTop, bodyW, h, outfit);
        _drawRoundCollar(canvas, cx, bodyTop, bodyW, _darken(outfit, 0.15));
      default: // jacket — lapels + buttons
        _drawLongSleeves(canvas, cx, bodyTop, bodyW, h, outfit);
        _drawJacket(canvas, cx, bodyTop, bodyBot, bodyW, outfit);
    }
  }

  void _drawShortSleeves(Canvas canvas, double cx, double bodyTop,
      double bodyW, Color outfit) {
    final sleeveColor = _darken(outfit, 0.08);
    // left sleeve
    final lPath = Path()
      ..moveTo(cx - bodyW * 0.28, bodyTop + 2)
      ..lineTo(cx - bodyW * 0.52, bodyTop + 2)
      ..quadraticBezierTo(cx - bodyW * 0.58, bodyTop + 10, cx - bodyW * 0.54, bodyTop + 28)
      ..lineTo(cx - bodyW * 0.36, bodyTop + 28)
      ..close();
    canvas.drawPath(lPath, _fill(sleeveColor));
    // right sleeve
    final rPath = Path()
      ..moveTo(cx + bodyW * 0.28, bodyTop + 2)
      ..lineTo(cx + bodyW * 0.52, bodyTop + 2)
      ..quadraticBezierTo(cx + bodyW * 0.58, bodyTop + 10, cx + bodyW * 0.54, bodyTop + 28)
      ..lineTo(cx + bodyW * 0.36, bodyTop + 28)
      ..close();
    canvas.drawPath(rPath, _fill(sleeveColor));
  }

  void _drawLongSleeves(Canvas canvas, double cx, double bodyTop,
      double bodyW, double h, Color outfit) {
    final sleeveColor = _darken(outfit, 0.08);
    // left
    final lPath = Path()
      ..moveTo(cx - bodyW * 0.28, bodyTop + 2)
      ..lineTo(cx - bodyW * 0.52, bodyTop + 2)
      ..quadraticBezierTo(cx - bodyW * 0.64, bodyTop + 20, cx - bodyW * 0.58, h * 0.60)
      ..lineTo(cx - bodyW * 0.38, h * 0.60)
      ..close();
    canvas.drawPath(lPath, _fill(sleeveColor));
    // right
    final rPath = Path()
      ..moveTo(cx + bodyW * 0.28, bodyTop + 2)
      ..lineTo(cx + bodyW * 0.52, bodyTop + 2)
      ..quadraticBezierTo(cx + bodyW * 0.64, bodyTop + 20, cx + bodyW * 0.58, h * 0.60)
      ..lineTo(cx + bodyW * 0.38, h * 0.60)
      ..close();
    canvas.drawPath(rPath, _fill(sleeveColor));
  }

  void _drawRoundCollar(Canvas canvas, double cx, double bodyTop,
      double bodyW, Color outfit) {
    final collar = _darken(outfit, 0.20);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, bodyTop - 2),
          width: bodyW * 0.45,
          height: 14),
      _fill(collar),
    );
  }

  void _drawHoodieDetail(Canvas canvas, double cx, double bodyTop,
      double bodyBot, double bodyW, Color outfit) {
    // kangaroo pocket
    final pocket = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(cx, (bodyTop + bodyBot) * 0.62),
          width: bodyW * 0.54,
          height: (bodyBot - bodyTop) * 0.28),
      const Radius.circular(8),
    );
    canvas.drawRRect(pocket, _fill(_darken(outfit, 0.14)));
    // drawstrings
    final sp = _stroke(_darken(outfit, 0.30), 1.5);
    canvas.drawLine(
        Offset(cx - 6, bodyTop + 6), Offset(cx - 8, bodyTop + 32), sp);
    canvas.drawLine(
        Offset(cx + 6, bodyTop + 6), Offset(cx + 8, bodyTop + 32), sp);
    _drawRoundCollar(canvas, cx, bodyTop, bodyW, outfit);
  }

  void _drawDress(Canvas canvas, double cx, double bodyTop, double bodyBot,
      double bodyW, Color outfit) {
    // Flared skirt overlay
    final skirtPath = Path()
      ..moveTo(cx - bodyW * 0.48, bodyTop + (bodyBot - bodyTop) * 0.45)
      ..lineTo(cx - bodyW * 0.72, bodyBot)
      ..lineTo(cx + bodyW * 0.72, bodyBot)
      ..lineTo(cx + bodyW * 0.48, bodyTop + (bodyBot - bodyTop) * 0.45)
      ..close();
    canvas.drawPath(skirtPath, _fill(_lighten(outfit, 0.10)));
    // Waist belt
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(cx, bodyTop + (bodyBot - bodyTop) * 0.46),
          width: bodyW * 0.96,
          height: 5),
      _fill(_darken(outfit, 0.25)),
    );
    // Round collar
    _drawRoundCollar(canvas, cx, bodyTop, bodyW, outfit);
  }

  void _drawCollarShirt(Canvas canvas, double cx, double bodyTop,
      double bodyBot, double bodyW, Color outfit) {
    // V collar
    final vPath = Path()
      ..moveTo(cx - bodyW * 0.13, bodyTop + 2)
      ..lineTo(cx, bodyTop + 22)
      ..lineTo(cx + bodyW * 0.13, bodyTop + 2);
    canvas.drawPath(vPath, _stroke(_darken(outfit, 0.28), 2.0));
    // Collar flaps
    canvas.drawPath(
      Path()
        ..moveTo(cx - bodyW * 0.20, bodyTop - 2)
        ..lineTo(cx - bodyW * 0.13, bodyTop + 2)
        ..lineTo(cx, bodyTop + 22)
        ..lineTo(cx - bodyW * 0.22, bodyTop + 12)
        ..close(),
      _fill(_lighten(outfit, 0.25)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(cx + bodyW * 0.20, bodyTop - 2)
        ..lineTo(cx + bodyW * 0.13, bodyTop + 2)
        ..lineTo(cx, bodyTop + 22)
        ..lineTo(cx + bodyW * 0.22, bodyTop + 12)
        ..close(),
      _fill(_lighten(outfit, 0.25)),
    );
    // buttons
    for (int i = 0; i < 3; i++) {
      final by = bodyTop + 28 + i * 18.0;
      canvas.drawCircle(Offset(cx, by), 2.5, _fill(_darken(outfit, 0.35)));
    }
  }

  void _drawJacket(Canvas canvas, double cx, double bodyTop, double bodyBot,
      double bodyW, Color outfit) {
    // Lapels
    canvas.drawPath(
      Path()
        ..moveTo(cx - bodyW * 0.22, bodyTop - 2)
        ..lineTo(cx - bodyW * 0.10, bodyTop + 8)
        ..lineTo(cx, bodyTop + 20)
        ..lineTo(cx - bodyW * 0.30, bodyTop + 36)
        ..lineTo(cx - bodyW * 0.48, bodyTop + 16)
        ..close(),
      _fill(_darken(outfit, 0.18)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(cx + bodyW * 0.22, bodyTop - 2)
        ..lineTo(cx + bodyW * 0.10, bodyTop + 8)
        ..lineTo(cx, bodyTop + 20)
        ..lineTo(cx + bodyW * 0.30, bodyTop + 36)
        ..lineTo(cx + bodyW * 0.48, bodyTop + 16)
        ..close(),
      _fill(_darken(outfit, 0.18)),
    );
    // two buttons
    canvas.drawCircle(Offset(cx - 7, bodyTop + 42), 3, _fill(_darken(outfit, 0.40)));
    canvas.drawCircle(Offset(cx - 7, bodyTop + 58), 3, _fill(_darken(outfit, 0.40)));
  }

  // ── 3. Head ───────────────────────────────────────────────────────────────

  void _drawHead(Canvas canvas, Offset headC, double headR) {
    final skin = _skin;
    final shape = config.faceShape;

    // Soft drop shadow
    canvas.drawCircle(
      headC + const Offset(2, 6),
      headR + 2,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    switch (shape) {
      case 1: // soft oval — taller
        canvas.drawOval(
          Rect.fromCenter(center: headC, width: headR * 1.85, height: headR * 2.10),
          _fill(skin),
        );
      case 2: // square-ish — slightly wider
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: headC, width: headR * 2.0, height: headR * 1.95),
            Radius.circular(headR * 0.50),
          ),
          _fill(skin),
        );
      case 3: // heart — wider top, slightly tapered chin suggestion
        final heartPath = Path()
          ..moveTo(headC.dx, headC.dy + headR * 0.95)
          ..quadraticBezierTo(
              headC.dx - headR * 1.0, headC.dy + headR * 0.30,
              headC.dx - headR * 0.95, headC.dy - headR * 0.18)
          ..quadraticBezierTo(
              headC.dx - headR * 0.92, headC.dy - headR * 0.95,
              headC.dx, headC.dy - headR * 0.70)
          ..quadraticBezierTo(
              headC.dx + headR * 0.92, headC.dy - headR * 0.95,
              headC.dx + headR * 0.95, headC.dy - headR * 0.18)
          ..quadraticBezierTo(
              headC.dx + headR * 1.0, headC.dy + headR * 0.30,
              headC.dx, headC.dy + headR * 0.95)
          ..close();
        canvas.drawPath(heartPath, _fill(skin));
      default: // round circle
        canvas.drawCircle(headC, headR, _fill(skin));
    }

    // Shading highlight (upper-left)
    canvas.drawCircle(
      headC,
      headR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.40, -0.45),
          radius: 0.75,
          colors: [Colors.white.withValues(alpha: 0.28), Colors.transparent],
        ).createShader(Rect.fromCircle(center: headC, radius: headR)),
    );
  }

  // ── 4. Face Details ───────────────────────────────────────────────────────

  void _drawFaceDetails(Canvas canvas, Offset headC, double headR) {
    // Blush circles
    final blushPaint = Paint()
      ..color = const Color(0xFFFF9BAA).withValues(alpha: 0.38)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(
        Offset(headC.dx - headR * 0.50, headC.dy + headR * 0.14), headR * 0.22, blushPaint);
    canvas.drawCircle(
        Offset(headC.dx + headR * 0.50, headC.dy + headR * 0.14), headR * 0.22, blushPaint);

    // Nose dot
    canvas.drawCircle(
      Offset(headC.dx, headC.dy + headR * 0.08),
      headR * 0.045,
      _fill(_darken(_skin, 0.22)),
    );
  }

  // ── 5. Eyes ───────────────────────────────────────────────────────────────

  void _drawEyes(Canvas canvas, Offset headC, double headR) {
    final lEye = Offset(headC.dx - headR * 0.36, headC.dy - headR * 0.06);
    final rEye = Offset(headC.dx + headR * 0.36, headC.dy - headR * 0.06);
    final eyeColor = _eye;
    final style = config.eyeStyle;

    _drawSingleEye(canvas, lEye, headR, eyeColor, style, flipped: false);
    _drawSingleEye(canvas, rEye, headR, eyeColor, style, flipped: true);
  }

  void _drawSingleEye(Canvas canvas, Offset center, double headR, Color eyeColor,
      int style, {required bool flipped}) {
    final eW = headR * 0.32;
    final eH = headR * 0.26;

    switch (style) {
      case 1: // almond — narrow horizontal oval
        _drawAlmondEye(canvas, center, headR, eyeColor, flipped);
      case 2: // wide anime — big oval with shine dots
        _drawWideAnimeEye(canvas, center, headR, eyeColor, flipped);
      case 3: // hooded — half-oval with eyelid
        _drawHoodedEye(canvas, center, headR, eyeColor, flipped);
      case 4: // round with lashes
        _drawRoundLashEye(canvas, center, headR, eyeColor, flipped);
      default: // normal round
        _drawNormalEye(canvas, center, eW, eH, eyeColor);
    }
  }

  void _drawNormalEye(Canvas canvas, Offset c, double eW, double eH, Color eyeColor) {
    // White
    canvas.drawOval(Rect.fromCenter(center: c, width: eW, height: eH),
        _fill(Colors.white));
    // Iris
    canvas.drawCircle(c, eH * 0.55, _fill(eyeColor));
    // Pupil
    canvas.drawCircle(c, eH * 0.28, _fill(Colors.black));
    // Shine
    canvas.drawCircle(c + Offset(-eH * 0.18, -eH * 0.18), eH * 0.12,
        _fill(Colors.white));
    // Outline
    canvas.drawOval(Rect.fromCenter(center: c, width: eW, height: eH),
        _stroke(Colors.black87, 1.2));
  }

  void _drawAlmondEye(Canvas canvas, Offset c, double headR, Color eyeColor, bool flipped) {
    final eW = headR * 0.38;
    final eH = headR * 0.20;
    // Almond shape with pointed ends
    final path = Path()
      ..moveTo(c.dx - eW / 2, c.dy)
      ..quadraticBezierTo(c.dx - eW * 0.1, c.dy - eH, c.dx + eW * 0.1, c.dy - eH)
      ..quadraticBezierTo(c.dx + eW * 0.4, c.dy - eH * 0.5, c.dx + eW / 2, c.dy)
      ..quadraticBezierTo(c.dx + eW * 0.4, c.dy + eH * 0.5, c.dx + eW * 0.1, c.dy + eH * 0.7)
      ..quadraticBezierTo(c.dx - eW * 0.1, c.dy + eH, c.dx - eW / 2, c.dy)
      ..close();
    canvas.drawPath(path, _fill(Colors.white));
    canvas.drawCircle(c + Offset(eW * 0.04, 0), eH * 0.52, _fill(eyeColor));
    canvas.drawCircle(c + Offset(eW * 0.04, 0), eH * 0.26, _fill(Colors.black));
    canvas.drawCircle(c + Offset(0, -eH * 0.22), eH * 0.14, _fill(Colors.white));
    canvas.drawPath(path, _stroke(Colors.black87, 1.2));
  }

  void _drawWideAnimeEye(Canvas canvas, Offset c, double headR, Color eyeColor, bool flipped) {
    final eW = headR * 0.36;
    final eH = headR * 0.36;
    // Large round with colored iris almost filling
    canvas.drawOval(Rect.fromCenter(center: c, width: eW, height: eH),
        _fill(Colors.white));
    // Iris fills most of eye
    canvas.drawOval(Rect.fromCenter(center: c, width: eW * 0.82, height: eH * 0.82),
        _fill(eyeColor));
    // Dark pupil
    canvas.drawOval(Rect.fromCenter(center: c, width: eW * 0.44, height: eH * 0.44),
        _fill(Colors.black));
    // Two shine dots
    canvas.drawCircle(c + Offset(-eW * 0.18, -eH * 0.18), eH * 0.13, _fill(Colors.white));
    canvas.drawCircle(c + Offset(eW * 0.10, eH * 0.05), eH * 0.07, _fill(Colors.white));
    // Iris highlight ring
    canvas.drawOval(
      Rect.fromCenter(center: c, width: eW * 0.80, height: eH * 0.80),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawOval(Rect.fromCenter(center: c, width: eW, height: eH),
        _stroke(Colors.black87, 1.5));
    // Thick top eyelid line
    canvas.drawArc(
      Rect.fromCenter(center: c, width: eW + 2, height: eH + 2),
      math.pi, math.pi, false,
      _stroke(Colors.black, 2.5),
    );
  }

  void _drawHoodedEye(Canvas canvas, Offset c, double headR, Color eyeColor, bool flipped) {
    final eW = headR * 0.34;
    final eH = headR * 0.22;
    // Bottom half open — eyelid covers top
    final openPath = Path()
      ..moveTo(c.dx - eW / 2, c.dy)
      ..quadraticBezierTo(c.dx, c.dy - eH * 0.5, c.dx + eW / 2, c.dy)
      ..quadraticBezierTo(c.dx, c.dy + eH, c.dx - eW / 2, c.dy)
      ..close();
    canvas.drawPath(openPath, _fill(Colors.white));
    canvas.drawCircle(c + Offset(0, eH * 0.08), eH * 0.48, _fill(eyeColor));
    canvas.drawCircle(c + Offset(0, eH * 0.08), eH * 0.24, _fill(Colors.black));
    canvas.drawCircle(c + Offset(-eH * 0.15, -eH * 0.08), eH * 0.11, _fill(Colors.white));
    // Eyelid (heavy top line)
    canvas.drawPath(openPath, _stroke(Colors.black87, 1.2));
    canvas.drawLine(
      Offset(c.dx - eW / 2, c.dy), Offset(c.dx + eW / 2, c.dy),
      _stroke(Colors.black, 2.2),
    );
  }

  void _drawRoundLashEye(Canvas canvas, Offset c, double headR, Color eyeColor, bool flipped) {
    final eW = headR * 0.32;
    final eH = headR * 0.28;
    canvas.drawOval(Rect.fromCenter(center: c, width: eW, height: eH),
        _fill(Colors.white));
    canvas.drawCircle(c, eH * 0.54, _fill(eyeColor));
    canvas.drawCircle(c, eH * 0.28, _fill(Colors.black));
    canvas.drawCircle(c + Offset(-eH * 0.18, -eH * 0.18), eH * 0.12, _fill(Colors.white));
    canvas.drawOval(Rect.fromCenter(center: c, width: eW, height: eH),
        _stroke(Colors.black87, 1.2));
    // Small upper lashes
    final lashPaint = _stroke(Colors.black, 1.5);
    final lashCount = 5;
    for (int i = 0; i < lashCount; i++) {
      final angle = math.pi + (i / (lashCount - 1)) * math.pi;
      final baseX = c.dx + (eW / 2) * math.cos(angle);
      final baseY = c.dy + (eH / 2) * math.sin(angle);
      final tipX  = baseX + math.cos(angle - math.pi / 2) * 5;
      final tipY  = baseY + math.sin(angle - math.pi / 2) * 5;
      if (baseY < c.dy) {
        canvas.drawLine(Offset(baseX, baseY), Offset(tipX, tipY), lashPaint);
      }
    }
  }

  // ── 6. Eyebrows ───────────────────────────────────────────────────────────

  void _drawEyebrows(Canvas canvas, Offset headC, double headR) {
    final browColor = _darken(_hair, 0.10);
    final browPaint = Paint()
      ..color = browColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = headR * 0.07
      ..strokeCap = StrokeCap.round;

    final yOff = headC.dy - headR * 0.22;
    final xOff = headR * 0.36;
    final browW = headR * 0.26;

    // Left brow — slight arc
    final lBrow = Path()
      ..moveTo(headC.dx - xOff - browW * 0.5, yOff + 2)
      ..quadraticBezierTo(
          headC.dx - xOff, yOff - 4,
          headC.dx - xOff + browW * 0.5, yOff + 2);
    canvas.drawPath(lBrow, browPaint);

    // Right brow
    final rBrow = Path()
      ..moveTo(headC.dx + xOff - browW * 0.5, yOff + 2)
      ..quadraticBezierTo(
          headC.dx + xOff, yOff - 4,
          headC.dx + xOff + browW * 0.5, yOff + 2);
    canvas.drawPath(rBrow, browPaint);
  }

  // ── 7. Mouth ──────────────────────────────────────────────────────────────

  void _drawMouth(Canvas canvas, Offset headC, double headR) {
    final mouthPath = Path()
      ..moveTo(headC.dx - headR * 0.18, headC.dy + headR * 0.32)
      ..quadraticBezierTo(
          headC.dx, headC.dy + headR * 0.46,
          headC.dx + headR * 0.18, headC.dy + headR * 0.32);
    canvas.drawPath(
      mouthPath,
      Paint()
        ..color = _darken(_skin, 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = headR * 0.065
        ..strokeCap = StrokeCap.round,
    );
  }

  // ── 8. Hair ───────────────────────────────────────────────────────────────

  void _drawHair(Canvas canvas, Offset headC, double headR,
      double cx, double totalH) {
    final hairColor = _hair;
    final style = config.hairStyle;

    switch (style) {
      case 0: _drawHairShortCrop(canvas, headC, headR, hairColor);
      case 1: _drawHairSidePart(canvas, headC, headR, hairColor);
      case 2: _drawHairWavyMedium(canvas, headC, headR, hairColor, totalH);
      case 3: _drawHairLongStraight(canvas, headC, headR, hairColor, totalH);
      case 4: _drawHairCurlyAfro(canvas, headC, headR, hairColor);
      case 5: _drawHairBun(canvas, headC, headR, hairColor);
      case 6: _drawHairPonytail(canvas, headC, headR, hairColor, totalH);
      default: _drawHairBuzzCut(canvas, headC, headR, hairColor);
    }
  }

  void _drawHairShortCrop(Canvas canvas, Offset h, double r, Color c) {
    // Cap that covers top and sides
    final path = Path()
      ..moveTo(h.dx - r * 0.92, h.dy - r * 0.05)
      ..quadraticBezierTo(h.dx - r * 0.95, h.dy - r * 0.95, h.dx, h.dy - r * 1.08)
      ..quadraticBezierTo(h.dx + r * 0.95, h.dy - r * 0.95, h.dx + r * 0.92, h.dy - r * 0.05)
      ..quadraticBezierTo(h.dx + r * 0.85, h.dy - r * 0.50, h.dx, h.dy - r * 0.55)
      ..quadraticBezierTo(h.dx - r * 0.85, h.dy - r * 0.50, h.dx - r * 0.92, h.dy - r * 0.05)
      ..close();
    canvas.drawPath(path, _fill(c));
    // Small fringe
    final fringe = Path()
      ..moveTo(h.dx - r * 0.48, h.dy - r * 0.58)
      ..quadraticBezierTo(h.dx - r * 0.20, h.dy - r * 0.78, h.dx, h.dy - r * 0.72)
      ..quadraticBezierTo(h.dx + r * 0.20, h.dy - r * 0.78, h.dx + r * 0.48, h.dy - r * 0.58)
      ..quadraticBezierTo(h.dx + r * 0.22, h.dy - r * 0.44, h.dx, h.dy - r * 0.40)
      ..quadraticBezierTo(h.dx - r * 0.22, h.dy - r * 0.44, h.dx - r * 0.48, h.dy - r * 0.58)
      ..close();
    canvas.drawPath(fringe, _fill(_darken(c, 0.10)));
  }

  void _drawHairSidePart(Canvas canvas, Offset h, double r, Color c) {
    // Swept to right
    final cap = Path()
      ..moveTo(h.dx - r * 0.92, h.dy - r * 0.05)
      ..quadraticBezierTo(h.dx - r * 0.94, h.dy - r * 0.92, h.dx - r * 0.1, h.dy - r * 1.05)
      ..quadraticBezierTo(h.dx + r * 0.94, h.dy - r * 0.92, h.dx + r * 0.92, h.dy - r * 0.05)
      ..close();
    canvas.drawPath(cap, _fill(c));
    // Side-parted fringe sweep — goes left to right
    final sweep = Path()
      ..moveTo(h.dx - r * 0.60, h.dy - r * 0.55)
      ..quadraticBezierTo(h.dx - r * 0.10, h.dy - r * 0.28, h.dx + r * 0.72, h.dy - r * 0.44)
      ..quadraticBezierTo(h.dx + r * 0.40, h.dy - r * 0.18, h.dx - r * 0.10, h.dy - r * 0.22)
      ..quadraticBezierTo(h.dx - r * 0.50, h.dy - r * 0.30, h.dx - r * 0.60, h.dy - r * 0.55)
      ..close();
    canvas.drawPath(sweep, _fill(_lighten(c, 0.12)));
  }

  void _drawHairWavyMedium(Canvas canvas, Offset h, double r, Color c, double totalH) {
    // Shoulder-length wavy — front cap + wavy sides
    final cap = Path()
      ..moveTo(h.dx - r * 0.92, h.dy - r * 0.05)
      ..quadraticBezierTo(h.dx - r * 0.95, h.dy - r * 0.96, h.dx, h.dy - r * 1.08)
      ..quadraticBezierTo(h.dx + r * 0.95, h.dy - r * 0.96, h.dx + r * 0.92, h.dy - r * 0.05)
      ..close();
    canvas.drawPath(cap, _fill(c));

    // Left wavy strand
    final lWave = Path()
      ..moveTo(h.dx - r * 0.88, h.dy - r * 0.05)
      ..cubicTo(h.dx - r * 1.12, h.dy + r * 0.30,
                h.dx - r * 1.05, h.dy + r * 0.68,
                h.dx - r * 1.18, h.dy + r * 1.00)
      ..cubicTo(h.dx - r * 0.95, h.dy + r * 0.80,
                h.dx - r * 1.00, h.dy + r * 0.44,
                h.dx - r * 0.74, h.dy - r * 0.05)
      ..close();
    canvas.drawPath(lWave, _fill(c));

    // Right wavy strand
    final rWave = Path()
      ..moveTo(h.dx + r * 0.88, h.dy - r * 0.05)
      ..cubicTo(h.dx + r * 1.12, h.dy + r * 0.30,
                h.dx + r * 1.05, h.dy + r * 0.68,
                h.dx + r * 1.18, h.dy + r * 1.00)
      ..cubicTo(h.dx + r * 0.95, h.dy + r * 0.80,
                h.dx + r * 1.00, h.dy + r * 0.44,
                h.dx + r * 0.74, h.dy - r * 0.05)
      ..close();
    canvas.drawPath(rWave, _fill(c));

    // Wavy lines on strands for texture
    final wavePaint = _stroke(_darken(c, 0.16), 1.2);
    for (int i = 0; i < 3; i++) {
      final yBase = h.dy + r * (0.20 + i * 0.25);
      final wPath = Path()
        ..moveTo(h.dx - r * 1.10, yBase)
        ..quadraticBezierTo(h.dx - r * 0.98, yBase + 6, h.dx - r * 0.82, yBase);
      canvas.drawPath(wPath, wavePaint);
    }
  }

  void _drawHairLongStraight(Canvas canvas, Offset h, double r, Color c, double totalH) {
    // Long curtains down both sides
    final lStrand = Path()
      ..moveTo(h.dx - r * 0.90, h.dy - r * 0.08)
      ..lineTo(h.dx - r * 1.06, h.dy + r * 1.55)
      ..lineTo(h.dx - r * 0.62, h.dy + r * 1.55)
      ..lineTo(h.dx - r * 0.70, h.dy - r * 0.08)
      ..close();
    canvas.drawPath(lStrand, _fill(c));

    final rStrand = Path()
      ..moveTo(h.dx + r * 0.90, h.dy - r * 0.08)
      ..lineTo(h.dx + r * 1.06, h.dy + r * 1.55)
      ..lineTo(h.dx + r * 0.62, h.dy + r * 1.55)
      ..lineTo(h.dx + r * 0.70, h.dy - r * 0.08)
      ..close();
    canvas.drawPath(rStrand, _fill(c));

    // Cap on top
    final cap = Path()
      ..moveTo(h.dx - r * 0.92, h.dy - r * 0.05)
      ..quadraticBezierTo(h.dx - r * 0.94, h.dy - r * 1.00, h.dx, h.dy - r * 1.08)
      ..quadraticBezierTo(h.dx + r * 0.94, h.dy - r * 1.00, h.dx + r * 0.92, h.dy - r * 0.05)
      ..close();
    canvas.drawPath(cap, _fill(c));

    // Hair shine lines
    final shine = _stroke(_lighten(c, 0.22), 1.0);
    canvas.drawLine(
        Offset(h.dx - r * 0.18, h.dy - r * 0.92), Offset(h.dx - r * 0.22, h.dy + r * 1.40), shine);
    canvas.drawLine(
        Offset(h.dx + r * 0.10, h.dy - r * 0.92), Offset(h.dx + r * 0.10, h.dy + r * 1.40), shine);
  }

  void _drawHairCurlyAfro(Canvas canvas, Offset h, double r, Color c) {
    // Big poofy cloud of curls
    final cloudPaint = _fill(c);
    // Multiple overlapping circles form the afro shape
    final positions = [
      Offset(h.dx, h.dy - r * 1.28),
      Offset(h.dx - r * 0.70, h.dy - r * 1.10),
      Offset(h.dx + r * 0.70, h.dy - r * 1.10),
      Offset(h.dx - r * 1.02, h.dy - r * 0.60),
      Offset(h.dx + r * 1.02, h.dy - r * 0.60),
      Offset(h.dx - r * 1.08, h.dy - r * 0.10),
      Offset(h.dx + r * 1.08, h.dy - r * 0.10),
      Offset(h.dx - r * 0.55, h.dy - r * 1.32),
      Offset(h.dx + r * 0.55, h.dy - r * 1.32),
    ];
    for (final p in positions) {
      canvas.drawCircle(p, r * 0.44, cloudPaint);
    }
    // Curl texture — small darker circles
    final texturePaint = _fill(_darken(c, 0.18));
    for (int i = 0; i < positions.length; i++) {
      canvas.drawCircle(positions[i] + Offset(r * 0.10, -r * 0.08), r * 0.14, texturePaint);
    }
  }

  void _drawHairBun(Canvas canvas, Offset h, double r, Color c) {
    // Side pieces
    canvas.drawOval(
      Rect.fromCenter(center: Offset(h.dx - r * 0.86, h.dy - r * 0.28), width: r * 0.30, height: r * 0.65),
      _fill(c),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(h.dx + r * 0.86, h.dy - r * 0.28), width: r * 0.30, height: r * 0.65),
      _fill(c),
    );
    // Top cap
    final cap = Path()
      ..moveTo(h.dx - r * 0.88, h.dy - r * 0.05)
      ..quadraticBezierTo(h.dx - r * 0.90, h.dy - r * 0.82, h.dx, h.dy - r * 0.92)
      ..quadraticBezierTo(h.dx + r * 0.90, h.dy - r * 0.82, h.dx + r * 0.88, h.dy - r * 0.05)
      ..close();
    canvas.drawPath(cap, _fill(c));
    // Bun itself — circle on top
    canvas.drawCircle(
      Offset(h.dx, h.dy - r * 1.12), r * 0.32,
      _fill(_darken(c, 0.08)),
    );
    // Bun ring
    canvas.drawCircle(
      Offset(h.dx, h.dy - r * 1.12), r * 0.32,
      _stroke(_darken(c, 0.25), 2.0),
    );
    // Hair tie elastic
    canvas.drawCircle(
      Offset(h.dx, h.dy - r * 1.12), r * 0.12,
      _fill(_darken(c, 0.45)),
    );
  }

  void _drawHairPonytail(Canvas canvas, Offset h, double r, Color c, double totalH) {
    // Side pieces and cap
    canvas.drawOval(
      Rect.fromCenter(center: Offset(h.dx - r * 0.86, h.dy - r * 0.20), width: r * 0.28, height: r * 0.60),
      _fill(c),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(h.dx + r * 0.86, h.dy - r * 0.20), width: r * 0.28, height: r * 0.60),
      _fill(c),
    );
    final cap = Path()
      ..moveTo(h.dx - r * 0.88, h.dy - r * 0.05)
      ..quadraticBezierTo(h.dx - r * 0.90, h.dy - r * 0.90, h.dx, h.dy - r * 1.02)
      ..quadraticBezierTo(h.dx + r * 0.90, h.dy - r * 0.90, h.dx + r * 0.88, h.dy - r * 0.05)
      ..close();
    canvas.drawPath(cap, _fill(c));
    // Ponytail — tapered ribbon going up-back
    final ponytail = Path()
      ..moveTo(h.dx + r * 0.58, h.dy - r * 0.82)
      ..quadraticBezierTo(h.dx + r * 1.30, h.dy - r * 1.30, h.dx + r * 1.10, h.dy + r * 0.42)
      ..quadraticBezierTo(h.dx + r * 0.88, h.dy + r * 0.28, h.dx + r * 0.82, h.dy - r * 0.70)
      ..close();
    canvas.drawPath(ponytail, _fill(c));
    // Hair tie
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(h.dx + r * 0.68, h.dy - r * 0.80),
          width: r * 0.22,
          height: r * 0.16),
      _fill(_darken(c, 0.40)),
    );
  }

  void _drawHairBuzzCut(Canvas canvas, Offset h, double r, Color c) {
    // Very tight cap — near-shaved
    canvas.drawCircle(h, r * 1.02, _fill(c));
    // Fade effect — lighter at temples
    final fadePaint = Paint()
      ..color = _lighten(c, 0.28).withValues(alpha: 0.50)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(h.dx - r * 0.72, h.dy), width: r * 0.40, height: r * 0.60),
      fadePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(h.dx + r * 0.72, h.dy), width: r * 0.40, height: r * 0.60),
      fadePaint,
    );
    // Hairline arc
    canvas.drawArc(
      Rect.fromCenter(center: h, width: r * 2.04, height: r * 2.04),
      math.pi * 1.10, math.pi * 0.80, false,
      _stroke(_darken(c, 0.20), 1.5),
    );
  }

  // ── 9. Accessories ────────────────────────────────────────────────────────

  void _drawAccessory(Canvas canvas, Offset headC, double headR,
      double cx, double bodyTop) {
    switch (config.accessory) {
      case 1: _drawGlasses(canvas, headC, headR, false);
      case 2: _drawGlasses(canvas, headC, headR, true);
      case 3: _drawHeadband(canvas, headC, headR);
      case 4: _drawTinyCrown(canvas, headC, headR);
      default: break;
    }
  }

  void _drawGlasses(Canvas canvas, Offset headC, double headR, bool isSunglasses) {
    final frameColor = isSunglasses
        ? const Color(0xFF2C2C2C)
        : _darken(_outfit, 0.25);
    final lensColor = isSunglasses
        ? Colors.black.withValues(alpha: 0.72)
        : Colors.white.withValues(alpha: 0.18);

    final lCx = Offset(headC.dx - headR * 0.36, headC.dy - headR * 0.06);
    final rCx = Offset(headC.dx + headR * 0.36, headC.dy - headR * 0.06);
    final lensW = headR * 0.34;
    final lensH = headR * 0.24;

    // Lenses
    canvas.drawOval(Rect.fromCenter(center: lCx, width: lensW, height: lensH),
        _fill(lensColor));
    canvas.drawOval(Rect.fromCenter(center: rCx, width: lensW, height: lensH),
        _fill(lensColor));
    // Frames
    canvas.drawOval(Rect.fromCenter(center: lCx, width: lensW, height: lensH),
        _stroke(frameColor, 2.0));
    canvas.drawOval(Rect.fromCenter(center: rCx, width: lensW, height: lensH),
        _stroke(frameColor, 2.0));
    // Bridge
    canvas.drawLine(
        Offset(lCx.dx + lensW / 2, lCx.dy),
        Offset(rCx.dx - lensW / 2, rCx.dy),
        _stroke(frameColor, 1.8));
    // Temple arms
    canvas.drawLine(
        Offset(lCx.dx - lensW / 2, lCx.dy),
        Offset(lCx.dx - lensW / 2 - 12, lCx.dy - 2),
        _stroke(frameColor, 1.8));
    canvas.drawLine(
        Offset(rCx.dx + lensW / 2, rCx.dy),
        Offset(rCx.dx + lensW / 2 + 12, rCx.dy - 2),
        _stroke(frameColor, 1.8));
  }

  void _drawHeadband(Canvas canvas, Offset headC, double headR) {
    final bandColor = _lighten(_outfit, 0.30);
    // Headband arc across top of head
    final bandPath = Path()
      ..moveTo(headC.dx - headR * 0.88, headC.dy - headR * 0.28)
      ..quadraticBezierTo(headC.dx, headC.dy - headR * 1.22, headC.dx + headR * 0.88, headC.dy - headR * 0.28);
    canvas.drawPath(bandPath, Paint()
      ..color = bandColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = headR * 0.18
      ..strokeCap = StrokeCap.round);
    // Bow on the left side
    final bowCx = headC.dx - headR * 0.72;
    final bowCy = headC.dy - headR * 0.78;
    canvas.drawPath(
      Path()
        ..moveTo(bowCx, bowCy)
        ..quadraticBezierTo(bowCx - 12, bowCy - 10, bowCx - 8, bowCy + 4)
        ..close(),
      _fill(bandColor),
    );
    canvas.drawPath(
      Path()
        ..moveTo(bowCx, bowCy)
        ..quadraticBezierTo(bowCx + 12, bowCy - 10, bowCx + 8, bowCy + 4)
        ..close(),
      _fill(bandColor),
    );
    canvas.drawCircle(Offset(bowCx, bowCy), 4, _fill(_darken(bandColor, 0.15)));
  }

  void _drawTinyCrown(Canvas canvas, Offset headC, double headR) {
    const crownColor = Color(0xFFFFD700);
    const gemColor   = Color(0xFFFF4488);
    final baseY = headC.dy - headR * 1.00;
    final crownW = headR * 0.88;

    // Crown base band
    final baseRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(headC.dx, baseY + 4), width: crownW, height: 10),
      const Radius.circular(3),
    );
    canvas.drawRRect(baseRect, _fill(crownColor));

    // Three points
    final points = [
      Offset(headC.dx - crownW * 0.38, baseY),
      Offset(headC.dx, baseY - 14),
      Offset(headC.dx + crownW * 0.38, baseY),
    ];
    final pointPath = Path()
      ..moveTo(headC.dx - crownW / 2, baseY + 8)
      ..lineTo(points[0].dx, points[0].dy)
      ..lineTo(headC.dx - crownW * 0.13, baseY)
      ..lineTo(points[1].dx, points[1].dy)
      ..lineTo(headC.dx + crownW * 0.13, baseY)
      ..lineTo(points[2].dx, points[2].dy)
      ..lineTo(headC.dx + crownW / 2, baseY + 8)
      ..close();
    canvas.drawPath(pointPath, _fill(crownColor));
    canvas.drawPath(pointPath, _stroke(_darken(crownColor, 0.22), 1.2));

    // Gems
    canvas.drawCircle(Offset(headC.dx, baseY - 12), 3.5, _fill(gemColor));
    canvas.drawCircle(Offset(headC.dx - crownW * 0.34, baseY - 2), 2.5, _fill(gemColor));
    canvas.drawCircle(Offset(headC.dx + crownW * 0.34, baseY - 2), 2.5, _fill(gemColor));
  }
}
