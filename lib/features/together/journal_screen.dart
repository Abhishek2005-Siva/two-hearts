import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/providers/providers.dart';
import '../../core/firebase/models.dart';
import '../../core/theme/app_theme.dart';

// ─── Bookshelf color palette ──────────────────────────────────────────────

const List<Color> _kBookColors = [
  Color(0xFF8B3A3A), // deep red
  Color(0xFF2E5E8E), // navy blue
  Color(0xFF4A7C59), // forest green
  Color(0xFF7B4E9E), // purple
  Color(0xFFB5681F), // burnt orange
  Color(0xFF3D6E8E), // teal
  Color(0xFF8E4A6A), // mauve
  Color(0xFF5C6E3E), // olive
  Color(0xFF6B4226), // chocolate
  Color(0xFF1E5E5E), // dark teal
];

Color _bookColor(String id) =>
    _kBookColors[id.hashCode.abs() % _kBookColors.length];

double _bookWidth(String id) => (id.hashCode.abs() % 17) + 36.0; // 36–52

// ─── Page splitting ───────────────────────────────────────────────────────

List<String> _splitIntoPages(String content, {int charsPerPage = 800}) {
  if (content.isEmpty) return [''];
  final pages = <String>[];
  for (int i = 0; i < content.length; i += charsPerPage) {
    pages.add(content.substring(i, min(i + charsPerPage, content.length)));
  }
  return pages;
}

// ─── Rich text rendering (==highlight== and __underline__) ────────────────

TextSpan _renderRichText(String text, TextStyle base) {
  final spans = <InlineSpan>[];
  final pattern = RegExp(r'==(.+?)==|__(.+?)__');
  int lastEnd = 0;
  for (final m in pattern.allMatches(text)) {
    if (m.start > lastEnd) {
      spans.add(TextSpan(text: text.substring(lastEnd, m.start), style: base));
    }
    if (m.group(1) != null) {
      // highlight
      spans.add(TextSpan(
        text: m.group(1),
        style: base.copyWith(
          backgroundColor: const Color(0xFFFFE066),
          color: const Color(0xFF3A2A00),
        ),
      ));
    } else if (m.group(2) != null) {
      // underline
      spans.add(TextSpan(
        text: m.group(2),
        style: base.copyWith(
          decoration: TextDecoration.underline,
          decorationColor: base.color,
        ),
      ));
    }
    lastEnd = m.end;
  }
  if (lastEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastEnd), style: base));
  }
  return TextSpan(children: spans);
}

// ─── Main Screen ──────────────────────────────────────────────────────────

class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journalAsync = ref.watch(journalProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF2A1F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1208),
        title: Text(
          'Our Journal',
          style: GoogleFonts.playfairDisplay(
            color: const Color(0xFFF5DEB3),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFF5DEB3)),
      ),
      body: journalAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: AppColors.textPrimary)),
        ),
        data: (entries) => _BookshelfBody(
          entries: entries,
          onLecternTap: () => _openTodayEntry(context, ref, entries),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _LecternWidget(
        onTap: () => _openTodayEntry(context, ref,
            ref.read(journalProvider).valueOrNull ?? []),
      ),
    );
  }

  void _openTodayEntry(
      BuildContext context, WidgetRef ref, List<JournalDay> entries) {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final existing = entries.where((e) => e.id == today).firstOrNull;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _BookView(
        day: existing ??
            JournalDay(id: today, title: '', sharedEntry: ''),
        isNew: existing == null,
      ),
    ));
  }
}

// ─── Bookshelf body ───────────────────────────────────────────────────────

class _BookshelfBody extends StatelessWidget {
  final List<JournalDay> entries;
  final VoidCallback onLecternTap;

  const _BookshelfBody({required this.entries, required this.onLecternTap});

  @override
  Widget build(BuildContext context) {
    final mid = (entries.length / 2).ceil();
    final shelf1 = entries.take(mid).toList();
    final shelf2 = entries.skip(mid).toList();

    return CustomPaint(
      painter: _WallPainter(),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),
            _Shelf(books: shelf1),
            const SizedBox(height: 32),
            _Shelf(books: shelf2),
            const SizedBox(height: 140),
          ],
        ),
      ),
    );
  }
}

// ─── Single shelf ─────────────────────────────────────────────────────────

