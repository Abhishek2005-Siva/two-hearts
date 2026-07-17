import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/delight/delight.dart';
import '../../core/firebase/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/cloudinary_service.dart';

String dailySnapDateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

const _milestones = [7, 30, 100, 365];

enum _EvolutionTier { none, flowers, lights, butterflies, tree }

_EvolutionTier _evolutionTier(int streak) {
  if (streak >= 365) return _EvolutionTier.tree;
  if (streak >= 100) return _EvolutionTier.butterflies;
  if (streak >= 30) return _EvolutionTier.lights;
  if (streak >= 7) return _EvolutionTier.flowers;
  return _EvolutionTier.none;
}

/// Shared "post today's snap" flow — used by the Daily Snap Calendar's own
/// CTA and by Chat's "Today's Snap" shared-activity card (see
/// chat_screen.dart). Shows a source picker, a caption/mood compose sheet,
/// uploads, and saves the entry. Surfaces upload state via the same
/// activity-status mechanism chat's presence header reads
/// ('uploading_snap'), so partner UI updates regardless of which screen
/// triggered the capture.
Future<bool> captureTodaysSnap(BuildContext context, WidgetRef ref) async {
  final coupleId = ref.read(coupleIdProvider);
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (coupleId == null || uid == null) return false;

  final source = await showDialog<ImageSource>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('📸 Today\'s snap',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18)),
      content: const Text('Capture the moment for today',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx, ImageSource.gallery),
          child: const Text('Gallery', style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx, ImageSource.camera),
          child: const Text('Camera',
              style: TextStyle(color: AppColors.rose, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  if (source == null || !context.mounted) return false;

  final picked = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1920,
    maxHeight: 1920,
    imageQuality: 85,
  );
  if (picked == null || !context.mounted) return false;

  final compose = await _showComposeSheet(context);
  if (compose == null || !context.mounted) return false;

  final firestoreService = ref.read(firestoreServiceProvider);
  firestoreService.setActivityStatus(coupleId, 'uploading_snap').ignore();
  try {
    final bytes = await File(picked.path).readAsBytes();
    final imageUrl = await CloudinaryService.uploadImage(bytes, folder: 'daily_snaps');
    final today = DateTime.now();
    await firestoreService.setDailySnapEntry(
      coupleId,
      dailySnapDateKey(today),
      uid,
      DailySnapEntry(imageUrl: imageUrl, caption: compose.$1, mood: compose.$2, createdAt: today),
    );
    if (context.mounted) {
      HapticFeedback.mediumImpact();
      FloatingStickers.burst(context, stickers: const ['✨', '❤️'], count: 5);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Today\'s snap saved ♡')),
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\'t save: $e')),
      );
    }
    return false;
  } finally {
    firestoreService.setActivityStatus(coupleId, null).ignore();
  }
}

