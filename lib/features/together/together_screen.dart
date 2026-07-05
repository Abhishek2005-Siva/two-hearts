import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/firebase/models.dart';
import '../../core/models/content_block.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/rich_content_viewer.dart';

class TogetherScreen extends ConsumerWidget {
  const TogetherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(accentColorProvider);
    final letters = ref.watch(lettersProvider).valueOrNull ?? [];
    final bucket = ref.watch(bucketListProvider).valueOrNull ?? [];
    final journal = ref.watch(journalProvider).valueOrNull ?? [];
    final cinema = ref.watch(cinemaSessionProvider).valueOrNull;
    final nowShowing = (cinema?['title'] as String?)?.trim();

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
                title: const Text('Fun'),
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
                      onTap: () => context.push('/together/bucket'),
                    ).animate().fadeIn(delay: 160.ms).slideX(begin: -0.05),
                    const SizedBox(height: 14),
                    _TogetherTile(
                      emoji: '🍿',
                      title: 'Movie Night',
                      subtitle: cinema != null
                          ? 'Now showing${nowShowing != null && nowShowing.isNotEmpty ? ': $nowShowing' : ''} — join in! 🎬'
                          : 'Watch a movie together, perfectly in sync',
                      badge: cinema != null ? 'LIVE' : null,
                      accent: accent,
                      onTap: () => context.push('/cinema'),
                    ).animate().fadeIn(delay: 240.ms).slideX(begin: -0.05),
                    const SizedBox(height: 14),
                    _TogetherTile(
                      emoji: '🎮',
                      title: 'Games',
                      subtitle: 'WYR, Truth Jar, Scribble, RPS, Thumb Kiss & more',
                      accent: accent,
                      onTap: () => context.push('/games'),
                    ).animate().fadeIn(delay: 320.ms).slideX(begin: -0.05),
                    const SizedBox(height: 14),
                    _TogetherTile(
                      emoji: '💡',
                      title: 'Date Idea',
                      subtitle: 'Spin the wheel — let fate plan your next date',
                      accent: accent,
                      onTap: () => context.push('/dates'),
                    ).animate().fadeIn(delay: 360.ms).slideX(begin: -0.05),
                    const SizedBox(height: 14),
                    _TogetherTile(
                      emoji: '📍',
                      title: 'Destination Wishlist',
                      subtitle: 'Pin dream spots to visit together',
                      accent: accent,
                      onTap: () => context.push('/places'),
                    ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.05),
                    const SizedBox(height: 14),
                    _TogetherTile(
                      emoji: '📚',
                      title: 'Books',
                      subtitle: 'Your shared reading wishlist',
                      accent: accent,
                      onTap: () => context.push('/books'),
                    ).animate().fadeIn(delay: 480.ms).slideX(begin: -0.05),
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
    return SquishyTap(
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
      builder: (dialogCtx) => Dialog(
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
              _LetterBody(body: letter.body),
              const SizedBox(height: 24),
              GradientButton(
                label: 'Close ♡',
                onTap: () => Navigator.pop(dialogCtx),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared bottom sheet wrapper ───────────────────────────────────────────

// ── Letter body renderer ──────────────────────────────────────────────────

class _LetterBody extends StatelessWidget {
  final String body;
  const _LetterBody({required this.body});

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
        style: const TextStyle(fontSize: 16, height: 1.75, color: AppColors.textPrimary),
      );
    }
    return RichContentViewer(blocks: blocks);
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
