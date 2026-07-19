import 'dart:async';
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
/// States: idles with a gentle breathing bob and the occasional blink;
/// tap → excited happy bounce + sparkle burst; long-press → a wave
/// (raised wing + a 👋 burst); falls asleep on its own after a while with
/// no interaction (closed eyes, tilted head, stilled bob) and wakes back
/// up — with a little burst each way — on the next tap.
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
  late final AnimationController _waveCtrl;
  late final AnimationController _sleepCtrl;
  final _rand = math.Random();
  Timer? _blinkTimer;
  Timer? _inactivityTimer;
  bool _asleep = false;

  static const _inactivityDelay = Duration(seconds: 45);

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

    _waveCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));

    _sleepCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));

    _resetInactivityTimer();
  }

  void _scheduleNextBlink() {
    _blinkTimer = Timer(Duration(milliseconds: 2200 + _rand.nextInt(3200)), () {
      if (!mounted) return;
      if (!_asleep) {
        _blinkCtrl.forward(from: 0).whenComplete(() {
          if (mounted) _blinkCtrl.reverse();
        });
      }
      _scheduleNextBlink();
    });
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_inactivityDelay, _fallAsleep);
  }

  void _fallAsleep() {
    if (!mounted || _asleep) return;
    setState(() => _asleep = true);
    _sleepCtrl.forward();
    _burstAt(const ['💤']);
  }

  void _wakeUp() {
    if (!_asleep) return;
    setState(() => _asleep = false);
    _sleepCtrl.reverse();
    _burstAt(const ['✨', '☀️']);
  }

  void _burstAt(List<String> stickers) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final origin = box.localToGlobal(box.size.center(Offset.zero));
    FloatingStickers.burst(context, stickers: stickers, count: stickers.length, origin: origin);
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _inactivityTimer?.cancel();
    _idleCtrl.dispose();
    _blinkCtrl.dispose();
    _tapCtrl.dispose();
    _waveCtrl.dispose();
    _sleepCtrl.dispose();
    super.dispose();
  }

  void _onTap() {
    _resetInactivityTimer();
    if (_asleep) {
      _wakeUp();
      return;
    }
    HapticFeedback.selectionClick();
    _tapCtrl.forward(from: 0);
    _burstAt(const ['✨', '💫']);
  }

  void _onLongPress() {
    _resetInactivityTimer();
    if (_asleep) {
      _wakeUp();
      return;
    }
    HapticFeedback.mediumImpact();
    _waveCtrl.forward(from: 0);
    _burstAt(const ['👋']);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      onLongPress: _onLongPress,
      child: AnimatedBuilder(
        animation: Listenable.merge(
            [_idleCtrl, _blinkCtrl, _tapCtrl, _waveCtrl, _sleepCtrl]),
        builder: (context, _) {
          final sleepAmount = _sleepCtrl.value;
          final bob = math.sin(_idleCtrl.value * math.pi) * 4 * (1 - sleepAmount);
          return Transform.translate(
            offset: Offset(0, -bob),
            child: ScaleTransition(
              scale: _tapScale,
              child: CustomPaint(
                size: Size.square(widget.size),
                painter: _MascotPainter(
                  wingFlutter: _idleCtrl.value,
                  blink: math.max(_blinkCtrl.value, sleepAmount),
                  sleepAmount: sleepAmount,
                  waveAmount: _waveCtrl.value,
                  excited: _tapCtrl.isAnimating,
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
  final double sleepAmount;
  final double waveAmount;
  final bool excited;
  _MascotPainter({
    required this.wingFlutter,
    required this.blink,
    required this.sleepAmount,
    required this.waveAmount,
    required this.excited,
  });

  static const _body = Color(0xFFE8899B); // app's rose accent
  static const _bodyDark = Color(0xFFC96A7C);
  static const _belly = Color(0xFFFDEEE7);
  static const _wing = Color(0xFFE8C170); // app's gold accent

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Sleeping tilts the whole creature a little, like it's leaning over.
    canvas.save();
    if (sleepAmount > 0) {
      canvas.translate(w / 2, h / 2);
      canvas.rotate(sleepAmount * 0.12);
      canvas.translate(-w / 2, -h / 2);
    }

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

    // Wings — small folded triangles. Idle: gentle flutter. Waving: the
    // right wing lifts up and rocks side to side like a hand-wave.
    final flutter = (math.sin(wingFlutter * math.pi * 2) * 0.08) * (1 - sleepAmount);
    final wavePaint = Paint()..color = _wing;
    for (final side in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(center.dx + side * w * 0.28, center.dy - h * 0.06);
      var angle = side * (0.5 + flutter) * (1 - sleepAmount * 0.6);
      if (side > 0 && waveAmount > 0) {
        final wave = math.sin(waveAmount * math.pi * 4) * 0.35;
        angle = -1.3 + wave; // raised, rocking
      }
      canvas.rotate(angle);
      final wingPath = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(side * w * 0.28, -h * 0.18, side * w * 0.22, h * 0.06)
        ..quadraticBezierTo(side * w * 0.1, h * 0.02, 0, 0)
        ..close();
      canvas.drawPath(wingPath, wavePaint);
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

    // Eyes — big and round normally; a wide-open "excited" look on tap;
    // squashed shut (blink, or fully closed while asleep).
    final excitedBoost = excited ? 1.15 : 1.0;
    final eyeH = h * 0.09 * excitedBoost * (1 - blink * 0.92);
    final eyeW = w * 0.11 * excitedBoost;
    final eyeWhite = Paint()..color = Colors.white;
    final eyePupil = Paint()..color = const Color(0xFF3D2B24);
    for (final side in [-1.0, 1.0]) {
      final eyeCenter = Offset(headCenter.dx + side * w * 0.11, headCenter.dy);
      if (blink > 0.92) {
        // Fully closed — a soft little curved line instead of an oval.
        final closedPaint = Paint()
          ..color = _bodyDark
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.015
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
          Rect.fromCenter(center: eyeCenter, width: eyeW, height: w * 0.06),
          0.15,
          2.8,
          false,
          closedPaint,
        );
        continue;
      }
      canvas.drawOval(
        Rect.fromCenter(center: eyeCenter, width: eyeW, height: eyeH),
        eyeWhite,
      );
      canvas.drawCircle(
        Offset(eyeCenter.dx, eyeCenter.dy + eyeH * 0.05),
        w * 0.035 * excitedBoost,
        eyePupil,
      );
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

    // Snout bump + smile — a bigger open smile while excited.
    final smilePaint = Paint()
      ..color = _bodyDark
      ..style = excited ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = w * 0.02
      ..strokeCap = StrokeCap.round;
    if (excited) {
      final path = Path()
        ..moveTo(headCenter.dx - w * 0.05, headCenter.dy + h * 0.09)
        ..quadraticBezierTo(headCenter.dx, headCenter.dy + h * 0.19, headCenter.dx + w * 0.05,
            headCenter.dy + h * 0.09)
        ..close();
      canvas.drawPath(path, smilePaint);
    } else {
      final smilePath = Path()
        ..moveTo(headCenter.dx - w * 0.04, headCenter.dy + h * 0.1)
        ..quadraticBezierTo(headCenter.dx, headCenter.dy + h * 0.14, headCenter.dx + w * 0.04,
            headCenter.dy + h * 0.1);
      canvas.drawPath(smilePath, smilePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MascotPainter oldDelegate) =>
      oldDelegate.wingFlutter != wingFlutter ||
      oldDelegate.blink != blink ||
      oldDelegate.sleepAmount != sleepAmount ||
      oldDelegate.waveAmount != waveAmount ||
      oldDelegate.excited != excited;
}
