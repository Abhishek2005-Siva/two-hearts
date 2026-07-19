import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/firebase/models.dart';
import '../../core/presence/activity_announcer.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

const _reactionEmojis = ['❤️', '😂', '😭', '🥰', '👏', '🔥'];

/// Full detail view for one calendar day — both partners' snaps, captions,
/// moods, reactions, and a flat comment thread. Pushed from a tile tap on
/// [DailySnapCalendarScreen].
class DailyMemoryDetailScreen extends ConsumerStatefulWidget {
  final String dateKey;
  const DailyMemoryDetailScreen({super.key, required this.dateKey});

  @override
  ConsumerState<DailyMemoryDetailScreen> createState() => _DailyMemoryDetailScreenState();
}

class _DailyMemoryDetailScreenState extends ConsumerState<DailyMemoryDetailScreen>
    with ActivityAnnouncer {
  final _commentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    announceActivity('Looking at a shared memory');
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleReaction(String emoji) async {
    final coupleId = ref.read(coupleIdProvider);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (coupleId == null || uid == null) return;
    final mine = ref
        .read(dailySnapReactionsProvider(widget.dateKey))
        .valueOrNull
        ?.where((r) => r['id'] == uid)
        .firstOrNull;
    HapticFeedback.selectionClick();
    final next = mine?['emoji'] == emoji ? null : emoji;
    await ref
        .read(firestoreServiceProvider)
        .setDailySnapReaction(coupleId, widget.dateKey, uid, next);
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    final coupleId = ref.read(coupleIdProvider);
    if (text.isEmpty || coupleId == null) return;
    _commentCtrl.clear();
    await ref.read(firestoreServiceProvider).addDailySnapComment(coupleId, widget.dateKey, text);
  }

  @override
  Widget build(BuildContext context) {
    final snaps = ref.watch(dailySnapsProvider).valueOrNull ?? [];
    final snap = snaps.where((s) => s.dateKey == widget.dateKey).firstOrNull;
    final entries = snap?.entries.values.toList() ?? [];
    final reactions = ref.watch(dailySnapReactionsProvider(widget.dateKey)).valueOrNull ?? [];
    final comments = ref.watch(dailySnapCommentsProvider(widget.dateKey)).valueOrNull ?? [];
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final myReaction = reactions.where((r) => r['id'] == myUid).firstOrNull?['emoji'] as String?;

    final date = DateTime.tryParse(widget.dateKey) ?? DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text(DateFormat('EEEE, MMM d, yyyy').format(date)),
        actions: [
          IconButton(
            tooltip: 'View chat from this day',
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            onPressed: () => context.push('/chat?date=${widget.dateKey}'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (entries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text('No memory for this day',
                            style: TextStyle(color: AppColors.textMuted)),
                      ),
                    )
                  else
                    ...entries.map((e) => _EntryCard(entry: e)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: _reactionEmojis.map((emoji) {
                      final count = reactions.where((r) => r['emoji'] == emoji).length;
                      final selected = myReaction == emoji;
                      return GestureDetector(
                        onTap: () => _toggleReaction(emoji),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.rose.withValues(alpha: 0.25)
                                : AppColors.bgCardLight,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected ? AppColors.rose : Colors.transparent,
                            ),
                          ),
                          child: Text(count > 0 ? '$emoji $count' : emoji,
                              style: const TextStyle(fontSize: 14)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  const Text('Comments',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (comments.isEmpty)
                    const Text('No comments yet ♡',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12))
                  else
                    ...comments.map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.bgCardLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(c['text'] as String? ?? '',
                                style: const TextStyle(
                                    color: AppColors.textPrimary, fontSize: 13)),
                          ),
                        )),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentCtrl,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Add a comment…',
                          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                          filled: true,
                          fillColor: AppColors.bgCardLight,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send_rounded, color: AppColors.rose),
                      onPressed: _sendComment,
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
}

class _EntryCard extends StatelessWidget {
  final DailySnapEntry entry;
  const _EntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: CachedNetworkImage(
              imageUrl: entry.imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (entry.mood != null) ...[
                Text(entry.mood!.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(entry.mood!.label,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(width: 10),
              ],
              Text(DateFormat('h:mm a').format(entry.createdAt),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
          if (entry.caption.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(entry.caption,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
          ],
        ],
      ),
    );
  }
}
