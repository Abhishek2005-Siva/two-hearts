import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/content_block.dart';
import '../../core/delight/delight.dart';
import '../../core/presence/activity_announcer.dart';
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
  Color(0xFF9E4545), // crimson
  Color(0xFF3B5998), // denim blue
];

Color _bookColor(String id) =>
    _kBookColors[id.hashCode.abs() % _kBookColors.length];

// Width varies 34–58px for more visual variety
double _bookWidth(String id) => (id.hashCode.abs() % 25) + 34.0;

// Height varies 85–138px — books stand at different heights
double _bookHeight(String id) => (id.hashCode.abs() % 54) + 85.0;

enum _BookDesign { plain, striped, gilded, embossed }

_BookDesign _bookDesign(String id) =>
    _BookDesign.values[(id.hashCode.abs() ~/ 3) % _BookDesign.values.length];

const _kGold = Color(0xFFF5DEB3);

// ─── A generic thing that can sit on the shelf as a "book" ────────────────
// Journal entries and letters both render through the same spine widget —
// this is the shape that lets either one do that.

class _ShelfBook {
  final String id;
  final String title;
  final int year;
  final String dateStr;
  final IconData? categoryIcon;
  final VoidCallback onTap;

  const _ShelfBook({
    required this.id,
    required this.title,
    required this.year,
    required this.dateStr,
    this.categoryIcon,
    required this.onTap,
  });
}

int _yearOf(String id) {
  final match = RegExp(r'^(\d{4})-\d{2}-\d{2}').firstMatch(id);
  if (match != null) return int.parse(match.group(1)!);
  final fallback = int.tryParse(id.length >= 4 ? id.substring(0, 4) : '');
  return fallback ?? 0;
}

String _formatId(String id) {
  final dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}');
  if (dateRegex.hasMatch(id)) return id.substring(0, 10);
  if (id.length >= 4) return id.substring(0, 4);
  return id;
}

/// Does a journal entry contain at least one real photo/video attachment?
bool _hasMedia(JournalDay day) {
  final raw = day.sharedEntry ?? day.entryA;
  if (raw == null || !raw.trimLeft().startsWith('[')) return false;
  try {
    final list = jsonDecode(raw) as List;
    return list.any((m) {
      final type = (m as Map<String, dynamic>)['type'] as String?;
      return type == 'image' || type == 'video';
    });
  } catch (_) {
    return false;
  }
}

bool _matchesKeywords(String title, List<String> keywords) {
  final lower = title.toLowerCase();
  return keywords.any(lower.contains);
}

// ─── Main Screen ──────────────────────────────────────────────────────────

