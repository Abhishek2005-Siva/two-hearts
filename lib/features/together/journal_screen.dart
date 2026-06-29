import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/content_block.dart';
import '../../core/providers/providers.dart';
import '../../core/firebase/models.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/rich_content_editor.dart' show RichContentEditor;
import '../../shared/widgets/rich_content_viewer.dart' show RichContentViewer;

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
        isNew: true,
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

    return Stack(
      children: [
        // Background: bookshelf image
        Positioned.fill(
          child: Image.asset(
            'assets/images/empty_bookshelf.webp',
            fit: BoxFit.cover,
          ),
        ),
        // Books and content on top
        SingleChildScrollView(
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
        // Barrel decoration in bottom-right corner
        Positioned(
          bottom: 0,
          right: 0,
          child: Image.asset(
            'assets/images/barrel.jpeg',
            width: 80,
            height: 100,
            fit: BoxFit.contain,
          ),
        ),
      ],
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

// ─── Lectern widget ───────────────────────────────────────────────────────

class _LecternWidget extends StatelessWidget {
  final VoidCallback onTap;
  const _LecternWidget({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Image.asset(
        'assets/images/lectern.webp',
        width: 100,
        height: 120,
        fit: BoxFit.contain,
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

  bool _editing = false;
  bool _saving = false;
  Timer? _debounce;

  List<ContentBlock> _blocks = [];

  static List<ContentBlock> _parseBlocks(String? raw) {
    if (raw == null || raw.isEmpty) return [ContentBlock.newText()];
    if (raw.trimLeft().startsWith('[')) {
      try {
        final list = jsonDecode(raw) as List;
        return list.map((m) => ContentBlock.fromMap(m as Map<String, dynamic>)).toList();
      } catch (_) {}
    }
    return [ContentBlock(id: '0', type: BlockType.text, text: raw, textSize: TextSize.body)];
  }

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.day.title ?? '');
    _blocks = _parseBlocks(widget.day.sharedEntry);

    // New entries start in edit mode
    if (widget.isNew) _editing = true;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleCtrl.dispose();
    super.dispose();
  }

  void _onBlocksChanged(List<ContentBlock> blocks) {
    setState(() => _blocks = blocks);
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () {
      if (mounted && _editing) _save(silent: true);
    });
  }

  Future<void> _save({bool silent = false}) async {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null) return;

    final encoded = jsonEncode(_blocks.map((b) => b.toMap()).toList());
    if (!silent) setState(() => _saving = true);
    try {
      await ref.read(firestoreServiceProvider).saveJournalEntry(
            coupleId,
            widget.day.id,
            encoded,
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

  @override
  Widget build(BuildContext context) {
    final color = _bookColor(widget.day.id);
    final dateStr = widget.day.id.length >= 10
        ? widget.day.id.substring(0, 10)
        : widget.day.id;

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
          // Main page area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: LayoutBuilder(
                builder: (context, constraints) => CustomPaint(
                  painter: _PagePainter(),
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(52, 16, 16, 16),
                      child: _editing
                          ? _PaperThemedEditor(
                              key: ValueKey(_editing),
                              initialBlocks: _blocks,
                              onChanged: _onBlocksChanged,
                            )
                          : _PaperThemedViewer(
                              blocks: _blocks,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Toolbar
          _BookToolbar(
            editing: _editing,
            onEdit: () => setState(() => _editing = true),
            onSave: () => _save(),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ─── Book toolbar ─────────────────────────────────────────────────────────

class _BookToolbar extends StatelessWidget {
  final bool editing;
  final VoidCallback onEdit;
  final VoidCallback onSave;

  const _BookToolbar({
    required this.editing,
    required this.onEdit,
    required this.onSave,
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
              label: '✏️ Edit',
              onTap: onEdit,
            )
          else
            _ToolbarBtn(
              icon: Icons.save_outlined,
              label: '💾 Save',
              onTap: onSave,
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

  const _ToolbarBtn(
      {required this.icon,
      required this.label,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = onTap != null;
    final col = active
        ? const Color(0xFFF5DEB3)
        : const Color(0xFFF5DEB3).withValues(alpha: 0.3);
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

// ─── Paper-themed wrappers (dark ink on aged paper) ───────────────────────

/// Wraps [RichContentEditor] with a dark-ink theme so text is legible on the
/// cream/aged-paper page background.
class _PaperThemedEditor extends StatelessWidget {
  final List<ContentBlock> initialBlocks;
  final ValueChanged<List<ContentBlock>> onChanged;

  const _PaperThemedEditor({
    super.key,
    required this.initialBlocks,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(
              bodyColor: const Color(0xFF2A1A0A),
              displayColor: const Color(0xFF2A1A0A),
            ),
        inputDecorationTheme: const InputDecorationTheme(
          border: InputBorder.none,
        ),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Color(0xFF2A1A0A)),
        child: RichContentEditor(
          initialBlocks: initialBlocks,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Wraps [RichContentViewer] with a dark-ink theme so text is legible on the
/// cream/aged-paper page background.
class _PaperThemedViewer extends StatelessWidget {
  final List<ContentBlock> blocks;

  const _PaperThemedViewer({required this.blocks});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(
              bodyColor: const Color(0xFF2A1A0A),
              displayColor: const Color(0xFF2A1A0A),
            ),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Color(0xFF2A1A0A)),
        child: RichContentViewer(blocks: blocks),
      ),
    );
  }
}