class _Shelf extends StatelessWidget {
  final List<JournalDay> books;
  const _Shelf({required this.books});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 130,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _buildBookItems(context),
            ),
          ),
        ),
        CustomPaint(
          painter: _ShelfPainter(),
          child: const SizedBox(height: 22),
        ),
      ],
    );
  }

  List<Widget> _buildBookItems(BuildContext context) {
    final items = <Widget>[];
    for (int i = 0; i < books.length; i++) {
      if (i > 0 && i % 6 == 0) {
        items.add(_DecoItem());
      }
      items.add(_BookSpine(
        day: books[i],
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => _BookView(day: books[i], isNew: false),
        )),
      ));
    }
    if (books.isEmpty) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            'No entries yet',
            style: GoogleFonts.lato(
              color: const Color(0xFFF5DEB3).withValues(alpha: 0.4),
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }
    return items;
  }
}

// ─── Book spine widget ────────────────────────────────────────────────────

class _BookSpine extends StatelessWidget {
  final JournalDay day;
  final VoidCallback onTap;

  const _BookSpine({required this.day, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _bookColor(day.id);
    final width = _bookWidth(day.id);
    final title = day.title ?? 'Untitled';
    final dateStr = _formatId(day.id);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: 120,
        margin: const EdgeInsets.only(right: 2),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.85),
              color,
              color.withValues(alpha: 0.7),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(3),
            topRight: Radius.circular(3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 4,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lato(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: RotatedBox(
                quarterTurns: 3,
                child: Text(
                  dateStr,
                  style: GoogleFonts.lato(
                    fontSize: 7,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatId(String id) {
    final dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}');
    if (dateRegex.hasMatch(id)) return id.substring(0, 10);
    if (id.length >= 4) return id.substring(0, 4);
    return id;
  }
}

// ─── Decorative candle ────────────────────────────────────────────────────

class _DecoItem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 120,
      margin: const EdgeInsets.only(right: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            width: 8,
            height: 12,
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Container(
            width: 10,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F0E0),
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          Container(
            width: 18,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFF8B6340),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Painters ─────────────────────────────────────────────────────────────

class _WallPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF2A1F14),
    );
  }

  @override
  bool shouldRepaint(_WallPainter old) => false;
}

class _ShelfPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final woodPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFA0733A), Color(0xFF8B6340), Color(0xFF7A5530)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), woodPaint);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 8),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.black.withValues(alpha: 0.5),
            Colors.black.withValues(alpha: 0.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, size.width, 8)),
    );

    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 6, size.width, 6),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.4),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, size.height - 6, size.width, 6)),
    );

    final grainPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x + 10, size.height), grainPaint);
    }
  }

  @override
  bool shouldRepaint(_ShelfPainter old) => false;
}

// ─── Lectern Painter ──────────────────────────────────────────────────────

