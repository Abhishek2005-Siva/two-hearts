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
    final lettersAsync = ref.watch(lettersProvider);
    final bucketAsync = ref.watch(bucketListProvider);
    final journalAsync = ref.watch(journalProvider);

    final unlockedLetters = lettersAsync.valueOrNull
            ?.where((l) => l.isUnlocked && !l.opened)
            .length ?? 0;
    final waitingLetters = lettersAsync.valueOrNull
            ?.where((l) => !l.isUnlocked)
            .length ?? 0;
    final bucketDone = bucketAsync.valueOrNull
            ?.where((b) => b.status == BucketStatus.done)
            .length ?? 0;
    final bucketTotal = bucketAsync.valueOrNull?.length ?? 0;
    final todayKey = _todayKey();
    final todayEntry = journalAsync.valueOrNull
        ?.where((j) => j.id == todayKey)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Together')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Journal card
          _TogetherCard(
            icon: Icons.menu_book_rounded,
            title: "Today's Journal",
            subtitle: todayEntry == null
                ? 'Write your thoughts for today'
                : todayEntry.bothSubmitted
                    ? 'Both have written ✓ Tap to read'
                    : 'You wrote — waiting for your partner',
            badge: todayEntry != null && !todayEntry.bothSubmitted ? '1 / 2' : null,
            accent: accent,
            onTap: () => context.go('/together/journal'),
          ).animate().fadeIn().slideX(begin: -0.05),
          const SizedBox(height: 12),

          // Letters card
          _TogetherCard(
            icon: Icons.mail_outline_rounded,
            title: 'Letters',
            subtitle: unlockedLetters > 0
                ? '$unlockedLetters letter${unlockedLetters > 1 ? 's' : ''} waiting to be opened ♡'
                : waitingLetters > 0
                    ? '$waitingLetters sealed letter${waitingLetters > 1 ? 's' : ''}'
                    : 'Write a letter to be opened later',
            badge: unlockedLetters > 0 ? '$unlockedLetters' : null,
            accent: accent,
            onTap: () => _showLettersSheet(context, ref, accent),
          ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.05),
          const SizedBox(height: 12),

          // Bucket list card
          _TogetherCard(
            icon: Icons.checklist_rounded,
            title: 'Bucket List',
            subtitle: bucketTotal == 0
                ? 'Dream together — add your first item'
                : '$bucketDone of $bucketTotal completed',
            accent: accent,
            onTap: () => _showBucketSheet(context, ref, accent),
          ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.05),
          const SizedBox(height: 12),

          // Question of the day placeholder
          _TogetherCard(
            icon: Icons.help_outline_rounded,
            title: 'Question of the Day',
            subtitle: 'Coming soon — both answer, then reveal',
            accent: accent,
            onTap: null,
            disabled: true,
          ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.05),
        ],
      ),
    );
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  void _showLettersSheet(BuildContext context, WidgetRef ref, Color accent) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.warmCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _LettersSheet(accent: accent),
      ),
    );
  }

  void _showBucketSheet(BuildContext context, WidgetRef ref, Color accent) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.warmCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _BucketListSheet(accent: accent),
      ),
    );
  }
}

class _TogetherCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final Color accent;
  final VoidCallback? onTap;
  final bool disabled;

  const _TogetherCard({
    required this.icon,
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
      opacity: disabled ? 0.5 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                )
              else
                Icon(Icons.chevron_right_rounded, color: AppColors.warmGray),
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
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Letters', style: Theme.of(context).textTheme.titleLarge),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/together/letter/new');
                  },
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Write'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: letters.isEmpty
                  ? Center(child: Text('No letters yet ♡', style: Theme.of(context).textTheme.bodyMedium))
                  : ListView.separated(
                      controller: scrollController,
                      itemCount: letters.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _LetterTile(letter: letters[i], accent: accent, ref: ref),
                    ),
            ),
          ],
        ),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: canOpen ? accent.withOpacity(0.5) : AppColors.divider,
            width: canOpen ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              letter.isUnlocked ? Icons.drafts_outlined : Icons.mail_outlined,
              color: canOpen ? accent : AppColors.warmGray,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    letter.opened ? letter.title : (letter.isUnlocked ? letter.title : '— sealed —'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    letter.opened
                        ? 'Opened ✓'
                        : letter.isUnlocked
                            ? 'Tap to open ♡'
                            : 'Unlocks ${letter.unlockAt != null ? _formatDate(letter.unlockAt!) : 'later'}',
                    style: TextStyle(fontSize: 12, color: canOpen ? accent : AppColors.warmGray),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day}/${d.month}/${d.year}';
  }

  void _openLetter(BuildContext context) {
    final coupleId = ref.read(coupleIdProvider)!;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(letter.title),
        content: Text(letter.body, style: const TextStyle(fontSize: 15, height: 1.6)),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(firestoreServiceProvider).openLetter(coupleId, letter.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Close ♡'),
          ),
        ],
      ),
    );
  }
}

// ── Bucket List Sheet ─────────────────────────────────────────────────────

class _BucketListSheet extends ConsumerStatefulWidget {
  final Color accent;
  const _BucketListSheet({required this.accent});

  @override
  ConsumerState<_BucketListSheet> createState() => _BucketListSheetState();
}

class _BucketListSheetState extends ConsumerState<_BucketListSheet> {
  final _ctrl = TextEditingController();

  Future<void> _add() async {
    final title = _ctrl.text.trim();
    if (title.isEmpty) return;
    final coupleId = ref.read(coupleIdProvider)!;
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

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, sc) => Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Bucket List', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: const InputDecoration(hintText: 'Something to do together…'),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _add, child: const Text('Add')),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                controller: sc,
                children: [
                  if (someday.isNotEmpty) ...[
                    _BucketSection(label: 'Someday', items: someday, accent: widget.accent, ref: ref),
                    const SizedBox(height: 8),
                  ],
                  if (planned.isNotEmpty) ...[
                    _BucketSection(label: 'Planned', items: planned, accent: widget.accent, ref: ref),
                    const SizedBox(height: 8),
                  ],
                  if (done.isNotEmpty)
                    _BucketSection(label: 'Done ✓', items: done, accent: widget.accent, ref: ref),
                ],
              ),
            ),
          ],
        ),
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
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: accent, letterSpacing: 1)),
        const SizedBox(height: 6),
        ...items.map((item) => _BucketTile(item: item, accent: accent, ref: ref)),
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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Checkbox(
        value: item.status == BucketStatus.done,
        activeColor: accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        onChanged: (v) async {
          final coupleId = ref.read(coupleIdProvider)!;
          final next = v == true ? BucketStatus.done : BucketStatus.someday;
          await ref.read(firestoreServiceProvider).updateBucketStatus(coupleId, item.id, next);
        },
      ),
      title: Text(
        item.title,
        style: TextStyle(
          decoration: item.status == BucketStatus.done ? TextDecoration.lineThrough : null,
          color: item.status == BucketStatus.done ? AppColors.warmGray : AppColors.darkBrown,
        ),
      ),
    );
  }
}
