import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:confetti/confetti.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/delight/couple_character.dart';
import '../../core/delight/delight.dart';
import '../../core/firebase/models.dart';
import '../../core/presence/activity_announcer.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

// ── Scribble word list ────────────────────────────────────────────────────
const _scribbleWords = [
  'cat', 'dog', 'house', 'tree', 'car', 'sun', 'moon', 'star', 'flower',
  'heart', 'pizza', 'ice cream', 'beach', 'mountain', 'rainbow', 'cloud',
  'umbrella', 'guitar', 'piano', 'camera', 'bicycle', 'airplane', 'rocket',
  'crown', 'diamond', 'book', 'pencil', 'clock', 'candle', 'cake',
  'balloon', 'butterfly', 'elephant', 'penguin', 'dolphin', 'owl', 'fox',
  'bridge', 'lighthouse', 'windmill', 'castle', 'snowflake', 'campfire',
  'coffee', 'popcorn', 'sushi', 'cupcake', 'pineapple', 'avocado',
];

// ── Would You Rather questions ────────────────────────────────────────────
const _wyrQuestions = [
  ('Wake up at 5 AM every day', 'Stay up until 2 AM every night'),
  ('Never use social media again', 'Never eat your favourite food again'),
  ('Have a private chef', 'Have a personal chauffeur'),
  ('Always be too hot', 'Always be too cold'),
  ('Be able to fly', 'Be invisible'),
  ('Live in the city', 'Live in the countryside'),
  ('Travel the world alone for a year', 'Stay home with your person forever'),
  ('Be rich but unloved', 'Be broke but deeply loved'),
  ('Cook every meal from scratch', 'Never cook again'),
  ('Know exactly when you will die', 'Know exactly how you will die'),
  ('Read minds', 'See the future'),
  ('Only text — no calls ever', 'Only calls — no texts ever'),
  ('Live in endless summer', 'Live in eternal winter'),
  ('Watch every new film the day it comes out', 'Always be 5 years behind on pop culture'),
  ('Have a photographic memory', 'Be able to forget anything at will'),
  ('Speak every language fluently', 'Play every instrument perfectly'),
  ('Never need to sleep', 'Never need to eat'),
  ('Live a safe comfortable life', 'Live a risky exciting life'),
  ('Always tell the truth', 'Always believe every lie'),
  ('Lose all your memories from birth to now', 'Never be able to make new memories'),
  ('Be famous', 'Be extremely rich but unknown'),
  ('Have one true love forever', 'Have many passionate but short loves'),
  ('Live your life in 2× speed', 'Live your life at 0.5× speed'),
  ('Be stuck in a lift for 3 hours', 'Be stuck outside in rain for 3 hours'),
  ('Have 10 close friends', 'Have 1 absolute best friend'),
  ('Know every secret about your partner', 'Never know any of their secrets'),
  ('Be wildly creative but disorganised', 'Be highly organised but not creative'),
  ('Age only from the neck up', 'Age only from the neck down'),
  ('Have one hour of extra sleep per night', 'Have one extra hour of free time per night'),
  ('Only wear one outfit forever', 'Never wear the same outfit twice'),
  ('Have a dog that talks', 'Have a cat that reads your mind'),
  ('Be the funniest person in the room', 'Be the smartest person in the room'),
  ('Give up hot showers', 'Give up fast internet'),
  ('Have no enemies', 'Have only loyal friends'),
  ('Be completely honest forever', 'Know when everyone is lying to you'),
  ('Have legs as long as fingers', 'Have fingers as long as legs'),
  ('Only eat sweet food forever', 'Only eat savoury food forever'),
  ('Never have a bad hair day', 'Never have a bad skin day'),
  ('Have super strength', 'Have super speed'),
  ('Be able to talk to animals', 'Be able to talk to plants'),
  ('Live in a house with no kitchen', 'Live in a house with no bathroom'),
  ('Always feel slightly cold', 'Always feel slightly hungry'),
  ('Win an argument but lose the relationship', 'Lose the argument but keep the love'),
  ('Have your partner always know when you lie', 'Have your partner know exactly what you want'),
  ('Travel anywhere instantly', 'Read every book ever written'),
  ('Be stuck inside for a month', 'Be outside with no shelter for a week'),
  ('Never be able to whisper', 'Never be able to shout'),
  ('Always laugh at the wrong moment', 'Always cry at the wrong moment'),
  ('Give up dessert forever', 'Give up takeaway forever'),
  ('Have your dreams be totally realistic', 'Have your dreams be wildly fantastical'),
  ('Forget everyone\'s name but never their face', 'Remember every name but never a face'),
  ('Have a rewind button for 10 seconds', 'Have a pause button for 10 minutes'),
  ('Always smell like fresh cookies', 'Always smell like the ocean'),
  ('Be extremely lucky once', 'Be slightly lucky every day'),
  ('Skip the next 5 years', 'Relive any 5 years you want'),
  ('Be the hero in a story that ends badly', 'Be a side character in a story with a happy ending'),
  ('Know all the answers on a test', 'Never be nervous before a test again'),
  ('Have lived in the 1980s', 'Live 50 years in the future'),
  ('Never feel physical pain', 'Never feel emotional pain'),
  ('Give up your phone for a month', 'Give up music for a month'),
];

