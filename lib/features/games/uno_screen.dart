import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/delight/delight.dart';
import '../../core/firebase/models.dart';
import '../../core/presence/activity_announcer.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

/// Two-player Uno, synced through a single Firestore document.
///
/// House rules worth knowing (all forced by there being exactly two
/// players): Skip and Reverse both simply hand the turn straight back to
/// whoever played them, and a +2/+4 makes the opponent draw and lose their
/// turn. Turn validation lives in FirestoreService — the UI only ever
/// offers legal moves, but the service re-checks them anyway.
class UnoScreen extends ConsumerStatefulWidget {
  const UnoScreen({super.key});

  @override
  ConsumerState<UnoScreen> createState() => _UnoScreenState();
}

class _UnoScreenState extends ConsumerState<UnoScreen> with ActivityAnnouncer {
  bool _busy = false;
  String? _lastWinner;

  @override
  void initState() {
    super.initState();
    announceActivity('Playing Uno');
  }

  static Color _colorOf(String c) => switch (c) {
        'R' => const Color(0xFFD64545),
        'Y' => const Color(0xFFE3B505),
        'G' => const Color(0xFF3E9C56),
        'B' => const Color(0xFF3A6EA5),
        _ => const Color(0xFF2B2B33),
      };

  Future<void> _guard(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Something went wrong: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startGame(String coupleId, List<String> uids) =>
      _guard(() => ref.read(firestoreServiceProvider).startUnoGame(coupleId, uids));

  Future<void> _play(String coupleId, String uid, UnoCard card) async {
    String? chosen;
    if (card.isWild) {
      chosen = await _pickColor();
      if (chosen == null) return; // cancelled
    }
    HapticFeedback.lightImpact();
    await _guard(() => ref
        .read(firestoreServiceProvider)
        .playUnoCard(coupleId, uid, card, chosenColor: chosen));
  }

  Future<String?> _pickColor() => showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.bgMid,
          title: const Text('Pick a colour',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['R', 'Y', 'G', 'B'].map((c) {
              return GestureDetector(
                onTap: () => Navigator.pop(ctx, c),
                child: Container(
                  width: 52,
                  height: 52,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: _colorOf(c),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final coupleId = ref.watch(coupleIdProvider);
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final gameAsync = ref.watch(unoGameProvider);
    final couple = ref.watch(coupleProvider).valueOrNull;
    final partner = ref.watch(partnerUserProvider).valueOrNull;
    final accent = ref.watch(accentColorProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text('Uno'),
      ),
      body: gameAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.rose)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text("Couldn't load the game: $e",
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
        ),
        data: (game) {
          if (coupleId == null || myUid == null) {
            return const Center(
              child: Text('Pair with your partner to play',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }

          final uids = couple?.members ?? const <String>[];
          final started = game.hands.isNotEmpty && game.topCard != null;

          if (!started) {
            return _EmptyState(
              accent: accent,
              busy: _busy,
              canStart: uids.length >= 2,
              onStart: () => _startGame(coupleId, uids),
            );
          }

          // Announce a win once, when it first appears.
          if (game.winnerUid != null && game.winnerUid != _lastWinner) {
            _lastWinner = game.winnerUid;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              DelightHaptics.thud();
              FloatingStickers.burst(context,
                  stickers: const ['🎉', '✨', '🃏'], count: 8);
            });
          }

          final myHand = game.hands[myUid] ?? const <UnoCard>[];
          final partnerUid =
              game.hands.keys.firstWhere((u) => u != myUid, orElse: () => '');
          final partnerCount = game.hands[partnerUid]?.length ?? 0;
          final myTurn = game.turnUid == myUid && game.winnerUid == null;
          final top = game.topCard!;
          final playable = myHand
              .where((c) => c.canPlayOn(top, game.activeColor))
              .map((c) => c.code)
              .toSet();

          return SafeArea(
            child: Column(
              children: [
                _PartnerBar(
                  name: partner?.displayName.split(' ').first ?? 'Partner',
                  cardCount: partnerCount,
                  calledUno: game.unoCalledBy == partnerUid,
                ),
                Expanded(
                  child: _Table(
                    top: top,
                    activeColor: game.activeColor,
                    colorOf: _colorOf,
                    drawCount: game.drawPile.length,
                    pendingDraw: game.pendingDraw,
                    statusText: game.winnerUid != null
                        ? (game.winnerUid == myUid
                            ? 'You won! 🎉'
                            : '${partner?.displayName.split(' ').first ?? 'They'} won 🎉')
                        : myTurn
                            ? (game.pendingDraw > 0
                                ? 'Draw ${game.pendingDraw} or play a stacking card'
                                : 'Your turn')
                            : 'Waiting for them…',
                    accent: accent,
                  ),
                ),
                if (game.winnerUid != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: GradientButton(
                      label: 'Play again',
                      cuteStickers: const ['🃏'],
                      onTap: _busy ? null : () => _startGame(coupleId, uids),
                    ),
                  )
                else
                  _ActionRow(
                    myTurn: myTurn,
                    busy: _busy,
                    hasPlayable: playable.isNotEmpty,
                    canCallUno: myHand.length == 1 && game.unoCalledBy != myUid,
                    pendingDraw: game.pendingDraw,
                    onDraw: () => _guard(() => ref
                        .read(firestoreServiceProvider)
                        .drawUnoCard(coupleId, myUid)),
                    onPass: () => _guard(() => ref
                        .read(firestoreServiceProvider)
                        .passUnoTurn(coupleId, myUid)),
                    onCallUno: () => _guard(() =>
                        ref.read(firestoreServiceProvider).callUno(coupleId, myUid)),
                  ),
                _Hand(
                  hand: myHand,
                  playable: playable,
                  myTurn: myTurn,
                  colorOf: _colorOf,
                  onPlay: (c) => _play(coupleId, myUid, c),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Color accent;
  final bool busy;
  final bool canStart;
  final VoidCallback onStart;
  const _EmptyState({
    required this.accent,
    required this.busy,
    required this.canStart,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🃏', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 14),
              Text('Uno',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 26)),
              const SizedBox(height: 8),
              const Text(
                'Seven cards each. Match the colour or the number.\n'
                'Skip and Reverse hand the turn straight back ♡',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 24),
              if (canStart)
                GradientButton(
                  label: busy ? 'Dealing…' : 'Deal a new game',
                  width: 220,
                  cuteStickers: const ['🃏', '✨'],
                  onTap: busy ? null : onStart,
                )
              else
                const Text('Pair with your partner to play',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
      );
}

class _PartnerBar extends StatelessWidget {
  final String name;
  final int cardCount;
  final bool calledUno;
  const _PartnerBar({
    required this.name,
    required this.cardCount,
    required this.calledUno,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Row(
          children: [
            Text(name,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            if (calledUno)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.rose,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('UNO!',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900)),
              ),
            const Spacer(),
            // Face-down backs — the partner's hand is never revealed.
            ...List.generate(
              cardCount.clamp(0, 8),
              (i) => Container(
                width: 16,
                height: 24,
                margin: const EdgeInsets.only(left: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B2B33),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: Colors.white24, width: 0.5),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text('$cardCount',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      );
}

class _Table extends StatelessWidget {
  final UnoCard top;
  final String activeColor;
  final Color Function(String) colorOf;
  final int drawCount;
  final int pendingDraw;
  final String statusText;
  final Color accent;

  const _Table({
    required this.top,
    required this.activeColor,
    required this.colorOf,
    required this.drawCount,
    required this.pendingDraw,
    required this.statusText,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  Container(
                    width: 64,
                    height: 92,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2B2B33),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Center(
                        child: Text('🃏', style: TextStyle(fontSize: 26))),
                  ),
                  const SizedBox(height: 6),
                  Text('$drawCount left',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
              const SizedBox(width: 28),
              Column(
                children: [
                  _CardFace(card: top, colorOf: colorOf, width: 84, height: 118),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('in play: ',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 11)),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: colorOf(activeColor),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(statusText,
              style: TextStyle(
                  color: accent, fontSize: 14, fontWeight: FontWeight.w700)),
          if (pendingDraw > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('+$pendingDraw stacked',
                  style: const TextStyle(color: AppColors.rose, fontSize: 12)),
            ),
        ],
      );
}

class _ActionRow extends StatelessWidget {
  final bool myTurn;
  final bool busy;
  final bool hasPlayable;
  final bool canCallUno;
  final int pendingDraw;
  final VoidCallback onDraw;
  final VoidCallback onPass;
  final VoidCallback onCallUno;

  const _ActionRow({
    required this.myTurn,
    required this.busy,
    required this.hasPlayable,
    required this.canCallUno,
    required this.pendingDraw,
    required this.onDraw,
    required this.onPass,
    required this.onCallUno,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SquishyTap(
              onTap: (!myTurn || busy) ? null : onDraw,
              style: TapAnimationStyle.bounce,
              child: _pill(
                pendingDraw > 0 ? 'Draw $pendingDraw' : 'Draw',
                enabled: myTurn && !busy,
                color: AppColors.bgCardLight,
              ),
            ),
            // Passing only makes sense once you've drawn and still can't go.
            if (myTurn && !hasPlayable && pendingDraw == 0) ...[
              const SizedBox(width: 10),
              SquishyTap(
                onTap: busy ? null : onPass,
                style: TapAnimationStyle.pulse,
                child: _pill('Pass', enabled: !busy, color: AppColors.bgCardLight),
              ),
            ],
            if (canCallUno) ...[
              const SizedBox(width: 10),
              SquishyTap(
                onTap: busy ? null : onCallUno,
                style: TapAnimationStyle.heartBeat,
                cuteStickers: const ['🃏'],
                child: _pill('UNO!', enabled: !busy, color: AppColors.rose),
              ),
            ],
          ],
        ),
      );

  Widget _pill(String label, {required bool enabled, required Color color}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        decoration: BoxDecoration(
          color: enabled ? color : color.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Text(label,
            style: TextStyle(
              color: enabled ? AppColors.textPrimary : AppColors.textMuted,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            )),
      );
}

class _Hand extends StatelessWidget {
  final List<UnoCard> hand;
  final Set<String> playable;
  final bool myTurn;
  final Color Function(String) colorOf;
  final ValueChanged<UnoCard> onPlay;

  const _Hand({
    required this.hand,
    required this.playable,
    required this.myTurn,
    required this.colorOf,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) => Container(
        height: 148,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          color: AppColors.bgMid,
          border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: hand.isEmpty
            ? const Center(
                child: Text('No cards',
                    style: TextStyle(color: AppColors.textMuted)))
            : ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: hand.length,
                itemBuilder: (_, i) {
                  final card = hand[i];
                  // Unplayable cards stay visible but dimmed, so the hand
                  // reads the same each turn instead of reshuffling.
                  final canPlay = myTurn && playable.contains(card.code);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Opacity(
                      opacity: canPlay ? 1 : 0.42,
                      child: SquishyTap(
                        onTap: canPlay ? () => onPlay(card) : null,
                        style: TapAnimationStyle.bounce,
                        child: _CardFace(
                            card: card, colorOf: colorOf, width: 76, height: 108),
                      ),
                    ),
                  );
                },
              ),
      );
}

class _CardFace extends StatelessWidget {
  final UnoCard card;
  final Color Function(String) colorOf;
  final double width;
  final double height;

  const _CardFace({
    required this.card,
    required this.colorOf,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final face = switch (card.value) {
      'S' => '⊘',
      'R' => '⇄',
      'D' => '+2',
      '4' => '+4',
      '' => '★',
      _ => card.value,
    };
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colorOf(card.color),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white30, width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 6),
        ],
      ),
      child: Stack(
        children: [
          // A wild shows the four colours so it reads as "any colour".
          if (card.isWild)
            Positioned(
              top: 6,
              left: 6,
              child: Row(
                children: ['R', 'Y', 'G', 'B']
                    .map((c) => Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(right: 2),
                          decoration: BoxDecoration(
                              color: colorOf(c), shape: BoxShape.circle),
                        ))
                    .toList(),
              ),
            ),
          Center(
            child: Text(
              face,
              style: TextStyle(
                color: Colors.white,
                fontSize: width * 0.42,
                fontWeight: FontWeight.w900,
                shadows: const [
                  Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
