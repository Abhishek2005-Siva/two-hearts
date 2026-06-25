import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/firebase/firestore_service.dart';
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
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    if (_ctrl.text.trim().isEmpty) return;
    final coupleId = ref.read(coupleIdProvider)!;
    final partner = ref.read(partnerUserProvider).valueOrNull;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    setState(() => _submitting = true);
    try {
      await ref.read(firestoreServiceProvider).submitJournalEntry(
        coupleId, _todayKey, _ctrl.text.trim(), partner?.uid ?? '',
      );
      setState(() { _submitted = true; });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(accentColorProvider);
    final journalAsync = ref.watch(journalProvider);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final todayEntry = journalAsync.valueOrNull
        ?.where((j) => j.id == _todayKey)
        .firstOrNull;

    final myEntry = todayEntry?.uidA == uid ? todayEntry?.entryA : todayEntry?.entryB;
    final hasMyEntry = myEntry != null && myEntry.isNotEmpty;
    if (hasMyEntry && !_submitted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _ctrl.text = myEntry;
          setState(() => _submitted = true);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(title: Text(_todayKey)),
      body: Column(
        children: [
          // Status banner
          if (todayEntry != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: todayEntry.bothSubmitted
                    ? accent.withOpacity(0.1)
                    : AppColors.softPeach,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    todayEntry.bothSubmitted ? Icons.lock_open_rounded : Icons.lock_outline,
                    color: accent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    todayEntry.bothSubmitted
                        ? '1 of 2 submitted — both unlocked ♡'
                        : '1 of 2 submitted — waiting for your partner',
                    style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (todayEntry?.bothSubmitted == true) ...[
                    // Show both entries
                    Expanded(
                      child: ListView(
                        children: [
                          _EntryCard(
                            label: 'You wrote',
                            entry: todayEntry!.uidA == uid
                                ? todayEntry.entryA ?? ''
                                : todayEntry.entryB ?? '',
                            accent: accent,
                          ),
                          const SizedBox(height: 16),
                          _EntryCard(
                            label: 'They wrote',
                            entry: todayEntry.uidA == uid
                                ? todayEntry.entryB ?? ''
                                : todayEntry.entryA ?? '',
                            accent: accent,
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Text(
                      _submitted ? 'Your entry (submitted)' : "What's on your mind today?",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        enabled: !_submitted,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: InputDecoration(
                          hintText: 'Write freely — your partner sees this only after they write too…',
                          hintStyle: TextStyle(color: AppColors.warmGray.withOpacity(0.7), height: 1.7),
                          filled: true,
                          fillColor: _submitted ? AppColors.softPeach : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.divider),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.divider),
                          ),
                          contentPadding: const EdgeInsets.all(18),
                        ),
                        style: const TextStyle(fontSize: 16, height: 1.7),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!_submitted)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Submit Entry'),
                        ),
                      )
                    else
                      Center(
                        child: Text(
                          'Waiting for your partner ♡',
                          style: TextStyle(color: accent, fontSize: 14, fontStyle: FontStyle.italic),
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),
        ],
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accent, letterSpacing: 1)),
          const SizedBox(height: 10),
          Text(entry, style: const TextStyle(fontSize: 16, height: 1.7)),
        ],
      ),
    );
  }
}
