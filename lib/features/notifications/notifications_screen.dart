import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/delight/couple_character.dart';
import '../../core/firebase/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../together/wildcards_screen.dart' show isWildcardGranter, showGiveWildcardSheet;

String _typeEmoji(String type) => switch (type) {
      'wildcard_request' => '🥺',
      'wildcard' => '🃏',
      'book' => '📚',
      'journal' => '📖',
      'recipe' => '🍳',
      'place' => '📍',
      'letter' => '💌',
      'daily_snap' => '📸',
      'daily_snap_comment' => '💬',
      'daily_snap_reaction' => '❤️',
      'streak_milestone' => '🎉',
      'reminiscing' => '🥺',
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

/// The actual calendar date + clock time, e.g. "Today, 3:45 PM" or
/// "Aug 2, 2026, 3:45 PM" — shown alongside the relative time since "2h
/// ago" alone doesn't say which day or what time something arrived.
String _absoluteTime(DateTime from) {
  final now = DateTime.now();
  final isToday =
      from.year == now.year && from.month == now.month && from.day == now.day;
  final yesterday = now.subtract(const Duration(days: 1));
  final isYesterday = from.year == yesterday.year &&
      from.month == yesterday.month &&
      from.day == yesterday.day;
  final time = DateFormat('h:mm a').format(from);
  if (isToday) return 'Today, $time';
  if (isYesterday) return 'Yesterday, $time';
  final sameYear = from.year == now.year;
  final datePart = DateFormat(sameYear ? 'MMM d' : 'MMM d, yyyy').format(from);
  return '$datePart, $time';
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(accentColorProvider);
    final density = ref.watch(layoutDensityProvider);
    final coupleId = ref.watch(coupleIdProvider);
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final notificationsAsync = ref.watch(notificationsProvider);
    final notifications = notificationsAsync.valueOrNull ?? [];
    final unreadIds = notifications
        .where((n) => n.isUnreadFor(myUid))
        .map((n) => n.id)
        .toList();

    // Only the granter can act on a Wildcard request, and only while it's
    // still pending (it may have already been approved/declined from the
    // Wildcards page itself, in which case no buttons should show here).
    final isGranter = isWildcardGranter();
    final pendingWildcardById = <String, WildcardRequest>{
      if (isGranter)
        for (final r in ref.watch(wildcardRequestsProvider).valueOrNull ?? const <WildcardRequest>[])
          if (r.status == WildcardRequestStatus.pending) r.id: r,
    };

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
                            padding: EdgeInsets.fromLTRB(16 * density.factor,
                                8 * density.factor, 16 * density.factor, 32 * density.factor),
                            itemCount: notifications.length,
                            itemBuilder: (context, i) {
                              final n = notifications[i];
                              final unread = n.isUnreadFor(myUid);
                              final pendingRequest = n.type == 'wildcard_request' && n.refId != null
                                  ? pendingWildcardById[n.refId]
                                  : null;
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
                                  pendingWildcardRequest: pendingRequest,
                                  onAcceptWildcard: pendingRequest == null
                                      ? null
                                      : () {
                                          if (unread && coupleId != null) {
                                            ref
                                                .read(firestoreServiceProvider)
                                                .markNotificationRead(coupleId, n.id);
                                          }
                                          showGiveWildcardSheet(context, ref, forRequest: pendingRequest);
                                        },
                                  onDeclineWildcard: pendingRequest == null || coupleId == null
                                      ? null
                                      : () {
                                          HapticFeedback.selectionClick();
                                          if (unread) {
                                            ref
                                                .read(firestoreServiceProvider)
                                                .markNotificationRead(coupleId, n.id);
                                          }
                                          ref
                                              .read(firestoreServiceProvider)
                                              .respondToWildcardRequest(
                                                  coupleId, pendingRequest.id, WildcardRequestStatus.declined);
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
  // Non-null only for a still-pending Wildcard request, shown to the
  // granter — lets them accept/decline right here instead of having to
  // navigate to the Wildcards page first.
  final WildcardRequest? pendingWildcardRequest;
  final VoidCallback? onAcceptWildcard;
  final VoidCallback? onDeclineWildcard;

  const _NotificationTile({
    required this.notification,
    required this.unread,
    required this.accent,
    required this.onTap,
    this.pendingWildcardRequest,
    this.onAcceptWildcard,
    this.onDeclineWildcard,
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
                  Text(
                      '${_relativeTime(notification.createdAt)} · '
                      '${_absoluteTime(notification.createdAt)}',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11)),
                  if (pendingWildcardRequest != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: onDeclineWildcard,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: AppColors.bgCardLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.divider),
                              ),
                              alignment: Alignment.center,
                              child: const Text('Decline',
                                  style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: onAcceptWildcard,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: AppColors.rose,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: const Text('Accept',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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
