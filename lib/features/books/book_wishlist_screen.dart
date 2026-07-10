import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:confetti/confetti.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'pdf_viewer_screen.dart';
import '../../core/firebase/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/cloudinary_service.dart';

// ── Palette (warm library / parchment) ────────────────────────────────────

const _kParchment = Color(0xFFF2E6C9);
const _kParchmentEdge = Color(0xFFE3D2A6);
const _kInk = Color(0xFF2A1A0A);
const _kInkMuted = Color(0xFF7A6650);
const _kGreen = Color(0xFF3F7D53);
const _kGreenDark = Color(0xFF2C5C3D);
const _kRibbon = Color(0xFFB33A3A);

// ── Deterministic spine color ─────────────────────────────────────────────

const _kSpineColors = [
  Color(0xFF8B2323),
  Color(0xFF2F5F3F),
  Color(0xFF9E7B1A),
  Color(0xFF1A2F5C),
  Color(0xFF7A4A2A),
  Color(0xFF6B1A2F),
  Color(0xFF3D4A5C),
  Color(0xFF2C4A3E),
];

Color _spineColor(String id) {
  int h = id.codeUnits.fold(0, (int a, int c) => (a * 31 + c) & 0x7FFFFFFF);
  return _kSpineColors[h % _kSpineColors.length];
}

// ── Main screen ───────────────────────────────────────────────────────────

class BookWishlistScreen extends ConsumerStatefulWidget {
  const BookWishlistScreen({super.key});

  @override
  ConsumerState<BookWishlistScreen> createState() => _BookWishlistScreenState();
}

