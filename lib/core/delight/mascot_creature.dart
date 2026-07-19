import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'delight.dart';

/// An original, hand-drawn (pure Flutter `CustomPainter`, no external
/// assets/images/fonts) little companion creature — a chubby round
/// dragon-ish thing with folded wings and a curled tail, in the app's own
/// warm rose/coral/gold palette. Deliberately its own design, not a
/// reference to any existing character — see the room_screen.dart call
/// site comment for why.
///
/// Idles with a gentle breathing bob and the occasional blink/wing-flick;
/// tapping it plays a bigger "excited" bounce plus a small sparkle burst.
class MascotCreature extends StatefulWidget {
  final double size;
  const MascotCreature({super.key, this.size = 72});

  @override
  State<MascotCreature> createState() => _MascotCreatureState();
}

class _MascotCreatureState extends State<MascotCreature>
    with TickerProviderStateMixin {
  late final AnimationController _idleCtrl;
  late final AnimationController _blinkCtrl;
  late final AnimationController _tapCtrl;
  late final Animation<double> _tapScale;
  final _rand = math.Random();

  @override
  void initState() {
    super.initState();
    _idleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _scheduleNextBlink();

    _tapCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _tapScale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.82).chain(CurveTween(curve: Curves.easeOut)),
          weight: 20),
      TweenSequenceItem(
          tween: Tween(begin: 0.82, end: 1.15).chain(CurveTween(curve: Curves.easeOut)),
          weight: 30),
      TweenSequenceItem(
          tween: Tween(begin: 1.15, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
          weight: 50),
    ]).animate(_tapCtrl);
  }

  void _scheduleNextBlink() {
    Future.delayed(Duration(milliseconds: 2200 + _rand.nextInt(3200)), () {
      if (!mounted) return;
      _blinkCtrl.forward(from: 0).whenComplete(() {
        if (mounted) _blinkCtrl.reverse();
      });
      _scheduleNextBlink();
    });
  }

  @override
  void dispose() {
    _idleCtrl.dispose();
    _blinkCtrl.dispose();
    _tapCtrl.dispose();
    super.dispose();
  }

  void _onTap() {
    HapticFeedback.selectionClick();
    _tapCtrl.forward(from: 0);
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final origin = box.localToGlobal(box.size.center(Offset.zero));
      FloatingStickers.burst(context, stickers: const ['✨', '💫'], count: 4, origin: origin);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_idleCtrl, _blinkCtrl, _tapCtrl]),
        builder: (context, _) {
          final bob = math.sin(_idleCtrl.value * math.pi) * 4;
          return Transform.translate(
            offset: Offset(0, -bob),
            child: ScaleTransition(
              scale: _tapScale,
              child: CustomPaint(
                size: Size.square(widget.size),
                painter: _MascotPainter(
                  wingFlutter: _idleCtrl.value,
                  blink: _blinkCtrl.value,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MascotPainter extends CustomPainter {
  final double wingFlutter;
  final double blink;
  _MascotPainter({required this.wingFlutter, required this.blink});

  static const _body = Color(0xFFE8899B); // app's rose accent
  static const _bodyDark = Color(0xFFC96A7C);
  static const _belly = Color(0xFFFDEEE7);
  static const _wing = Color(0xFFE8C170); // app's gold accent

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final center = Offset(w / 2, h * 0.56);

    // Tail — a soft curl behind the body.
    final tailPaint = Paint()..color = _bodyDark;
    final tailPath = Path()
      ..moveTo(center.dx - w * 0.18, center.dy + h * 0.1)
      ..quadraticBezierTo(
          center.dx - w * 0.55, center.dy + h * 0.35, center.dx - w * 0.32, center.dy + h * 0.5)
      ..quadraticBezierTo(
          center.dx - w * 0.2, center.dy + h * 0.42, center.dx - w * 0.12, center.dy + h * 0.22)
      ..close();
    canvas.drawPath(tailPath, tailPaint);

    // Wings — small folded triangles, gently flutter.
    final flutter = (math.sin(wingFlutter * math.pi * 2) * 0.08);
    final wingPaint = Paint()..color = _wing;
    for (final side in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(center.dx + side * w * 0.28, center.dy - h * 0.06);
      canvas.rotate(side * (0.5 + flutter));
      final wingPath = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(side * w * 0.28, -h * 0.18, side * w * 0.22, h * 0.06)
        ..quadraticBezierTo(side * w * 0.1, h * 0.02, 0, 0)
        ..close();
      canvas.drawPath(wingPath, wingPaint);
      canvas.restore();
    }

    // Body — a soft round blob.
    final bodyPaint = Paint()..color = _body;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: w * 0.62, height: h * 0.52),
      bodyPaint,
    );

    // Belly patch.
    final bellyPaint = Paint()..color = _belly;
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(center.dx, center.dy + h * 0.08), width: w * 0.34, height: h * 0.26),
      bellyPaint,
    );

    // Head — slightly smaller circle above the body.
    final headCenter = Offset(center.dx, center.dy - h * 0.32);
    canvas.drawCircle(headCenter, w * 0.28, bodyPaint);

    // Ears/horns — two small triangles on top of the head.
    final earPaint = Paint()..color = _bodyDark;
    for (final side in [-1.0, 1.0]) {
      final earPath = Path()
        ..moveTo(headCenter.dx + side * w * 0.14, headCenter.dy - h * 0.16)
        ..lineTo(headCenter.dx + side * w * 0.22, headCenter.dy - h * 0.34)
        ..lineTo(headCenter.dx + side * w * 0.06, headCenter.dy - h * 0.2)
        ..close();
      canvas.drawPath(earPath, earPaint);
    }

    // Eyes — big and round, with a blink squash.
    final eyeH = h * 0.09 * (1 - blink * 0.85);
    final eyeWhite = Paint()..color = Colors.white;
    final eyePupil = Paint()..color = const Color(0xFF3D2B24);
    for (final side in [-1.0, 1.0]) {
      final eyeCenter = Offset(headCenter.dx + side * w * 0.11, headCenter.dy);
      canvas.drawOval(
        Rect.fromCenter(center: eyeCenter, width: w * 0.11, height: eyeH),
        eyeWhite,
      );
      if (blink < 0.6) {
        canvas.drawCircle(
          Offset(eyeCenter.dx, eyeCenter.dy + eyeH * 0.05),
          w * 0.035,
          eyePupil,
        );
      }
    }

    // Little rosy cheeks.
    final cheekPaint = Paint()..color = _body.withValues(alpha: 0.5);
    for (final side in [-1.0, 1.0]) {
      canvas.drawCircle(
        Offset(headCenter.dx + side * w * 0.19, headCenter.dy + h * 0.06),
        w * 0.035,
        cheekPaint,
      );
    }

    // Snout bump + smile.
    final smilePaint = Paint()
      ..color = _bodyDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.02
      ..strokeCap = StrokeCap.round;
    final smilePath = Path()
      ..moveTo(headCenter.dx - w * 0.04, headCenter.dy + h * 0.1)
      ..quadraticBezierTo(headCenter.dx, headCenter.dy + h * 0.14, headCenter.dx + w * 0.04,
          headCenter.dy + h * 0.1);
    canvas.drawPath(smilePath, smilePaint);
  }

  @override
  bool shouldRepaint(covariant _MascotPainter oldDelegate) =>
      oldDelegate.wingFlutter != wingFlutter || oldDelegate.blink != blink;
}
