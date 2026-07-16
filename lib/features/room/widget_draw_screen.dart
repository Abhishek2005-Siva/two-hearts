import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/cloudinary_service.dart';

/// A single freehand stroke — a polyline of points with its own color/width.
class _Stroke {
  final List<Offset> points;
  final Color color;
  final double width;

  _Stroke({required this.color, required this.width}) : points = [];
}

/// Draw-and-send screen: one partner draws with a finger, the finished
/// drawing is rendered to a PNG, uploaded, and pushed to the *other*
/// partner's Android home-screen widget. No live streaming — a single
/// static image per send, matching this app's other singleton-doc,
/// full-rebuild-on-change room features.
class WidgetDrawScreen extends ConsumerStatefulWidget {
  const WidgetDrawScreen({super.key});

  @override
  ConsumerState<WidgetDrawScreen> createState() => _WidgetDrawScreenState();
}

class _WidgetDrawScreenState extends ConsumerState<WidgetDrawScreen> {
  static const _palette = [
    AppColors.rose,
    AppColors.coral,
    AppColors.gold,
    AppColors.lavender,
    Colors.white,
  ];

  final GlobalKey _boardKey = GlobalKey();
  final List<_Stroke> _strokes = [];
  Color _color = AppColors.rose;
  double _brushWidth = 6;
  bool _sending = false;

  void _startStroke(Offset point) {
    setState(() {
      _strokes.add(_Stroke(color: _color, width: _brushWidth)..points.add(point));
    });
  }

  void _extendStroke(Offset point) {
    setState(() => _strokes.last.points.add(point));
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.removeLast());
  }

  void _clear() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.clear());
  }

  Future<void> _send() async {
    if (_strokes.isEmpty || _sending) return;
    final coupleId = ref.read(coupleIdProvider);
    final myUid = ref.read(currentUserProvider).valueOrNull?.uid;
    if (coupleId == null || myUid == null) return;

    setState(() => _sending = true);
    try {
      final boundary =
          _boardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final imageUrl = await CloudinaryService.uploadImage(
        bytes,
        folder: 'home_widget',
      );

      await ref.read(firestoreServiceProvider).setHomeWidgetDrawing(
            coupleId,
            imageUrl: imageUrl,
            authorUid: myUid,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sent to their widget ♡')),
      );
      setState(() => _strokes.clear());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\'t send: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text('Draw for them'),
        actions: [
          IconButton(
            tooltip: 'Undo',
            icon: const Icon(Icons.undo_rounded),
            onPressed: _strokes.isEmpty ? null : _undo,
          ),
          IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _strokes.isEmpty ? null : _clear,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: RepaintBoundary(
                    key: _boardKey,
                    child: GestureDetector(
                      onPanStart: (d) => _startStroke(d.localPosition),
                      onPanUpdate: (d) => _extendStroke(d.localPosition),
                      child: CustomPaint(
                        painter: _DrawingPainter(_strokes),
                        size: Size.infinite,
                        child: Container(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final swatch in _palette)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () => setState(() => _color = swatch),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: swatch,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _color == swatch
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Slider(
                      value: _brushWidth,
                      min: 2,
                      max: 20,
                      activeColor: _color,
                      onChanged: (v) => setState(() => _brushWidth = v),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: GradientButton(
                label: _sending ? 'Sending...' : 'Send to their widget',
                loading: _sending,
                cuteStickers: const ['💌', '❤️', '✨'],
                onTap: _send,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawingPainter extends CustomPainter {
  final List<_Stroke> strokes;

  _DrawingPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      for (var i = 0; i < stroke.points.length - 1; i++) {
        canvas.drawLine(stroke.points[i], stroke.points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) => true;
}
