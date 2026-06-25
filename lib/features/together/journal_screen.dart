import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  final _ctrl = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;

  String get _todayKey {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    if (_ctrl.text.trim().isEmpty) return;
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null) return;
    final partner = ref.read(partnerUserProvider).valueOrNull;
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) return;
    setState(() => _submitting = true);
    try {
      await ref.read(firestoreServiceProvider).submitJournalEntry(
        coupleId, _todayKey, _ctrl.text.trim(), partner?.uid ?? '',
      );
      setState(() => _submitted = true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final accent = ref.watch(accentColorProvider);
    final journal = ref.watch(journalProvider).valueOrNull ?? [];
    final uid = authUser.uid;
    final todayEntry = journal.where((j) => j.id == _todayKey).firstOrNull;

    final myEntry = todayEntry?.uidA == uid ? todayEntry?.entryA : todayEntry?.entryB;
    if (myEntry != null && myEntry.isNotEmpty && !_submitted && _ctrl.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) { _ctrl.text = myEntry; setState(() => _submitted = true); }
      });
    }

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
              // App bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(_todayKey,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // Status banner
              if (todayEntry != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: todayEntry.bothSubmitted
                        ? accent.withValues(alpha: 0.12)
                        : AppColors.bgCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: todayEntry.bothSubmitted ? accent.withValues(alpha: 0.4) : AppColors.divider,
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(todayEntry.bothSubmitted ? '🔓' : '🔒', style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Text(
                        todayEntry.bothSubmitted
                            ? 'Both written — unlocked ♡'
                            : '1 of 2 — waiting for partner',
                        style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: todayEntry?.bothSubmitted == true
                      ? ListView(
                          children: [
                            _EntryCard(
                              label: 'YOU WROTE',
                              entry: todayEntry!.uidA == uid
                                  ? todayEntry.entryA ?? ''
                                  : todayEntry.entryB ?? '',
                              accent: accent,
                            ),
                            const SizedBox(height: 16),
                            _EntryCard(
                              label: 'THEY WROTE',
                              entry: todayEntry.uidA == uid
                                  ? todayEntry.entryB ?? ''
                                  : todayEntry.entryA ?? '',
                              accent: accent,
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _submitted ? 'Your entry' : "What's on your mind?",
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.bgCard,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _submitted ? accent.withValues(alpha: 0.3) : AppColors.divider,
                                    width: 0.5,
                                  ),
                                ),
                                child: TextField(
                                  controller: _ctrl,
                                  enabled: !_submitted,
                                  maxLines: null,
                                  expands: true,
                                  textAlignVertical: TextAlignVertical.top,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    height: 1.7,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: 'Write freely — only unlocks when your partner writes too…',
                                    hintStyle: TextStyle(color: AppColors.textMuted),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.all(18),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (!_submitted)
                              GradientButton(
                                label: 'Submit Entry',
                                onTap: _submit,
                                loading: _submitting,
                              )
                            else
                              Center(
                                child: Text(
                                  'Waiting for your partner ♡',
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
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
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final String label;
  final String entry;
  final Color accent;

  const _EntryCard({required this.label, required this.entry, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.bold, color: accent, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          Text(entry,
              style: const TextStyle(
                  fontSize: 16, height: 1.7, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
