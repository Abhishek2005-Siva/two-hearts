import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/firebase/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

class TogetherScreen extends ConsumerWidget {
  const TogetherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(accentColorProvider);
    final letters = ref.watch(lettersProvider).valueOrNull ?? [];
    final bucket = ref.watch(bucketListProvider).valueOrNull ?? [];
    final journal = ref.watch(journalProvider).valueOrNull ?? [];

    final unlockedLetters = letters.where((l) => l.isUnlocked && !l.opened).length;
    final waitingLetters = letters.where((l) => !l.isUnlocked).length;
    final bucketDone = bucket.where((b) => b.status == BucketStatus.done).length;
    final todayKey = _todayKey();
    final todayEntry = journal.where((j) => j.id == todayKey).firstOrNull;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.bgGradient,
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: Colors.transparent,
                title: const Text('Together'),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _TogetherTile(
                      emoji: '📖',
                      title: "Today's Journal",
                      subtitle: todayEntry == null
                          ? 'Write your thoughts for today'
                          : todayEntry.bothSubmitted
                              ? 'Both have written — tap to read ♡'
                              : 'You wrote — waiting for partner',
                      badge: todayEntry != null && !todayEntry.bothSubmitted ? '1/2' : null,
                      accent: accent,
                      onTap: () => context.go('/together/journal'),
                    ).animate().fadeIn().slideX(begin: -0.05),
                    const SizedBox(height: 14),
                    _TogetherTile(
                      emoji: '💌',
                      title: 'Letters',
                      subtitle: unlockedLetters > 0
                          ? '$unlockedLetters letter${unlockedLetters > 1 ? 's' : ''} waiting to be opened ♡'
                          : waitingLetters > 0
                              ? '$waitingLetters sealed letter${waitingLetters > 1 ? 's' : ''}'
                              : 'Write a letter for later',
                      badge: unlockedLetters > 0 ? '$unlockedLetters' : null,
                      accent: accent,
                      onTap: () => _showLettersSheet(context, ref, accent),
                    ).animate().fadeIn(delay: 80.ms).slideX(begin: -0.05),
                    const SizedBox(height: 14),
                    _TogetherTile(
                      emoji: '🌟',
                      title: 'Bucket List',
                      subtitle: bucket.isEmpty
                          ? 'Dream together'
                          : '$bucketDone of ${bucket.length} done',
                      accent: accent,
                      onTap: () => _showBucketSheet(context, ref, accent),
                    ).animate().fadeIn(delay: 160.ms).slideX(begin: -0.05),
                    const SizedBox(height: 14),
                    _TogetherTile(
                      emoji: '❓',
                      title: 'Question of the Day',
                      subtitle: 'Coming soon',
                      accent: accent,
                      onTap: null,
                      disabled: true,
                    ).animate().fadeIn(delay: 240.ms).slideX(begin: -0.05),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  void _showLettersSheet(BuildContext context, WidgetRef ref, Color accent) {
    final container = ProviderScope.containerOf(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UncontrolledProviderScope(
        container: container,
        child: _LettersSheet(accent: accent),
      ),
    );
  }

  void _showBucketSheet(BuildContext context, WidgetRef ref, Color accent) {
    final container = ProviderScope.containerOf(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UncontrolledProviderScope(
        container: container,
        child: _BucketSheet(accent: accent),
      ),
    );
  }
}

class _TogetherTile extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String? badge;
  final Color accent;
  final VoidCallback? onTap;
  final bool disabled;

  const _TogetherTile({
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.badge,
    required this.accent,
    this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: AppColors.cardGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.divider, width: 0.5),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [accent, AppColors.coral]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 8)],
                  ),
                  child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                )
              else
                Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Letters Sheet ─────────────────────────────────────────────────────────

class _LettersSheet extends ConsumerWidget {
  final Color accent;
  const _LettersSheet({required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final letters = ref.watch(lettersProvider).valueOrNull ?? [];
    return _Sheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Letters 💌', style: Theme.of(context).textTheme.titleLarge),
              GestureDetector(
                onTap: () { Navigator.pop(context); context.go('/together/letter/new'); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [accent, AppColors.coral]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Write', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (letters.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('No letters yet.\nWrite one for a future moment ♡',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
            )
          else
            ...letters.map((l) => _LetterTile(letter: l, accent: accent, ref: ref)),
        ],
      ),
    );
  }
}

class _LetterTile extends StatelessWidget {
  final LetterModel letter;
  final Color accent;
  final WidgetRef ref;
  const _LetterTile({required this.letter, required this.accent, required this.ref});

