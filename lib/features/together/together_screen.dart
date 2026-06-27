import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                      title: "Journal",
                      subtitle: todayEntry == null
                          ? 'Write your thoughts for today'
                          : todayEntry.bothSubmitted
                              ? 'Both have written — tap to read ♡'
                              : 'You wrote — waiting for partner',
                      badge: todayEntry != null && !todayEntry.bothSubmitted ? '1/2' : null,
                      accent: accent,
                      onTap: () => context.push('/together/journal'),
                    ).animate().fadeIn().slideX(begin: -0.05),
                    const SizedBox(height: 14),
                    _TogetherTile(
                      emoji: '💌',
                      title: 'Letters',
                      subtitle: unlockedLetters > 0
                          ? '$unlockedLetters letter${unlockedLetters > 1 ? 's' : ''} waiting to be opened ♡'
                          : letters.isEmpty
                              ? 'No letters yet — partner will write you one'
                              : '${letters.length} letter${letters.length > 1 ? 's' : ''} for you',
                      badge: unlockedLetters > 0 ? '$unlockedLetters' : null,
                      accent: accent,
                      onTap: () => _showLettersSheet(context, ref, accent),
                    ).animate().fadeIn(delay: 80.ms).slideX(begin: -0.05),
                    const SizedBox(height: 14),
                    _TogetherTile(
                      emoji: '🪜',
                      title: 'Bucket List',
                      subtitle: bucket.isEmpty
                          ? 'Dream together — build your ladder'
                          : '$bucketDone of ${bucket.length} done',
                      accent: accent,
                      onTap: () => _showBucketSheet(context, ref, accent),
                    ).animate().fadeIn(delay: 160.ms).slideX(begin: -0.05),
                    const SizedBox(height: 14),
                    _TogetherTile(
                      emoji: '📸',
                      title: 'Photo Booth',
                      subtitle: 'Event albums — your moments, organised',
                      accent: accent,
                      onTap: () => context.push('/photo_booth'),
                    ).animate().fadeIn(delay: 240.ms).slideX(begin: -0.05),
                    const SizedBox(height: 14),
                    _TogetherTile(
                      emoji: '🎮',
                      title: 'Games',
                      subtitle: 'Would You Rather, Truth Jar, Scribble & more',
                      accent: accent,
                      onTap: () => context.push('/games'),
                    ).animate().fadeIn(delay: 320.ms).slideX(begin: -0.05),
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

// ── Shared tile ───────────────────────────────────────────────────────────

