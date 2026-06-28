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

double _bookWidth(String id) {
  final w = (id.hashCode.abs() % 17) + 36.0; // 36–52
  return w;
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
        data: (entries) => _BookshelfBody(entries: entries),
      ),
      floatingActionButton: _LecternButton(
        onTap: () => _showCreateSheet(context, ref),
      ),
    );
  }

  void _showCreateSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateJournalSheet(),
    );
  }
}

// ─── Bookshelf body ───────────────────────────────────────────────────────

class _BookshelfBody extends StatelessWidget {
  final List<JournalDay> entries;
  const _BookshelfBody({required this.entries});

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
            const SizedBox(height: 100),
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
        onTap: () => _showDetailSheet(context, books[i]),
      ));
    }
    // Always show at least the lectern placeholder if empty
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

  void _showDetailSheet(BuildContext context, JournalDay day) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookDetailSheet(day: day),
    );
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
          // Flame
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
          // Candle body
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
          // Candle holder
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
    // Shelf plank
    final woodPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFA0733A), Color(0xFF8B6340), Color(0xFF7A5530)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), woodPaint);

    // Top shadow
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

    // Bottom shadow
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

    // Wood grain
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

// ─── Lectern FAB ──────────────────────────────────────────────────────────

class _LecternButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LecternButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent, AppColors.coral],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

// ─── Create journal bottom sheet ──────────────────────────────────────────

class _CreateJournalSheet extends ConsumerStatefulWidget {
  const _CreateJournalSheet();

  @override
  ConsumerState<_CreateJournalSheet> createState() =>
      _CreateJournalSheetState();
}

class _CreateJournalSheetState extends ConsumerState<_CreateJournalSheet> {
  final _titleCtrl = TextEditingController();
  final _entryCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final title = _titleCtrl.text.trim();
    final entry = _entryCtrl.text.trim();
    if (title.isEmpty || entry.isEmpty) return;

    final coupleId = ref.read(coupleIdProvider);
    final me = ref.read(currentUserProvider).valueOrNull;
    final partner = ref.read(partnerUserProvider).valueOrNull;
    if (coupleId == null || me == null) return;

    setState(() => _loading = true);
    try {
      final dayId = DateTime.now().toIso8601String().substring(0, 10);
      await ref.read(firestoreServiceProvider).submitJournalEntry(
            coupleId,
            dayId,
            entry,
            partner?.uid ?? '',
            title: title,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + insets.bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1208),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Color(0xFF8B6340), width: 1.5),
          left: BorderSide(color: Color(0xFF8B6340), width: 1.5),
          right: BorderSide(color: Color(0xFF8B6340), width: 1.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF8B6340),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'New Journal Entry',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              color: const Color(0xFFF5DEB3),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _titleCtrl,
            style: const TextStyle(color: Color(0xFFF5DEB3)),
            decoration: InputDecoration(
              hintText: 'Title',
              hintStyle: TextStyle(
                  color: const Color(0xFFF5DEB3).withValues(alpha: 0.4)),
              filled: true,
              fillColor: const Color(0xFF2A1A0A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF8B6340)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                    color: const Color(0xFF8B6340).withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: Color(0xFF8B6340), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _entryCtrl,
            maxLines: 5,
            style: const TextStyle(color: Color(0xFFF5DEB3)),
            decoration: InputDecoration(
              hintText: 'Write your entry...',
              hintStyle: TextStyle(
                  color: const Color(0xFFF5DEB3).withValues(alpha: 0.4)),
              filled: true,
              fillColor: const Color(0xFF2A1A0A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF8B6340)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                    color: const Color(0xFF8B6340).withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: Color(0xFF8B6340), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 20),
          GradientButton(
            label: 'Publish',
            onTap: _publish,
            loading: _loading,
          ),
        ],
      ),
    );
  }
}

// ─── Book detail sheet ────────────────────────────────────────────────────

class _BookDetailSheet extends ConsumerStatefulWidget {
  final JournalDay day;
  const _BookDetailSheet({required this.day});