  @override
  Widget build(BuildContext context) {
    final canOpen = letter.isUnlocked && !letter.opened;
    return GestureDetector(
      onTap: canOpen ? () => _openLetter(context) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgCardLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: canOpen ? accent.withValues(alpha: 0.5) : AppColors.divider,
            width: canOpen ? 1.5 : 0.5,
          ),
          boxShadow: canOpen
              ? [BoxShadow(color: accent.withValues(alpha: 0.15), blurRadius: 12)]
              : null,
        ),
        child: Row(
          children: [
            Text(
              letter.opened ? '📬' : letter.isUnlocked ? '💌' : '🔒',
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    letter.opened ? letter.title : letter.isUnlocked ? letter.title : '— sealed —',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    letter.opened
                        ? 'Opened ✓'
                        : letter.isUnlocked
                            ? 'Tap to open ♡'
                            : 'Unlocks ${letter.unlockAt != null ? '${letter.unlockAt!.day}/${letter.unlockAt!.month}/${letter.unlockAt!.year}' : 'later'}',
                    style: TextStyle(fontSize: 12, color: canOpen ? accent : AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openLetter(BuildContext context) {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(letter.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Text(letter.body, style: const TextStyle(fontSize: 16, height: 1.7, color: AppColors.textPrimary)),
              const SizedBox(height: 24),
              GradientButton(
                label: 'Close ♡',
                onTap: () async {
                  await ref.read(firestoreServiceProvider).openLetter(coupleId, letter.id);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bucket List Sheet ─────────────────────────────────────────────────────

class _BucketSheet extends ConsumerStatefulWidget {
  final Color accent;
  const _BucketSheet({required this.accent});

  @override
  ConsumerState<_BucketSheet> createState() => _BucketSheetState();
}

class _BucketSheetState extends ConsumerState<_BucketSheet> {
  final _ctrl = TextEditingController();

  Future<void> _add() async {
    final title = _ctrl.text.trim();
    if (title.isEmpty) return;
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null) return;
    _ctrl.clear();
    await ref.read(firestoreServiceProvider).addBucketItem(
      coupleId,
      BucketItem(id: const Uuid().v4(), title: title, createdAt: DateTime.now()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(bucketListProvider).valueOrNull ?? [];
    final someday = items.where((i) => i.status == BucketStatus.someday).toList();
    final planned = items.where((i) => i.status == BucketStatus.planned).toList();
    final done = items.where((i) => i.status == BucketStatus.done).toList();

    return _Sheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Bucket List 🌟', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(hintText: 'Something to do together…'),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _add,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [widget.accent, AppColors.coral]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (someday.isNotEmpty) _BucketSection(label: 'SOMEDAY', items: someday, accent: widget.accent, ref: ref),
          if (planned.isNotEmpty) _BucketSection(label: 'PLANNED', items: planned, accent: widget.accent, ref: ref),
          if (done.isNotEmpty) _BucketSection(label: 'DONE ✓', items: done, accent: widget.accent, ref: ref),
          if (items.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Add your first dream ✨', style: Theme.of(context).textTheme.bodyMedium),
              ),
            ),
        ],
      ),
    );
  }
}

class _BucketSection extends StatelessWidget {
  final String label;
  final List<BucketItem> items;
  final Color accent;
  final WidgetRef ref;
  const _BucketSection({required this.label, required this.items, required this.accent, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: accent, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        ...items.map((item) => _BucketTile(item: item, accent: accent, ref: ref)),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _BucketTile extends StatelessWidget {
  final BucketItem item;
  final Color accent;
  final WidgetRef ref;
  const _BucketTile({required this.item, required this.accent, required this.ref});

  @override
  Widget build(BuildContext context) {
    final done = item.status == BucketStatus.done;
    return GestureDetector(
      onTap: () async {
        final coupleId = ref.read(coupleIdProvider);
        if (coupleId == null) return;
        final next = done ? BucketStatus.someday : BucketStatus.done;
        await ref.read(firestoreServiceProvider).updateBucketStatus(coupleId, item.id, next);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: done ? accent.withValues(alpha: 0.1) : AppColors.bgCardLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: done ? accent.withValues(alpha: 0.3) : AppColors.divider, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: done ? LinearGradient(colors: [accent, AppColors.coral]) : null,
                border: done ? null : Border.all(color: AppColors.textMuted, width: 1.5),
              ),
              child: done ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  color: done ? AppColors.textMuted : AppColors.textPrimary,
                  decoration: done ? TextDecoration.lineThrough : null,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared bottom sheet wrapper ───────────────────────────────────────────

class _Sheet extends StatelessWidget {
  final Widget child;
  const _Sheet({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      padding: EdgeInsets.fromLTRB(
        24, 20, 24, MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgMid,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
          ),
          Flexible(child: SingleChildScrollView(child: child)),
        ],
      ),
    );
  }
}
