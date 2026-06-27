import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/firebase/models.dart';

// ── Main journal list (bookshelf) ─────────────────────────────────────────

class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(accentColorProvider);
    final journal = ref.watch(journalProvider).valueOrNull ?? [];
    final me = ref.watch(currentUserProvider).valueOrNull;

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
                    Expanded(
                      child: Text('Our Journal',
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                    GestureDetector(
                      onTap: () => _openCompose(context, ref, accent, me),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient:
                              LinearGradient(colors: [accent, AppColors.coral]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Write',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              if (journal.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('📖',
                            style: TextStyle(fontSize: 64)),
                        const SizedBox(height: 16),
                        Text('Start your first journal entry ♡',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    itemCount: journal.length,
                    itemBuilder: (context, i) {
                      final entry = journal[i];
                      return _BookCover(
                        entry: entry,
                        accent: accent,
                        index: i,
                        myUid: me?.uid ?? '',
                        myName:
                            me?.displayName.split(' ').first ?? 'You',
                        onTap: () =>
                            _openBook(context, ref, entry, accent, me),
                      ).animate().fadeIn(
                          delay: Duration(milliseconds: i * 60));
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCompose(BuildContext context, WidgetRef ref, Color accent,
      UserModel? me) {
    final container = ProviderScope.containerOf(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UncontrolledProviderScope(
        container: container,
        child: _ComposeSheet(accent: accent),
      ),
    );
  }

  void _openBook(BuildContext context, WidgetRef ref, JournalDay entry,
      Color accent, UserModel? me) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _BookDetailScreen(
          entry: entry,
          accent: accent,
          myUid: me?.uid ?? '',
          myName: me?.displayName ?? 'You',
          ref: ref,
        ),
      ),
    );
  }
}

// ── Book Cover Card ───────────────────────────────────────────────────────

class _BookCover extends StatelessWidget {
  final JournalDay entry;
  final Color accent;
  final int index;
  final String myUid;
  final String myName;
  final VoidCallback onTap;

  const _BookCover({
    required this.entry,
    required this.accent,
    required this.index,
    required this.myUid,
    required this.myName,
    required this.onTap,
  });

  // Cycle through a few book spine colors
  static const _spineColors = [
    Color(0xFF6B3A6B),
    Color(0xFF2A4A6B),
    Color(0xFF3A6B4A),
    Color(0xFF6B4A2A),
    Color(0xFF4A2A6B),
    Color(0xFF6B2A3A),
  ];

  @override
  Widget build(BuildContext context) {
    final spineColor = _spineColors[index % _spineColors.length];
    final title = entry.title?.isNotEmpty == true
        ? entry.title!
        : _dateLabel(entry.id);
    final hasMyEntry = entry.uidA == myUid
        ? entry.entryA != null
        : entry.entryB != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(4, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Book spine
            Container(
              width: 16,
              decoration: BoxDecoration(
                color: spineColor.withValues(alpha: 0.7),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            // Cover
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      spineColor.withValues(alpha: 0.25),
                      AppColors.bgCard,
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  border: Border.all(
                    color: spineColor.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _dateLabel(entry.id),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (entry.bothSubmitted)
                          Icon(Icons.lock_open_rounded,
                              color: accent, size: 20)
                        else if (hasMyEntry)
                          const Icon(Icons.hourglass_top_rounded,
                              color: AppColors.textMuted, size: 18)
                        else
                          Icon(Icons.edit_note_rounded,
                              color: accent.withValues(alpha: 0.6),
                              size: 20),
                        const SizedBox(height: 4),
                        Text(
                          entry.bothSubmitted
                              ? 'Unlocked'
                              : hasMyEntry
                                  ? 'Waiting'
                                  : 'Write',
                          style: TextStyle(
                            color: entry.bothSubmitted
                                ? accent
                                : AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _dateLabel(String id) {
    // id format: YYYY-MM-DD
    final parts = id.split('-');
    if (parts.length != 3) return id;
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final m = int.tryParse(parts[1]) ?? 0;
    final d = int.tryParse(parts[2]) ?? 0;
    return '${months[m]} $d, ${parts[0]}';
  }
}

// ── Book Detail Screen (open book) ────────────────────────────────────────

class _BookDetailScreen extends StatelessWidget {
  final JournalDay entry;
  final Color accent;
  final String myUid;
  final String myName;
  final WidgetRef ref;

  const _BookDetailScreen({
    required this.entry,
    required this.accent,
    required this.myUid,
    required this.myName,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final partner = ref.read(partnerUserProvider).valueOrNull;
    final partnerName = partner?.displayName ?? 'Partner';

    final myEntry = entry.uidA == myUid ? entry.entryA : entry.entryB;
    final theirEntry = entry.uidA == myUid ? entry.entryB : entry.entryA;

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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppColors.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  child: Column(
                    children: [
                      // ── Book cover page ────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accent.withValues(alpha: 0.25),
                              AppColors.bgCard,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: accent.withValues(alpha: 0.3),
                              width: 0.5),
                        ),
                        child: Column(
                          children: [
                            const Text('📖',
                                style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 20),
                            Text(
                              entry.title?.isNotEmpty == true
                                  ? entry.title!
                                  : _dateLabel(entry.id),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: 60,
                              height: 1,
                              color: accent.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Signed by $myName'
                              '${entry.bothSubmitted ? ' & $partnerName' : ''}',
                              style: TextStyle(
                                color: accent,
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _dateLabel(entry.id),
                              style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (!entry.bothSubmitted)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.bgCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColors.divider, width: 0.5),
                          ),
                          child: Row(
                            children: [
                              const Text('🔒',
                                  style: TextStyle(fontSize: 24)),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  myEntry != null
                                      ? 'Waiting for your partner to write before the pages unlock ♡'
                                      : 'Write your entry so the book can open together ♡',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                      height: 1.5),
                                ),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        _EntryPage(
                          label: 'YOUR WORDS',
                          name: myName,
                          entry: myEntry ?? '',
                          accent: accent,
                        ),
                        const SizedBox(height: 16),
                        _EntryPage(
                          label: 'THEIR WORDS',
                          name: partnerName,
                          entry: theirEntry ?? '',
                          accent: AppColors.rose,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _dateLabel(String id) {
    final parts = id.split('-');
    if (parts.length != 3) return id;
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final m = int.tryParse(parts[1]) ?? 0;
    final d = int.tryParse(parts[2]) ?? 0;
    return '${months[m]} $d, ${parts[0]}';
  }
}

class _EntryPage extends StatelessWidget {
  final String label;
  final String name;
  final String entry;
  final Color accent;

  const _EntryPage({
    required this.label,
    required this.name,
    required this.entry,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.08),
            AppColors.bgCard,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: accent.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: accent,
                  letterSpacing: 1.5)),
          const SizedBox(height: 2),
          Text(name,
              style: TextStyle(
                  fontSize: 13,
                  color: accent,
                  fontStyle: FontStyle.italic)),
          const SizedBox(height: 14),
          Text(entry,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  height: 1.75)),
        ],
      ),
    );
  }
}

// ── Compose Sheet ─────────────────────────────────────────────────────────

class _ComposeSheet extends ConsumerStatefulWidget {
  final Color accent;
  const _ComposeSheet({required this.accent});

  @override
  ConsumerState<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends ConsumerState<_ComposeSheet> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _submitting = false;

  String get _todayKey {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (body.isEmpty) return;
    final coupleId = ref.read(coupleIdProvider);
    final partner = ref.read(partnerUserProvider).valueOrNull;
    if (coupleId == null) return;
    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();
    try {
      await ref.read(firestoreServiceProvider).submitJournalEntry(
        coupleId,
        _todayKey,
        body,
        partner?.uid ?? '',
        title: title.isNotEmpty ? title : null,
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final journal = ref.watch(journalProvider).valueOrNull ?? [];
    final me = ref.watch(currentUserProvider).valueOrNull;
    final todayEntry =
        journal.where((j) => j.id == _todayKey).firstOrNull;
    final alreadyWrote = todayEntry != null &&
        (todayEntry.uidA == me?.uid
            ? todayEntry.entryA != null
            : todayEntry.entryB != null);

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            24,
      ),
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: const BoxDecoration(
        color: AppColors.bgMid,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border:
            Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),

          Text('Today\'s Entry',
              style: Theme.of(context).textTheme.titleLarge),
          Text('Write freely — unlocks when your partner writes too ♡',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),

          if (alreadyWrote)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: widget.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Text('✅', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You already wrote today! Waiting for your partner ♡',
                      style: TextStyle(
                          color: widget.accent, fontSize: 13),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // Title field
            Container(
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: AppColors.divider, width: 0.5),
              ),
              child: TextField(
                controller: _titleCtrl,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  hintText: 'Title (optional)…',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Entry field
            Flexible(
              child: Container(
                constraints: const BoxConstraints(minHeight: 140),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: AppColors.divider, width: 0.5),
                ),
                child: TextField(
                  controller: _bodyCtrl,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      height: 1.7),
                  decoration: const InputDecoration(
                    hintText:
                        'What\'s on your mind today?',
                    hintStyle:
                        TextStyle(color: AppColors.textMuted),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            GradientButton(
              label: 'Save Entry',
              onTap: _submit,
              loading: _submitting,
            ),
          ],
        ],
      ),
    );
  }
}