class _BookWishlistScreenState extends ConsumerState<BookWishlistScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late ConfettiController _confetti;
  final _searchCtrl = TextEditingController();
  bool _searching = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (mounted) setState(() {});
      });
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _confetti.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _triggerConfetti() {
    _confetti.play();
    HapticFeedback.heavyImpact();
  }

  Future<void> _showAddSheet() async {
    final container = ProviderScope.containerOf(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => UncontrolledProviderScope(
        container: container,
        child: _AddBookSheet(
          onAdd: (book) async {
            final coupleId = ref.read(coupleIdProvider);
            if (coupleId == null) return;
            await ref.read(firestoreServiceProvider).addBook(coupleId, book);
          },
        ),
      ),
    );
  }

  List<BookWish> _filtered(List<BookWish> books) {
    if (_query.isEmpty) return books;
    return books
        .where((b) =>
            b.title.toLowerCase().contains(_query) ||
            (b.author?.toLowerCase().contains(_query) ?? false))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(booksProvider);
    final allBooks = booksAsync.valueOrNull ?? [];
    final readCount = allBooks.where((b) => b.read).length;
    final wishlistCount = allBooks.where((b) => !b.read).length;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/book_wishlist_bg.png', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.4)),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CircleIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.maybePop(context),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: _searching
                              ? _SearchField(
                                  controller: _searchCtrl,
                                  onClose: () => setState(() {
                                    _searching = false;
                                    _searchCtrl.clear();
                                  }),
                                )
                              : Column(
                                  children: [
                                    RichText(
                                      textAlign: TextAlign.center,
                                      text: TextSpan(
                                        style: GoogleFonts.playfairDisplay(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                        children: const [
                                          TextSpan(text: 'My Book '),
                                          TextSpan(
                                              text: 'Wishlist',
                                              style: TextStyle(color: AppColors.coral)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text('The books you want to read',
                                        style: GoogleFonts.lato(
                                            fontSize: 12.5,
                                            color: Colors.white70,
                                            fontStyle: FontStyle.italic)),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(width: 28, height: 1, color: Colors.white24),
                                        const SizedBox(width: 8),
                                        const Text('✦',
                                            style: TextStyle(color: AppColors.gold, fontSize: 13)),
                                        const SizedBox(width: 8),
                                        Container(width: 28, height: 1, color: Colors.white24),
                                      ],
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      if (!_searching)
                        _CircleIconButton(
                          icon: Icons.search_rounded,
                          onTap: () => setState(() => _searching = true),
                        )
                      else
                        const SizedBox(width: 40),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Stat cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          emoji: '📖',
                          value: '$readCount',
                          label: 'Read Together',
                          sub: 'Shared reads',
                          color: _kGreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          emoji: '📚',
                          value: '$wishlistCount',
                          label: 'On Wishlist',
                          sub: 'Books saved',
                          color: AppColors.coral,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn().slideY(begin: -0.15),

                const SizedBox(height: 16),

                // Wood-plank tab selector
                Container(
                  height: 54,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5C3D26), Color(0xFF2E1C10)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.4)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _WoodTab(
                          label: 'Wishlist',
                          icon: Icons.menu_book_rounded,
                          selected: _tabCtrl.index == 0,
                          onTap: () => _tabCtrl.animateTo(0),
                        ),
                      ),
                      Expanded(
                        child: _WoodTab(
                          label: 'Read Together',
                          icon: Icons.people_alt_rounded,
                          selected: _tabCtrl.index == 1,
                          onTap: () => _tabCtrl.animateTo(1),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Open-book content area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _kParchment,
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    blurRadius: 20,
                                    offset: const Offset(0, -4)),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(width: 12, color: _kParchmentEdge),
                                Expanded(
                                  child: booksAsync.when(
                                    loading: () => const Center(
                                        child: CircularProgressIndicator(color: _kGreen)),
                                    error: (e, _) => Center(
                                        child: Text('$e',
                                            style: const TextStyle(color: _kInkMuted))),
                                    data: (books) {
                                      final filtered = _filtered(books);
                                      return TabBarView(
                                        controller: _tabCtrl,
                                        children: [
                                          _BookList(
                                            books: filtered.where((b) => !b.read).toList(),
                                            emptyMessage: _query.isNotEmpty
                                                ? 'No books match "$_query"'
                                                : 'No books yet!\nAdd your first read ♡',
                                            emptyIcon: '📖',
                                            onToggleRead: (book) async {
                                              final coupleId = ref.read(coupleIdProvider);
                                              if (coupleId == null) return;
                                              await ref
                                                  .read(firestoreServiceProvider)
                                                  .toggleRead(coupleId, book.id, true);
                                              _triggerConfetti();
                                            },
                                            onDelete: (book) async {
                                              final coupleId = ref.read(coupleIdProvider);
                                              if (coupleId == null) return;
                                              await ref
                                                  .read(firestoreServiceProvider)
                                                  .deleteBook(coupleId, book.id);
                                            },
                                            onUndo: (book) async {
                                              final coupleId = ref.read(coupleIdProvider);
                                              if (coupleId == null) return;
                                              await ref
                                                  .read(firestoreServiceProvider)
                                                  .addBook(coupleId, book);
                                            },
                                            ref: ref,
                                          ),
                                          _BookList(
                                            books: filtered.where((b) => b.read).toList(),
                                            emptyMessage: _query.isNotEmpty
                                                ? 'No books match "$_query"'
                                                : 'Nothing read yet.\nFinish a book to see it here ♡',
                                            emptyIcon: '✓',
                                            onToggleRead: (book) async {
                                              final coupleId = ref.read(coupleIdProvider);
                                              if (coupleId == null) return;
                                              await ref
                                                  .read(firestoreServiceProvider)
                                                  .toggleRead(coupleId, book.id, false);
                                            },
                                            onDelete: (book) async {
                                              final coupleId = ref.read(coupleIdProvider);
                                              if (coupleId == null) return;
                                              await ref
                                                  .read(firestoreServiceProvider)
                                                  .deleteBook(coupleId, book.id);
                                            },
                                            onUndo: (book) async {
                                              final coupleId = ref.read(coupleIdProvider);
                                              if (coupleId == null) return;
                                              await ref
                                                  .read(firestoreServiceProvider)
                                                  .addBook(coupleId, book);
                                            },
                                            ref: ref,
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Bookmark ribbon peeking below the page edge
                        Positioned(
                          bottom: -16,
                          left: 44,
                          child: Container(
                            width: 14,
                            height: 34,
                            decoration: const BoxDecoration(
                              color: _kRibbon,
                              borderRadius: BorderRadius.vertical(bottom: Radius.circular(3)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 30,
              colors: const [
                AppColors.rose,
                AppColors.coral,
                AppColors.gold,
                AppColors.lavender,
                _kGreen,
              ],
              gravity: 0.3,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSheet,
        backgroundColor: _kGreen,
        elevation: 6,
        child: const Text('🪶', style: TextStyle(fontSize: 22)),
      ),
    );
  }
}

// ── Header helper widgets ───────────────────────────────────────────────────

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SquishyTap(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.4),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Icon(icon, color: Colors.white, size: 19),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onClose;
  const _SearchField({required this.controller, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search title or author…',
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          GestureDetector(
            onTap: onClose,
            child: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
          ),
        ],
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final String sub;
  final Color color;

  const _StatCard({
    required this.emoji,
    required this.value,
    required this.label,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(sub,
                    style: const TextStyle(color: Colors.white60, fontSize: 10.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Wood tab ──────────────────────────────────────────────────────────────

class _WoodTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _WoodTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SquishyTap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: [_kGreen, _kGreenDark])
              : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : Colors.white54),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white54,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Book list ─────────────────────────────────────────────────────────────

class _BookList extends StatelessWidget {
  final List<BookWish> books;
  final String emptyMessage;
  final String emptyIcon;
  final Future<void> Function(BookWish) onToggleRead;
  final Future<void> Function(BookWish) onDelete;
  final Future<void> Function(BookWish) onUndo;
  final WidgetRef ref;

  const _BookList({
    required this.books,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.onToggleRead,
    required this.onDelete,
    required this.onUndo,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emptyIcon, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 14),
            Text(
              emptyMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kInkMuted, fontSize: 14, height: 1.6),
            ),
          ],
        ),
      ).animate().fadeIn();
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
      itemCount: books.length,
      separatorBuilder: (_, _) => Divider(
          height: 1, thickness: 0.6, color: _kInk.withValues(alpha: 0.12)),
      itemBuilder: (ctx, i) {
        final book = books[i];
        return _BookCard(
          key: ValueKey(book.id),
          book: book,
          ref: ref,
          onToggleRead: () => onToggleRead(book),
          onDelete: () async {
            await onDelete(book);
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text('"${book.title}" removed'),
                  backgroundColor: AppColors.bgCard,
                  action: SnackBarAction(
                    label: 'Undo',
                    textColor: AppColors.rose,
                    onPressed: () => onUndo(book),
                  ),
                ),
              );
            }
          },
        ).animate().fadeIn(delay: (i * 60).ms).slideX(begin: 0.05);
      },
    );
  }
}

// ── Book card ─────────────────────────────────────────────────────────────

class _BookCard extends StatelessWidget {
  final BookWish book;
  final WidgetRef ref;
  final VoidCallback onToggleRead;
  final VoidCallback onDelete;

  const _BookCard({
    super.key,
    required this.book,
    required this.ref,
    required this.onToggleRead,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).valueOrNull;
    final partner = ref.watch(partnerUserProvider).valueOrNull;
    final addedByName = book.addedBy == me?.uid
        ? (me?.displayName.split(' ').first ?? 'You')
        : (partner?.displayName.split(' ').first ?? 'Partner');

    return Dismissible(
      key: ValueKey('dismissible_${book.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 12),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: _kRibbon.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: _kRibbon, size: 24),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.bgCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Remove book?', style: TextStyle(color: AppColors.textPrimary)),
            content: Text('"${book.title}"',
                style: const TextStyle(color: AppColors.textSecondary)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Remove', style: TextStyle(color: AppColors.rose)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BookCover(book: book),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              book.title,
                              style: GoogleFonts.playfairDisplay(
                                color: _kInk,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          Icon(
                            book.read
                                ? Icons.check_circle_rounded
                                : Icons.favorite_border_rounded,
                            color: _kGreen.withValues(alpha: 0.8),
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      if (book.author != null)
                        Text('by ${book.author}',
                            style: GoogleFonts.lato(
                                color: _kGreen, fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 12, color: _kInkMuted),
                          const SizedBox(width: 5),
                          Text(DateFormat('MMM d').format(book.addedAt),
                              style: const TextStyle(color: _kInkMuted, fontSize: 11.5)),
                          const SizedBox(width: 10),
                          Text('added by $addedByName',
                              style: const TextStyle(color: _kInkMuted, fontSize: 11.5)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (book.note != null) ...[
              const SizedBox(height: 10),
              Text(book.note!,
                  style: const TextStyle(color: _kInk, fontSize: 13, height: 1.5)),
            ],
            if (book.pdfUrl != null) ...[
              const SizedBox(height: 10),
              Builder(builder: (context) {
                final myUid = FirebaseAuth.instance.currentUser?.uid;
                final mine = book.progressOf(myUid);
                final partnerEntry =
                    book.progress.entries.where((e) => e.key != myUid).toList();
                final theirs = partnerEntry.isNotEmpty ? partnerEntry.first.value : null;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (mine != null || theirs != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.menu_book_rounded, size: 13, color: _kInkMuted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              [
                                if (mine != null)
                                  'You: page ${mine.page + 1}'
                                      '${mine.totalPages > 0 ? '/${mine.totalPages}' : ''}',
                                if (theirs != null)
                                  '${partner?.displayName.split(' ').first ?? 'Partner'}: '
                                      'page ${theirs.page + 1}'
                                      '${theirs.totalPages > 0 ? '/${theirs.totalPages}' : ''}',
                              ].join('  ·  '),
                              style: const TextStyle(color: _kInkMuted, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (_) => PdfViewerScreen(
                            url: book.pdfUrl!,
                            title: book.title,
                            bookId: book.id,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 17, color: _kGreen),
                      label: Text(
                          mine != null && mine.page > 0
                              ? 'Continue reading (p. ${mine.page + 1})'
                              : 'Read in-app',
                          style: const TextStyle(color: _kGreen)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _kGreen, width: 0.9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                );
              }),
            ],
            const SizedBox(height: 12),
            SquishyTap(
              onTap: onToggleRead,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_kGreen, AppColors.coral]),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: _kGreen.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.people_alt_rounded, color: Colors.white, size: 17),
                    const SizedBox(width: 8),
                    Text(
                      book.read ? 'Move back to wishlist' : 'Mark as read together',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    if (!book.read) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.favorite_rounded, color: Colors.white, size: 15),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Book cover (image or colored spine fallback) ──────────────────────────

class _BookCover extends StatelessWidget {
  final BookWish book;

  const _BookCover({required this.book});

  @override
  Widget build(BuildContext context) {
    final spine = _spineColor(book.id);

    if (book.coverUrl != null && book.coverUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: book.coverUrl!,
          width: 58,
          height: 82,
          fit: BoxFit.cover,
          errorWidget: (_, _, e) => _Spine(color: spine, title: book.title),
          placeholder: (_, _) => _Spine(color: spine, title: book.title),
        ),
      );
    }
    return _Spine(color: spine, title: book.title);
  }
}

class _Spine extends StatelessWidget {
  final Color color;
  final String title;

  const _Spine({required this.color, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 82,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(2, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              title.isNotEmpty ? title[0].toUpperCase() : '?',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(7)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add book bottom sheet ─────────────────────────────────────────────────

class _AddBookSheet extends StatefulWidget {
  final Future<void> Function(BookWish) onAdd;

  const _AddBookSheet({required this.onAdd});

  @override
  State<_AddBookSheet> createState() => _AddBookSheetState();
}

class _AddBookSheetState extends State<_AddBookSheet> {
  final _titleCtrl = TextEditingController();
  String? _pdfPath;
  String? _pdfName;
  bool _loading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _pdfPath = result.files.single.path;
        _pdfName = result.files.single.name;
      });
    }
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _loading = true);

    String? pdfUrl;
    if (_pdfPath != null) {
      try {
        pdfUrl = await CloudinaryService.uploadPdf(File(_pdfPath!));
      } catch (_) {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF upload failed, adding without PDF')),
          );
        }
      }
    }

    final book = BookWish(
      id: const Uuid().v4(),
      title: title,
      pdfUrl: pdfUrl,
      read: false,
      addedBy: uid,
      addedAt: DateTime.now(),
    );

    await widget.onAdd(book);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
        decoration: const BoxDecoration(
          color: AppColors.bgMid,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Add a Book', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Book title *',
                prefixIcon: Icon(Icons.book_rounded, color: AppColors.rose),
              ),
            ),
            const SizedBox(height: 16),
            // PDF picker
            GestureDetector(
              onTap: _pickPdf,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _pdfPath != null
                        ? AppColors.rose
                        : AppColors.divider,
                    width: _pdfPath != null ? 1.5 : 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.picture_as_pdf_rounded,
                      color: _pdfPath != null ? AppColors.rose : AppColors.textMuted,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _pdfName ?? 'Upload PDF (optional)',
                        style: TextStyle(
                          color: _pdfPath != null
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_pdfPath != null)
                      GestureDetector(
                        onTap: () => setState(() {
                          _pdfPath = null;
                          _pdfName = null;
                        }),
                        child: const Icon(Icons.close_rounded,
                            color: AppColors.textMuted, size: 18),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            GradientButton(
              label: 'Add to wishlist',
              loading: _loading,
              onTap: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
