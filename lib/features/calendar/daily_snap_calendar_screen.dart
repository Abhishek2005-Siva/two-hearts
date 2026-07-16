import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/firebase/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/cloudinary_service.dart';

String _dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// A private shared calendar: one photo per day, gradually building a
/// visual timeline of the relationship. Missed days stay empty — no
/// fabricated streaks or backfilled entries, real counts only.
class DailySnapCalendarScreen extends ConsumerStatefulWidget {
  const DailySnapCalendarScreen({super.key});

  @override
  ConsumerState<DailySnapCalendarScreen> createState() => _DailySnapCalendarScreenState();
}

class _DailySnapCalendarScreenState extends ConsumerState<DailySnapCalendarScreen> {
  late DateTime _focusedMonth;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
  }

  void _shiftMonth(int delta) {
    setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta));
  }

  int _streak(Map<String, DailySnap> byDate) {
    var day = DateTime.now();
    if (!byDate.containsKey(_dateKey(day))) {
      day = day.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (byDate.containsKey(_dateKey(day))) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Future<void> _captureToday() async {
    final coupleId = ref.read(coupleIdProvider);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (coupleId == null || uid == null || _uploading) return;

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
    if (source == null) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final bytes = await File(picked.path).readAsBytes();
      final imageUrl = await CloudinaryService.uploadImage(bytes, folder: 'daily_snaps');
      final today = DateTime.now();
      await ref.read(firestoreServiceProvider).setDailySnap(
            coupleId,
            DailySnap(
              dateKey: _dateKey(today),
              imageUrl: imageUrl,
              uploaderUid: uid,
              createdAt: today,
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Today\'s snap saved ♡')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn\'t save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _openSnap(DailySnap snap) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CachedNetworkImage(
                imageUrl: snap.imageUrl,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              DateFormat('EEEE, MMM d, yyyy').format(DateTime.parse(snap.dateKey)),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snaps = ref.watch(dailySnapsProvider).valueOrNull ?? [];
    final byDate = {for (final s in snaps) s.dateKey: s};
    final streak = _streak(byDate);
    final todayKey = _dateKey(DateTime.now());
    final hasToday = byDate.containsKey(todayKey);

    final firstOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final leadingBlanks = firstOfMonth.weekday % 7; // week starts Sunday

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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    const Text('Daily Snap Calendar',
                        style: TextStyle(
                            color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    if (streak > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.coral.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text('🔥 $streak day${streak == 1 ? '' : 's'}',
                            style: const TextStyle(
                                color: AppColors.gold,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
                      onPressed: () => _shiftMonth(-1),
                    ),
                    SizedBox(
                      width: 160,
                      child: Text(
                        DateFormat('MMMM yyyy').format(_focusedMonth),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
                      onPressed: () => _shiftMonth(1),
                    ),
                  ],
                ),
              ),
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
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                    ),
                    itemCount: leadingBlanks + daysInMonth,
                    itemBuilder: (context, index) {
                      if (index < leadingBlanks) return const SizedBox.shrink();
                      final day = index - leadingBlanks + 1;
                      final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
                      final key = _dateKey(date);
                      final snap = byDate[key];
                      final isToday = key == todayKey;

                      return GestureDetector(
                        onTap: snap != null
                            ? () => _openSnap(snap)
                            : (isToday ? _captureToday : null),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: isToday
                                ? Border.all(color: AppColors.rose, width: 1.5)
                                : null,
                            color: snap == null ? AppColors.bgCardLight : null,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (snap != null)
                                CachedNetworkImage(
                                  imageUrl: snap.imageUrl,
                                  fit: BoxFit.cover,
                                ),
                              if (snap == null)
                                Center(
                                  child: isToday && _uploading
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : Text('$day',
                                          style: TextStyle(
                                              color: isToday
                                                  ? AppColors.rose
                                                  : AppColors.textMuted,
                                              fontSize: 12)),
                                ),
                              if (snap != null)
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
                              if (isToday && snap == null)
                                const Positioned(
                                  top: 2,
                                  right: 2,
                                  child: Icon(Icons.add_a_photo_rounded,
                                      color: AppColors.rose, size: 12),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  hasToday
                      ? 'Today\'s snap is saved ♡ (${snaps.length} total)'
                      : 'No snap for today yet — tap the highlighted day (${snaps.length} total)',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