// ── Truth Jar prompts ─────────────────────────────────────────────────────
const _truthPrompts = [
  'What is your biggest irrational fear?',
  'What is the most embarrassing thing that has happened to you?',
  'What is one thing you wish you had done differently in your life?',
  'What is a secret talent nobody knows about?',
  'If you could change one thing about yourself, what would it be?',
  'What was your first impression of me?',
  'What is your biggest insecurity?',
  'What is a memory that still makes you cringe?',
  'What is the most spontaneous thing you have ever done?',
  'What is something you have never told anyone?',
  'What is your happiest childhood memory?',
  'What made you cry last?',
  'What is a dream you are secretly terrified of failing at?',
  'What is something you find beautiful that most people overlook?',
  'What habit of yours do you wish you could break?',
  'What is the worst lie you have ever told?',
  'What is a moment you are truly proud of?',
  'What is something you regret not saying?',
  'Who has had the biggest influence on you?',
  'What is your love language?',
  'What is one thing about relationships you had to unlearn?',
  'What do you do when you are sad but do not want to show it?',
  'What is the most vulnerable you have ever felt?',
  'What is something silly that genuinely made your day recently?',
  'If you could relive one day of your life, which one and why?',
  'What makes you feel most understood?',
  'What is a small thing that means a lot to you?',
  'What is your most unpopular opinion?',
  'What do you think about before falling asleep?',
  'What is a side of yourself you rarely let people see?',
  'What is something you are still healing from?',
  'What is the nicest thing anyone has ever done for you?',
  'What gives your life meaning right now?',
  'What is one thing you would like to be braver about?',
  'What does a perfect Sunday look like to you?',
  'What is the most beautiful thing you have ever experienced?',
  'What would you do if you knew you could not fail?',
  'What is something you are genuinely working on about yourself?',
  'When do you feel most alive?',
  'What is a belief you hold that has changed over the years?',
  'What is something you want more of in your life right now?',
  'What is a compliment that really stuck with you?',
  'What did you need most as a child that you did not get?',
  'What is the bravest thing you have ever done?',
  'What is something others admire about you that you struggle to see?',
  'If you had to describe love in one sentence, what would you say?',
  'What is something you would do today if you were fearless?',
  'What is a place that feels like home to you?',
  'What is one thing you hope never changes about you?',
  'What does feeling truly loved feel like to you?',
];

// ── Guess Me questions (how well do you know each other?) ─────────────────
const _guessMeQuestions = [
  'What would I order at a café right now?',
  'What song can I not stop playing lately?',
  'What tiny thing instantly makes my day better?',
  'What would I grab first in a house fire (after you)?',
  'What food could I eat every single day?',
  'What is my most-used emoji?',
  'What do I do when I can\'t sleep?',
  'What movie could I quote start to finish?',
  'What would I do with a totally free Saturday?',
  'What is my guilty-pleasure snack?',
  'What superpower would I pick?',
  'What am I most likely to lose this week?',
  'What show would I binge for the third time?',
  'What is my go-to excuse for being late?',
  'What would my dream vacation look like?',
  'What sound or noise do I secretly hate?',
  'What was my favourite thing about our last call?',
  'What app do I open first in the morning?',
  'What would I name a pet if we got one today?',
  'What childhood cartoon do I still love?',
  'What is my comfort outfit?',
  'What weird food combo do I actually enjoy?',
  'What time do I *actually* fall asleep?',
  'What would I do if I won the lottery tomorrow?',
  'What is the one chore I always avoid?',
  'What smell instantly reminds me of home?',
  'What is my hidden talent?',
  'What phrase do I say way too often?',
  'What would I want for my birthday this year?',
  'What makes me laugh even on a bad day?',
];

// ─────────────────────────────────────────────────────────────────────────

class GamesScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;
  const GamesScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends ConsumerState<GamesScreen>
    with TickerProviderStateMixin, ActivityAnnouncer {
  late final TabController _tabCtrl;
  late final ConfettiController _confettiCtrl;
  bool _initialising = false;
  bool _confettiFired = false;

  static const _gameNames = [
    'Would You Rather',
    'Truth or Dare',
    'Scribble',
    'Rock Paper Scissors',
    'Kiss Roulette',
    'Love Quiz',
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
        length: 6, vsync: this, initialIndex: widget.initialTabIndex);
    _confettiCtrl = ConfettiController(duration: const Duration(seconds: 3));
    announceActivity('Playing ${_gameNames[_tabCtrl.index]}');
    _tabCtrl.addListener(_onTabChanged);
  }

  void _showWinMoment() {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => const IgnorePointer(
        child: Center(
          child: CoupleCharacter(
            character: CoupleCharacterId.combo, pose: 'excited', height: 130),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (entry.mounted) entry.remove();
    });
  }

  void _onTabChanged() {
    if (!_tabCtrl.indexIsChanging) return;
    announceActivity('Playing ${_gameNames[_tabCtrl.index]}');
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  int _todayIndex(int listLength) {
    final now = DateTime.now();
    return now.difference(DateTime(now.year, 1, 1)).inDays % listLength;
  }

  Future<void> _ensureGameExists(String coupleId) async {
    if (_initialising) return;
    final existing = ref.read(todayGameProvider).valueOrNull;
    if (existing != null) return;
    setState(() => _initialising = true);
    final idx = _todayIndex(_wyrQuestions.length);
    final q = _wyrQuestions[idx];
    await ref.read(firestoreServiceProvider).setTodayGame(
      coupleId,
      GameRound(date: _todayKey(), questionIndex: idx,
          optionA: q.$1, optionB: q.$2, picks: const {}),
    );
    if (mounted) setState(() => _initialising = false);
  }

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(accentColorProvider);
    final coupleId = ref.watch(coupleIdProvider);
    final gameAsync = ref.watch(todayGameProvider);
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final me = ref.watch(currentUserProvider).valueOrNull;
    final partner = ref.watch(partnerUserProvider).valueOrNull;

    if (coupleId == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // Ensure WYR game exists
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (gameAsync.valueOrNull == null && !_initialising) _ensureGameExists(coupleId);
    });

    // Trigger confetti when WYR match happens
    ref.listen(todayGameProvider, (_, next) {
      final game = next.valueOrNull;
      if (game != null && game.matched && !_confettiFired) {
        _confettiFired = true;
        HapticFeedback.heavyImpact();
        _confettiCtrl.play();
        _showWinMoment();
      }
    });

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
          SafeArea(
            child: Column(
              children: [
                // App bar + tabs
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      Text('Games', style: Theme.of(context).textTheme.titleLarge),
                      const Spacer(),
                      Text('🎮', style: const TextStyle(fontSize: 24)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TabBar(
                    controller: _tabCtrl,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.textMuted,
                    labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      gradient: LinearGradient(colors: [accent, AppColors.coral]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    tabs: const [
                      Tab(text: '🎯 WYR'),
                      Tab(text: '🫙 Truth'),
                      Tab(text: '🎨 Scribble'),
                      Tab(text: '✊ RPS'),
                      Tab(text: '💋 Kiss'),
                      Tab(text: '💘 Quiz'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      // ── WYR ──────────────────────────────────────────
                      _WyrTab(
                        accent: accent,
                        coupleId: coupleId,
                        gameAsync: gameAsync,
                        myUid: myUid,
                        myName: me?.displayLabel ?? 'You',
                        partnerName: partner?.displayLabel ?? 'Partner',
                        initialising: _initialising,
                      ),

                      // ── Truth Jar ─────────────────────────────────────
                      _TruthJarTab(
                        accent: accent,
                        coupleId: coupleId,
                        myUid: myUid,
                        myName: me?.displayLabel ?? 'You',
                        partnerName: partner?.displayLabel ?? 'Partner',
                        todayPrompt: _truthPrompts[_todayIndex(_truthPrompts.length)],
                        todayKey: _todayKey(),
                      ),

                      // ── Scribble ──────────────────────────────────────
                      _ScribbleTab(
                        accent: accent,
                        coupleId: coupleId,
                        myUid: myUid,
                        myName: me?.displayLabel ?? 'You',
                        partnerName: partner?.displayLabel ?? 'Partner',
                      ),

                      // ── Rock Paper Scissors ───────────────────────────
                      _RpsTab(
                        accent: accent,
                        coupleId: coupleId,
                        myUid: myUid,
                        partnerName: partner?.displayLabel ?? 'Partner',
                      ),

                      // ── Thumb Kiss ────────────────────────────────────
                      _ThumbKissTab(
                        accent: accent,
                        coupleId: coupleId,
                        myUid: myUid,
                        partner: partner,
                      ),

                      // ── Guess Me quiz ─────────────────────────────────
                      _GuessMeTab(
                        accent: accent,
                        coupleId: coupleId,
                        myUid: myUid,
                        myName: me?.displayLabel ?? 'You',
                        partnerName: partner?.displayLabel ?? 'Partner',
                        todayQuestion:
                            _guessMeQuestions[_todayIndex(_guessMeQuestions.length)],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Confetti overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiCtrl,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 30,
              gravity: 0.3,
              colors: [accent, AppColors.rose, AppColors.coral,
                  Colors.yellow, Colors.white],
            ),
          ),
        ],
      ),
    );
  }
}

// ── WYR Tab ───────────────────────────────────────────────────────────────

class _WyrTab extends StatelessWidget {
  final Color accent;
  final String coupleId;
  final AsyncValue<GameRound?> gameAsync;
  final String myUid;
  final String myName;
  final String partnerName;
  final bool initialising;

  const _WyrTab({
    required this.accent, required this.coupleId, required this.gameAsync,
    required this.myUid, required this.myName, required this.partnerName,
    required this.initialising,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        children: [
          _SectionHeader(emoji: '🎯', title: 'Would You Rather?',
              subtitle: 'A new question every day. See if you match.', accent: accent),
          const SizedBox(height: 20),
          gameAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.rose)),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (game) {
              if (game == null) {
                return const Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: AppColors.rose),
                );
              }
              return _WyrGame(
                game: game, myUid: myUid, myName: myName,
                partnerName: partnerName, accent: accent,
                onPick: (option) async {
                  await ProviderScope.containerOf(context)
                      .read(firestoreServiceProvider)
                      .pickGameOption(coupleId, game.date, option);
                },
              ).animate().fadeIn();
            },
          ),
        ],
      ),
    );
  }
}

