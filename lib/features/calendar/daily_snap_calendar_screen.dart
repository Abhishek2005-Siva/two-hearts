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

import '../../core/firebase/models.dart';
import '../../core/providers/providers.dart';
import '../../core/utils/cloudinary_service.dart';
import '../room/room_screen.dart' show sendHomeGiftDialog;

String dailySnapDateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

const _milestones = [7, 30, 100, 365];

/// Light, cream/pastel palette — scoped to this screen only (the rest of
/// the app uses the dark romantic AppColors palette; Calendar deliberately
/// breaks from it per an explicit reference-image request).
class _Cal {
  static const bgTop = Color(0xFFFCEFEA);
  static const bgBottom = Color(0xFFFBF5F0);
  static const card = Color(0xFFFFFFFF);
  static const emptyTile = Color(0xFFF3E8E2);
  static const textDark = Color(0xFF3D2B24);
  static const textMuted = Color(0xFFAE9086);
  static const heart = Color(0xFFE0687A);
  static const ctaDark = Color(0xFF241A17);
}

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
      backgroundColor: _Cal.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('📸 Today\'s snap',
          style: TextStyle(color: _Cal.textDark, fontSize: 18)),
      content: const Text('Capture the moment for today',
          style: TextStyle(color: _Cal.textMuted, fontSize: 13)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx),
          child: const Text('Cancel', style: TextStyle(color: _Cal.textMuted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx, ImageSource.gallery),
          child: const Text('Gallery', style: TextStyle(color: _Cal.textDark)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx, ImageSource.camera),
          child: const Text('Camera',
              style: TextStyle(color: _Cal.heart, fontWeight: FontWeight.w700)),
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
            color: _Cal.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add a little context',
                  style: TextStyle(color: _Cal.textDark, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLength: 140,
                maxLines: 2,
                style: const TextStyle(color: _Cal.textDark, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Caption (optional)',
                  hintStyle: const TextStyle(color: _Cal.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: _Cal.emptyTile,
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
                  final moodColor = Color(int.parse(m.color.substring(1), radix: 16) | 0xFF000000);
                  return GestureDetector(
                    onTap: () => setSheetState(() => mood = selected ? null : m),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? moodColor.withValues(alpha: 0.20) : _Cal.emptyTile,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: selected ? moodColor : Colors.transparent),
                      ),
                      child: Text('${m.emoji} ${m.label}',
                          style: const TextStyle(color: _Cal.textDark, fontSize: 12)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _Cal.ctaDark,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(sheetCtx, (ctrl.text.trim(), mood)),
                  child: const Text('Save today\'s memory'),
                ),
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
/// Months scroll continuously (one long list, Monday-first weeks) rather
/// than paging one month at a time — matches the reference design.
class DailySnapCalendarScreen extends ConsumerStatefulWidget {
  const DailySnapCalendarScreen({super.key});

  @override
  ConsumerState<DailySnapCalendarScreen> createState() => _DailySnapCalendarScreenState();
}

class _DailySnapCalendarScreenState extends ConsumerState<DailySnapCalendarScreen> {
  bool _uploading = false;
  bool _wasBothCompleteToday = false;
  final _scrollController = ScrollController();
  final Map<DateTime, GlobalKey> _monthKeys = {};
  bool _didJumpToCurrentMonth = false;

  late final List<DateTime> _months;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final current = DateTime(now.year, now.month);
    // A bounded 12-months-back window, ascending (oldest at top) — real
    // continuous scroll without needing true infinite pagination.
    _months = List.generate(12, (i) => DateTime(current.year, current.month - 11 + i));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(DateTime month) => _monthKeys.putIfAbsent(month, () => GlobalKey());

  void _jumpToCurrentMonthOnce() {
    if (_didJumpToCurrentMonth) return;
    final now = DateTime.now();
    final key = _monthKeys[DateTime(now.year, now.month)];
    if (key?.currentContext == null) return;
    _didJumpToCurrentMonth = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key!.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, alignment: 0, duration: const Duration(milliseconds: 1));
      }
    });
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
    } else if (!bothPostedToday) {
      _wasBothCompleteToday = false;
    }

    final totalMemories = snaps.fold<int>(0, (sum, s) => sum + s.entries.length);
    final now = DateTime.now();
    final daysInCurrentMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysCompletedThisMonth = List.generate(daysInCurrentMonth, (i) {
      final d = DateTime(now.year, now.month, i + 1);
      final snap = byDate[dailySnapDateKey(d)];
      return snap != null && snap.entries.length >= 2;
    }).where((v) => v).length;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_Cal.bgTop, _Cal.bgBottom],
          ),
        ),
        child: Stack(
          children: [
            const _CalendarAmbience(),
            SafeArea(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Our Calendar 💕',
                              style: TextStyle(
                                  color: _Cal.textDark,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text('$totalMemories Memor${totalMemories == 1 ? 'y' : 'ies'} Together',
                        style: const TextStyle(color: _Cal.textMuted, fontSize: 12)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                          .map((d) => Expanded(
                                child: Center(
                                  child: Text(d,
                                      style: const TextStyle(
                                          color: _Cal.textMuted,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _months.length,
                      itemBuilder: (context, i) {
                        final month = _months[i];
                        if (month.year == now.year && month.month == now.month) {
                          _jumpToCurrentMonthOnce();
                        }
                        return KeyedSubtree(
                          key: _keyFor(month),
                          child: _MonthBlock(
                            month: month,
                            byDate: byDate,
                            todayKey: todayKey,
                            myUid: myUid,
                            uploading: _uploading,
                            evolutionTier:
                                (month.year == now.year && month.month == now.month) ? tier : _EvolutionTier.none,
                            onTapToday: _captureToday,
                            onTapDay: (dateKey) => context.push('/calendar/day/$dateKey'),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: _StreakBanner(
                        streak: streak, nextMilestone: nextMilestone, bothPostedToday: bothPostedToday),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _ProgressReadout(
                      completed: daysCompletedThisMonth,
                      total: daysInCurrentMonth,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _BottomCta(
                            uploading: _uploading,
                            iPostedToday: iPostedToday,
                            bothPostedToday: bothPostedToday,
                            onTap: _captureToday,
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () => sendHomeGiftDialog(context, ref),
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: _Cal.card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _Cal.emptyTile),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.card_giftcard_rounded, color: _Cal.heart, size: 18),
                                SizedBox(height: 2),
                                Text('Surprise',
                                    style: TextStyle(color: _Cal.textMuted, fontSize: 9)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakBanner extends StatelessWidget {
  final int streak;
  final int? nextMilestone;
  final bool bothPostedToday;
  const _StreakBanner(
      {required this.streak, required this.nextMilestone, required this.bothPostedToday});

  @override
  Widget build(BuildContext context) {
    if (streak == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _Cal.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.favorite_rounded, color: _Cal.heart, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bothPostedToday ? 'You both posted today! ✨' : 'Keep it going ✨',
                  style: const TextStyle(
                      color: _Cal.textDark, fontSize: 13, fontWeight: FontWeight.w700),
                ),
                Text(
                  nextMilestone != null ? 'Next milestone: $nextMilestone days' : 'Keep the streak going',
                  style: const TextStyle(color: _Cal.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Text('$streak days',
              style: const TextStyle(color: _Cal.heart, fontSize: 14, fontWeight: FontWeight.w800)),
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
            style: const TextStyle(color: _Cal.textMuted, fontSize: 12)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: _Cal.emptyTile,
            valueColor: const AlwaysStoppedAnimation(_Cal.heart),
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
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _Cal.card,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(
          child: Text('Today\'s Memory Complete ❤️',
              style: TextStyle(color: _Cal.textDark, fontWeight: FontWeight.w700)),
        ),
      );
    }
    if (iPostedToday) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _Cal.emptyTile,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(
          child: Text('Waiting for both of you…',
              style: TextStyle(color: _Cal.textMuted, fontWeight: FontWeight.w600)),
        ),
      );
    }
    return GestureDetector(
      onTap: uploading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _Cal.ctaDark,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: uploading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Post Today\'s Snap',
                            style: TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                        Text('Just for each other',
                            style: TextStyle(color: Colors.white70, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _MonthBlock extends StatelessWidget {
  final DateTime month;
  final Map<String, DailySnap> byDate;
  final String todayKey;
  final String? myUid;
  final bool uploading;
  final _EvolutionTier evolutionTier;
  final VoidCallback onTapToday;
  final void Function(String dateKey) onTapDay;

  const _MonthBlock({
    required this.month,
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
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = (firstOfMonth.weekday - 1) % 7; // Monday-first
    final today = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
          child: Text(DateFormat('MMMM yyyy').format(month),
              style: const TextStyle(
                  color: _Cal.textDark, fontSize: 15, fontWeight: FontWeight.w700)),
        ),
        _EvolutionRing(tier: evolutionTier),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemCount: leadingBlanks + daysInMonth,
          itemBuilder: (context, index) {
            if (index < leadingBlanks) return const SizedBox.shrink();
            final day = index - leadingBlanks + 1;
            final date = DateTime(month.year, month.month, day);
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
    final hasAnyEntry = myEntry != null || partnerEntry != null;

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
      return Container(color: _Cal.emptyTile);
    }

    return Opacity(
      opacity: isFuture ? 0.45 : 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: _Cal.emptyTile,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasAnyEntry)
              Row(
                children: [
                  Expanded(child: half(myEntry)),
                  Container(width: 1, color: Colors.white54),
                  Expanded(child: half(partnerEntry)),
                ],
              ),
            if (uploading)
              const Center(
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _Cal.heart),
                ),
              )
            else ...[
              Positioned(
                top: 4,
                left: 5,
                child: Text('$day',
                    style: TextStyle(
                        color: hasAnyEntry ? Colors.white : _Cal.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        shadows: hasAnyEntry
                            ? const [Shadow(color: Colors.black87, blurRadius: 4)]
                            : null)),
              ),
              if (hasAnyEntry)
                Positioned(
                  bottom: 3,
                  right: 3,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.favorite_rounded, color: _Cal.heart, size: 10),
                  ),
                ),
              if (isFuture)
                const Positioned(
                  top: 4,
                  right: 4,
                  child: Icon(Icons.lock_outline_rounded, color: _Cal.textMuted, size: 11),
                ),
              if (isToday && myEntry == null && !isFuture)
                const Positioned(
                  bottom: 3,
                  right: 3,
                  child: Icon(Icons.add_a_photo_rounded, color: _Cal.heart, size: 13),
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
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _Cal.heart.withValues(alpha: 0.35 + t * 0.25),
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

/// Themed decorative ring above the current month's grid — grows richer as
/// the streak grows. Emoji decoration, not illustrated artwork (no
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
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(7, (i) => Text(emoji, style: const TextStyle(fontSize: 14)))
            .expand((w) => [w, const SizedBox(width: 6)])
            .toList(),
      ),
    );
  }
}

/// Extremely subtle drifting stars/clouds — same drift-flake technique as
/// SeasonalDrift (core/delight/delight.dart) but with its own emoji set,
/// tuned for this screen's light background.
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
  static const _emojis = ['✨', '☁️', '💫'];

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
        size: 12.0 + rng.nextDouble() * 8,
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
                  opacity: 0.18,
                  child: Text(f.emoji, style: TextStyle(fontSize: f.size)),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
