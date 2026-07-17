import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

/// One persistent shared note per couple — a single sticky note, not a
/// list. Whoever edits last wins (last-write-wins merge), same simplicity
/// convention as the app's other singleton per-couple docs.
class SharedNoteScreen extends ConsumerStatefulWidget {
  const SharedNoteScreen({super.key});

  @override
  ConsumerState<SharedNoteScreen> createState() => _SharedNoteScreenState();
}

class _SharedNoteScreenState extends ConsumerState<SharedNoteScreen> {
  final _ctrl = TextEditingController();
  bool _inited = false;
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(firestoreServiceProvider).setSharedNote(coupleId, _ctrl.text);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final note = ref.watch(sharedNoteProvider).valueOrNull;
    if (!_inited && note != null) {
      _ctrl.text = note['text'] as String? ?? '';
      _inited = true;
    }
    final updatedAt = (note?['updatedAt']);
    final updatedLabel = updatedAt != null
        ? 'Last updated ${timeago.format((updatedAt as dynamic).toDate())}'
        : null;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text('Shared Note'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save',
                style: const TextStyle(color: AppColors.rose, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (updatedLabel != null) ...[
                Text(updatedLabel,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, height: 1.5),
                  decoration: InputDecoration(
                    hintText: 'Write something for both of you to see…',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.bgCardLight,
                    contentPadding: const EdgeInsets.all(16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
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