class _LecternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Shadow/glow beneath lectern
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w / 2, h * 0.96), width: w * 0.7, height: 10),
      shadowPaint,
    );

    // Dark brown base (trapezoid — wider at bottom)
    final basePaint = Paint()..color = const Color(0xFF3B1F0A);
    final basePath = Path()
      ..moveTo(w * 0.25, h * 0.62)
      ..lineTo(w * 0.75, h * 0.62)
      ..lineTo(w * 0.82, h * 0.90)
      ..lineTo(w * 0.18, h * 0.90)
      ..close();
    canvas.drawPath(basePath, basePaint);

    // Base highlight (top edge lighter)
    final baseHighlight = Paint()
      ..color = const Color(0xFF6B3A15)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
        Offset(w * 0.25, h * 0.62), Offset(w * 0.75, h * 0.62), baseHighlight);

    // Medium brown column/stand
    final standPaint = Paint()
      ..shader = LinearGradient(
        colors: const [Color(0xFF7A4A1A), Color(0xFF5C3510)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(w * 0.38, h * 0.35, w * 0.24, h * 0.30));
    final standRect =
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.38, h * 0.35, w * 0.24, h * 0.30),
            const Radius.circular(2));
    canvas.drawRRect(standRect, standPaint);

    // Open book on top of stand
    // Book body — slightly angled, open V shape
    final leftPage = Path()
      ..moveTo(w * 0.10, h * 0.12)
      ..lineTo(w * 0.50, h * 0.22)
      ..lineTo(w * 0.50, h * 0.38)
      ..lineTo(w * 0.08, h * 0.36)
      ..close();
    final rightPage = Path()
      ..moveTo(w * 0.90, h * 0.12)
      ..lineTo(w * 0.50, h * 0.22)
      ..lineTo(w * 0.50, h * 0.38)
      ..lineTo(w * 0.92, h * 0.36)
      ..close();

    // Book cover (darker outer)
    final coverPaint = Paint()..color = const Color(0xFF8B5E2A);
    final leftCover = Path()
      ..moveTo(w * 0.07, h * 0.11)
      ..lineTo(w * 0.50, h * 0.21)
      ..lineTo(w * 0.50, h * 0.40)
      ..lineTo(w * 0.05, h * 0.38)
      ..close();
    final rightCover = Path()
      ..moveTo(w * 0.93, h * 0.11)
      ..lineTo(w * 0.50, h * 0.21)
      ..lineTo(w * 0.50, h * 0.40)
      ..lineTo(w * 0.95, h * 0.38)
      ..close();
    canvas.drawPath(leftCover, coverPaint);
    canvas.drawPath(rightCover, coverPaint);

    // White pages
    final pagePaint = Paint()..color = const Color(0xFFFDF6E3);
    canvas.drawPath(leftPage, pagePaint);
    canvas.drawPath(rightPage, pagePaint);

    // Page lines (subtle)
    final linePaint = Paint()
      ..color = const Color(0xFFBBA97A).withValues(alpha: 0.5)
      ..strokeWidth = 0.7;
    for (int i = 1; i <= 3; i++) {
      final t = i / 4.0;
      // Left page lines
      final lx1 = w * 0.10 + (w * 0.40) * t * 0.0 + w * 0.04;
      final ly = h * 0.12 + (h * 0.24) * t;
      final lx2 = w * 0.50 - w * 0.04;
      canvas.drawLine(Offset(lx1, ly), Offset(lx2, ly), linePaint);
      // Right page lines
      final rx1 = w * 0.50 + w * 0.04;
      final rx2 = w * 0.90 - (w * 0.02);
      canvas.drawLine(Offset(rx1, ly), Offset(rx2, ly), linePaint);
    }

    // Spine crease in center
    final spinePaint = Paint()
      ..color = const Color(0xFF6B4220)
      ..strokeWidth = 2.0;
    canvas.drawLine(
        Offset(w * 0.50, h * 0.21), Offset(w * 0.50, h * 0.40), spinePaint);

    // Lectern top flat surface connecting book to stand
    final topPaint = Paint()..color = const Color(0xFF6B3A15);
    final topPath = Path()
      ..moveTo(w * 0.05, h * 0.36)
      ..lineTo(w * 0.95, h * 0.36)
      ..lineTo(w * 0.75, h * 0.45)
      ..lineTo(w * 0.25, h * 0.45)
      ..close();
    canvas.drawPath(topPath, topPaint);

    // Pixel-style accent dots on base (Minecraft block texture hint)
    final dotPaint = Paint()..color = const Color(0xFF2A1005).withValues(alpha: 0.6);
    for (int row = 0; row < 2; row++) {
      for (int col = 0; col < 4; col++) {
        canvas.drawRect(
          Rect.fromLTWH(
            w * 0.28 + col * w * 0.12,
            h * 0.68 + row * h * 0.08,
            w * 0.06,
            h * 0.04,
          ),
          dotPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_LecternPainter old) => false;
}

// ─── Lectern widget ───────────────────────────────────────────────────────

class _LecternWidget extends StatelessWidget {
  final VoidCallback onTap;
  const _LecternWidget({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            painter: _LecternPainter(),
            size: const Size(80, 100),
          ),
          const SizedBox(height: 4),
          Text(
            'Write',
            style: GoogleFonts.lato(
              color: const Color(0xFFF5DEB3).withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Aged paper page painter ──────────────────────────────────────────────

class _PagePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Paper background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(4)),
      Paint()..color = const Color(0xFFF5E6C8),
    );

    // Horizontal line guides
    final linePaint = Paint()
      ..color = const Color(0xFFBFA882).withValues(alpha: 0.45)
      ..strokeWidth = 0.8;
    const lineSpacing = 28.0;
    const topPad = 48.0;
    for (double y = topPad; y < size.height - 20; y += lineSpacing) {
      canvas.drawLine(
          Offset(16, y), Offset(size.width - 16, y), linePaint);
    }

    // Left margin line (red, like ruled paper)
    final marginPaint = Paint()
      ..color = const Color(0xFFE8A09A).withValues(alpha: 0.4)
      ..strokeWidth = 1.0;
    canvas.drawLine(
        const Offset(44, 0), Offset(44, size.height), marginPaint);

    // Page curl shadow on bottom-right
    final curlPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.bottomRight,
        radius: 0.3,
        colors: [
          Colors.black.withValues(alpha: 0.18),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(4)),
      curlPaint,
    );
  }

  @override
  bool shouldRepaint(_PagePainter old) => false;
}