  @override
  ConsumerState<_BookDetailSheet> createState() => _BookDetailSheetState();
}

class _BookDetailSheetState extends ConsumerState<_BookDetailSheet> {
  final _editCtrl = TextEditingController();
  bool _editing = false;
  bool _loading = false;

  @override
  void dispose() {
    _editCtrl.dispose();
    super.dispose();
  }

  String _formatDate(String id) {
    final dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}');
    if (dateRegex.hasMatch(id)) return id.substring(0, 10);
    return id;
  }

  Future<void> _save() async {
    final entry = _editCtrl.text.trim();
    if (entry.isEmpty) return;

    final coupleId = ref.read(coupleIdProvider);
    final me = ref.read(currentUserProvider).valueOrNull;
    final partner = ref.read(partnerUserProvider).valueOrNull;
    if (coupleId == null || me == null) return;

    setState(() => _loading = true);
    try {
      await ref.read(firestoreServiceProvider).submitJournalEntry(
            coupleId,
            widget.day.id,
            entry,
            partner?.uid ?? '',
            title: widget.day.title,
          );
      setState(() {
        _editing = false;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).valueOrNull;
    final partner = ref.watch(partnerUserProvider).valueOrNull;
    final day = widget.day;

    final myUid = me?.uid ?? '';
    final isA = day.uidA == myUid;
    final myEntry = isA ? day.entryA : day.entryB;
    final partnerEntry = isA ? day.entryB : day.entryA;
    final myName = me?.displayName ?? 'You';
    final partnerName = partner?.displayName ?? 'Partner';
    final color = _bookColor(day.id);
    final insets = MediaQuery.of(context).viewInsets;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + insets.bottom),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1008),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: color, width: 2),
          left: BorderSide(color: color.withValues(alpha: 0.5)),
          right: BorderSide(color: color.withValues(alpha: 0.5)),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              day.title ?? 'Untitled',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                color: const Color(0xFFF5DEB3),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(day.id),
              style: GoogleFonts.lato(
                fontSize: 13,
                color: const Color(0xFFF5DEB3).withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            _EntryBlock(
              name: myName,
              entry: myEntry,
              isMe: true,
              color: color,
            ),
            const SizedBox(height: 16),
            _EntryBlock(
              name: partnerName,
              entry: partnerEntry,
              isMe: false,
              color: color,
            ),
            const SizedBox(height: 20),
            if (_editing) ...[
              TextField(
                controller: _editCtrl,
                maxLines: 5,
                style: const TextStyle(color: Color(0xFFF5DEB3)),
                decoration: InputDecoration(
                  hintText: 'Update your entry...',
                  hintStyle: TextStyle(
                      color: const Color(0xFFF5DEB3).withValues(alpha: 0.4)),
                  filled: true,
                  fillColor: const Color(0xFF2A1A0A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: color),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: color.withValues(alpha: 0.5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: color, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: GradientButton(
                      label: 'Save',
                      onTap: _save,
                      loading: _loading,
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => setState(() => _editing = false),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.lato(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ] else ...[
              TextButton.icon(
                onPressed: () {
                  _editCtrl.text = myEntry ?? '';
                  setState(() => _editing = true);
                },
                icon: Icon(Icons.edit_outlined, color: color, size: 18),
                label: Text(
                  myEntry == null ? 'Write your entry' : 'Edit your entry',
                  style: GoogleFonts.lato(color: color, fontSize: 14),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Entry block ──────────────────────────────────────────────────────────

class _EntryBlock extends StatelessWidget {
  final String name;
  final String? entry;
  final bool isMe;
  final Color color;

  const _EntryBlock({
    required this.name,
    required this.entry,
    required this.isMe,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMe
            ? color.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe
              ? color.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: GoogleFonts.lato(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isMe ? color : AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            entry ??
                (isMe
                    ? "You haven't written yet."
                    : 'Waiting for their entry...'),
            style: GoogleFonts.lato(
              fontSize: 14,
              color: entry != null ? const Color(0xFFF5DEB3) : AppColors.textMuted,
              height: 1.6,
              fontStyle: entry == null ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }
}