// ── Truth Jar Tab ─────────────────────────────────────────────────────────

class _TruthJarTab extends ConsumerStatefulWidget {
  final Color accent;
  final String coupleId;
  final String myUid;
  final String myName;
  final String partnerName;
  final String todayPrompt;
  final String todayKey;

  const _TruthJarTab({
    required this.accent, required this.coupleId, required this.myUid,
    required this.myName, required this.partnerName,
    required this.todayPrompt, required this.todayKey,
  });

  @override
  ConsumerState<_TruthJarTab> createState() => _TruthJarTabState();
}

class _TruthJarTabState extends ConsumerState<_TruthJarTab> {
  final _ctrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();
    try {
      await ref.read(firestoreServiceProvider)
          .submitTruth(widget.coupleId, widget.todayKey, text);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final truths = ref.watch(todayTruthsProvider).valueOrNull ?? {};
    final myAnswer = truths[widget.myUid];
    final partnerAnswered = truths.keys.any((k) => k != widget.myUid);
    final bothAnswered = myAnswer != null && partnerAnswered;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        children: [
          _SectionHeader(emoji: '🫙', title: 'Truth Jar',
              subtitle: 'A deep question every day. Both answer, both reveal.', accent: widget.accent),
          const SizedBox(height: 20),

          // Prompt card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [widget.accent.withValues(alpha: 0.15), AppColors.bgCard],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: widget.accent.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text('Today\'s question', style: TextStyle(
                    color: widget.accent, fontSize: 12, fontWeight: FontWeight.w600,
                    letterSpacing: 1)),
                const SizedBox(height: 14),
                Text(widget.todayPrompt, style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 18, height: 1.4,
                    fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (!bothAnswered) ...[
            // Input
            Container(
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.divider),
              ),
              child: TextField(
                controller: _ctrl,
                maxLines: 4,
                minLines: 2,
                enabled: myAnswer == null,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: myAnswer != null
                      ? 'Waiting for ${widget.partnerName}…'
                      : 'Your honest answer…',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (myAnswer == null)
              GradientButton(
                  label: 'Submit answer',
                  onTap: _submit,
                  loading: _submitting,
                  cuteStickers: const ['🎉', '✨'])
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(children: [
                  Icon(Icons.check_circle_rounded, color: widget.accent, size: 20),
                  const SizedBox(width: 10),
                  Text('You answered! Waiting for ${widget.partnerName}…',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ]),
              ),
          ] else ...[
            // Both answered — reveal
            _TruthReveal(
              truths: truths,
              myUid: widget.myUid,
              myName: widget.myName,
              partnerName: widget.partnerName,
              accent: widget.accent,
            ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),
          ],
        ],
      ),
    );
  }
}

class _TruthReveal extends StatelessWidget {
  final Map<String, String> truths;
  final String myUid;
  final String myName;
  final String partnerName;
  final Color accent;

