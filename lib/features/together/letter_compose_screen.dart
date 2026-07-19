import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../core/firebase/models.dart';
import '../../core/presence/activity_announcer.dart';
import '../../core/models/content_block.dart';
import '../../core/delight/delight.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/rich_content_editor.dart';

enum _UnlockMode { tomorrow, nextWeek, openWhen, myBirthday, partnerBirthday, anniversary, custom }

// Emotions for "Open When…"
const _openWhenEmotions = [
  ('😢', 'Sad'),
  ('😊', 'Happy'),
  ('😤', 'Angry'),
  ('😰', 'Anxious'),
  ('💔', 'Lonely'),
  ('🥺', 'Missing You'),
  ('🌟', 'Proud'),
  ('😨', 'Scared'),
  ('😵', 'Overwhelmed'),
  ('💌', 'Any time'),
];

class LetterComposeScreen extends ConsumerStatefulWidget {
  const LetterComposeScreen({super.key});

  @override
  ConsumerState<LetterComposeScreen> createState() => _LetterComposeScreenState();
}

class _LetterComposeScreenState extends ConsumerState<LetterComposeScreen>
    with ActivityAnnouncer {
  final _title = TextEditingController();
  List<ContentBlock> _blocks = [ContentBlock.newText()];
  _UnlockMode _mode = _UnlockMode.tomorrow;
  DateTime? _customDate;
  TimeOfDay _customTime = const TimeOfDay(hour: 8, minute: 0);
  String _openWhenEmotion = 'Any time';
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    announceActivity('Writing a letter');
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  static const _occasionIdeas = [
    'Just because ♡',
    'Missing you today',
    'For our next chapter',
    'A little reminder that I love you',
    'For a rainy day',
    'Thinking of you again',
    'For whenever you need this most',
    'A note for future us',
  ];

  String _randomOccasion() =>
      _occasionIdeas[math.Random().nextInt(_occasionIdeas.length)];

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
      case _UnlockMode.openWhen:
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
    final initialDate = _customDate ?? DateTime.now().add(const Duration(days: 1));

    // Step 1 — Calendar date picker
    DateTime? pickedDate;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        DateTime tempDate = initialDate;
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFF12090F),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
            ),
            padding: EdgeInsets.fromLTRB(
              24, 16, 24,
              MediaQuery.of(ctx).padding.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2)),
                ),
                Row(children: [
                  Icon(Icons.calendar_month_outlined, color: accent, size: 20),
                  const SizedBox(width: 10),
                  Text('When can they open it?',
                      style: const TextStyle(color: AppColors.textPrimary,
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 4),
                const Text('Pick a date', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 12),
                Theme(
                  data: ThemeData.dark().copyWith(
                    colorScheme: ColorScheme.dark(primary: accent),
                  ),
                  child: CalendarDatePicker(
                    initialDate: tempDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                    onDateChanged: (d) => setSheetState(() => tempDate = d),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    pickedDate = tempDate;
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [accent, AppColors.coral]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text('Next →',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white,
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (pickedDate == null || !mounted) return;

    // Step 2 — Circular clock time picker
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _customTime,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(primary: accent),
        ),
        child: child!,
      ),
    );

    if (pickedTime == null || !mounted) return;

    setState(() {
      _customDate = pickedDate;
      _customTime = pickedTime;
      _mode = _UnlockMode.custom;
    });
  }

  Future<void> _send() async {
    final titleText = _title.text.trim();
    final hasContent = _blocks.any((b) =>
        (b.type == BlockType.text && (b.text ?? '').trim().isNotEmpty) ||
        b.type != BlockType.text);
    if (titleText.isEmpty || !hasContent) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please add a subject and write something ♡'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    // Don't send while photos/videos are still uploading — they'd be lost.
    final uploading = _blocks.any((b) =>
        (b.type == BlockType.image ||
            b.type == BlockType.video ||
            b.type == BlockType.voice) &&
        b.mediaUrl == null);
    if (uploading) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Media is still uploading — one moment…'),
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
          body: jsonEncode(_blocks.map((b) => b.toMap()).toList()),
          unlockType: _modeToLetterType(_mode),
          unlockAt: unlockAt,
          createdAt: DateTime.now(),
        ),
      );
      if (mounted) {
        // The letter seals and flies away 💌
        DelightHaptics.crack();
        FlyAway.play(context, '💌');
        context.go('/together');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  LetterUnlockType _modeToLetterType(_UnlockMode mode) {
    switch (mode) {
      case _UnlockMode.tomorrow: return LetterUnlockType.tomorrow;
      case _UnlockMode.nextWeek: return LetterUnlockType.custom;
      case _UnlockMode.openWhen: return LetterUnlockType.openWhenSad;
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
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppColors.textPrimary),
                      onPressed: () => context.go('/together'),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('Write a Letter',
                                    style: Theme.of(context)
                                        .textTheme
                                        .displayMedium
                                        ?.copyWith(fontSize: 24)),
                                const SizedBox(width: 4),
                                _FloatingSparkles(color: accent),
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Text('Create a heartfelt letter for any occasion',
                                style: TextStyle(
                                    color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _sending
                          ? const SizedBox(width: 24, height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.rose))
                          : SquishyTap(
                              onTap: _send,
                              cuteStickers: const ['💌', '✨', '💕'],
                              style: TapAnimationStyle.heartBeat,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [accent, AppColors.coral]),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                        color: accent.withValues(alpha: 0.35),
                                        blurRadius: 14),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Send',
                                        style: TextStyle(color: Colors.white,
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.send_rounded,
                                        color: Colors.white, size: 15),
                                  ],
                                ),
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
                      _EnvelopeHero(accent: accent),
                      const SizedBox(height: 20),

                      // Subject field
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 6),
                        child: Row(
                          children: [
                            Text('•', style: TextStyle(color: AppColors.rose, fontSize: 16)),
                            SizedBox(width: 4),
                            Text('Subject',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0.10),
                                  accent.withValues(alpha: 0.06),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  width: 1),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _title,
                                    style: const TextStyle(color: AppColors.textPrimary,
                                        fontSize: 17, fontWeight: FontWeight.w600),
                                    decoration: const InputDecoration(
                                      hintText: 'What\'s the occasion?',
                                      hintStyle: TextStyle(color: AppColors.textMuted),
                                      border: InputBorder.none,
                                      // Otherwise the global dark-fill theme
                                      // paints a solid layer under this
                                      // frosted-glass field, defeating the
                                      // blur.
                                      filled: false,
                                      contentPadding: EdgeInsets.fromLTRB(18, 16, 8, 16),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: GestureDetector(
                                    onTap: () => setState(
                                        () => _title.text = _randomOccasion()),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: accent.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(Icons.auto_awesome_rounded,
                                          color: accent, size: 18),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── UNLOCK SECTION ──────────────────────────────────
                      const Text('WHEN SHOULD THIS LETTER OPEN?',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                              color: AppColors.rose, letterSpacing: 1.2)),
                      const SizedBox(height: 12),

                      // Quick picks row
                      _UnlockChip(
                        emoji: '🌅',
                        label: 'Tomorrow',
                        subtitle: 'Open this letter tomorrow',
                        selected: _mode == _UnlockMode.tomorrow,
                        accent: accent,
                        tint: const Color(0xFFE8896A),
                        motif: _CardMotif.sunrise,
                        onTap: () => setState(() { _mode = _UnlockMode.tomorrow; _customDate = null; }),
                      ),
                      const SizedBox(height: 8),
                      _UnlockChip(
                        emoji: '📆',
                        label: 'Next Week',
                        subtitle: 'Open this letter in 7 days',
                        selected: _mode == _UnlockMode.nextWeek,
                        accent: accent,
                        tint: const Color(0xFF5B9BD5),
                        motif: _CardMotif.wave,
                        onTap: () => setState(() { _mode = _UnlockMode.nextWeek; _customDate = null; }),
                      ),
                      const SizedBox(height: 8),
                      _UnlockChip(
                        emoji: '💜',
                        label: 'Open when…',
                        subtitle: _mode == _UnlockMode.openWhen
                            ? '${_openWhenEmotions.firstWhere(
                                (e) => e.$2 == _openWhenEmotion,
                                orElse: () => _openWhenEmotions.last).$1} $_openWhenEmotion'
                            : 'Pick an emotion to unlock the letter',
                        selected: _mode == _UnlockMode.openWhen,
                        accent: accent,
                        tint: const Color(0xFFBA68C8),
                        motif: _CardMotif.clouds,
                        onTap: () => setState(() { _mode = _UnlockMode.openWhen; _customDate = null; }),
                      ),
                      if (_mode == _UnlockMode.openWhen) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 44,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _openWhenEmotions.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 8),
                            itemBuilder: (_, i) {
                              final e = _openWhenEmotions[i];
                              final selected = _openWhenEmotion == e.$2;
                              return GestureDetector(
                                onTap: () => setState(() => _openWhenEmotion = e.$2),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? accent.withValues(alpha: 0.2)
                                        : AppColors.bgCard,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: selected ? accent : AppColors.divider,
                                      width: selected ? 1.5 : 0.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(e.$1, style: const TextStyle(fontSize: 16)),
                                      const SizedBox(width: 6),
                                      Text(e.$2,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: selected ? accent : AppColors.textSecondary,
                                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                                          )),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],

                      // Special dates (show only if data available)
                      if (myBirthday != null || partnerBirthday != null || anniversary != null) ...[
                        const SizedBox(height: 14),
                        const Text('SPECIAL DATES',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                                color: AppColors.rose, letterSpacing: 1.2)),
                        const SizedBox(height: 10),
                      ],
                      Builder(builder: (context) {
                        final cards = <Widget>[
                          if (myBirthday != null)
                            _UnlockChip(
                              emoji: '🎂',
                              label: 'My Birthday',
                              subtitle: '${_monthShort(myBirthday.month)} ${myBirthday.day}, '
                                  '${_nextOccurrence(myBirthday).year} · ${_daysUntil(_nextOccurrence(myBirthday))}',
                              selected: _mode == _UnlockMode.myBirthday,
                              accent: accent,
                              tint: AppColors.gold,
                              onTap: () => setState(() { _mode = _UnlockMode.myBirthday; _customDate = null; }),
                            ),
                          if (partnerBirthday != null)
                            _UnlockChip(
                              emoji: '🎁',
                              label: '$partnerFirstName\'s Birthday',
                              subtitle: '${_monthShort(partnerBirthday.month)} ${partnerBirthday.day}, '
                                  '${_nextOccurrence(partnerBirthday).year} · ${_daysUntil(_nextOccurrence(partnerBirthday))}',
                              selected: _mode == _UnlockMode.partnerBirthday,
                              accent: accent,
                              tint: AppColors.lavender,
                              onTap: () => setState(() { _mode = _UnlockMode.partnerBirthday; _customDate = null; }),
                            ),
                          if (anniversary != null)
                            _UnlockChip(
                              emoji: '💑',
                              label: 'Our Anniversary',
                              subtitle: '${_monthShort(anniversary.month)} ${anniversary.day} '
                                  '— ${_daysUntil(_nextOccurrence(anniversary))}',
                              selected: _mode == _UnlockMode.anniversary,
                              accent: accent,
                              tint: AppColors.rose,
                              onTap: () => setState(() { _mode = _UnlockMode.anniversary; _customDate = null; }),
                            ),
                        ];
                        if (cards.isEmpty) return const SizedBox.shrink();
                        final rows = <Widget>[];
                        for (var i = 0; i < cards.length; i += 2) {
                          final hasSecond = i + 1 < cards.length;
                          rows.add(Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: cards[i]),
                                if (hasSecond) ...[
                                  const SizedBox(width: 8),
                                  Expanded(child: cards[i + 1]),
                                ],
                              ],
                            ),
                          ));
                        }
                        return Column(children: rows);
                      }),

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

                      // Custom date picker — teal, matching "Specific Date & Time"
                      const SizedBox(height: 6),
                      Builder(builder: (context) {
                        const teal = Color(0xFF4DB6AC);
                        final selected = _mode == _UnlockMode.custom;
                        return GestureDetector(
                          onTap: _pickDateAndTime,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: CustomPaint(
                                      painter: _MotifPainter(_CardMotif.clock, teal)),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: selected
                                        ? [teal.withValues(alpha: 0.32), teal.withValues(alpha: 0.14)]
                                        : [teal.withValues(alpha: 0.12), AppColors.bgCard]),
                                    border: Border.all(
                                      color: selected ? teal : teal.withValues(alpha: 0.25),
                                      width: selected ? 1.5 : 0.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: teal.withValues(alpha: 0.22),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.calendar_month_outlined,
                                            color: teal, size: 20),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              selected && _customDate != null
                                                  ? _formatDateTime(_customDate!, _customTime)
                                                  : 'Specific Date & Time',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const Text('Choose any date and time',
                                                style: TextStyle(fontSize: 11,
                                                    color: AppColors.textMuted)),
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.chevron_right_rounded,
                                          color: selected ? teal : AppColors.textMuted, size: 20),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                      // Unlock date preview card
                      if (_mode != _UnlockMode.openWhen && _mode != _UnlockMode.custom) ...[
                        const SizedBox(height: 12),
                        _UnlockPreview(
                          mode: _mode,
                          date: _resolveUnlockAt(
                            myBirthday: me?.birthday,
                            partnerBirthday: partner?.birthday,
                            anniversary: couple?.anniversary,
                          ),
                          accent: accent,
                          onTap: _pickDateAndTime,
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
                          onTap: _pickDateAndTime,
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Body field — parchment paper, like the letter itself
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            constraints: BoxConstraints(
                              minHeight: MediaQuery.of(context).size.height * 0.3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBF3E3),
                              borderRadius: BorderRadius.circular(4),
                              border: Border(
                                top: BorderSide(
                                    color: const Color(0xFF4A3420).withValues(alpha: 0.25),
                                    width: 1.5),
                              ),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6)),
                              ],
                            ),
                            padding: const EdgeInsets.all(14),
                            child: DefaultTextStyle.merge(
                              style: const TextStyle(color: Color(0xFF2A1A0A)),
                              child: RichContentEditor(
                                initialBlocks: _blocks,
                                onChanged: (blocks) => setState(() => _blocks = blocks),
                                textColor: const Color(0xFF2A1A0A),
                                hintColor: const Color(0xFF2A1A0A).withValues(alpha: 0.4),
                                toolbarIconColor: const Color(0xFF5C3D1E),
                              ),
                            ),
                          ),
                          Positioned(
                            top: -14,
                            left: 22,
                            child: Transform.rotate(
                              angle: 0.32,
                              child: Icon(Icons.attach_file_rounded,
                                  color: Colors.grey.shade400,
                                  size: 34,
                                  shadows: [
                                    Shadow(
                                        color: Colors.black.withValues(alpha: 0.4),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2)),
                                  ]),
                            ),
                          ),
                        ],
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

