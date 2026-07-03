import 'package:cached_network_image/cached_network_image.dart';
import 'package:confetti/confetti.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/firebase/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _confetti.dispose();
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

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(accentColorProvider);
    final booksAsync = ref.watch(booksProvider);
    final books = booksAsync.valueOrNull ?? [];
    final readCount = books.where((b) => b.read).length;
    final wishlistCount = books.where((b) => !b.read).length;

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: AppColors.bgGradient,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: AppColors.textPrimary),
                        onPressed: () => Navigator.maybePop(context),
                      ),
                      const Expanded(
                        child: Text(
                          'Book Wishlist',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Stats card
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accent.withValues(alpha: 0.15),
                          AppColors.coral.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatChip(
                          icon: '✓',
                          label: '$readCount read together',
                          color: const Color(0xFF4CAF50),
                        ),
                        Container(
                          width: 1,
                          height: 28,
                          color: AppColors.divider,
                        ),
                        _StatChip(
                          icon: '📚',
                          label: '$wishlistCount on wishlist',
                          color: accent,
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn().slideY(begin: -0.2),

                const SizedBox(height: 16),

                // Tabs
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TabBar(
                    controller: _tabCtrl,
                    indicator: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [accent, AppColors.coral]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.textSecondary,
                    dividerColor: Colors.transparent,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                    tabs: const [
                      Tab(text: 'Wishlist'),
                      Tab(text: 'Read Together'),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Tab views
                Expanded(
                  child: booksAsync.when(
                    loading: () => const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.rose)),
                    error: (e, _) => Center(
                        child: Text('$e',
                            style: const TextStyle(
                                color: AppColors.textSecondary))),
                    data: (books) => TabBarView(
                      controller: _tabCtrl,
                      children: [
                        _BookList(
                          books: books.where((b) => !b.read).toList(),
                          emptyMessage: 'No books yet!\nAdd your first read ♡',
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
                          books: books.where((b) => b.read).toList(),
                          emptyMessage:
                              'Nothing read yet.\nFinish a book to see it here ♡',
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
              colors: [
                AppColors.rose,
                AppColors.coral,
                AppColors.gold,
                AppColors.lavender,
                const Color(0xFF4CAF50),
              ],
              gravity: 0.3,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSheet,
        backgroundColor: accent,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }
}

// ── Stat chip ─────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;

  const _StatChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: TextStyle(fontSize: 16, color: color)),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
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
            Text(emptyIcon, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ],
        ),
      ).animate().fadeIn();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      itemCount: books.length,
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

class _BookCard extends StatefulWidget {
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
  State<_BookCard> createState() => _BookCardState();
}

class _BookCardState extends State<_BookCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.ref.watch(accentColorProvider);
    final me = widget.ref.watch(currentUserProvider).valueOrNull;
    final partner = widget.ref.watch(partnerUserProvider).valueOrNull;
    final addedByName = widget.book.addedBy == me?.uid
        ? (me?.displayName.split(' ').first ?? 'You')
        : (partner?.displayName.split(' ').first ?? 'Partner');

    return Dismissible(
      key: ValueKey('dismissible_${widget.book.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.rose.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppColors.rose, size: 26),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.bgCard,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Text('Remove book?',
                style: TextStyle(color: AppColors.textPrimary)),
            content: Text('"${widget.book.title}"',
                style:
                    const TextStyle(color: AppColors.textSecondary)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel',
                    style:
                        TextStyle(color: AppColors.textSecondary)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Remove',
                    style: TextStyle(color: AppColors.rose)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => widget.onDelete(),
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: AppColors.cardGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.book.read
                  ? const Color(0xFF4CAF50).withValues(alpha: 0.4)
                  : AppColors.divider,
              width: widget.book.read ? 1.0 : 0.5,
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cover image or spine
                    _BookCover(book: widget.book),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.book.title,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                            maxLines: _expanded ? null : 2,
                            overflow: _expanded
                                ? null
                                : TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.book.author,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.1),
                                  borderRadius:
                                      BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'by $addedByName',
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('MMM d')
                                    .format(widget.book.addedAt),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    widget.book.read
                        ? const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF4CAF50), size: 22)
                        : Icon(Icons.favorite_border_rounded,
                            color: accent, size: 22),
                  ],
                ),
              ),

              // Expanded detail
              if (_expanded) ...[
                const Divider(
                    height: 1, color: AppColors.divider, thickness: 0.5),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.book.note != null) ...[
                        Text(
                          widget.book.note!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      GradientButton(
                        label: widget.book.read
                            ? 'Move back to wishlist'
                            : 'Mark as read together ♡',
                        onTap: () {
                          setState(() => _expanded = false);
                          widget.onToggleRead();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
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
          width: 56,
          height: 80,
          fit: BoxFit.cover,
          errorWidget: (_, __, e) => _Spine(color: spine, title: book.title),
          placeholder: (_, __) => _Spine(color: spine, title: book.title),
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
      width: 56,
      height: 80,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Center(
        child: RotatedBox(
          quarterTurns: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              title.isNotEmpty ? title[0].toUpperCase() : '?',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
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
  final _authorCtrl = TextEditingController();
  final _coverCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _coverCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final author = _authorCtrl.text.trim();
    if (title.isEmpty || author.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _loading = true);

    final book = BookWish(
      id: const Uuid().v4(),
      title: title,
      author: author,
      coverUrl: _coverCtrl.text.trim().isEmpty ? null : _coverCtrl.text.trim(),
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
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
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
        decoration: const BoxDecoration(
          color: AppColors.bgMid,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: SingleChildScrollView(
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
              Text('Add a Book',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: _titleCtrl,
                autofocus: true,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Book title *',
                  prefixIcon: Icon(Icons.book_rounded,
                      color: AppColors.rose),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _authorCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Author *',
                  prefixIcon: Icon(Icons.person_outline_rounded,
                      color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _coverCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  hintText: 'Cover image URL (optional)',
                  prefixIcon: Icon(Icons.image_outlined,
                      color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Note (optional)…',
                  prefixIcon: Icon(Icons.notes_rounded,
                      color: AppColors.textMuted),
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
      ),
    );
  }
}