// ─── Book open view ───────────────────────────────────────────────────────

class _BookView extends ConsumerStatefulWidget {
  final JournalDay day;
  final bool isNew;

  const _BookView({required this.day, required this.isNew});

  @override
  ConsumerState<_BookView> createState() => _BookViewState();
}

class _BookViewState extends ConsumerState<_BookView> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  late PageController _pageCtrl;

  bool _editing = false;
  bool _saving = false;
  int _currentPage = 0;
  List<String> _pages = [''];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.day.title ?? '');
    _contentCtrl = TextEditingController(text: widget.day.content);
    _pages = _splitIntoPages(widget.day.content);
    _pageCtrl = PageController();

    // New entries start in edit mode
    if (widget.isNew) _editing = true;

    _contentCtrl.addListener(_onContentChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    // Re-split pages on content change
    setState(() {
      _pages = _splitIntoPages(_contentCtrl.text);
    });
    // Debounced auto-save
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () {
      if (mounted && _editing) _save(silent: true);
    });
  }

  Future<void> _save({bool silent = false}) async {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null) return;

    if (!silent) setState(() => _saving = true);
    try {
      await ref.read(firestoreServiceProvider).saveJournalEntry(
            coupleId,
            widget.day.id,
            _contentCtrl.text,
            title: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
          );
      if (mounted && !silent) {
        setState(() {
          _editing = false;
          _saving = false;
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    }
  }

  void _applyMarkup(String open, String close) {
    final sel = _contentCtrl.selection;
    if (!sel.isValid || sel.isCollapsed) return;
    final text = _contentCtrl.text;
    final selected = text.substring(sel.start, sel.end);
    final newText =
        text.replaceRange(sel.start, sel.end, '$open$selected$close');
    _contentCtrl.value = _contentCtrl.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(
          offset: sel.start + open.length + selected.length + close.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _bookColor(widget.day.id);
    final dateStr = widget.day.id.length >= 10
        ? widget.day.id.substring(0, 10)
        : widget.day.id;
    final totalPages = _pages.isEmpty ? 1 : _pages.length;

    final baseStyle = GoogleFonts.lora(
      fontSize: 16,
      color: const Color(0xFF2C1A0A),
      height: 1.75,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF1A1208),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1208),
        iconTheme: const IconThemeData(color: Color(0xFFF5DEB3)),
        title: _editing
            ? TextField(
                controller: _titleCtrl,
                style: GoogleFonts.playfairDisplay(
                  color: const Color(0xFFF5DEB3),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Entry title...',
                  hintStyle: TextStyle(color: Color(0x55F5DEB3)),
                ),
              )
            : Text(
                widget.day.title?.isNotEmpty == true
                    ? widget.day.title!
                    : dateStr,
                style: GoogleFonts.playfairDisplay(
                  color: const Color(0xFFF5DEB3),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
        actions: [
          if (_editing) ...[
            if (_saving)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFFF5DEB3)),
                ),
              )
            else
              TextButton(
                onPressed: () => _save(),
                child: Text('Save',
                    style: GoogleFonts.lato(
                        color: color, fontWeight: FontWeight.bold)),
              ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Page counter
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'Page ${_currentPage + 1} of $totalPages',
              style: GoogleFonts.lato(
                color: const Color(0xFFF5DEB3).withValues(alpha: 0.45),
                fontSize: 11,
              ),
            ),
          ),
          // Main page area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Left arrow
                  _PageArrow(
                    icon: Icons.chevron_left,
                    enabled: _currentPage > 0,
                    onTap: () {
                      _pageCtrl.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut);
                    },
                  ),
                  // Page widget
                  Expanded(
                    child: _editing
                        ? _EditablePage(
                            controller: _contentCtrl,
                            baseStyle: baseStyle,
                          )
                        : PageView.builder(
                            controller: _pageCtrl,
                            itemCount: totalPages,
                            onPageChanged: (i) =>
                                setState(() => _currentPage = i),
                            itemBuilder: (_, i) => _ReadPage(
                              text: _pages[i],
                              baseStyle: baseStyle,
                            ),
                          ),
                  ),
                  // Right arrow
                  _PageArrow(
                    icon: Icons.chevron_right,
                    enabled: _currentPage < totalPages - 1,
                    onTap: () {
                      _pageCtrl.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut);
                    },
                  ),
                ],
              ),
            ),
          ),
          // Toolbar
          _BookToolbar(
            editing: _editing,
            onEdit: () {
              setState(() => _editing = true);
            },
            onHighlight: () => _applyMarkup('==', '=='),
            onUnderline: () => _applyMarkup('__', '__'),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ─── Read-only page ───────────────────────────────────────────────────────

class _ReadPage extends StatelessWidget {
  final String text;
  final TextStyle baseStyle;
  const _ReadPage({required this.text, required this.baseStyle});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PagePainter(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(52, 16, 16, 16),
        child: text.isEmpty
            ? Text(
                'Empty page...',
                style: baseStyle.copyWith(
                  color: const Color(0xFF9B7B5A).withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                ),
              )
            : RichText(
                text: _renderRichText(text, baseStyle),
              ),
      ),
    );
  }
}