enum _JournalFilter { all, letters, photos, trips, dates, random }

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen>
    with SingleTickerProviderStateMixin, ActivityAnnouncer {
  bool _newestFirst = true;
  _JournalFilter _filter = _JournalFilter.all;
  bool _searching = false;
  final _searchCtrl = TextEditingController();
  String _query = '';
  int _randomSeed = 0;
  late final AnimationController _twinkle;

  @override
  void initState() {
    super.initState();
    _twinkle = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    announceActivity('In the Journal');
  }

  @override
  void dispose() {
    _twinkle.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openTodayEntry(BuildContext context) {
    final now = DateTime.now();
    final id =
        '${now.toIso8601String().substring(0, 10)}-${now.millisecondsSinceEpoch}';
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _BookView(
        day: JournalDay(id: id, title: '', sharedEntry: ''),
        isNew: true,
      ),
    ));
  }

  void _openLetter(BuildContext context, LetterModel letter, Color accent) {
    if (!letter.opened) {
      final coupleId = ref.read(coupleIdProvider);
      if (coupleId != null) {
        ref.read(firestoreServiceProvider).openLetter(coupleId, letter.id).ignore();
      }
    }
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: const Color(0xFFFBF3E3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('💌', style: TextStyle(fontSize: 28)),
              const SizedBox(height: 10),
              Text(letter.title,
                  style: GoogleFonts.playfairDisplay(
                      color: const Color(0xFF2A1A0A),
                      fontSize: 19,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              _LetterBodyPreview(body: letter.body),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text('Close',
                      style: TextStyle(color: accent, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_ShelfBook> _buildShelfBooks(
    BuildContext context,
    List<JournalDay> journal,
    List<LetterModel> letters,
    Color accent,
  ) {
    List<_ShelfBook> books;
    switch (_filter) {
      case _JournalFilter.letters:
        books = letters
            .map((l) => _ShelfBook(
                  id: l.id,
                  title: l.title.isEmpty ? 'Untitled' : l.title,
                  year: l.createdAt.year,
                  dateStr: '${l.createdAt.year}-'
                      '${l.createdAt.month.toString().padLeft(2, '0')}-'
                      '${l.createdAt.day.toString().padLeft(2, '0')}',
                  categoryIcon: Icons.mail_rounded,
                  onTap: () => _openLetter(context, l, accent),
                ))
            .toList();
      case _JournalFilter.photos:
        books = journal.where(_hasMedia).map((d) => _dayToBook(context, d)).toList();
      case _JournalFilter.trips:
        books = journal
            .where((d) => _matchesKeywords(
                d.title ?? '', const ['trip', 'travel', 'vacation', 'holiday']))
            .map((d) => _dayToBook(context, d))
            .toList();
      case _JournalFilter.dates:
        books = journal
            .where((d) => _matchesKeywords(
                d.title ?? '', const ['date night', 'date', 'dinner', 'movie night']))
            .map((d) => _dayToBook(context, d))
            .toList();
      case _JournalFilter.all:
      case _JournalFilter.random:
        books = journal.map((d) => _dayToBook(context, d)).toList();
    }

    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      books = books.where((b) => b.title.toLowerCase().contains(q)).toList();
    }

    if (_filter == _JournalFilter.random) {
      books = List.of(books)..shuffle(math.Random(_randomSeed));
    } else {
      if (!_newestFirst) books = books.reversed.toList();
    }
    return books;
  }

  _ShelfBook _dayToBook(BuildContext context, JournalDay day) {
    return _ShelfBook(
      id: day.id,
      title: day.title?.isNotEmpty == true ? day.title! : 'Untitled',
      year: _yearOf(day.id),
      dateStr: _formatId(day.id),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _BookView(day: day, isNew: false),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(accentColorProvider);
    final journalAsync = ref.watch(journalProvider);
    final journal = journalAsync.valueOrNull ?? [];
    final letters = ref.watch(lettersProvider).valueOrNull ?? [];
    final memories = ref.watch(memoriesProvider).valueOrNull ?? [];
    final couple = ref.watch(coupleProvider).valueOrNull;

    final photosCount = memories.where((m) => !m.isVideo).length;
    final years = _yearsTogether(couple);
    final books = _buildShelfBooks(context, journal, letters, accent);

    return Scaffold(
      backgroundColor: const Color(0xFF2A1F14),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/journal_bookshelf_bg.png', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.4)),
          ),
          SafeArea(
            child: Column(
              children: [
                _JournalHeader(
                  searching: _searching,
                  searchCtrl: _searchCtrl,
                  onSearchToggle: () => setState(() {
                    _searching = !_searching;
                    if (!_searching) {
                      _query = '';
                      _searchCtrl.clear();
                    }
                  }),
                  onQueryChanged: (v) => setState(() => _query = v),
                  onOrderToggle: () => setState(() => _newestFirst = !_newestFirst),
                  newestFirst: _newestFirst,
                  twinkle: _twinkle,
                ),
                if (!_searching) ...[
                  _StatsPlaque(
                    memories: journal.length,
                    letters: letters.length,
                    photos: photosCount,
                    years: years,
                  ),
                  const SizedBox(height: 10),
                  _FilterChipsRow(
                    value: _filter,
                    onChanged: (f) => setState(() {
                      _filter = f;
                      if (f == _JournalFilter.random) {
                        _randomSeed = math.Random().nextInt(1 << 31);
                      }
                    }),
                  ),
                ],
                Expanded(
                  child: journalAsync.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Stack(
                          children: [
                            _BookshelfBody(books: books),
                            if (!_searching)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: _WritingStation(
                                  onTap: () => _openTodayEntry(context),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _yearsTogether(dynamic couple) {
    if (couple == null) return 0;
    final DateTime since = couple.anniversary ?? couple.createdAt;
    final days = DateTime.now().difference(since).inDays;
    return (days / 365).floor();
  }
}

// ─── Header — back, sparkly title, search ────────────────────────────────

class _JournalHeader extends StatelessWidget {
  final bool searching;
  final TextEditingController searchCtrl;
  final VoidCallback onSearchToggle;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onOrderToggle;
  final bool newestFirst;
  final AnimationController twinkle;

  const _JournalHeader({
    required this.searching,
    required this.searchCtrl,
    required this.onSearchToggle,
    required this.onQueryChanged,
    required this.onOrderToggle,
    required this.newestFirst,
    required this.twinkle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _kGold),
            onPressed: () => context.go('/together'),
          ),
          Expanded(
            child: searching
                ? TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    style: const TextStyle(color: _kGold),
                    onChanged: onQueryChanged,
                    decoration: const InputDecoration(
                      hintText: 'Search entries…',
                      hintStyle: TextStyle(color: Color(0x99F5DEB3)),
                      border: InputBorder.none,
                    ),
                  )
                : Center(
                    child: AnimatedBuilder(
                      animation: twinkle,
                      builder: (_, _) {
                        final t = twinkle.value;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Opacity(
                              opacity: 0.4 + 0.6 * t,
                              child: const Text('✦',
                                  style: TextStyle(fontSize: 12, color: _kGold)),
                            ),
                            const SizedBox(width: 8),
                            Text('Our Journal',
                                style: GoogleFonts.playfairDisplay(
                                  color: _kGold,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  shadows: const [
                                    Shadow(color: Colors.black54, blurRadius: 6)
                                  ],
                                )),
                            const SizedBox(width: 8),
                            Opacity(
                              opacity: 0.4 + 0.6 * (1 - t),
                              child: const Text('✧',
                                  style: TextStyle(fontSize: 12, color: _kGold)),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
          ),
          if (searching)
            IconButton(
              icon: const Icon(Icons.close_rounded, color: _kGold),
              onPressed: onSearchToggle,
            )
          else ...[
            IconButton(
              tooltip: newestFirst ? 'Newest first' : 'Oldest first',
              icon: Icon(
                  newestFirst ? Icons.south_rounded : Icons.north_rounded,
                  color: _kGold, size: 20),
              onPressed: onOrderToggle,
            ),
            IconButton(
              icon: const Icon(Icons.search_rounded, color: _kGold),
              onPressed: onSearchToggle,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Stats plaque — wooden plank showing real relationship stats ─────────

class _StatsPlaque extends StatelessWidget {
  final int memories;
  final int letters;
  final int photos;
  final int years;

  const _StatsPlaque({
    required this.memories,
    required this.letters,
    required this.photos,
    required this.years,
  });

  @override
  Widget build(BuildContext context) {
    Widget stat(IconData icon, int value, String label) {
      return Expanded(
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF6B4226), size: 16),
            const SizedBox(height: 4),
            Text('$value',
                style: GoogleFonts.playfairDisplay(
                    color: const Color(0xFF2A1A0A),
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
            Text(label,
                style: GoogleFonts.lato(
                    color: const Color(0xFF5C3D1E), fontSize: 10)),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8D4B8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF8B6340).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          stat(Icons.menu_book_rounded, memories, 'Memories'),
          stat(Icons.mail_rounded, letters, 'Letters'),
          stat(Icons.photo_camera_rounded, photos, 'Photos'),
          stat(Icons.favorite_rounded, years, years == 1 ? 'Year' : 'Years'),
        ],
      ),
    );
  }
}

// ─── Filter chips ─────────────────────────────────────────────────────────

class _FilterChipsRow extends StatelessWidget {
  final _JournalFilter value;
  final ValueChanged<_JournalFilter> onChanged;
  const _FilterChipsRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget chip(_JournalFilter f, String label) {
      final selected = value == f;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: SquishyTap(
          onTap: () => onChanged(f),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? _kGold : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: selected ? _kGold : _kGold.withValues(alpha: 0.4)),
            ),
            child: Text(label,
                style: GoogleFonts.lato(
                    color: selected ? const Color(0xFF2A1A0A) : _kGold,
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.normal)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            chip(_JournalFilter.all, 'All'),
            chip(_JournalFilter.letters, 'Letters'),
            chip(_JournalFilter.photos, 'Photos'),
            chip(_JournalFilter.trips, 'Trips'),
            chip(_JournalFilter.dates, 'Dates'),
            chip(_JournalFilter.random, 'Random'),
          ],
        ),
      ),
    );
  }
}

// ─── Bookshelf body ───────────────────────────────────────────────────────
//
// Grows naturally instead of being pinned to fixed shelf slots: books are
// grouped by year, and within each year, chunked into shelf-rows of a
// fixed capacity (computed from how many book-widths actually fit the
// screen) — once a shelf fills up, the rest continue onto the next one.

const _kBookContainerHeight = 150.0;
const _kShelfSidePad = 16.0;

List<List<T>> _chunk<T>(List<T> items, int size) {
  final out = <List<T>>[];
  for (var i = 0; i < items.length; i += size) {
    out.add(items.sublist(i, (i + size).clamp(0, items.length)));
  }
  return out;
}

class _BookshelfBody extends StatelessWidget {
  final List<_ShelfBook> books;

  const _BookshelfBody({required this.books});

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return Center(
        child: Text(
          'No entries here yet ✍️',
          style: GoogleFonts.lato(
            color: _kGold.withValues(alpha: 0.5),
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    final byYear = <int, List<_ShelfBook>>{};
    for (final b in books) {
      byYear.putIfAbsent(b.year, () => []).add(b);
    }

    return LayoutBuilder(builder: (context, constraints) {
      final shelfW = constraints.maxWidth - _kShelfSidePad * 2;
      final maxPerShelf = (shelfW / 46).floor().clamp(4, 14);

      return ListView(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 210),
        children: [
          for (final year in byYear.keys) ...[
            _YearLabel(year: year),
            for (final chunk in _chunk(byYear[year]!, maxPerShelf))
              _ShelfRow(books: chunk),
          ],
          // Memory of the Day sits on its own little shelf at the end.
          const _MemoryOfTheDayCard(),
          const SizedBox(height: 12),
        ],
      );
    });
  }
}

// ─── Year label ───────────────────────────────────────────────────────────

class _YearLabel extends StatelessWidget {
  final int year;
  const _YearLabel({required this.year});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_kShelfSidePad, 18, _kShelfSidePad, 10),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: _kGold.withValues(alpha: 0.25))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              year == 0 ? 'Undated' : '$year',
              style: GoogleFonts.playfairDisplay(
                color: _kGold,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          Expanded(child: Container(height: 1, color: _kGold.withValues(alpha: 0.25))),
        ],
      ),
    );
  }
}

// ─── A single shelf: a row of books resting on a wooden plank ────────────

class _ShelfRow extends StatelessWidget {
  final List<_ShelfBook> books;
  const _ShelfRow({required this.books});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kShelfSidePad, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _kBookContainerHeight,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _buildBookItems(),
              ),
            ),
          ),
          const _WoodPlank(),
        ],
      ),
    );
  }

  List<Widget> _buildBookItems() {
    final items = <Widget>[];
    for (int i = 0; i < books.length; i++) {
      if (i > 0 && i % 6 == 0) {
        items.add(_DecoItem(kind: i ~/ 6));
      }
      items.add(_BookSpine(book: books[i]));
    }
    return items;
  }
}

// ─── Wooden shelf plank ───────────────────────────────────────────────────

class _WoodPlank extends StatelessWidget {
  const _WoodPlank();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 14,
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF6B4226),
            Color(0xFF4A2E18),
            Color(0xFF2E1B0E),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          color: const Color(0xFF8B6340).withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

// ─── Book spine widget ────────────────────────────────────────────────────

class _BookSpine extends StatefulWidget {
  final _ShelfBook book;

  const _BookSpine({required this.book});

  @override
  State<_BookSpine> createState() => _BookSpineState();
}

class _BookSpineState extends State<_BookSpine> {
  bool _lifted = false;

  @override
  Widget build(BuildContext context) {
    final day = widget.book;
    final color = _bookColor(day.id);
    final width = _bookWidth(day.id);
    final height = _bookHeight(day.id);
    final design = _bookDesign(day.id);

    return GestureDetector(
      onTapDown: (_) => setState(() => _lifted = true),
      onTapCancel: () => setState(() => _lifted = false),
      onTapUp: (_) => setState(() => _lifted = false),
      onTap: widget.book.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _lifted ? -10 : 0, 0),
        width: width,
        height: height,
        margin: const EdgeInsets.only(right: 3),
        decoration: BoxDecoration(
          gradient: _spineGradient(design, color),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(3),
            topRight: Radius.circular(3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _lifted ? 0.7 : 0.55),
              blurRadius: _lifted ? 12 : 5,
              offset: Offset(2, _lifted ? 8 : 3),
            ),
            if (_lifted)
              BoxShadow(color: _kGold.withValues(alpha: 0.35), blurRadius: 14),
          ],
        ),
        child: Stack(
          children: [
            if (design == _BookDesign.gilded)
              Positioned(
                left: 0, top: 0, bottom: 0,
                child: Container(
                  width: 4,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            if (design == _BookDesign.striped)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(3), topRight: Radius.circular(3)),
                  child: _StripeOverlay(color: color),
                ),
              ),
            if (design == _BookDesign.embossed)
              Positioned(
                top: 8, left: 0, right: 0,
                child: Center(
                  child: Container(
                    width: width * 0.55,
                    height: width * 0.55,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25), width: 1.5),
                    ),
                  ),
                ),
              ),
            // Category icon near the top
            if (day.categoryIcon != null)
              Positioned(
                top: 6,
                left: 0,
                right: 0,
                child: Icon(day.categoryIcon,
                    color: Colors.white.withValues(alpha: 0.7), size: 12),
              ),
            // Bookmark ribbon protruding from the bottom
            Positioned(
              bottom: -8,
              left: width / 2 - 5,
              child: Container(
                width: 10,
                height: 16,
                decoration: BoxDecoration(
                  color: _kGold.withValues(alpha: 0.85),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(2)),
                ),
              ),
            ),
            // Title + date text
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Text(
                        day.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.lato(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      day.dateStr,
                      style: GoogleFonts.lato(
                        fontSize: 7,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Gradient _spineGradient(_BookDesign design, Color color) {
    switch (design) {
      case _BookDesign.striped:
        return LinearGradient(
          colors: [color, color.withValues(alpha: 0.75)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
      case _BookDesign.gilded:
        return LinearGradient(
          colors: [color.withValues(alpha: 0.9), color, color.withValues(alpha: 0.8)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
      case _BookDesign.embossed:
        return RadialGradient(
          center: const Alignment(-0.3, -0.5),
          radius: 1.4,
          colors: [color.withValues(alpha: 0.95), color.withValues(alpha: 0.65)],
        );
      case _BookDesign.plain:
        return LinearGradient(
          colors: [
            color.withValues(alpha: 0.9),
            color,
            color.withValues(alpha: 0.7),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
    }
  }
}

// ─── Stripe overlay for striped book design ───────────────────────────────

class _StripeOverlay extends StatelessWidget {
  final Color color;
  const _StripeOverlay({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _StripePainter(color: color));
  }
}

class _StripePainter extends CustomPainter {
  final Color color;
  const _StripePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final light = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 4;
    const gap = 8.0;
    for (double y = 0; y < size.height + size.width; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y - size.width), light);
    }
  }

  @override
  bool shouldRepaint(_StripePainter old) => old.color != color;
}

// ─── Decorative keepsakes — cycles through a handful of little objects ───

class _DecoItem extends StatelessWidget {
  final int kind;
  const _DecoItem({this.kind = 0});

  @override
  Widget build(BuildContext context) {
    switch (kind % 4) {
      case 0:
        return _candle();
      case 1:
        return _plant();
      case 2:
        return _polaroid();
      default:
        return _stackedBooks();
    }
  }

  Widget _candle() {
    return SizedBox(
      width: 28,
      height: 120,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            width: 8, height: 12,
            decoration: BoxDecoration(
              gradient: const RadialGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Container(
            width: 10, height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F0E0),
              borderRadius: BorderRadius.circular(2),
              boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 2)],
            ),
          ),
          Container(
            width: 18, height: 8,
            decoration: BoxDecoration(color: const Color(0xFF8B6340), borderRadius: BorderRadius.circular(3)),
          ),
        ],
      ),
    );
  }

  Widget _plant() {
    return SizedBox(
      width: 32,
      height: 70,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Text('🪴', style: TextStyle(fontSize: 30)),
        ],
      ),
    );
  }

  Widget _polaroid() {
    return SizedBox(
      width: 40,
      height: 90,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Transform.rotate(
          angle: -0.12,
          child: Container(
            width: 34,
            height: 42,
            padding: const EdgeInsets.fromLTRB(3, 3, 3, 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDF8),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(1, 3))],
            ),
            child: Container(color: const Color(0xFFDDCAB4)),
          ),
        ),
      ),
    );
  }

  Widget _stackedBooks() {
    return SizedBox(
      width: 34,
      height: 40,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 30, height: 8, color: const Color(0xFF7B4E9E)),
            Container(width: 26, height: 8, color: const Color(0xFF4A7C59)),
            Container(width: 32, height: 8, color: const Color(0xFFB5681F)),
          ],
        ),
      ),
    );
  }
}

