import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/delight/couple_character.dart';
import '../../core/firebase/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

String _typeEmoji(String type) => switch (type) {
      'wildcard_request' => '🃏',
      'book' => '📚',
      'journal' => '📖',
      'recipe' => '🍳',
      'place' => '📍',
      'letter' => '💌',
      _ => '✨',
    };

String _relativeTime(DateTime from) {
  final diff = DateTime.now().difference(from);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m ago';
  }
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  final weeks = (diff.inDays / 7).floor();
  if (diff.inDays < 30) return '${weeks}w ago';
  final months = (diff.inDays / 30).floor();
  return '${months}mo ago';
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(accentColorProvider);
    final coupleId = ref.watch(coupleIdProvider);
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final notificationsAsync = ref.watch(notificationsProvider);
    final notifications = notificationsAsync.valueOrNull ?? [];
    final unreadIds = notifications
        .where((n) => n.isUnreadFor(myUid))
        .map((n) => n.id)
        .toList();

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
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppColors.textPrimary),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    Expanded(
                      child: Text('Notifications',
                          style: Theme.of(context)
                              .textTheme
                              .displayMedium
                              ?.copyWith(fontSize: 20)),
                    ),
                    if (unreadIds.isNotEmpty && coupleId != null)
                      TextButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          ref
                              .read(firestoreServiceProvider)
                              .markAllNotificationsRead(coupleId, unreadIds);
                        },
                        child: Text('Mark all read',
                            style: TextStyle(
                                color: accent,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: notificationsAsync.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : notifications.isEmpty
                        ? _EmptyInbox(accent: accent)
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                            itemCount: notifications.length,
                            itemBuilder: (context, i) {
                              final n = notifications[i];
                              final unread = n.isUnreadFor(myUid);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _NotificationTile(
                                  notification: n,
                                  unread: unread,
                                  accent: accent,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    if (unread && coupleId != null) {
                                      ref
                                          .read(firestoreServiceProvider)
                                          .markNotificationRead(coupleId, n.id);
                                    }
                                    if (n.route != null) context.push(n.route!);
                                  },
                                ).animate().fadeIn(
                                    delay: (i * 40).clamp(0, 400).ms,
                                    duration: 300.ms).slideY(begin: 0.06),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final bool unread;
  final Color accent;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.unread,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: unread
              ? LinearGradient(
                  colors: [
                    accent.withValues(alpha: 0.18),
                    AppColors.bgCard,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(colors: [
                  AppColors.bgCard,
                  AppColors.bgCard,
                ]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: unread
                ? accent.withValues(alpha: 0.45)
                : AppColors.divider,
            width: unread ? 1.2 : 0.5,
          ),
          boxShadow: unread
              ? [
                  BoxShadow(
                      color: accent.withValues(alpha: 0.25), blurRadius: 18),
                  BoxShadow(
                      color: accent.withValues(alpha: 0.08), blurRadius: 32),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (unread)
              const CoupleCharacter(
                character: CoupleCharacterId.wren, pose: 'surprised', height: 42)
            else
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.bgCardLight, AppColors.bgCardLight],
                  ),
                ),
                child: Text(_typeEmoji(notification.type),
                    style: const TextStyle(fontSize: 18)),
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notification.title,
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14.5,
                          fontWeight:
                              unread ? FontWeight.w700 : FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(notification.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          height: 1.4)),
                  const SizedBox(height: 8),
                  Text(_relativeTime(notification.createdAt),
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
            if (unread)
              Container(
                margin: const EdgeInsets.only(top: 4, left: 6),
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent,
                  boxShadow: [
                    BoxShadow(color: accent.withValues(alpha: 0.8), blurRadius: 6),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  final Color accent;
  const _EmptyInbox({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [
                  accent.withValues(alpha: 0.25),
                  AppColors.coral.withValues(alpha: 0.15),
                ]),
                boxShadow: [
                  BoxShadow(color: accent.withValues(alpha: 0.2), blurRadius: 24),
                ],
              ),
              child: const Center(
                child: Text('📭', style: TextStyle(fontSize: 34)),
              ),
            ),
            const SizedBox(height: 18),
            const Text('All quiet for now',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text(
              'New pins, letters, recipes and more\nwill show up here ♡',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