// ─── Editable page ────────────────────────────────────────────────────────

class _EditablePage extends StatelessWidget {
  final TextEditingController controller;
  final TextStyle baseStyle;
  const _EditablePage(
      {required this.controller, required this.baseStyle});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PagePainter(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(52, 16, 16, 16),
        child: TextField(
          controller: controller,
          maxLines: null,
          expands: true,
          style: baseStyle,
          cursorColor: const Color(0xFF8B5E2A),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Write your story here...',
            hintStyle: TextStyle(
              color: Color(0xFF9B7B5A),
              fontStyle: FontStyle.italic,
            ),
          ),
          textAlignVertical: TextAlignVertical.top,
        ),
      ),
    );
  }
}

// ─── Page arrow button ────────────────────────────────────────────────────

class _PageArrow extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _PageArrow(
      {required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: SizedBox(
        width: 32,
        child: Icon(
          icon,
          color: enabled
              ? const Color(0xFFF5DEB3).withValues(alpha: 0.8)
              : const Color(0xFFF5DEB3).withValues(alpha: 0.15),
          size: 28,
        ),
      ),
    );
  }
}

// ─── Book toolbar ─────────────────────────────────────────────────────────

class _BookToolbar extends StatelessWidget {
  final bool editing;
  final VoidCallback onEdit;
  final VoidCallback onHighlight;
  final VoidCallback onUnderline;

  const _BookToolbar({
    required this.editing,
    required this.onEdit,
    required this.onHighlight,
    required this.onUnderline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1A0A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF8B6340).withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          if (!editing)
            _ToolbarBtn(
              icon: Icons.edit_outlined,
              label: 'Edit',
              onTap: onEdit,
            ),
          _ToolbarBtn(
            icon: Icons.highlight,
            label: 'Highlight',
            onTap: editing ? onHighlight : null,
            color: const Color(0xFFFFE066),
          ),
          _ToolbarBtn(
            icon: Icons.format_underline,
            label: 'Underline',
            onTap: editing ? onUnderline : null,
          ),
        ],
      ),
    );
  }
}

class _ToolbarBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  const _ToolbarBtn(
      {required this.icon,
      required this.label,
      this.onTap,
      this.color});

  @override
  Widget build(BuildContext context) {
    final active = onTap != null;
    final col = color ??
        (active
            ? const Color(0xFFF5DEB3)
            : const Color(0xFFF5DEB3).withValues(alpha: 0.3));
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: col, size: 20),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.lato(
              fontSize: 10,
              color: col,
            ),
          ),
        ],
      ),
    );
  }
}
