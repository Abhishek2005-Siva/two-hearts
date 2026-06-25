import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/firebase/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

class LetterComposeScreen extends ConsumerStatefulWidget {
  const LetterComposeScreen({super.key});

  @override
  ConsumerState<LetterComposeScreen> createState() => _LetterComposeScreenState();
}

class _LetterComposeScreenState extends ConsumerState<LetterComposeScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  LetterUnlockType _unlockType = LetterUnlockType.tomorrow;
  bool _sending = false;

  Future<void> _send() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) return;
    final coupleId = ref.read(coupleIdProvider);
    final authUser = FirebaseAuth.instance.currentUser;
    if (coupleId == null || authUser == null) return;
    setState(() => _sending = true);
    try {
      final unlockAt = _unlockDateFor(_unlockType);
      await ref.read(firestoreServiceProvider).sendLetter(
        coupleId,
        LetterModel(
          id: const Uuid().v4(),
          authorId: authUser.uid,
          title: _title.text.trim(),
          body: _body.text.trim(),
          unlockType: _unlockType,
          unlockAt: unlockAt,
          createdAt: DateTime.now(),
        ),
      );
      if (mounted) context.go('/together');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  DateTime? _unlockDateFor(LetterUnlockType type) {
    final now = DateTime.now();
    switch (type) {
      case LetterUnlockType.tomorrow: return now.add(const Duration(days: 1));
      case LetterUnlockType.nextMonth: return DateTime(now.year, now.month + 1, now.day);
      case LetterUnlockType.openWhenSad: return null;
      default: return now.add(const Duration(days: 1));
    }
  }

  String _labelFor(LetterUnlockType type) {
    switch (type) {
      case LetterUnlockType.tomorrow: return 'Tomorrow';
      case LetterUnlockType.nextMonth: return 'Next month';
      case LetterUnlockType.birthday: return 'Birthday';
      case LetterUnlockType.anniversary: return 'Anniversary';
      case LetterUnlockType.openWhenSad: return 'Open when sad';
      case LetterUnlockType.custom: return 'Custom';
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(accentColorProvider);
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
              // Top bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
                      onPressed: () => context.go('/together'),
                    ),
                    const Expanded(
                      child: Text('Write a Letter', textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _sending
                          ? const SizedBox(width: 24, height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.rose))
                          : GestureDetector(
                              onTap: _send,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [accent, AppColors.coral]),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text('Send', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              ),
                            ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subject
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.bgCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider, width: 0.5),
                        ),
                        child: TextField(
                          controller: _title,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
                          decoration: const InputDecoration(
                            hintText: 'Subject…',
                            hintStyle: TextStyle(color: AppColors.textMuted),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(18),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Unlock type
                      const Text('OPEN WHEN…',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                              color: AppColors.textMuted, letterSpacing: 1.5)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: LetterUnlockType.values.take(5).map((type) {
                          final selected = _unlockType == type;
                          return GestureDetector(
                            onTap: () => setState(() => _unlockType = type),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: selected
                                    ? LinearGradient(colors: [accent, AppColors.coral])
                                    : null,
                                color: selected ? null : AppColors.bgCard,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selected ? Colors.transparent : AppColors.divider,
                                  width: 0.5,
                                ),
                                boxShadow: selected
                                    ? [BoxShadow(color: accent.withValues(alpha: 0.3), blurRadius: 8)]
                                    : null,
                              ),
                              child: Text(_labelFor(type),
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: selected ? Colors.white : AppColors.textSecondary,
                                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // Body
                      Container(
                        constraints: BoxConstraints(
                          minHeight: MediaQuery.of(context).size.height * 0.35,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.bgCard,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.divider, width: 0.5),
                        ),
                        child: TextField(
                          controller: _body,
                          maxLines: null,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 16, height: 1.8),
                          decoration: const InputDecoration(
                            hintText: 'Dear love,\n\nI wanted to tell you…',
                            hintStyle: TextStyle(color: AppColors.textMuted, height: 1.8),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 80),
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
