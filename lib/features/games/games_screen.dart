import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/firebase/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

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

// ── Date Wheel ideas ──────────────────────────────────────────────────────
const _dateIdeas = [
  ('🌅', 'Sunrise breakfast date', 'Wake up early, watch the sunrise together with coffee and something good to eat.'),
  ('🎨', 'Create something together', 'Paint, draw, make pottery — no talent required, just vibes.'),
  ('🎬', 'Old movie marathon', 'Pick 2 classics neither of you has seen. Order in, turn off your phones.'),
  ('🚶', 'Explore somewhere new', 'Pick a part of your city you\'ve never properly walked. No plan, just wander.'),
  ('🍳', 'Cook a new recipe', 'Find a dish you\'ve both never made. Cook it together, eat it together.'),
  ('⭐', 'Stargazing night', 'Drive somewhere dark, lie on a blanket, find constellations (or make up your own).'),
  ('📚', 'Bookshop date', 'Spend an hour in a bookshop. Pick one book for each other to read.'),
  ('🃏', 'Game night at home', 'Competitive board games, card games, or video games — with a small prize for the winner.'),
];

// ─────────────────────────────────────────────────────────────────────────

class GamesScreen extends ConsumerStatefulWidget {
  const GamesScreen({super.key});

  @override
  ConsumerState<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends ConsumerState<GamesScreen>
    with TickerProviderStateMixin {
  late final TabController _tabCtrl;
  late final ConfettiController _confettiCtrl;
  bool _initialising = false;
  bool _confettiFired = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _confettiCtrl = ConfettiController(duration: const Duration(seconds: 3));
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
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.textMuted,
                    labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      gradient: LinearGradient(colors: [accent, AppColors.coral]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    tabs: const [
                      Tab(text: 'WYR'),
                      Tab(text: 'Truth Jar'),
                      Tab(text: 'Date Wheel'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      // ── WYR ──────────────────────────────────────────
                      _WyrTab(
                        accent: accent,
                        coupleId: coupleId,
                        gameAsync: gameAsync,
                        myUid: myUid,
                        myName: me?.displayName.split(' ').first ?? 'You',
                        partnerName: partner?.displayName.split(' ').first ?? 'Partner',
                        initialising: _initialising,
                      ),

                      // ── Truth Jar ─────────────────────────────────────
                      _TruthJarTab(
                        accent: accent,
                        coupleId: coupleId,
                        myUid: myUid,
                        myName: me?.displayName.split(' ').first ?? 'You',
                        partnerName: partner?.displayName.split(' ').first ?? 'Partner',
                        todayPrompt: _truthPrompts[_todayIndex(_truthPrompts.length)],
                        todayKey: _todayKey(),
                      ),

                      // ── Date Wheel ────────────────────────────────────
                      _DateWheelTab(
                        accent: accent,
                        coupleId: coupleId,
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
              GradientButton(label: 'Submit answer', onTap: _submit, loading: _submitting)
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

// ── Date Wheel Tab ────────────────────────────────────────────────────────

class _DateWheelTab extends ConsumerStatefulWidget {
  final Color accent;
  final String coupleId;
  const _DateWheelTab({required this.accent, required this.coupleId});

  @override
  ConsumerState<_DateWheelTab> createState() => _DateWheelTabState();
}

class _DateWheelTabState extends ConsumerState<_DateWheelTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinCtrl;
  int _displayIndex = 0;
  bool _spinning = false;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2500));
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    super.dispose();
  }

  Future<void> _spin() async {
    if (_spinning) return;
    setState(() => _spinning = true);
    HapticFeedback.mediumImpact();

    final target = Random().nextInt(_dateIdeas.length);
    final rounds = _dateIdeas.length * 3 + target;

    // Animate through indices with easing
    _spinCtrl.reset();
    await _spinCtrl.animateTo(1.0, curve: Curves.easeInOut);

    // Rapid cycling
    for (int i = 0; i < rounds; i++) {
      final progress = i / rounds;
      final delay = (30 + (progress * progress * 300)).toInt();
      await Future.delayed(Duration(milliseconds: delay));
      if (mounted) {
        setState(() => _displayIndex = i % _dateIdeas.length);
        if (i % 3 == 0) HapticFeedback.selectionClick();
      }
    }

    if (mounted) {
      setState(() {
        _displayIndex = target;
        _spinning = false;
      });
      HapticFeedback.heavyImpact();
      // Save to Firestore
      final svc = ref.read(firestoreServiceProvider);
      final weekKey = svc.currentWeekKey;
      await svc.setDateWheelResult(widget.coupleId, weekKey, target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final savedIndex = ref.watch(dateWheelProvider).valueOrNull;
    final shownIndex = _spinning ? _displayIndex : (savedIndex ?? _displayIndex);
    final idea = _dateIdeas[shownIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        children: [
          _SectionHeader(emoji: '🎡', title: 'Date Wheel',
              subtitle: 'Spin for a date idea. Do it this week.', accent: widget.accent),
          const SizedBox(height: 24),

          // Wheel display
          GlassCard(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                // Emoji icon
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: Text(idea.$1,
                    key: ValueKey(shownIndex),
                    style: const TextStyle(fontSize: 64)),
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: Text(idea.$2,
                    key: ValueKey('title_$shownIndex'),
                    style: const TextStyle(color: AppColors.textPrimary,
                        fontSize: 20, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center),
                ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: Text(idea.$3,
                    key: ValueKey('desc_$shownIndex'),
                    style: const TextStyle(color: AppColors.textSecondary,
                        fontSize: 14, height: 1.5),
                    textAlign: TextAlign.center),
                ),
                const SizedBox(height: 28),
                GestureDetector(
                  onTap: _spinning ? null : _spin,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [widget.accent, AppColors.coral]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(
                          color: widget.accent.withValues(alpha: 0.5),
                          blurRadius: 16, offset: const Offset(0, 6))],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedRotation(
                          turns: _spinning ? 2 : 0,
                          duration: const Duration(milliseconds: 2500),
                          child: const Icon(Icons.casino_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Text(_spinning ? 'Spinning…' : 'Spin!',
                            style: const TextStyle(color: Colors.white,
                                fontWeight: FontWeight.w700, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
                if (savedIndex != null && !_spinning) ...[
                  const SizedBox(height: 16),
                  const Text('This week\'s date idea 🗓',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // All options as a grid hint
          Text('All ideas', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          ...List.generate(_dateIdeas.length, (i) {
            final d = _dateIdeas[i];
            final isSelected = i == shownIndex && !_spinning;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? widget.accent.withValues(alpha: 0.12) : AppColors.bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: isSelected ? widget.accent.withValues(alpha: 0.5) : AppColors.divider,
                    width: isSelected ? 1.5 : 0.5),
              ),
              child: Row(
                children: [
                  Text(d.$1, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(d.$2,
                      style: TextStyle(
                        color: isSelected ? widget.accent : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 14,
                      ))),
                  if (isSelected) Icon(Icons.check_circle_rounded,
                      color: widget.accent, size: 18),
                ],
              ),
            );
          }),
        ],
      ),
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
                  bothPicked: bothPicked, game: game, myName: myName,
                  partnerName: partnerName, accent: accent,
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
                  bothPicked: bothPicked, game: game, myName: myName,
                  partnerName: partnerName, accent: accent,
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
  final String myName;
  final String partnerName;
  final Color accent;
  final VoidCallback? onTap;

  const _OptionButton({
    required this.label, required this.option, required this.myPick,
    required this.bothPicked, required this.game, required this.myName,
    required this.partnerName, required this.accent, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPicked = myPick == option;
    final isOtherPicked = myPick != null && myPick != option;
    List<String> pickerNames = [];
    if (bothPicked) {
      for (final entry in game.picks.entries) {
        if (entry.value == option) {
          pickerNames.add(entry.key == '' ? myName : partnerName);
        }
      }
    }

    return GestureDetector(
      onTap: () { if (onTap != null) { HapticFeedback.lightImpact(); onTap!(); } },
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