// ── Envelope hero illustration ────────────────────────────────────────────

class _EnvelopeHero extends StatelessWidget {
  final Color accent;
  const _EnvelopeHero({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Envelope body
          Positioned(
            left: 24,
            right: 24,
            bottom: 6,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent.withValues(alpha: 0.85), AppColors.coral.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8)),
                ],
              ),
            ),
          ),
          // Letter card peeking out
          Positioned(
            top: 0,
            child: Transform.rotate(
              angle: -0.03,
              child: Container(
                width: 190,
                height: 108,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBF3E3),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('For someone special,',
                        style: GoogleFonts.caveat(
                            color: const Color(0xFF4A3420), fontSize: 17)),
                    Text('today and always.',
                        style: GoogleFonts.caveat(
                            color: const Color(0xFF4A3420), fontSize: 17)),
                    const Spacer(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Icon(Icons.favorite_rounded,
                          color: accent.withValues(alpha: 0.4), size: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Wax seal
          Positioned(
            bottom: 30,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFB33A3A), Color(0xFF7A2323)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8),
                ],
              ),
              child: const Icon(Icons.favorite_rounded, color: Colors.white70, size: 18),
            ),
          ),
          // Little flowers, bottom-left
          const Positioned(
            left: 0,
            bottom: 10,
            child: Text('✿', style: TextStyle(fontSize: 22, color: Color(0xFFD8C4A0))),
          ),
          // Fountain pen, bottom-right
          Positioned(
            right: 4,
            bottom: 0,
            child: Transform.rotate(
              angle: -0.55,
              child: const Icon(Icons.edit_rounded, color: Color(0xFFD4A84B), size: 30),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Floating sparkles (title decoration) ───────────────────────────────────

class _FloatingSparkles extends StatefulWidget {
  final Color color;
  const _FloatingSparkles({required this.color});

  @override
  State<_FloatingSparkles> createState() => _FloatingSparklesState();
}

class _FloatingSparklesState extends State<_FloatingSparkles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  static const _specs = [
    (dx: 0.0, dy: 2.0, size: 12.0, phase: 0.0),
    (dx: 20.0, dy: -6.0, size: 8.0, phase: 0.4),
    (dx: 38.0, dy: 6.0, size: 9.0, phase: 0.75),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 24,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) => Stack(
          clipBehavior: Clip.none,
          children: [
            for (final s in _specs)
              Positioned(
                left: s.dx,
                top: s.dy + math.sin((_ctrl.value + s.phase) * 2 * math.pi) * 3,
                child: Opacity(
                  opacity: (0.35 +
                          0.65 *
                              (0.5 +
                                  0.5 *
                                      math.sin(
                                          (_ctrl.value + s.phase) * 2 * math.pi)))
                      .clamp(0.0, 1.0),
                  child: Icon(Icons.auto_awesome_rounded,
                      color: widget.color, size: s.size),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Illustrated card-background motifs ─────────────────────────────────────

enum _CardMotif { sunrise, wave, clouds, clock }

class _MotifPainter extends CustomPainter {
  final _CardMotif motif;
  final Color color;
  const _MotifPainter(this.motif, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    switch (motif) {
      case _CardMotif.sunrise:
        final center = Offset(size.width - 26, size.height + 4);
        canvas.drawCircle(center, 20, fill);
        final rayPaint = Paint()
          ..color = color.withValues(alpha: 0.10)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
        for (var i = 0; i < 3; i++) {
          canvas.drawArc(
              Rect.fromCircle(center: center, radius: 28.0 + i * 8),
              3.5, 2.3, false, rayPaint);
        }
        break;
      case _CardMotif.wave:
        final baseY = size.height * 0.6;
        final startX = size.width - 66;
        for (var line = 0; line < 2; line++) {
          final path = Path();
          final y0 = baseY + line * 9;
          path.moveTo(startX, y0);
          for (double x = 0; x <= 66; x += 2) {
            path.lineTo(startX + x,
                y0 + math.sin(x / 9 + line * 1.1) * 5);
          }
          canvas.drawPath(
              path,
              Paint()
                ..color = color.withValues(alpha: line == 0 ? 0.14 : 0.08)
                ..strokeWidth = 2.2
                ..style = PaintingStyle.stroke);
        }
        break;
      case _CardMotif.clouds:
        final cx = size.width - 38;
        final cy = size.height * 0.4;
        for (final o in [
          Offset(cx - 13, cy + 4),
          Offset(cx, cy - 5),
          Offset(cx + 13, cy + 4),
          Offset(cx - 3, cy + 9),
          Offset(cx + 8, cy + 9),
        ]) {
          canvas.drawCircle(o, 9, fill);
        }
        break;
      case _CardMotif.clock:
        final center = Offset(size.width - 28, size.height / 2);
        final ring = Paint()
          ..color = color.withValues(alpha: 0.14)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(center, 18, ring);
        canvas.drawLine(center, center + const Offset(0, -10), ring);
        canvas.drawLine(center, center + const Offset(8, 4), ring);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _MotifPainter oldDelegate) =>
      oldDelegate.motif != motif || oldDelegate.color != color;
}

// ── Unlock Chip ───────────────────────────────────────────────────────────

class _UnlockChip extends StatelessWidget {
  final String emoji;
  final String label;
  final String? subtitle;
  final bool selected;
  final Color accent;
  final Color? tint;
  final _CardMotif? motif;
  final VoidCallback onTap;

  const _UnlockChip({
    required this.emoji,
    required this.label,
    this.subtitle,
    required this.selected,
    required this.accent,
    this.tint,
    this.motif,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = tint ?? accent;
    return SquishyTap(
      onTap: onTap,
      style: TapAnimationStyle.pulse,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            if (motif != null)
              Positioned.fill(child: CustomPaint(painter: _MotifPainter(motif!, color))),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: selected
                      ? [color.withValues(alpha: 0.32), color.withValues(alpha: 0.14)]
                      : [color.withValues(alpha: 0.12), AppColors.bgCard],
                ),
                border: Border.all(
                  color: selected ? color : color.withValues(alpha: 0.25),
                  width: selected ? 1.5 : 0.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                              color: AppColors.textPrimary,
                            )),
                        if (subtitle != null)
                          Text(subtitle!,
                              style: TextStyle(fontSize: 11,
                                  color: selected ? color : AppColors.textMuted)),
                      ],
                    ),
                  ),
                  if (selected)
                    Container(
                      width: 22, height: 22,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                      child: Icon(Icons.check_rounded, color: color, size: 15),
                    )
                  else
                    Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.divider, width: 1.5),
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

// ── Unlock Preview ────────────────────────────────────────────────────────

class _UnlockPreview extends StatelessWidget {
  final _UnlockMode mode;
  final DateTime? date;
  final Color accent;
  final VoidCallback? onTap;

  const _UnlockPreview({
    required this.mode,
    required this.date,
    required this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (date == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.rose.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.rose.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_rounded, color: AppColors.gold, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unlocks ${_formatDateTime(date!, null)}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.rose),
                  ),
                  const Text('You can edit until then',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ),
            if (onTap != null) ...[
              const Icon(Icons.mail_outline_rounded, color: AppColors.textMuted, size: 16),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 18),
            ],
          ],
        ),
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