  const _TruthReveal({
    required this.truths, required this.myUid, required this.myName,
    required this.partnerName, required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final myAnswer = truths[myUid] ?? '';
    final partnerAnswer = truths.entries.firstWhere((e) => e.key != myUid,
        orElse: () => const MapEntry('', '')).value;

    return Column(
      children: [
        for (final item in [
          (myName, myAnswer, accent),
          (partnerName, partnerAnswer, AppColors.rose),
        ])
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [item.$3.withValues(alpha: 0.15), AppColors.bgCard],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: item.$3.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.$1, style: TextStyle(color: item.$3, fontSize: 12,
                    fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                Text(item.$2, style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 15, height: 1.5)),
              ],
            ),
          ),
        const SizedBox(height: 8),
        const Text('Come back tomorrow for a new question',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
      ],
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color accent;
  const _SectionHeader({required this.emoji, required this.title,
      required this.subtitle, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.15), AppColors.coral.withValues(alpha: 0.08)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── WYR Game ──────────────────────────────────────────────────────────────

class _WyrGame extends StatelessWidget {
  final GameRound game;
  final String myUid;
  final String myName;
  final String partnerName;
  final Color accent;
  final Future<void> Function(String option) onPick;

  const _WyrGame({
    required this.game, required this.myUid, required this.myName,
    required this.partnerName, required this.accent, required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final myPick = game.picks[myUid];
    final bothPicked = game.bothPicked;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassCard(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Text('Would you rather…',
                  style: TextStyle(fontSize: 13, color: accent, letterSpacing: 1,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              _OptionButton(label: game.optionA, option: 'A', myPick: myPick,
                  bothPicked: bothPicked, game: game, myUid: myUid,
                  myName: myName, partnerName: partnerName, accent: accent,
                  onTap: myPick == null ? () => onPick('A') : null),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.divider, width: 0.5),
                ),
                child: Text('OR', style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.bold, color: accent, letterSpacing: 2)),
              ),
              const SizedBox(height: 14),
              _OptionButton(label: game.optionB, option: 'B', myPick: myPick,
                  bothPicked: bothPicked, game: game, myUid: myUid,
                  myName: myName, partnerName: partnerName, accent: accent,
                  onTap: myPick == null ? () => onPick('B') : null),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!bothPicked && myPick != null)
          _StatusCard(message: 'Waiting for $partnerName to pick…',
              emoji: '⏳', accent: accent).animate().fadeIn()
        else if (bothPicked)
          _ResultCard(game: game, myName: myName, partnerName: partnerName, accent: accent)
              .animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),
      ],
    );
  }
}

class _OptionButton extends StatelessWidget {
  final String label;
  final String option;
  final String? myPick;
  final bool bothPicked;
  final GameRound game;
  final String myUid;
  final String myName;
  final String partnerName;
  final Color accent;
  final VoidCallback? onTap;

  const _OptionButton({
    required this.label, required this.option, required this.myPick,
    required this.bothPicked, required this.game, required this.myUid,
    required this.myName, required this.partnerName, required this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPicked = myPick == option;
    final isOtherPicked = myPick != null && myPick != option;
    List<String> pickerNames = [];
    if (bothPicked) {
      for (final entry in game.picks.entries) {
        if (entry.value == option) {
          pickerNames.add(entry.key == myUid ? myName : partnerName);
        }
      }
    }

    return SquishyTap(
      onTap: onTap,
      style: TapAnimationStyle.pulse,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          gradient: isPicked && !bothPicked
              ? LinearGradient(colors: [accent.withValues(alpha: 0.3),
                    AppColors.coral.withValues(alpha: 0.2)])
              : bothPicked && isPicked
                  ? LinearGradient(colors: [accent.withValues(alpha: 0.2),
                        AppColors.coral.withValues(alpha: 0.15)])
                  : null,
          color: isPicked || bothPicked ? null : AppColors.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isPicked ? accent
                : isOtherPicked ? AppColors.divider.withValues(alpha: 0.3)
                : AppColors.divider,
            width: isPicked ? 2 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 16,
                fontWeight: isPicked ? FontWeight.w600 : FontWeight.normal,
                color: isOtherPicked && !bothPicked
                    ? AppColors.textMuted : AppColors.textPrimary)),
            if (bothPicked && pickerNames.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 6, children: pickerNames.map((n) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(n, style: TextStyle(fontSize: 11, color: accent,
                    fontWeight: FontWeight.w600)),
              )).toList()),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final GameRound game;
  final String myName;
  final String partnerName;
  final Color accent;

  const _ResultCard({required this.game, required this.myName,
      required this.partnerName, required this.accent});