// ─── Memory of the Day ────────────────────────────────────────────────────

class _MemoryOfTheDayCard extends ConsumerWidget {
  const _MemoryOfTheDayCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memories = ref.watch(memoriesProvider).valueOrNull ?? [];
    final withCaption = memories.where((m) => m.caption?.isNotEmpty == true).toList();
    if (withCaption.isEmpty) return const SizedBox.shrink();

    // Stable "pick of the day" — same one all day, changes tomorrow.
    final dayKey = DateTime.now().toIso8601String().substring(0, 10);
    final pick = withCaption[dayKey.hashCode.abs() % withCaption.length];

    return Padding(
      padding: const EdgeInsets.fromLTRB(_kShelfSidePad, 8, _kShelfSidePad, 0),
      child: GestureDetector(
        onTap: () => context.push('/memory/${pick.id}'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF3A2A18),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kGold.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 5))],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded, color: _kGold, size: 14),
                        const SizedBox(width: 6),
                        Text('Memory of the Day',
                            style: GoogleFonts.playfairDisplay(
                                color: _kGold, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('"${pick.caption}"',
                        style: GoogleFonts.lato(
                            color: _kGold.withValues(alpha: 0.85),
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            height: 1.4)),
                    const SizedBox(height: 6),
                    Text('Tap to revisit',
                        style: GoogleFonts.lato(color: _kGold.withValues(alpha: 0.5), fontSize: 10.5)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Transform.rotate(
                angle: 0.06,
                child: Container(
                  width: 60,
                  height: 74,
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFDF8),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(1, 4))],
                  ),
                  child: ClipRRect(
                    child: Image.network(pick.imageUrl, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(color: const Color(0xFFDDCAB4))),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Writing station — bottom desk bar with the primary action ──────────

class _WritingStation extends StatelessWidget {
  final VoidCallback onTap;
  const _WritingStation({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF2A1F14).withValues(alpha: 0),
            const Color(0xFF1D1610),
            const Color(0xFF120D08),
          ],
          stops: const [0, 0.4, 1],
        ),
      ),
      child: Row(
        children: [
          const Text('🖋️', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 10),
          const Text('✿', style: TextStyle(fontSize: 18, color: Color(0xFFD8C4A0))),
          const SizedBox(width: 14),
          Expanded(
            child: SquishyTap(
              onTap: onTap,
              cuteStickers: const ['✍️', '📖'],
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6B4226), Color(0xFF4A2E18)]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _kGold.withValues(alpha: 0.4)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('✍️', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text('Write Today\'s Journal',
                        style: GoogleFonts.playfairDisplay(
                            color: _kGold, fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Letter body preview (plain-text summary for the dialog) ────────────

class _LetterBodyPreview extends StatelessWidget {
  final String body;
  const _LetterBodyPreview({required this.body});

  List<ContentBlock> _parseBlocks(String raw) {
    if (raw.trimLeft().startsWith('[')) {
      try {
        final list = jsonDecode(raw) as List;
        return list.map((m) => ContentBlock.fromMap(m as Map<String, dynamic>)).toList();
      } catch (_) {}
    }
    return [ContentBlock(id: '0', type: BlockType.text, text: raw, textSize: TextSize.body)];
  }

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(body);
    if (blocks.length == 1 && blocks.first.type == BlockType.text) {
      return Text(
        blocks.first.text ?? '',
        style: const TextStyle(fontSize: 15, height: 1.7, color: Color(0xFF2A1A0A)),
      );
    }
    return DefaultTextStyle.merge(
      style: const TextStyle(color: Color(0xFF2A1A0A)),
      child: RichContentViewer(blocks: blocks),
    );
  }
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
  bool _notifiedCreation = false;
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
      if (widget.isNew && !_notifiedCreation) {
        // Only the very first save of a brand-new entry notifies — later
        // edits (including every silent 3s autosave) stay quiet.
        _notifiedCreation = true;
        ref.read(firestoreServiceProvider).recordNotification(
              coupleId,
              type: 'journal',
              title: '📖 New journal entry',
              body: _titleCtrl.text.trim().isEmpty
                  ? 'Today\'s page is written'
                  : _titleCtrl.text.trim(),
              route: '/together/journal',
            );
      }
      if (mounted && !silent) {
        setState(() {
          _editing = false;
          _saving = false;
        });
        // Today's page is written ✍️
        DelightHaptics.soft();
        FloatingStickers.burst(context,
            stickers: const ['✨', '📖'], count: 5);
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
                  filled: false,
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
          textColor: const Color(0xFF2A1A0A),
          hintColor: const Color(0xFF2A1A0A).withValues(alpha: 0.35),
          toolbarIconColor: const Color(0xFF5C3D1E),
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