class _TogetherTile extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String? badge;
  final Color accent;
  final VoidCallback? onTap;

  const _TogetherTile({
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.badge,
    required this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
                child: Text(badge!,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              )
            else
              Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Letters Sheet ─────────────────────────────────────────────────────────
// Only shows letters the current user received (sender cannot see their own sent letters).
// Locked letters are invisible.

class _LettersSheet extends ConsumerWidget {
  final Color accent;
  const _LettersSheet({required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // lettersProvider already filters to receiver-only + unlocked-only
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
                onTap: () {
                  Navigator.pop(context);
                  context.push('/together/letter/new');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [accent, AppColors.coral]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Write',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Letters written for you — locked ones are invisible until they unlock ♡',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          if (letters.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No letters from your partner yet.\nThey\'ll write you something special ♡',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
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
    // Receiver can open & re-read unlimited times; opened flag is just informational
    return GestureDetector(
      onTap: () => _openLetter(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgCardLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: !letter.opened ? accent.withValues(alpha: 0.5) : AppColors.divider,
            width: !letter.opened ? 1.5 : 0.5,
          ),
          boxShadow: !letter.opened
              ? [BoxShadow(color: accent.withValues(alpha: 0.15), blurRadius: 12)]
              : null,
        ),
        child: Row(
          children: [
            Text(letter.opened ? '📬' : '💌', style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(letter.title, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    letter.opened ? 'Tap to read again ♡' : 'Tap to open ♡',
                    style: TextStyle(fontSize: 12, color: accent),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: accent, size: 18),
          ],
        ),
      ),
    );
  }

  void _openLetter(BuildContext context) {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null) return;
    // Mark as opened (idempotent)
    ref.read(firestoreServiceProvider).openLetter(coupleId, letter.id).ignore();

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('💌', style: TextStyle(fontSize: 32)),
              const SizedBox(height: 12),
              Text(letter.title, style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text(letter.body,
                  style: const TextStyle(
                      fontSize: 16, height: 1.75, color: AppColors.textPrimary)),
              const SizedBox(height: 24),
              GradientButton(
                label: 'Close ♡',
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bucket List Sheet — Ladder visualization ──────────────────────────────

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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _ctrl.clear();
    HapticFeedback.lightImpact();
    await ref.read(firestoreServiceProvider).addBucketItem(
      coupleId,
      BucketItem(
        id: const Uuid().v4(),
        title: title,
        createdAt: DateTime.now(),
        addedBy: uid,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(bucketListProvider).valueOrNull ?? [];
    final doneCount = items.where((i) => i.status == BucketStatus.done).length;

    return _Sheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Text('Bucket List 🪜', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            if (items.isNotEmpty)
              Text('$doneCount/${items.length} done',
                  style: TextStyle(color: widget.accent, fontSize: 12,
                      fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 6),
          Text('Each step is a dream. Climb together.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),

          // Add input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                      hintText: 'Add a step to the ladder…'),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _add,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient:
                        LinearGradient(colors: [widget.accent, AppColors.coral]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (items.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Add your first dream step ✨',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
            )
          else
            _LadderView(items: items, accent: widget.accent, ref: ref),
        ],
      ),
    );
  }
}

// ── Ladder visualization ──────────────────────────────────────────────────

class _LadderView extends StatelessWidget {
  final List<BucketItem> items;
  final Color accent;
  final WidgetRef ref;
  const _LadderView({required this.items, required this.accent, required this.ref});

  @override
  Widget build(BuildContext context) {
    // Show in reverse: top of ladder (most recent / not done) at top, done items below
    final active = items.where((i) => i.status != BucketStatus.done).toList();
    final done = items.where((i) => i.status == BucketStatus.done).toList();
    final all = [...active, ...done];

    return Column(
      children: List.generate(all.length, (i) {
        final item = all[i];
        final isDone = item.status == BucketStatus.done;
        final isLast = i == all.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ladder rail + rung connector
            SizedBox(
              width: 48,
              child: Column(
                children: [
                  // Step circle
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isDone
                          ? LinearGradient(colors: [accent, AppColors.coral])
                          : null,
                      color: isDone ? null : AppColors.bgCardLight,
                      border: isDone
                          ? null
                          : Border.all(color: accent.withValues(alpha: 0.5), width: 1.5),
                    ),
                    child: Center(
                      child: isDone
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                          : Text(
                              '${active.length - (i < active.length ? i : 0)}',
                              style: TextStyle(
                                  color: accent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  // Connector line to next rung
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 48,
                      color: accent.withValues(alpha: 0.25),
                    ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Step card
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final coupleId = ref.read(coupleIdProvider);
                  if (coupleId == null) return;
                  HapticFeedback.selectionClick();
                  final next = isDone
                      ? BucketStatus.someday
                      : BucketStatus.done;
                  await ref
                      .read(firestoreServiceProvider)
                      .updateBucketStatus(coupleId, item.id, next);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 0),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDone
                        ? accent.withValues(alpha: 0.08)
                        : AppColors.bgCardLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDone
                          ? accent.withValues(alpha: 0.3)
                          : AppColors.divider,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    item.title,
                    style: TextStyle(
                      color: isDone
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                      fontSize: 15,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      decorationColor: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ).animate().fadeIn(delay: Duration(milliseconds: i * 40));
      }),
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
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            24,
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
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2)),
          ),
          Flexible(child: SingleChildScrollView(child: child)),
        ],
      ),
    );
  }
}
