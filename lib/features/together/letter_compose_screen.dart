import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/firebase/firestore_service.dart';
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
    if (coupleId == null) return;
    setState(() => _sending = true);
    try {
      final unlockAt = _unlockDateFor(_unlockType);
      await ref.read(firestoreServiceProvider).sendLetter(
        coupleId,
        LetterModel(
          id: const Uuid().v4(),
          authorId: FirebaseAuth.instance.currentUser!.uid,
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
      case LetterUnlockType.tomorrow:
        return now.add(const Duration(days: 1));
      case LetterUnlockType.nextMonth:
        return DateTime(now.year, now.month + 1, now.day);
      case LetterUnlockType.openWhenSad:
        return null; // manual unlock
      default:
        return now.add(const Duration(days: 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(accentColorProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Write a Letter'),
        actions: [
          if (_sending)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            IconButton(
              icon: Icon(Icons.send_rounded, color: accent),
              onPressed: _send,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Subject'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Text('Open when…', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: LetterUnlockType.values.take(5).map((type) {
                final selected = _unlockType == type;
                return ChoiceChip(
                  label: Text(_labelFor(type)),
                  selected: selected,
                  selectedColor: accent.withOpacity(0.2),
                  onSelected: (_) => setState(() => _unlockType = type),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _body,
              decoration: InputDecoration(
                hintText: 'Dear …\n\nI wanted to tell you…',
                hintStyle: TextStyle(color: AppColors.warmGray.withOpacity(0.7), height: 1.7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(18),
              ),
              maxLines: 16,
              style: const TextStyle(fontSize: 16, height: 1.7),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  String _labelFor(LetterUnlockType type) {
    switch (type) {
      case LetterUnlockType.tomorrow: return 'Tomorrow';
      case LetterUnlockType.nextMonth: return 'Next month';
      case LetterUnlockType.birthday: return 'Birthday';
      case LetterUnlockType.anniversary: return 'Anniversary';
      case LetterUnlockType.openWhenSad: return 'Open when sad';
      case LetterUnlockType.custom: return 'Custom date';
    }
  }
}
