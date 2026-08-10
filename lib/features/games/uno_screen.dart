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
/// House rules worth knowing: no Skip (with exactly two players it's
/// identical to Reverse — both just hand the turn straight back — so it was
/// dropped rather than kept as a confusing duplicate); a +2/+4 can be
/// stacked by the receiving player if they hold one, otherwise they draw
/// the pile and lose their turn; drawing is never a free choice, only
/// reachable when you genuinely have no legal play; and a Heart card play
/// freezes the game until the person it's addressed to submits an answer
/// and the asker accepts it. Turn/move validation lives in
/// FirestoreService (UnoGame.legalMoves is the single source of truth) —
/// the UI only ever offers legal moves, but the service re-checks them
/// anyway.
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

  // Pulled from the app's own palette family (AppColors/kCoupleAccents)
  // instead of the stock crayon-box Uno red/yellow/green/blue — still four
  // clearly distinct hues, but ones that actually belong next to the rest
  // of the app rather than looking like a different product.
  static Color _colorOf(String c) => switch (c) {
        'R' => const Color(0xFFE85D50), // coral-red
        'Y' => const Color(0xFFE8B84B), // warm gold
        'G' => const Color(0xFF4FAF7E), // sage
        'B' => const Color(0xFF5B9BD5), // soft blue
        'H' => AppColors.rose, // Heart cards — the app's actual primary rose
        _ => const Color(0xFF241627), // wild / card back
      };

  static (String, Color) _categoryStyle(String? category) => switch (category) {
        'truth' => ('💗 Truth', Color(0xFFE8899B)),
        'dare' => ('🔥 Dare', Color(0xFFFF8C5A)),
        'sweet' => ('✨ Sweet', Color(0xFFE8C170)),
        'spicy' => ('😈 Spicy', Color(0xFFD65A8E)),
        _ => ('💗 Heart', Color(0xFFE8899B)),
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

  bool _spicy = true;

  Future<void> _startGame(String coupleId, List<String> uids) =>
      _guard(() => ref
          .read(firestoreServiceProvider)
          .startUnoGame(coupleId, uids, spicy: _spicy));

  void _showRules() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.8),
        padding: EdgeInsets.fromLTRB(
            22, 22, 22, MediaQuery.of(ctx).padding.bottom + 22),
        decoration: const BoxDecoration(
          color: AppColors.bgMid,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('How to play',
                  style: Theme.of(context)
                      .textTheme
                      .displayMedium
                      ?.copyWith(fontSize: 22)),
              const SizedBox(height: 14),
              _rule('🃏', 'The basics',
                  'Seven cards each. Play a card matching the colour or the '
                  'number on the pile. If you have a legal move, you have '
                  'to play it — drawing is only for when nothing in your '
                  'hand fits.'),
              _rule('⇄', 'Reverse',
                  'With just the two of you, it hands the turn straight '
                  'back to you — play another right after and you go again.'),
              _rule('+2', 'Draw cards',
                  "They draw that many and lose their turn — unless they're "
                  'holding a +2 or +4 of their own, in which case they can '
                  'stack it on top instead of drawing, and the pile grows '
                  'for whoever it lands on next.'),
              _rule('★', 'Wild',
                  'Play it on anything and name the next colour.'),
              const SizedBox(height: 8),
              const Divider(color: AppColors.divider),
              const SizedBox(height: 8),
              Text('Heart cards ♡',
                  style: Theme.of(context)
                      .textTheme
                      .displayMedium
                      ?.copyWith(fontSize: 18)),
              const SizedBox(height: 4),
              const Text(
                'A dozen or so are shuffled in. They play on ANY card and '
                'you name the next colour — but the game pauses right there: '
                'your partner has to type and send an actual answer, you '
                'read it and tap Accept, and only then does play continue. '
                'Nobody can just tap past it, and a Heart card can never be '
                'the card that ends the game. Everything is written for '
                'distance: voice notes, selfies, texts. Nothing assumes '
                'you\'re in the same room.',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 12.5, height: 1.5),
              ),
              const SizedBox(height: 12),
              _rule('💗', 'Truth',
                  'They answer honestly. No deflecting.'),
              _rule('🔥', 'Dare',
                  'They do it now — a voice note, an unfiltered selfie, '
                  'a photo of whatever is nearest.'),
              _rule('✨', 'Sweet',
                  'The soft ones. Say the thing you keep meaning to say.'),
              _rule('😈', 'Spicy',
                  'Flirtier. Toggle these off before dealing if you want a '
                  'gentler game.'),
              const SizedBox(height: 10),
              const Text(
                'Winning: first to empty their hand. Call UNO when you\'re '
                'down to one card — it shows on their screen, so there\'s '
                'nowhere to hide ♡',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 12.5, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rule(String glyph, String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 34,
              child: Text(glyph,
                  style: const TextStyle(fontSize: 17), textAlign: TextAlign.center),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(body,
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          height: 1.45)),
                ],
              ),
            ),
          ],
        ),
      );

  Future<void> _play(String coupleId, String uid, UnoCard card) async {
    String? chosen;
    // Hearts are wild-coloured too, so they also need a colour choice.
    if (card.isWild || card.isHeart) {
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
        actions: [
          IconButton(
            tooltip: 'How to play',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: _showRules,
          ),
        ],
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
              spicy: _spicy,
              onSpicyChanged: (v) => setState(() => _spicy = v),
              onRules: _showRules,
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
          // Empty while a Heart prompt is unresolved — nobody can play
          // anything until it's answered and accepted.
          final playable = game.activePrompt != null
              ? const <String>{}
              : game.legalMoves(myUid).map((c) => c.code).toSet();

          return SafeArea(
            child: Column(
              children: [
                _PartnerBar(
                  name: partner?.displayName.split(' ').first ?? 'Partner',
                  cardCount: partnerCount,
                  calledUno: game.unoCalledBy == partnerUid,
                ),
                if (game.activePrompt != null)
                  _PromptCard(
                    key: ValueKey(game.activePrompt),
                    prompt: game.activePrompt!,
                    style: _categoryStyle(game.promptCategory),
                    forMe: game.promptForUid == myUid,
                    partnerName:
                        partner?.displayName.split(' ').first ?? 'They',
                    answer: game.promptAnswer,
                    busy: _busy,
                    onSubmitAnswer: (text) => _guard(() => ref
                        .read(firestoreServiceProvider)
                        .answerUnoPrompt(coupleId, myUid, text)),
                    onAccept: () => _guard(() => ref
                        .read(firestoreServiceProvider)
                        .clearUnoPrompt(coupleId, myUid)),
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
                        : game.activePrompt != null
                            ? (game.promptForUid == myUid
                                ? 'Answer their card first ♡'
                                : 'Waiting on their answer…')
                            : myTurn
                                ? (game.pendingDraw > 0
                                    ? 'Draw ${game.pendingDraw} or stack a +2/+4'
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
                    myTurn: myTurn && game.activePrompt == null,
                    busy: _busy,
                    hasPlayable: playable.isNotEmpty,
                    hasDrawnThisTurn: game.hasDrawnThisTurn,
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
  final bool spicy;
  final ValueChanged<bool> onSpicyChanged;
  final VoidCallback onRules;
  final VoidCallback onStart;
  const _EmptyState({
    required this.accent,
    required this.busy,
    required this.canStart,
    required this.spicy,
    required this.onSpicyChanged,
    required this.onRules,
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
                'Seven cards each. Match the colour or the number —\n'
                'and twelve Heart cards are shuffled in ♡',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 18),
              // Spicy is opt-out rather than opt-in, but it's right here so
              // it's a one-tap decision before dealing.
              Container(
                padding: const EdgeInsets.fromLTRB(16, 6, 10, 6),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider, width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('😈', style: TextStyle(fontSize: 15)),
                    const SizedBox(width: 8),
                    const Text('Spicy cards',
                        style: TextStyle(
                            color: AppColors.textPrimary, fontSize: 13)),
                    const SizedBox(width: 6),
                    Switch(
                      value: spicy,
                      activeThumbColor: accent,
                      onChanged: busy ? null : onSpicyChanged,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
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

/// The Heart-card prompt on the table. Blocks the game (see
/// FirestoreService.playUnoCard/drawUnoCard) until it's resolved: the
/// person it's addressed to types and submits an answer, then the asker
/// reads it and taps Accept — only then does play unfreeze. Nobody can just
/// tap past it, and the answer is never invisible to the other person.
class _PromptCard extends StatefulWidget {
  final String prompt;
  final (String, Color) style;
  final bool forMe;
  final String partnerName;
  final String? answer;
  final bool busy;
  final ValueChanged<String> onSubmitAnswer;
  final VoidCallback onAccept;

  const _PromptCard({
    super.key,
    required this.prompt,
    required this.style,
    required this.forMe,
    required this.partnerName,
    required this.answer,
    required this.busy,
    required this.onSubmitAnswer,
    required this.onAccept,
  });

  @override
  State<_PromptCard> createState() => _PromptCardState();
}

class _PromptCardState extends State<_PromptCard> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (label, color) = widget.style;
    final answered = widget.answer != null;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.28), AppColors.bgCard],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1.2),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.22), blurRadius: 18),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.w900)),
              const Spacer(),
              Text(widget.forMe ? 'for you' : 'for ${widget.partnerName}',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          Text(widget.prompt,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 14.5, height: 1.45)),
          const SizedBox(height: 12),
          if (answered) ...[
            // Everyone sees the actual answer — this used to just be a
            // "Done" tap with the reply typed nowhere the other person
            // could see it.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(12),
                border: Border(left: BorderSide(color: color, width: 3)),
              ),
              child: Text(widget.answer!,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 13.5, height: 1.4)),
            ),
            const SizedBox(height: 10),
            if (widget.forMe)
              const Text('Waiting for them to accept your answer…',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontStyle: FontStyle.italic))
            else
              SquishyTap(
                onTap: widget.busy ? null : widget.onAccept,
                style: TapAnimationStyle.heartBeat,
                cuteStickers: const ['💗'],
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text('Accept ♡ — next card',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13)),
                  ),
                ),
              ),
          ] else if (widget.forMe) ...[
            Container(
              decoration: BoxDecoration(
                color: AppColors.bgMid,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                maxLines: 3,
                minLines: 2,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5),
                decoration: const InputDecoration(
                  hintText: 'Type your answer…',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SquishyTap(
              onTap: widget.busy
                  ? null
                  : () {
                      final text = _ctrl.text.trim();
                      if (text.isEmpty) return;
                      widget.onSubmitAnswer(text);
                    },
              style: TapAnimationStyle.bounce,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text('Send answer',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                ),
              ),
            ),
          ] else
            Text('Waiting for ${widget.partnerName}…',
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
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
  final bool hasDrawnThisTurn;
  final bool canCallUno;
  final int pendingDraw;
  final VoidCallback onDraw;
  final VoidCallback onPass;
  final VoidCallback onCallUno;

  const _ActionRow({
    required this.myTurn,
    required this.busy,
    required this.hasPlayable,
    required this.hasDrawnThisTurn,
    required this.canCallUno,
    required this.pendingDraw,
    required this.onDraw,
    required this.onPass,
    required this.onCallUno,
  });

  @override
  Widget build(BuildContext context) {
    // Never a free choice: only reachable when there's a +2/+4 to serve, or
    // you genuinely have nothing playable and haven't already taken this
    // turn's one draw yet.
    final canDraw = myTurn &&
        !busy &&
        (pendingDraw > 0 || (!hasPlayable && !hasDrawnThisTurn));
    // Only appears once you've drawn and the card you got still doesn't fit.
    final canPass = myTurn && !hasPlayable && pendingDraw == 0 && hasDrawnThisTurn;
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SquishyTap(
              onTap: canDraw ? onDraw : null,
              style: TapAnimationStyle.bounce,
              child: _pill(
                pendingDraw > 0 ? 'Draw $pendingDraw' : 'Draw',
                enabled: canDraw,
                color: AppColors.bgCardLight,
              ),
            ),
            if (canPass) ...[
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
  }

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
    // Hearts show their category glyph rather than a number/action symbol.
    final face = card.isHeart
        ? switch (card.code) {
            'HT' => '💗',
            'HD' => '🔥',
            'HS' => '✨',
            'HX' => '😈',
            _ => '💗',
          }
        : switch (card.value) {
            'R' => '⇄',
            'D' => '+2',
            '4' => '+4',
            '' => '★',
            _ => card.value,
          };
    final base = colorOf(card.color);
    final ovalGlyph = !card.isWild && !card.isHeart;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [base, Color.lerp(base, Colors.black, 0.28)!],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28), width: 1.4),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Stack(
        children: [
          // A corner pip on every non-wild, non-heart card — the classic
          // Uno "read it from a fan of cards" cue.
          if (ovalGlyph)
            Positioned(
              top: 6,
              left: 8,
              child: Text(face,
                  style: TextStyle(
                      color: Colors.white, fontSize: width * 0.14, fontWeight: FontWeight.w800)),
            ),
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
            child: ovalGlyph
                ? Transform.rotate(
                    angle: -0.5,
                    child: Container(
                      width: width * 0.72,
                      height: height * 0.5,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Center(
                        child: Transform.rotate(
                          angle: 0.5,
                          child: Text(
                            face,
                            style: TextStyle(
                              color: base,
                              fontSize: width * 0.4,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : Text(
                    face,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: width * (card.isHeart ? 0.34 : 0.42),
                      fontWeight: FontWeight.w900,
                      shadows: const [
                        Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                  ),
          ),
          // Heart cards name their category so you know what you're playing.
          if (card.isHeart)
            Positioned(
              bottom: 6,
              left: 0,
              right: 0,
              child: Text(
                card.label.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: width * 0.13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