  @override
  Widget build(BuildContext context) {
    final matched = game.matched;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: matched
              ? [accent.withValues(alpha: 0.25), AppColors.rose.withValues(alpha: 0.15)]
              : [AppColors.bgCard.withValues(alpha: 0.8), AppColors.bgCard.withValues(alpha: 0.6)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: matched ? accent.withValues(alpha: 0.5) : AppColors.divider),
      ),
      child: Column(
        children: [
          Text(matched ? '🎉' : '🤝', style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 10),
          Text(matched ? 'You matched!' : 'Different choices!',
              style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            matched ? 'Great minds think alike 💕'
                : 'Opposites attract — or maybe you just disagree 😄',
            style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          const Text('Come back tomorrow for a new question',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String message;
  final String emoji;
  final Color accent;
  const _StatusCard({required this.message, required this.emoji, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 14),
          Expanded(child: Text(message, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

// ── Scribble Tab ──────────────────────────────────────────────────────────

class _ScribbleTab extends ConsumerStatefulWidget {
  final Color accent;
  final String coupleId;
  final String myUid;
  final String myName;
  final String partnerName;

  const _ScribbleTab({
    required this.accent,
    required this.coupleId,
    required this.myUid,
    required this.myName,
    required this.partnerName,
  });

  @override
  ConsumerState<_ScribbleTab> createState() => _ScribbleTabState();
}

class _ScribbleTabState extends ConsumerState<_ScribbleTab> {
  final _guessCtrl = TextEditingController();
  List<_Stroke> _currentStrokes = [];
  _Stroke? _activeStroke;
  Color _penColor = const Color(0xFFFF6B8A);
  double _penWidth = 4.0;
  bool _submittingGuess = false;

  static const _colors = [
    Color(0xFFFF6B8A), Color(0xFFFFFFFF), Color(0xFFFFD166),
    Color(0xFF6FBFA0), Color(0xFF5B9BD5), Color(0xFFFF8C42),
    Color(0xFFB8A0D9), Color(0xFF000000),
  ];

  @override
  void dispose() {
    _guessCtrl.dispose();
    super.dispose();
  }


  Future<void> _startGame() async {
    final word = _scribbleWords[Random().nextInt(_scribbleWords.length)];
    await ref.read(firestoreServiceProvider)
        .startScribble(widget.coupleId, word, widget.myUid);
  }

  Future<void> _submitGuess() async {
    final guess = _guessCtrl.text.trim();
    if (guess.isEmpty) return;
    _guessCtrl.clear();
    setState(() => _submittingGuess = true);
    try {
      await ref.read(firestoreServiceProvider)
          .submitScribbleGuess(widget.coupleId, guess);
    } finally {
      if (mounted) setState(() => _submittingGuess = false);
    }
  }

  Future<void> _onStrokeEnd() async {
    if (_activeStroke == null || _activeStroke!.pts.isEmpty) return;
    final stroke = _activeStroke!;
    setState(() {
      _currentStrokes.add(stroke);
      _activeStroke = null;
    });
    final pts = stroke.pts
        .map((p) => {'x': p.dx, 'y': p.dy})
        .toList();
    await ref.read(firestoreServiceProvider)
        .addScribbleStroke(widget.coupleId, pts, _colorHex(stroke.color), stroke.width);
  }

  String _colorHex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

  Color _hexColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final scribbleAsync = ref.watch(scribbleProvider);
    final data = scribbleAsync.valueOrNull;

    // Extract game state outside widget tree
    final isDrawer = data == null || data['drawerId'] == widget.myUid;
    final word = data?['word'] as String? ?? '';
    final status = data?['status'] as String? ?? 'drawing';
    final rawStrokes = (data?['strokes'] as List?)?.cast<Map>() ?? [];
    final guesses = (data?['guesses'] as List?)?.cast<Map>() ?? [];
    final correct = status == 'correct';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        children: [
          _SectionHeader(
            emoji: '🎨',
            title: 'Scribble',
            subtitle: 'One draws, one guesses — real-time!',
            accent: widget.accent,
          ),
          const SizedBox(height: 20),

          if (data == null) ...[
            // No active game
            GlassCard(
              child: Column(
                children: [
                  const Text('🎨', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 16),
                  Text('Start a round!',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'You\'ll draw a secret word — your partner tries to guess it.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  GradientButton(
                      label: 'I\'ll Draw!',
                      onTap: _startGame,
                      cuteStickers: const ['🎨', '✨']),
                ],
              ),
            ),
          ] else ...[
            if (correct) ...[
              // ── Game won ──
              GlassCard(
                child: Column(children: [
                  const Text('🎉', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  Text('Correct!', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('The word was "$word"',
                      style: TextStyle(color: widget.accent,
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  GradientButton(
                    label: 'Play Again',
                    onTap: () async {
                      await ref.read(firestoreServiceProvider)
                          .resetScribble(widget.coupleId);
                    },
                  ),
                ]),
              ),
            ] else if (isDrawer) ...[
              // ── Drawing side ──
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: widget.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: widget.accent.withValues(alpha: 0.4)),
                ),
                child: Row(children: [
                  const Text('🎯', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Text('Draw: ',
                      style: TextStyle(color: widget.accent,
                          fontWeight: FontWeight.w600)),
                  Text(word,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ]),
              ),
              const SizedBox(height: 12),

              // Canvas
              _DrawCanvas(
                remoteStrokes: rawStrokes,
                activeStroke: _activeStroke,
                localStrokes: _currentStrokes,
                penColor: _penColor,
                penWidth: _penWidth,
                hexColor: _hexColor,
                onPanStart: (pos) => setState(() {
                  _activeStroke = _Stroke(color: _penColor, width: _penWidth, pts: [pos]);
                }),
                onPanUpdate: (pos) => setState(() {
                  _activeStroke?.pts.add(pos);
                }),
                onPanEnd: (_) => _onStrokeEnd(),
              ),
              const SizedBox(height: 12),

              // Pen controls
              Row(children: [
                ..._colors.map((c) => SquishyTap(
                  onTap: () => setState(() => _penColor = c),
                  style: TapAnimationStyle.jelly,
                  child: Container(
                    width: 28, height: 28,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: _penColor == c
                          ? Border.all(
                              color: widget.accent, width: 2.5)
                          : Border.all(
                              color: AppColors.divider, width: 0.5),
                    ),
                  ),
                )),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.undo_rounded,
                      color: AppColors.textMuted),
                  onPressed: () async {
                    setState(() => _currentStrokes = []);
                    await ref.read(firestoreServiceProvider)
                        .clearScribbleCanvas(widget.coupleId);
                  },
                ),
              ]),
              const SizedBox(height: 8),
              // Width slider
              Row(children: [
                const Icon(Icons.line_weight_rounded,
                    color: AppColors.textMuted, size: 18),
                Expanded(
                  child: Slider(
                    value: _penWidth,
                    min: 2, max: 16,
                    activeColor: widget.accent,
                    inactiveColor: AppColors.divider,
                    onChanged: (v) => setState(() => _penWidth = v),
                  ),
                ),
              ]),

              // Recent guesses
              if (guesses.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Guesses',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 6),
                ...guesses.reversed.take(5).map((g) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${widget.partnerName}: ${g['guess']}',
                    style: TextStyle(
                      color: g['correct'] == true
                          ? const Color(0xFF4CAF50)
                          : AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                )),
              ],
            ] else ...[
              // ── Guessing side ──
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(children: [
                  const Text('🔍', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Text('${widget.partnerName} is drawing something…',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ]),
              ),
              const SizedBox(height: 12),

              // View-only canvas
              _DrawCanvas(
                remoteStrokes: rawStrokes,
                activeStroke: null,
                localStrokes: const [],
                penColor: Colors.white,
                penWidth: 4,
                hexColor: _hexColor,
                onPanStart: (_) {},
                onPanUpdate: (_) {},
                onPanEnd: (_) {},
              ),
              const SizedBox(height: 12),

              // Guess input
              Row(children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: TextField(
                      controller: _guessCtrl,
                      style: const TextStyle(
                          color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Type your guess…',
                        hintStyle:
                            TextStyle(color: AppColors.textMuted),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => _submitGuess(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SquishyTap(
                  onTap: _submittingGuess ? null : _submitGuess,
                  style: TapAnimationStyle.bounce,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [widget.accent, AppColors.coral]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: _submittingGuess
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 18),
                  ),
                ),
              ]),

              if (guesses.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...guesses.reversed.take(5).map((g) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'You: ${g['guess']}',
                    style: TextStyle(
                      color: g['correct'] == true
                          ? const Color(0xFF4CAF50)
                          : AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                )),
              ],
            ],
          ],
        ],
      ),
    );
  }
}

// ── Drawing canvas ────────────────────────────────────────────────────────

class _Stroke {
  final Color color;
  final double width;
  final List<Offset> pts;
  _Stroke({required this.color, required this.width, required this.pts});
}

class _DrawCanvas extends StatelessWidget {
  final List<Map> remoteStrokes;
  final _Stroke? activeStroke;
  final List<_Stroke> localStrokes;
  final Color penColor;
  final double penWidth;
  final Color Function(String) hexColor;
  final void Function(Offset) onPanStart;
  final void Function(Offset) onPanUpdate;
  final void Function(DragEndDetails) onPanEnd;

  const _DrawCanvas({
    required this.remoteStrokes,
    required this.activeStroke,
    required this.localStrokes,
    required this.penColor,
    required this.penWidth,
    required this.hexColor,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 260,
        color: const Color(0xFF1A1A2E),
        child: GestureDetector(
          onPanStart: (d) => onPanStart(d.localPosition),
          onPanUpdate: (d) => onPanUpdate(d.localPosition),
          onPanEnd: onPanEnd,
          child: CustomPaint(
            painter: _CanvasPainter(
              remoteStrokes: remoteStrokes,
              activeStroke: activeStroke,
              localStrokes: localStrokes,
              hexColor: hexColor,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _CanvasPainter extends CustomPainter {
  final List<Map> remoteStrokes;
  final _Stroke? activeStroke;
  final List<_Stroke> localStrokes;
  final Color Function(String) hexColor;

  _CanvasPainter({
    required this.remoteStrokes,
    required this.activeStroke,
    required this.localStrokes,
    required this.hexColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw remote strokes
    for (final s in remoteStrokes) {
      final rawPts = (s['pts'] as List?)?.cast<Map>() ?? [];
      if (rawPts.isEmpty) continue;
      final pts = rawPts
          .map((p) => Offset(
                (p['x'] as num?)?.toDouble() ?? 0,
                (p['y'] as num?)?.toDouble() ?? 0,
              ))
          .toList();
      final color = hexColor(s['color'] as String? ?? '#FFFFFF');
      final width = (s['width'] as num?)?.toDouble() ?? 4.0;
      _drawStroke(canvas, pts, color, width);
    }

    // Draw local confirmed strokes
    for (final s in localStrokes) {
      _drawStroke(canvas, s.pts, s.color, s.width);
    }

    // Draw active stroke in progress
    if (activeStroke != null && activeStroke!.pts.isNotEmpty) {
      _drawStroke(canvas, activeStroke!.pts,
          activeStroke!.color, activeStroke!.width);
    }
  }

  void _drawStroke(Canvas canvas, List<Offset> pts, Color color, double width) {
    if (pts.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CanvasPainter old) => true;
}

// ── Rock Paper Scissors Tab ───────────────────────────────────────────────

const _rpsEmoji = {'rock': '✊', 'paper': '✋', 'scissors': '✌️'};

class _RpsTab extends ConsumerStatefulWidget {
  final Color accent;
  final String coupleId;
  final String myUid;
  final String partnerName;

  const _RpsTab({
    required this.accent,
    required this.coupleId,
    required this.myUid,
    required this.partnerName,
  });

  @override
  ConsumerState<_RpsTab> createState() => _RpsTabState();
}

class _RpsTabState extends ConsumerState<_RpsTab> {
  @override
  Widget build(BuildContext context) {
    final fs = ref.watch(firestoreServiceProvider);
    return StreamBuilder<Map<String, dynamic>?>(
      stream: fs.watchRps(widget.coupleId),
      builder: (context, snap) {
        final data = snap.data ?? {};
        final picks = Map<String, String>.from(data['picks'] ?? {});
        final scores = Map<String, dynamic>.from(data['scores'] ?? {});
        final myPick = picks[widget.myUid];
        final partnerPicked = picks.keys.any((k) => k != widget.myUid);
        final bothPicked = myPick != null && partnerPicked;
        final myScore = (scores[widget.myUid] ?? 0) as int;
        final partnerScore = scores.entries
            .where((e) => e.key != widget.myUid)
            .fold<int>(0, (_, e) => (e.value as num).toInt());

        String? partnerPick;
        if (bothPicked) {
          partnerPick =
              picks.entries.firstWhere((e) => e.key != widget.myUid).value;
        }
        String resultText = '';
        String resultEmoji = '🤝';
        if (bothPicked) {
          if (myPick == partnerPick) {
            resultText = 'It\'s a tie! Great minds…';
            resultEmoji = '🤝';
          } else {
            const beats = {
              'rock': 'scissors',
              'paper': 'rock',
              'scissors': 'paper'
            };
            final iWin = beats[myPick] == partnerPick;
            resultText = iWin
                ? 'You win this round! 🏆'
                : '${widget.partnerName} takes it! 👑';
            resultEmoji = iWin ? '🎉' : '😤';
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          child: Column(
            children: [
              _SectionHeader(
                emoji: '✊',
                title: 'Rock · Paper · Scissors',
                subtitle: 'The classic — settle any argument, any distance.',
                accent: widget.accent,
              ),
              const SizedBox(height: 16),

              // Scoreboard
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.divider, width: 0.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(children: [
                      Text('You',
                          style: TextStyle(
                              color: widget.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      Text('$myScore',
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.bold)),
                    ]),
                    const Text('⚡', style: TextStyle(fontSize: 22)),
                    Column(children: [
                      Text(widget.partnerName,
                          style: const TextStyle(
                              color: AppColors.coral,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      Text('$partnerScore',
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.bold)),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (!bothPicked) ...[
                Text(
                  myPick == null
                      ? 'Pick your weapon!'
                      : 'Locked in! Waiting for ${widget.partnerName}…',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _rpsEmoji.entries.map((e) {
                    final selected = myPick == e.key;
                    return SquishyTap(
                      style: TapAnimationStyle.bounce,
                      onTap: myPick == null
                          ? () {
                              HapticFeedback.mediumImpact();
                              ref
                                  .read(firestoreServiceProvider)
                                  .pickRps(widget.coupleId, e.key);
                            }
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          gradient: selected
                              ? LinearGradient(colors: [
                                  widget.accent,
                                  AppColors.coral
                                ])
                              : null,
                          color: selected ? null : AppColors.bgCard,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? Colors.transparent
                                : myPick != null
                                    ? AppColors.divider.withValues(alpha: 0.3)
                                    : AppColors.divider,
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                      color: widget.accent
                                          .withValues(alpha: 0.5),
                                      blurRadius: 16)
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(e.value,
                              style: TextStyle(
                                  fontSize: selected ? 42 : 34,
                                  color: myPick != null && !selected
                                      ? AppColors.textMuted
                                      : null)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ] else ...[
                // Reveal!
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      widget.accent.withValues(alpha: 0.18),
                      AppColors.bgCard
                    ]),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: widget.accent.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(children: [
                            Text(_rpsEmoji[myPick] ?? '❔',
                                style: const TextStyle(fontSize: 56)),
                            const SizedBox(height: 6),
                            const Text('You',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12)),
                          ]),
                          const Text('VS',
                              style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          Column(children: [
                            Text(_rpsEmoji[partnerPick] ?? '❔',
                                style: const TextStyle(fontSize: 56)),
                            const SizedBox(height: 6),
                            Text(widget.partnerName,
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12)),
                          ]),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(resultEmoji, style: const TextStyle(fontSize: 34)),
                      const SizedBox(height: 6),
                      Text(resultText,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ).animate().scale(
                    begin: const Offset(0.9, 0.9),
                    curve: Curves.easeOutBack,
                    duration: 300.ms),
                const SizedBox(height: 16),
                GradientButton(
                  label: 'Next round ✊✋✌️',
                  onTap: () => ref
                      .read(firestoreServiceProvider)
                      .nextRpsRound(widget.coupleId),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── Thumb Kiss Tab ────────────────────────────────────────────────────────

class _ThumbKissTab extends ConsumerStatefulWidget {
  final Color accent;
  final String coupleId;
  final String myUid;
  final UserModel? partner;

  const _ThumbKissTab({
    required this.accent,
    required this.coupleId,
    required this.myUid,
    required this.partner,
  });

  @override
  ConsumerState<_ThumbKissTab> createState() => _ThumbKissTabState();
}

class _ThumbKissTabState extends ConsumerState<_ThumbKissTab> {
  bool _iAmTouching = false;
  Timer? _heartbeat;
  bool _wasKissing = false;

  // Hold the kiss for 3 s together → the whole screen floods with hearts.
  Timer? _bombTimer;
  bool _bombed = false;

  @override
  void dispose() {
    _heartbeat?.cancel();
    _bombTimer?.cancel();
    if (_iAmTouching) {
      ref.read(firestoreServiceProvider).setTouching(widget.coupleId, false);
    }
    super.dispose();
  }

  void _startTouch() {
    setState(() => _iAmTouching = true);
    HapticFeedback.lightImpact();
    final fs = ref.read(firestoreServiceProvider);
    fs.setTouching(widget.coupleId, true);
    // Refresh the timestamp so "touching" stays fresh while held.
    _heartbeat = Timer.periodic(const Duration(seconds: 2), (_) {
      fs.setTouching(widget.coupleId, true);
    });
  }

  void _endTouch() {
    _heartbeat?.cancel();
    setState(() => _iAmTouching = false);
    ref.read(firestoreServiceProvider).setTouching(widget.coupleId, false);
  }

  bool _isFresh(dynamic ts) {
    if (ts == null) return false;
    final t = (ts as Timestamp).toDate();
    return DateTime.now().difference(t).inSeconds < 6;
  }

  @override
  Widget build(BuildContext context) {
    final fs = ref.watch(firestoreServiceProvider);
    return StreamBuilder<Map<String, dynamic>?>(
      stream: fs.watchTouch(widget.coupleId),
      builder: (context, snap) {
        final data = snap.data ?? {};
        bool partnerTouching = false;
        for (final e in data.entries) {
          if (e.key.startsWith('touch_') &&
              e.key != 'touch_${widget.myUid}' &&
              _isFresh(e.value)) {
            partnerTouching = true;
          }
        }
        final kissing = _iAmTouching && partnerTouching;
        if (kissing && !_wasKissing) {
          HapticFeedback.heavyImpact();
          // Kiss just started — arm the 3-second heart bombardment.
          _bombed = false;
          _bombTimer?.cancel();
          _bombTimer = Timer(const Duration(seconds: 3), () {
            if (mounted && _wasKissing && !_bombed) {
              _bombed = true;
              DelightHaptics.heartbeat();
              HeartBombardment.play(context);
            }
          });
        } else if (!kissing && _wasKissing) {
          _bombTimer?.cancel();
        }
        _wasKissing = kissing;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            children: [
              _SectionHeader(
                emoji: '💋',
                title: 'Thumb Kiss',
                subtitle:
                    'Both hold the heart at the same time — feel the buzz.',
                accent: widget.accent,
              ),
              const SizedBox(height: 12),
              Text(
                kissing
                    ? 'You\'re touching right now!! 💞'
                    : _iAmTouching
                        ? 'Holding… waiting for ${widget.partner?.displayLabel ?? 'them'} 🥺'
                        : partnerTouching
                            ? '${widget.partner?.displayLabel ?? 'They'} is holding — join them!'
                            : 'Press and hold the heart together ♡',
                style: TextStyle(
                  color: kissing ? widget.accent : AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: kissing ? FontWeight.w700 : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              GestureDetector(
                onTapDown: (_) => _startTouch(),
                onTapUp: (_) => _endTouch(),
                onTapCancel: _endTouch,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: kissing ? 230 : 190,
                  height: kissing ? 230 : 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: kissing
                          ? [
                              widget.accent,
                              AppColors.coral.withValues(alpha: 0.8)
                            ]
                          : _iAmTouching || partnerTouching
                              ? [
                                  widget.accent.withValues(alpha: 0.55),
                                  AppColors.bgCard
                                ]
                              : [
                                  widget.accent.withValues(alpha: 0.25),
                                  AppColors.bgCard
                                ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.accent
                            .withValues(alpha: kissing ? 0.7 : 0.25),
                        blurRadius: kissing ? 60 : 24,
                        spreadRadius: kissing ? 10 : 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      kissing ? '💞' : '🤍',
                      style: TextStyle(fontSize: kissing ? 84 : 64),
                    ),
                  ),
                )
                    .animate(
                        target: kissing || _iAmTouching || partnerTouching
                            ? 1
                            : 0,
                        onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.06, 1.06),
                        duration: 500.ms,
                        curve: Curves.easeInOut),
              ),
              const Spacer(),
              const Text(
                'Tip: hop on a call and thumb-kiss goodnight 🌙',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

// ── Guess Me Tab ──────────────────────────────────────────────────────────

class _GuessMeTab extends ConsumerStatefulWidget {
  final Color accent;
  final String coupleId;
  final String myUid;
  final String myName;
  final String partnerName;
  final String todayQuestion;

  const _GuessMeTab({
    required this.accent,
    required this.coupleId,
    required this.myUid,
    required this.myName,
    required this.partnerName,
    required this.todayQuestion,
  });

  @override
  ConsumerState<_GuessMeTab> createState() => _GuessMeTabState();
}

class _GuessMeTabState extends ConsumerState<_GuessMeTab> {
  final _selfCtrl = TextEditingController();
  final _guessCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _selfCtrl.dispose();
    _guessCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final self = _selfCtrl.text.trim();
    final guess = _guessCtrl.text.trim();
    if (self.isEmpty || guess.isEmpty) return;
    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();
    try {
      await ref
          .read(firestoreServiceProvider)
          .submitGuessMe(widget.coupleId, self, guess);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fs = ref.watch(firestoreServiceProvider);
    return StreamBuilder<Map<String, dynamic>?>(
      stream: fs.watchGuessMe(widget.coupleId),
      builder: (context, snap) {
        final data = snap.data ?? {};
        final selfAnswers = Map<String, dynamic>.from(data['self'] ?? {});
        final guesses = Map<String, dynamic>.from(data['guess'] ?? {});
        final iSubmitted = selfAnswers.containsKey(widget.myUid);
        final partnerUid = selfAnswers.keys
            .where((k) => k != widget.myUid)
            .followedBy(guesses.keys.where((k) => k != widget.myUid))
            .firstOrNull;
        final partnerSubmitted =
            partnerUid != null && selfAnswers.containsKey(partnerUid);
        final bothDone = iSubmitted && partnerSubmitted;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          child: Column(
            children: [
              _SectionHeader(
                emoji: '💘',
                title: 'Guess Me',
                subtitle:
                    'Answer for yourself, guess for them. How well do you really know each other?',
                accent: widget.accent,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    widget.accent.withValues(alpha: 0.15),
                    AppColors.bgCard
                  ]),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: widget.accent.withValues(alpha: 0.3)),
                ),
                child: Column(children: [
                  Text('Today\'s question',
                      style: TextStyle(
                          color: widget.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1)),
                  const SizedBox(height: 12),
                  Text(widget.todayQuestion,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          height: 1.4,
                          fontWeight: FontWeight.w500)),
                ]),
              ),
              const SizedBox(height: 20),

              if (!bothDone) ...[
                if (!iSubmitted) ...[
                  _GuessMeField(
                      label: '✍️ Your own honest answer',
                      hint: 'The truth about you…',
                      ctrl: _selfCtrl),
                  const SizedBox(height: 12),
                  _GuessMeField(
                      label: '🔮 Your guess for ${widget.partnerName}',
                      hint: 'What will they say?',
                      ctrl: _guessCtrl),
                  const SizedBox(height: 16),
                  GradientButton(
                      label: 'Lock in both 💘',
                      onTap: _submit,
                      loading: _submitting),
                ] else
                  _StatusCard(
                      message:
                          'Locked in! Waiting for ${widget.partnerName} to answer…',
                      emoji: '⏳',
                      accent: widget.accent),
              ] else ...[
                // Reveal
                _GuessMeReveal(
                  title: 'Your guess about ${widget.partnerName}',
                  guess: (guesses[widget.myUid] ?? '—') as String,
                  truth: (selfAnswers[partnerUid] ?? '—') as String,
                  accent: widget.accent,
                ),
                const SizedBox(height: 14),
                _GuessMeReveal(
                  title: '${widget.partnerName}\'s guess about you',
                  guess: (guesses[partnerUid] ?? '—') as String,
                  truth: (selfAnswers[widget.myUid] ?? '—') as String,
                  accent: AppColors.coral,
                ),
                const SizedBox(height: 12),
                const Text('New question tomorrow ♡',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _GuessMeField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController ctrl;
  const _GuessMeField(
      {required this.label, required this.hint, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: TextField(
            controller: ctrl,
            maxLines: 2,
            minLines: 1,
            style:
                const TextStyle(color: AppColors.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppColors.textMuted),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ),
      ],
    );
  }
}

class _GuessMeReveal extends StatelessWidget {
  final String title;
  final String guess;
  final String truth;
  final Color accent;

  const _GuessMeReveal({
    required this.title,
    required this.guess,
    required this.truth,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [accent.withValues(alpha: 0.14), AppColors.bgCard]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4)),
          const SizedBox(height: 10),
          Row(children: [
            const Text('🔮 ', style: TextStyle(fontSize: 14)),
            Expanded(
                child: Text('Guess: $guess',
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.4))),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            const Text('💡 ', style: TextStyle(fontSize: 14)),
            Expanded(
                child: Text('Truth: $truth',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: FontWeight.w600))),
          ]),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05);
  }
}