Future<(String, MoodType?)?> _showComposeSheet(BuildContext context) {
  final ctrl = TextEditingController();
  MoodType? mood;
  return showModalBottomSheet<(String, MoodType?)>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetCtx) => StatefulBuilder(
      builder: (sheetCtx, setSheetState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          decoration: const BoxDecoration(
            color: AppColors.bgMid,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add a little context',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLength: 140,
                maxLines: 2,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Caption (optional)',
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.bgCardLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: MoodType.values.map((m) {
                  final selected = mood == m;
                  return GestureDetector(
                    onTap: () => setSheetState(() => mood = selected ? null : m),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? Color(int.parse(m.color.substring(1), radix: 16) | 0xFF000000)
                                .withValues(alpha: 0.25)
                            : AppColors.bgCardLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected
                              ? Color(int.parse(m.color.substring(1), radix: 16) | 0xFF000000)
                              : Colors.transparent,
                        ),
                      ),
                      child: Text('${m.emoji} ${m.label}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              GradientButton(
                label: 'Save today\'s memory',
                onTap: () => Navigator.pop(sheetCtx, (ctrl.text.trim(), mood)),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// A private shared calendar: one photo slot per partner per day, gradually
/// building a visual timeline of the relationship. Missed days/slots stay
/// empty — no fabricated streaks or backfilled entries, real counts only.
class DailySnapCalendarScreen extends ConsumerStatefulWidget {
  const DailySnapCalendarScreen({super.key});

  @override
  ConsumerState<DailySnapCalendarScreen> createState() => _DailySnapCalendarScreenState();
}

class _DailySnapCalendarScreenState extends ConsumerState<DailySnapCalendarScreen> {
  late DateTime _focusedMonth;
  bool _uploading = false;
  double _dragAccum = 0;
  bool _wasBothCompleteToday = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
  }

  void _shiftMonth(int delta) {
    HapticFeedback.selectionClick();
    setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta));
  }

  int _streak(Map<String, DailySnap> byDate) {
    bool bothPosted(DateTime d) {
      final snap = byDate[dailySnapDateKey(d)];
      return snap != null && snap.entries.length >= 2;
    }

    var day = DateTime.now();
    if (!bothPosted(day)) {
      day = day.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (bothPosted(day)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int? _nextMilestone(int streak) {
    for (final m in _milestones) {
      if (streak < m) return m;
    }
    return null;
  }

  Future<void> _captureToday() async {
    if (_uploading) return;
    setState(() => _uploading = true);
    await captureTodaysSnap(context, ref);
    if (mounted) setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    final snaps = ref.watch(dailySnapsProvider).valueOrNull ?? [];
    final byDate = {for (final s in snaps) s.dateKey: s};
    final streak = _streak(byDate);
    final nextMilestone = _nextMilestone(streak);
    final tier = _evolutionTier(streak);
    final todayKey = dailySnapDateKey(DateTime.now());
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final todaySnap = byDate[todayKey];
    final iPostedToday = myUid != null && (todaySnap?.entries.containsKey(myUid) ?? false);
    final bothPostedToday = (todaySnap?.entries.length ?? 0) >= 2;

    if (bothPostedToday && !_wasBothCompleteToday) {
      _wasBothCompleteToday = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          FloatingStickers.burst(context, stickers: const ['✨', '❤️', '🎉'], count: 6);
        }
      });
    } else if (!bothPostedToday) {
      _wasBothCompleteToday = false;
    }

    final totalMemories = snaps.fold<int>(0, (sum, s) => sum + s.entries.length);
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final daysCompletedThisMonth = List.generate(daysInMonth, (i) {
      final d = DateTime(_focusedMonth.year, _focusedMonth.month, i + 1);
      final snap = byDate[dailySnapDateKey(d)];
      return snap != null && snap.entries.length >= 2;
    }).where((v) => v).length;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: AppColors.bgGradient,
              ),
            ),
          ),
          const _CalendarAmbience(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: _EmotionalHeader(month: _focusedMonth, totalMemories: totalMemories),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _StreakBanner(streak: streak, nextMilestone: nextMilestone),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: GestureDetector(
                    onVerticalDragUpdate: (d) => _dragAccum += d.delta.dy,
                    onVerticalDragEnd: (d) {
                      if (_dragAccum.abs() > 40) {
                        _shiftMonth(_dragAccum < 0 ? 1 : -1);
                      }
                      _dragAccum = 0;
                    },
                    child: ClipRect(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          final isIncoming = child.key == ValueKey(_focusedMonth);
                          final offsetAnim = Tween<Offset>(
                            begin: isIncoming ? const Offset(0, 0.15) : Offset.zero,
                            end: isIncoming ? Offset.zero : const Offset(0, -0.15),
                          ).animate(animation);
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(position: offsetAnim, child: child),
                          );
                        },
                        layoutBuilder: (currentChild, previousChildren) => Stack(
                          alignment: Alignment.topCenter,
                          children: [...previousChildren, ?currentChild],
                        ),
                        child: _MonthGrid(
                          key: ValueKey(_focusedMonth),
                          focusedMonth: _focusedMonth,
                          byDate: byDate,
                          todayKey: todayKey,
                          myUid: myUid,
                          uploading: _uploading,
                          evolutionTier: tier,
                          onTapToday: _captureToday,
                          onTapDay: (dateKey) => context.push('/calendar/day/$dateKey'),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _ProgressReadout(
                    completed: daysCompletedThisMonth,
                    total: daysInMonth,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: _BottomCta(
                    uploading: _uploading,
                    iPostedToday: iPostedToday,
                    bothPostedToday: bothPostedToday,
                    onTap: _captureToday,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmotionalHeader extends StatelessWidget {
  final DateTime month;
  final int totalMemories;
  const _EmotionalHeader({required this.month, required this.totalMemories});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${DateFormat('MMMM yyyy').format(month)} ❤️',
                style: const TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
              ),
              Text(
                '$totalMemories Memor${totalMemories == 1 ? 'y' : 'ies'} Together',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StreakBanner extends StatelessWidget {
  final int streak;
  final int? nextMilestone;
  const _StreakBanner({required this.streak, required this.nextMilestone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.coral.withValues(alpha: 0.18),
          AppColors.gold.withValues(alpha: 0.10)
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.coral.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Text('🔥 $streak Day${streak == 1 ? '' : 's'} Streak',
              style: const TextStyle(
                  color: AppColors.gold, fontSize: 14, fontWeight: FontWeight.w800)),
          const Spacer(),
          if (nextMilestone != null)
            Text('Next milestone: $nextMilestone days',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

class _ProgressReadout extends StatelessWidget {
  final int completed;
  final int total;
  const _ProgressReadout({required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : completed / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$completed / $total Days Completed',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: AppColors.bgCardLight,
            valueColor: const AlwaysStoppedAnimation(AppColors.rose),
          ),
        ),
      ],
    );
  }
}

class _BottomCta extends StatelessWidget {
  final bool uploading;
  final bool iPostedToday;
  final bool bothPostedToday;
  final VoidCallback onTap;

  const _BottomCta({
    required this.uploading,
    required this.iPostedToday,
    required this.bothPostedToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (bothPostedToday) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.rose.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.rose.withValues(alpha: 0.3)),
        ),
        child: const Center(
          child: Text('Today\'s Memory Complete ❤️',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        ),
      );
    }
    if (iPostedToday) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bgCardLight,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(
          child: Text('Waiting for both of you…',
              style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        ),
      );
    }
    return GradientButton(
      label: uploading ? 'Saving…' : '📸 Post Today\'s Snap',
      loading: uploading,
      cuteStickers: const ['📸', '❤️'],
      onTap: onTap,
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime focusedMonth;
  final Map<String, DailySnap> byDate;
  final String todayKey;
  final String? myUid;
  final bool uploading;
  final _EvolutionTier evolutionTier;
  final VoidCallback onTapToday;
  final void Function(String dateKey) onTapDay;

  const _MonthGrid({
    super.key,
    required this.focusedMonth,
    required this.byDate,
    required this.todayKey,
    required this.myUid,
    required this.uploading,
    required this.evolutionTier,
    required this.onTapToday,
    required this.onTapDay,
  });

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final daysInMonth = DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final leadingBlanks = firstOfMonth.weekday % 7; // week starts Sunday
    final today = DateTime.now();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _EvolutionRing(tier: evolutionTier),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d,
                            style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemCount: leadingBlanks + daysInMonth,
            itemBuilder: (context, index) {
              if (index < leadingBlanks) return const SizedBox.shrink();
              final day = index - leadingBlanks + 1;
              final date = DateTime(focusedMonth.year, focusedMonth.month, day);
              final key = dailySnapDateKey(date);
              final snap = byDate[key];
              final isToday = key == todayKey;
              final isFuture = date.isAfter(DateTime(today.year, today.month, today.day));

              final tile = _DayTile(
                day: day,
                snap: snap,
                myUid: myUid,
                isToday: isToday,
                isFuture: isFuture,
                uploading: uploading && isToday,
              );

              return GestureDetector(
                onTap: isFuture
                    ? null
                    : (snap != null ? () => onTapDay(key) : (isToday ? onTapToday : null)),
                child: isToday ? _PulsingGlow(child: tile) : tile,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DayTile extends StatelessWidget {
  final int day;
  final DailySnap? snap;
  final String? myUid;
  final bool isToday;
  final bool isFuture;
  final bool uploading;

  const _DayTile({
    required this.day,
    required this.snap,
    required this.myUid,
    required this.isToday,
    required this.isFuture,
    required this.uploading,
  });

  @override
  Widget build(BuildContext context) {
    final myEntry = myUid != null ? snap?.entries[myUid] : null;
    final partnerEntry =
        snap?.entries.entries.where((e) => e.key != myUid).map((e) => e.value).firstOrNull;

    Widget half(DailySnapEntry? entry) {
      if (entry != null) {
        return Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(imageUrl: entry.imageUrl, fit: BoxFit.cover),
            if (entry.mood != null)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Color(
                          int.parse(entry.mood!.color.substring(1), radix: 16) | 0xFF000000),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        );
      }
      return Container(
        color: AppColors.bgCardLight,
        child: isFuture
            ? null
            : Icon(Icons.person_outline_rounded,
                color: AppColors.textMuted.withValues(alpha: 0.4), size: 12),
      );
    }

    return Opacity(
      opacity: isFuture ? 0.35 : 1,
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Row(
              children: [
                Expanded(child: half(myEntry)),
                Container(width: 1, color: Colors.black26),
                Expanded(child: half(partnerEntry)),
              ],
            ),
            if (uploading)
              const Center(
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else ...[
              Positioned(
                bottom: 2,
                right: 3,
                child: Text('$day',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        shadows: [Shadow(color: Colors.black87, blurRadius: 4)])),
              ),
              if (isFuture)
                const Positioned(
                  top: 2,
                  right: 2,
                  child: Icon(Icons.lock_outline_rounded, color: Colors.white54, size: 10),
                ),
              if (isToday && myEntry == null && !isFuture)
                const Positioned(
                  top: 2,
                  right: 2,
                  child: Icon(Icons.add_a_photo_rounded, color: AppColors.rose, size: 12),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Animated soft glow border for today's tile — a repeating BoxShadow pulse,
/// same "own AnimationController per small widget" idiom used elsewhere in
/// this app (e.g. room_screen's twinkle/paw-walk controllers).
class _PulsingGlow extends StatefulWidget {
  final Widget child;
  const _PulsingGlow({required this.child});

  @override
  State<_PulsingGlow> createState() => _PulsingGlowState();
}

class _PulsingGlowState extends State<_PulsingGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _ctrl.value;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: AppColors.rose.withValues(alpha: 0.35 + t * 0.25),
                blurRadius: 6 + t * 8,
                spreadRadius: 1 + t * 1.5,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Themed decorative ring above the grid — grows richer as the streak
/// grows. Emoji/gradient decoration, not illustrated artwork (no
/// image-gen tool available here).
class _EvolutionRing extends StatelessWidget {
  final _EvolutionTier tier;
  const _EvolutionRing({required this.tier});

  @override
  Widget build(BuildContext context) {
    if (tier == _EvolutionTier.none) return const SizedBox.shrink();
    final emoji = switch (tier) {
      _EvolutionTier.flowers => '🌸',
      _EvolutionTier.lights => '🎇',
      _EvolutionTier.butterflies => '🦋',
      _EvolutionTier.tree => '🌳',
      _EvolutionTier.none => '',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(7, (i) => Text(emoji, style: const TextStyle(fontSize: 14)))
            .expand((w) => [w, const SizedBox(width: 6)])
            .toList(),
      ),
    );
  }
}

/// Extremely subtle drifting stars/hearts — same drift-flake technique as
/// SeasonalDrift (core/delight/delight.dart) but with its own emoji set
/// and much lower opacity, since SeasonalDrift is real-world-season-themed
/// and already used louder elsewhere.
class _CalendarAmbience extends StatefulWidget {
  const _CalendarAmbience();

  @override
  State<_CalendarAmbience> createState() => _CalendarAmbienceState();
}

class _AmbienceFlake {
  final String emoji;
  final double x;
  final double phase;
  final double speed;
  final double sway;
  final double size;
  _AmbienceFlake({
    required this.emoji,
    required this.x,
    required this.phase,
    required this.speed,
    required this.sway,
    required this.size,
  });
}

class _CalendarAmbienceState extends State<_CalendarAmbience> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_AmbienceFlake> _flakes;
  static const _emojis = ['✨', '♡', '💫'];

  @override
  void initState() {
    super.initState();
    final rng = math.Random();
    _flakes = List.generate(5, (i) {
      return _AmbienceFlake(
        emoji: _emojis[i % _emojis.length],
        x: rng.nextDouble(),
        phase: rng.nextDouble(),
        speed: 0.4 + rng.nextDouble() * 0.4,
        sway: 10 + rng.nextDouble() * 14,
        size: 10.0 + rng.nextDouble() * 6,
      );
    });
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 28))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) {
          return Stack(
            children: _flakes.map((f) {
              final t = (_ctrl.value * f.speed + f.phase) % 1.0;
              final y = t * (size.height + 60) - 40;
              final x = f.x * size.width + math.sin(t * 6 * math.pi + f.phase * 10) * f.sway;
              return Positioned(
                left: x,
                top: y,
                child: Opacity(
                  opacity: 0.12,
                  child: Text(f.emoji, style: TextStyle(fontSize: f.size, color: Colors.white)),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
