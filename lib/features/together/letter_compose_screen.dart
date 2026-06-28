import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart' show CupertinoDatePicker, CupertinoDatePickerMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/firebase/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

enum _UnlockMode { tomorrow, nextWeek, openWhenSad, myBirthday, partnerBirthday, anniversary, custom }

class LetterComposeScreen extends ConsumerStatefulWidget {
  const LetterComposeScreen({super.key});

  @override
  ConsumerState<LetterComposeScreen> createState() => _LetterComposeScreenState();
}

class _LetterComposeScreenState extends ConsumerState<LetterComposeScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  _UnlockMode _mode = _UnlockMode.tomorrow;
  DateTime? _customDate;
  TimeOfDay _customTime = const TimeOfDay(hour: 8, minute: 0);
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  DateTime? _resolveUnlockAt({
    required DateTime? myBirthday,
    required DateTime? partnerBirthday,
    required DateTime? anniversary,
  }) {
    final now = DateTime.now();
    switch (_mode) {
      case _UnlockMode.tomorrow:
        return DateTime(now.year, now.month, now.day + 1, 8, 0);
      case _UnlockMode.nextWeek:
        return now.add(const Duration(days: 7));
      case _UnlockMode.openWhenSad:
        return null;
      case _UnlockMode.myBirthday:
        return myBirthday != null ? _nextOccurrence(myBirthday) : null;
      case _UnlockMode.partnerBirthday:
        return partnerBirthday != null ? _nextOccurrence(partnerBirthday) : null;
      case _UnlockMode.anniversary:
        return anniversary != null ? _nextOccurrence(anniversary) : null;
      case _UnlockMode.custom:
        if (_customDate == null) return null;
        return DateTime(
          _customDate!.year, _customDate!.month, _customDate!.day,
          _customTime.hour, _customTime.minute,
        );
    }
  }

  DateTime _nextOccurrence(DateTime date) {
    final now = DateTime.now();
    var next = DateTime(now.year, date.month, date.day, 8, 0);
    if (!next.isAfter(now)) next = DateTime(now.year + 1, date.month, date.day, 8, 0);
    return next;
  }

  Future<void> _pickDateAndTime() async {
    final accent = ref.read(accentColorProvider);
    var picked = _customDate != null
        ? DateTime(
            _customDate!.year, _customDate!.month, _customDate!.day,
            _customTime.hour, _customTime.minute)
        : DateTime.now().add(const Duration(days: 1, hours: 1)).copyWith(
            minute: 0, second: 0, millisecond: 0, microsecond: 0);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => _DateWheelSheet(
        initial: picked,
        accent: accent,
        onConfirm: (dt) {
          setState(() {
            _customDate = DateTime(dt.year, dt.month, dt.day);
            _customTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
            _mode = _UnlockMode.custom;
          });
        },
      ),
    );
  }

  Future<void> _send() async {
    final titleText = _title.text.trim();
    final bodyText = _body.text.trim();
    if (titleText.isEmpty || bodyText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please add a subject and write something ♡'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (_mode == _UnlockMode.custom && _customDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please pick a date for the letter to unlock'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final coupleId = ref.read(coupleIdProvider);
    final authUser = FirebaseAuth.instance.currentUser;
    if (coupleId == null || authUser == null) return;

    final me = ref.read(currentUserProvider).valueOrNull;
    final partner = ref.read(partnerUserProvider).valueOrNull;
    final couple = ref.read(coupleProvider).valueOrNull;

    final unlockAt = _resolveUnlockAt(
      myBirthday: me?.birthday,
      partnerBirthday: partner?.birthday,
      anniversary: couple?.anniversary,
    );

    setState(() => _sending = true);
    try {
      await ref.read(firestoreServiceProvider).sendLetter(
        coupleId,
        LetterModel(
          id: const Uuid().v4(),
          authorId: authUser.uid,
          receiverId: partner?.uid,
          title: titleText,
          body: bodyText,
          unlockType: _modeToLetterType(_mode),
          unlockAt: unlockAt,
          createdAt: DateTime.now(),
        ),
      );
      if (mounted) context.go('/together');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  LetterUnlockType _modeToLetterType(_UnlockMode mode) {
    switch (mode) {
      case _UnlockMode.tomorrow: return LetterUnlockType.tomorrow;
      case _UnlockMode.nextWeek: return LetterUnlockType.custom;
      case _UnlockMode.openWhenSad: return LetterUnlockType.openWhenSad;
      case _UnlockMode.myBirthday: return LetterUnlockType.birthday;
      case _UnlockMode.partnerBirthday: return LetterUnlockType.birthday;
      case _UnlockMode.anniversary: return LetterUnlockType.anniversary;
      case _UnlockMode.custom: return LetterUnlockType.custom;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(accentColorProvider);
    final me = ref.watch(currentUserProvider).valueOrNull;
    final partner = ref.watch(partnerUserProvider).valueOrNull;
    final couple = ref.watch(coupleProvider).valueOrNull;

    final myBirthday = me?.birthday;
    final partnerBirthday = partner?.birthday;
    final anniversary = couple?.anniversary;
    final partnerFirstName = partner?.displayName.split(' ').first ?? 'Partner';

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
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppColors.textPrimary),
                      onPressed: () => context.go('/together'),
                    ),
                    const Expanded(
                      child: Text('Write a Letter',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
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
                                child: const Text('Send',
                                    style: TextStyle(color: Colors.white,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subject field
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.bgCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider, width: 0.5),
                        ),
                        child: TextField(
                          controller: _title,
                          style: const TextStyle(color: AppColors.textPrimary,
                              fontSize: 18, fontWeight: FontWeight.w600),
                          decoration: const InputDecoration(
                            hintText: 'Subject…',
                            hintStyle: TextStyle(color: AppColors.textMuted),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(18),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── UNLOCK SECTION ──────────────────────────────────
                      const Text('OPEN THIS LETTER…',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                              color: AppColors.textMuted, letterSpacing: 1.5)),
                      const SizedBox(height: 12),

                      // Quick picks row
                      _UnlockChip(
                        emoji: '🌅',
                        label: 'Tomorrow',
                        selected: _mode == _UnlockMode.tomorrow,
                        accent: accent,
                        onTap: () => setState(() { _mode = _UnlockMode.tomorrow; _customDate = null; }),
                      ),
                      const SizedBox(height: 8),
                      _UnlockChip(
                        emoji: '📆',
                        label: 'Next Week',
                        selected: _mode == _UnlockMode.nextWeek,
                        accent: accent,
                        onTap: () => setState(() { _mode = _UnlockMode.nextWeek; _customDate = null; }),
                      ),
                      const SizedBox(height: 8),
                      _UnlockChip(
                        emoji: '💙',
                        label: 'Open When Sad',
                        subtitle: 'Unlocks any time',
                        selected: _mode == _UnlockMode.openWhenSad,
                        accent: accent,
                        onTap: () => setState(() { _mode = _UnlockMode.openWhenSad; _customDate = null; }),
                      ),

                      // Special dates (show only if data available)
                      if (myBirthday != null || partnerBirthday != null || anniversary != null) ...[
                        const SizedBox(height: 14),
                        const Text('SPECIAL DATES',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                                color: AppColors.textMuted, letterSpacing: 1.5)),
                        const SizedBox(height: 10),
                      ],
                      if (myBirthday != null) ...[
                        _UnlockChip(
                          emoji: '🎂',
                          label: 'My Birthday',
                          subtitle: '${_monthShort(myBirthday.month)} ${myBirthday.day} '
                              '— ${_daysUntil(_nextOccurrence(myBirthday))}',
                          selected: _mode == _UnlockMode.myBirthday,
                          accent: accent,
                          onTap: () => setState(() { _mode = _UnlockMode.myBirthday; _customDate = null; }),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (partnerBirthday != null) ...[
                        _UnlockChip(
                          emoji: '🎁',
                          label: '$partnerFirstName\'s Birthday',
                          subtitle: '${_monthShort(partnerBirthday.month)} ${partnerBirthday.day} '
                              '— ${_daysUntil(_nextOccurrence(partnerBirthday))}',
                          selected: _mode == _UnlockMode.partnerBirthday,
                          accent: accent,
                          onTap: () => setState(() { _mode = _UnlockMode.partnerBirthday; _customDate = null; }),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (anniversary != null) ...[
                        _UnlockChip(
                          emoji: '💑',
                          label: 'Our Anniversary',
                          subtitle: '${_monthShort(anniversary.month)} ${anniversary.day} '
                              '— ${_daysUntil(_nextOccurrence(anniversary))}',
                          selected: _mode == _UnlockMode.anniversary,
                          accent: accent,
                          onTap: () => setState(() { _mode = _UnlockMode.anniversary; _customDate = null; }),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Tip if birthdays not set
                      if (myBirthday == null && partnerBirthday == null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.bgCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.divider, width: 0.5),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded,
                                  color: AppColors.textMuted, size: 16),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Set birthdays in You & Me → Your Profile to unlock birthday letters',
                                  style: const TextStyle(fontSize: 12,
                                      color: AppColors.textMuted, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Custom date picker
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _pickDateAndTime,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: _mode == _UnlockMode.custom
                                ? LinearGradient(colors: [
                                    accent.withValues(alpha: 0.2),
                                    AppColors.coral.withValues(alpha: 0.12),
                                  ])
                                : null,
                            color: _mode == _UnlockMode.custom ? null : AppColors.bgCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _mode == _UnlockMode.custom
                                  ? accent.withValues(alpha: 0.5)
                                  : AppColors.divider,
                              width: _mode == _UnlockMode.custom ? 1.5 : 0.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.calendar_month_outlined,
                                    color: accent, size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _mode == _UnlockMode.custom && _customDate != null
                                          ? _formatDateTime(_customDate!, _customTime)
                                          : 'Pick a specific date & time',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: _mode == _UnlockMode.custom
                                            ? FontWeight.w600 : FontWeight.normal,
                                        color: _mode == _UnlockMode.custom
                                            ? AppColors.textPrimary : AppColors.textSecondary,
                                      ),
                                    ),
                                    if (_mode != _UnlockMode.custom || _customDate == null)
                                      const Text('Choose any date and time',
                                          style: TextStyle(fontSize: 11,
                                              color: AppColors.textMuted)),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: _mode == _UnlockMode.custom ? accent : AppColors.textMuted,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Unlock date preview card
                      if (_mode != _UnlockMode.openWhenSad && _mode != _UnlockMode.custom) ...[
                        const SizedBox(height: 12),
                        _UnlockPreview(
                          mode: _mode,
                          date: _resolveUnlockAt(
                            myBirthday: me?.birthday,
                            partnerBirthday: partner?.birthday,
                            anniversary: couple?.anniversary,
                          ),
                          accent: accent,
                        ),
                      ],
                      if (_mode == _UnlockMode.custom && _customDate != null) ...[
                        const SizedBox(height: 12),
                        _UnlockPreview(
                          mode: _mode,
                          date: _resolveUnlockAt(
                            myBirthday: me?.birthday,
                            partnerBirthday: partner?.birthday,
                            anniversary: couple?.anniversary,
                          ),
                          accent: accent,
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Body field
                      Container(
                        constraints: BoxConstraints(
                          minHeight: MediaQuery.of(context).size.height * 0.3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.bgCard,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.divider, width: 0.5),
                        ),
                        child: TextField(
                          controller: _body,
                          maxLines: null,
                          style: const TextStyle(color: AppColors.textPrimary,
                              fontSize: 16, height: 1.8),
                          decoration: const InputDecoration(
                            hintText: 'Dear love,\n\nI wanted to tell you…',
                            hintStyle: TextStyle(color: AppColors.textMuted, height: 1.8),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(20),
                          ),
                        ),
                      ),
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

// ── Unlock Chip ───────────────────────────────────────────────────────────

class _UnlockChip extends StatelessWidget {
  final String emoji;
  final String label;
  final String? subtitle;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _UnlockChip({
    required this.emoji,
    required this.label,
    this.subtitle,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(colors: [accent.withValues(alpha: 0.2),
                  AppColors.coral.withValues(alpha: 0.12)])
              : null,
          color: selected ? null : AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? accent.withValues(alpha: 0.6) : AppColors.divider,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                      )),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: TextStyle(fontSize: 11,
                            color: selected ? accent : AppColors.textMuted)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: accent, size: 18)
            else
              Icon(Icons.radio_button_unchecked_rounded,
                  color: AppColors.divider, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Unlock Preview ────────────────────────────────────────────────────────

class _UnlockPreview extends StatelessWidget {
  final _UnlockMode mode;
  final DateTime? date;
  final Color accent;

  const _UnlockPreview({required this.mode, required this.date, required this.accent});

  @override
  Widget build(BuildContext context) {
    if (date == null) return const SizedBox.shrink();
    final daysAway = date!.difference(DateTime.now()).inDays;
    final daysText = daysAway == 0
        ? 'today'
        : daysAway == 1
            ? 'tomorrow'
            : 'in $daysAway days';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_clock_outlined, color: accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Unlocks ${_formatDateTime(date!, null)} ($daysText)',
              style: TextStyle(fontSize: 12, color: accent, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────

String _formatDateTime(DateTime date, TimeOfDay? time) {
  final months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final t = time ?? TimeOfDay(hour: date.hour, minute: date.minute);
  final h = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
  final m = t.minute.toString().padLeft(2, '0');
  final amPm = t.hour < 12 ? 'AM' : 'PM';
  return '${months[date.month]} ${date.day}, ${date.year} at $h:$m $amPm';
}

String _monthShort(int month) {
  const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return months[month];
}

String _daysUntil(DateTime date) {
  final days = date.difference(DateTime.now()).inDays;
  if (days == 0) return 'today';
  if (days == 1) return 'tomorrow';
  if (days < 30) return 'in $days days';
  final months = (days / 30).round();
  return 'in $months month${months > 1 ? 's' : ''}';
}

// ── Date & Time Wheel Sheet ────────────────────────────────────────────────

class _DateWheelSheet extends StatefulWidget {
  final DateTime initial;
  final Color accent;
  final void Function(DateTime) onConfirm;

  const _DateWheelSheet({
    required this.initial,
    required this.accent,
    required this.onConfirm,
  });

  @override
  State<_DateWheelSheet> createState() => _DateWheelSheetState();
}

class _DateWheelSheetState extends State<_DateWheelSheet> {
  late DateTime _picked;

  @override
  void initState() {
    super.initState();
    _picked = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF12090F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 16, 24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Row(
            children: [
              Icon(Icons.lock_clock_outlined, color: accent, size: 20),
              const SizedBox(width: 10),
              Text(
                'When can they open it?',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Spin the wheels to set the unlock date & time',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 20),

          // Wheel picker in a frosted card
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider, width: 0.5),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Selection highlight band
                Center(
                  child: Container(
                    height: 44,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accent.withValues(alpha: 0.15),
                          AppColors.coral.withValues(alpha: 0.10),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                  ),
                ),

                // Top + bottom fade overlays
                Positioned(
                  top: 0, left: 0, right: 0, height: 56,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF12090F),
                          const Color(0xFF12090F).withValues(alpha: 0),
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20)),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0, left: 0, right: 0, height: 56,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          const Color(0xFF12090F),
                          const Color(0xFF12090F).withValues(alpha: 0),
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(20)),
                    ),
                  ),
                ),

                // The CupertinoDatePicker
                CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.dateAndTime,
                  initialDateTime: _picked,
                  minimumDate: DateTime.now(),
                  maximumDate: DateTime(2100),
                  use24hFormat: false,
                  itemExtent: 44,
                  onDateTimeChanged: (dt) => setState(() => _picked = dt),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Confirm button
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              widget.onConfirm(_picked);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [accent, AppColors.coral]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Text(
                'Set Unlock Date',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
