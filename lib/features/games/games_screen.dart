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

// ── Date Wheel idea groups ────────────────────────────────────────────────
const _kDefaultGroups = {
  'Romantic 🌹': ['Candlelit dinner at home', 'Sunset picnic', 'Star gazing', 'Dance in the kitchen', 'Write love letters', 'Couples massage', 'Cook a new recipe together', 'Watch the sunrise'],
  'Adventure 🏕️': ['Hiking trail', 'Road trip', 'Try a new sport', 'Camping overnight', 'Escape room', 'Rock climbing', 'Kayaking', 'Explore a new city'],
  'Cozy 🛋️': ['Movie marathon', 'Board game night', 'Bake together', 'Build a blanket fort', 'Read books together', 'Puzzle night', 'Indoor picnic', 'Watch old photos'],
  'Foodie 🍜': ['Try a new restaurant', 'Street food tour', 'Cook a 3-course meal', 'Sushi making class', 'Brunch date', 'Ice cream tasting', 'Wine/mocktail tasting', 'Recreate a memory meal'],
  'Creative 🎨': ['Paint together', 'Take photos around the city', 'Make a scrapbook', 'Learn a dance', 'Write a short story together', 'DIY craft project', 'Pottery class', 'Make a playlist for each other'],
};

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
    _tabCtrl = TabController(length: 4, vsync: this);
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
                      Tab(text: 'Truth'),
                      Tab(text: 'Dates'),
                      Tab(text: 'Scribble'),
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

                      // ── Scribble ──────────────────────────────────────
                      _ScribbleTab(
                        accent: accent,
                        coupleId: coupleId,
                        myUid: myUid,
                        myName: me?.displayName.split(' ').first ?? 'You',
                        partnerName: partner?.displayName.split(' ').first ?? 'Partner',
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

class _DateWheelTab extends StatefulWidget {
  final Color accent;
  final String coupleId;
  const _DateWheelTab({required this.accent, required this.coupleId});

  @override
  State<_DateWheelTab> createState() => _DateWheelTabState();
}

class _DateWheelTabState extends State<_DateWheelTab> {
  late Map<String, List<String>> _groups;
  late String _selectedGroup;
  int _selectedIndex = 0;
  late FixedExtentScrollController _scrollCtrl;

  @override
  void initState() {
    super.initState();
    _groups = Map<String, List<String>>.fromEntries(
      _kDefaultGroups.entries.map(
        (e) => MapEntry(e.key, List<String>.from(e.value)),
      ),
    );
    _selectedGroup = _groups.keys.first;
    _scrollCtrl = FixedExtentScrollController();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  List<String> get _ideas => _groups[_selectedGroup] ?? [];

  void _onGroupTap(String group) {
    if (group == _selectedGroup) return;
    setState(() {
      _selectedGroup = group;
      _selectedIndex = 0;
    });
    _scrollCtrl.jumpToItem(0);
  }

  Future<void> _spin() async {
    if (_ideas.isEmpty) return;
    HapticFeedback.mediumImpact();
    final target = Random().nextInt(_ideas.length);
    await _scrollCtrl.animateToItem(
      target,
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOut,
    );
  }

  void _pickThis() {
    if (_ideas.isEmpty) return;
    final idea = _ideas[_selectedIndex];
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Locked in: $idea 🎉'),
        backgroundColor: widget.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _addIdea() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Add idea to $_selectedGroup',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Your date idea…',
            hintStyle: TextStyle(color: AppColors.textMuted),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.divider),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.rose),
            ),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: Text('Add', style: TextStyle(color: widget.accent,
                fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null && result.isNotEmpty) {
      setState(() => _groups[_selectedGroup]!.add(result));
    }
  }

  void _removeIdea() {
    if (_ideas.isEmpty) return;
    final removed = _ideas[_selectedIndex];
    setState(() {
      _groups[_selectedGroup]!.removeAt(_selectedIndex);
      if (_selectedIndex >= _ideas.length && _selectedIndex > 0) {
        _selectedIndex = _ideas.length - 1;
      }
    });
    if (_ideas.isNotEmpty) {
      _scrollCtrl.jumpToItem(_selectedIndex);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed "$removed"'),
        backgroundColor: AppColors.bgCard,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'Undo',
          textColor: widget.accent,
          onPressed: () {
            setState(() {
              _groups[_selectedGroup]!.insert(_selectedIndex, removed);
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ideas = _ideas;
    final selectedIdea = ideas.isNotEmpty ? ideas[_selectedIndex] : '';

    return Column(
      children: [
        // Group chips
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: _groups.keys.map((group) {
              final isSelected = group == _selectedGroup;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => _onGroupTap(group),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(colors: [widget.accent, AppColors.coral])
                          : null,
                      color: isSelected ? null : AppColors.bgCard,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isSelected ? Colors.transparent : AppColors.divider,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      group,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Wheel
        Expanded(
          child: ideas.isEmpty
              ? const Center(
                  child: Text('No ideas yet. Add one below!',
                      style: TextStyle(color: AppColors.textMuted)))
              : ListWheelScrollView.useDelegate(
                  key: ValueKey(_selectedGroup),
                  controller: _scrollCtrl,
                  itemExtent: 52,
                  perspective: 0.003,
                  diameterRatio: 2.5,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (i) => setState(() => _selectedIndex = i),
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: ideas.length,
                    builder: (ctx, i) => _IdeaTile(
                      index: i + 1,
                      text: ideas[i],
                      selected: i == _selectedIndex,
                      accent: widget.accent,
                    ),
                  ),
                ),
        ),

        // Selected idea highlight
        if (selectedIdea.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [widget.accent.withValues(alpha: 0.18),
                      AppColors.coral.withValues(alpha: 0.10)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: widget.accent.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('✦ ', style: TextStyle(color: widget.accent, fontSize: 14)),
                  Flexible(
                    child: Text(
                      selectedIdea,
                      style: TextStyle(
                        color: widget.accent,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Text(' ✦', style: TextStyle(color: widget.accent, fontSize: 14)),
                ],
              ),
            ),
          ),

        // Action buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _spin,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [widget.accent, AppColors.coral]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(
                          color: widget.accent.withValues(alpha: 0.4),
                          blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('🎲', style: TextStyle(fontSize: 18)),
                        SizedBox(width: 8),
                        Text('Spin', style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700,
                            fontSize: 15)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _pickThis,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: widget.accent.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, color: widget.accent, size: 18),
                        const SizedBox(width: 8),
                        Text('Pick This', style: TextStyle(
                            color: widget.accent, fontWeight: FontWeight.w700,
                            fontSize: 15)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Add / Remove row
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _addIdea,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.divider, width: 0.5),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, color: AppColors.textSecondary, size: 18),
                        SizedBox(width: 6),
                        Text('Add Idea', style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: ideas.isEmpty ? null : _removeIdea,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.divider, width: 0.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.close_rounded,
                            color: ideas.isEmpty
                                ? AppColors.textMuted
                                : AppColors.textSecondary,
                            size: 18),
                        const SizedBox(width: 6),
                        Text('Remove',
                            style: TextStyle(
                                color: ideas.isEmpty
                                    ? AppColors.textMuted
                                    : AppColors.textSecondary,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IdeaTile extends StatelessWidget {
  final int index;
  final String text;
  final bool selected;
  final Color accent;

  const _IdeaTile({
    required this.index,
    required this.text,
    required this.selected,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? accent.withValues(alpha: 0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: selected
            ? Border.all(color: accent.withValues(alpha: 0.5))
            : null,
      ),
      child: Text(
        '$index. $text',
        style: TextStyle(
          color: selected ? accent : AppColors.textMuted,
          fontSize: selected ? 16 : 13,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
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
                  GradientButton(label: 'I\'ll Draw!', onTap: _startGame),
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
                ..._colors.map((c) => GestureDetector(
                  onTap: () => setState(() => _penColor = c),
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
                GestureDetector(
                  onTap: _submittingGuess ? null : _submitGuess,
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
