import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/firebase/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

// 60 Would You Rather questions
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

class GamesScreen extends ConsumerStatefulWidget {
  const GamesScreen({super.key});

  @override
  ConsumerState<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends ConsumerState<GamesScreen> {
  bool _initialising = false;

  int _todayQuestionIndex() {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    return dayOfYear % _wyrQuestions.length;
  }

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> _ensureGameExists(String coupleId) async {
    if (_initialising) return;
    final existing = ref.read(todayGameProvider).valueOrNull;
    if (existing != null) return;
    setState(() => _initialising = true);
    final idx = _todayQuestionIndex();
    final q = _wyrQuestions[idx];
    await ref.read(firestoreServiceProvider).setTodayGame(
      coupleId,
      GameRound(
        date: _todayKey(),
        questionIndex: idx,
        optionA: q.$1,
        optionB: q.$2,
        picks: const {},
      ),
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

    // Create today's game if it doesn't exist yet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (gameAsync.valueOrNull == null && !_initialising) {
        _ensureGameExists(coupleId);
      }
    });

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
          child: CustomScrollView(
            slivers: [
              const SliverAppBar(
                pinned: true,
                backgroundColor: Colors.transparent,
                title: Text('Games 🎮'),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _WyrHeader(accent: accent),
                    const SizedBox(height: 20),
                    gameAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.rose)),
                      error: (e, _) => Center(child: Text('Error: $e')),
                      data: (game) {
                        if (game == null) {
                          return const Center(child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(color: AppColors.rose),
                          ));
                        }
                        return _WyrGame(
                          game: game,
                          myUid: myUid,
                          myName: me?.displayName.split(' ').first ?? 'You',
                          partnerName: partner?.displayName.split(' ').first ?? 'Partner',
                          accent: accent,
                          coupleId: coupleId,
                          onPick: (option) async {
                            await ref.read(firestoreServiceProvider)
                                .pickGameOption(coupleId, game.date, option);
                          },
                        ).animate().fadeIn();
                      },
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WyrHeader extends StatelessWidget {
  final Color accent;
  const _WyrHeader({required this.accent});

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
          Text('🎯', style: const TextStyle(fontSize: 36)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Would You Rather?', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('A new question every day. Pick one — see if you match.',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WyrGame extends StatelessWidget {
  final GameRound game;
  final String myUid;
  final String myName;
  final String partnerName;
  final Color accent;
  final String coupleId;
  final Future<void> Function(String option) onPick;

  const _WyrGame({
    required this.game,
    required this.myUid,
    required this.myName,
    required this.partnerName,
    required this.accent,
    required this.coupleId,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final myPick = game.picks[myUid];
    final bothPicked = game.bothPicked;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // VS card
        GlassCard(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Text('Would you rather…',
                  style: TextStyle(fontSize: 13, color: accent, letterSpacing: 1,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              _OptionButton(
                label: game.optionA,
                option: 'A',
                myPick: myPick,
                bothPicked: bothPicked,
                game: game,
                myName: myName,
                partnerName: partnerName,
                accent: accent,
                onTap: myPick == null ? () => onPick('A') : null,
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.divider, width: 0.5),
                ),
                child: Text('OR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                    color: accent, letterSpacing: 2)),
              ),
              const SizedBox(height: 14),
              _OptionButton(
                label: game.optionB,
                option: 'B',
                myPick: myPick,
                bothPicked: bothPicked,
                game: game,
                myName: myName,
                partnerName: partnerName,
                accent: accent,
                onTap: myPick == null ? () => onPick('B') : null,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Status card
        if (!bothPicked && myPick != null)
          _StatusCard(
            message: 'Waiting for $partnerName to pick…',
            emoji: '⏳',
            accent: accent,
          ).animate().fadeIn()
        else if (bothPicked)
          _ResultCard(
            game: game,
            myName: myName,
            partnerName: partnerName,
            accent: accent,
          ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),
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
    required this.label,
    required this.option,
    required this.myPick,
    required this.bothPicked,
    required this.game,
    required this.myName,
    required this.partnerName,
    required this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPicked = myPick == option;
    final isOtherPicked = myPick != null && myPick != option;

    // After reveal, show who picked what
    List<String> pickerNames = [];
    if (bothPicked) {
      for (final entry in game.picks.entries) {
        if (entry.value == option) {
          pickerNames.add(entry.key == '' ? myName : partnerName);
        }
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          gradient: isPicked && !bothPicked
              ? LinearGradient(colors: [accent.withValues(alpha: 0.3), AppColors.coral.withValues(alpha: 0.2)])
              : bothPicked && isPicked
                  ? LinearGradient(colors: [accent.withValues(alpha: 0.2), AppColors.coral.withValues(alpha: 0.15)])
                  : null,
          color: isPicked || bothPicked ? null : AppColors.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isPicked ? accent : isOtherPicked ? AppColors.divider.withValues(alpha: 0.3) : AppColors.divider,
            width: isPicked ? 2 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isPicked ? FontWeight.w600 : FontWeight.normal,
                  color: isOtherPicked && !bothPicked ? AppColors.textMuted : AppColors.textPrimary,
                )),
            if (bothPicked && pickerNames.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: pickerNames.map((n) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(n, style: TextStyle(fontSize: 11, color: accent, fontWeight: FontWeight.w600)),
                )).toList(),
              ),
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

  const _ResultCard({
    required this.game,
    required this.myName,
    required this.partnerName,
    required this.accent,
  });

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
          Text(
            matched ? 'You matched!' : 'Different choices!',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            matched
                ? 'Great minds think alike 💕'
                : 'Opposites attract — or maybe you just disagree 😄',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text('Come back tomorrow for a new question',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
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
