import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/delight/couple_character.dart';
import '../../core/firebase/models.dart';
import '../../core/presence/activity_announcer.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

// Only this account can grant a Wildcard — the partner can request one,
// never send one directly.
const _kGranterEmail = 'abhishek2005.siva@gmail.com';

bool isWildcardGranter() => FirebaseAuth.instance.currentUser?.email == _kGranterEmail;

const List<String> _kFavorIdeas = [
  'Free pass to bite me 😈',
  'Your wish is my command today 👑',
  'I forgive you, no questions asked 💕',
  'Free hug, anytime, no reason needed 🤗',
  'Skip one chore, guilt-free 🧹',
  "I'll cook dinner tonight 🍳",
  'Free pass to be extra clingy 🥹',
  "One free 'I told you so' immunity 🙊",
  'Pick the movie tonight, no debate 🎬',
  'Free pass to steal my hoodie 🧥',
  "I'll give you the best massage 💆",
  'Redeem for unlimited kisses 💋',
  'You win this argument, officially 🏳️',
  'Free pass to wake me up however you want 😴',
];

// ── Card rank/suit display helpers ─────────────────────────────────────────

String _rankLabel(WildcardRank r) {
  switch (r) {
    case WildcardRank.ace: return 'A';
    case WildcardRank.two: return '2';
    case WildcardRank.three: return '3';
    case WildcardRank.four: return '4';
    case WildcardRank.five: return '5';
    case WildcardRank.six: return '6';
    case WildcardRank.seven: return '7';
    case WildcardRank.eight: return '8';
    case WildcardRank.nine: return '9';
    case WildcardRank.ten: return '10';
    case WildcardRank.jack: return 'J';
    case WildcardRank.queen: return 'Q';
    case WildcardRank.king: return 'K';
    case WildcardRank.joker: return '';
  }
}

String _rankName(WildcardRank r) {
  switch (r) {
    case WildcardRank.ace: return 'Ace';
    case WildcardRank.jack: return 'Jack';
    case WildcardRank.queen: return 'Queen';
    case WildcardRank.king: return 'King';
    case WildcardRank.joker: return 'Joker';
    default: return _rankLabel(r);
  }
}

String _suitSymbol(WildcardSuit? s) {
  switch (s) {
    case WildcardSuit.hearts: return '♥';
    case WildcardSuit.diamonds: return '♦';
    case WildcardSuit.clubs: return '♣';
    case WildcardSuit.spades: return '♠';
    case null: return '';
  }
}

String _suitName(WildcardSuit? s) {
  switch (s) {
    case WildcardSuit.hearts: return 'Hearts';
    case WildcardSuit.diamonds: return 'Diamonds';
    case WildcardSuit.clubs: return 'Clubs';
    case WildcardSuit.spades: return 'Spades';
    case null: return '';
  }
}

Color _suitColor(WildcardSuit? s) {
  switch (s) {
    case WildcardSuit.hearts:
    case WildcardSuit.diamonds:
      return const Color(0xFFC7364B);
    case WildcardSuit.clubs:
    case WildcardSuit.spades:
    case null:
      return const Color(0xFF2A2A2A);
  }
}

(WildcardRank, WildcardSuit?) _drawRandomCard() {
  final n = math.Random().nextInt(54); // 52 + 2 jokers
  if (n >= 52) return (WildcardRank.joker, null);
  final ranks = WildcardRank.values.where((r) => r != WildcardRank.joker).toList();
  final rank = ranks[n % 13];
  final suit = WildcardSuit.values[n ~/ 13];
  return (rank, suit);
}

/// Shows the "give a Wildcard" compose sheet. Defaults to a random draw, but
/// offers a "Gift a specific card" toggle so a rank + suit can be hand-picked
/// instead — for when the card itself should mean something (e.g. the Queen
/// of Hearts). Reused by both the Wildcards screen itself and any other
/// quick-access entry point (e.g. Together's Quick Picks row).
void showGiveWildcardSheet(BuildContext context, WidgetRef ref, {WildcardRequest? forRequest}) {
  final ctrl = TextEditingController(text: forRequest?.note ?? '');
  bool gifting = false;
  WildcardRank pickedRank = WildcardRank.ace;
  WildcardSuit pickedSuit = WildcardSuit.hearts;

  Future<void> sendCard(String favorText, (WildcardRank, WildcardSuit?)? chosen) async {
    final coupleId = ref.read(coupleIdProvider);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (coupleId == null || uid == null) return;
    final (rank, suit) = chosen ?? _drawRandomCard();
    final card = WildCard(
      id: const Uuid().v4(),
      favorText: favorText.trim(),
      rank: rank,
      suit: suit,
      givenBy: uid,
      givenAt: DateTime.now(),
      requestId: forRequest?.id,
    );
    await ref.read(firestoreServiceProvider).sendWildcard(coupleId, card);
    if (forRequest != null) {
      await ref
          .read(firestoreServiceProvider)
          .respondToWildcardRequest(coupleId, forRequest.id, WildcardRequestStatus.approved);
    }
    if (context.mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _CardRevealDialog(card: card),
      );
    }
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetCtx) => StatefulBuilder(
      builder: (sheetCtx, setSheetState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
        child: Container(
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(sheetCtx).padding.bottom + 24),
          decoration: const BoxDecoration(
            color: AppColors.bgMid,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  forRequest != null ? 'Grant this Wildcard' : 'Give a Wildcard',
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 19, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  gifting
                      ? 'Pick the exact card to gift ♡'
                      : 'A random card will be drawn when you send it ♡',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                ),
                const SizedBox(height: 14),
                // Random draw / gift-a-specific-card toggle
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ModeTab(
                          label: '🎴 Random draw',
                          selected: !gifting,
                          onTap: () => setSheetState(() => gifting = false),
                        ),
                      ),
                      Expanded(
                        child: _ModeTab(
                          label: '🎁 Gift a card',
                          selected: gifting,
                          onTap: () => setSheetState(() => gifting = true),
                        ),
                      ),
                    ],
                  ),
                ),
                if (gifting) ...[
                  const SizedBox(height: 16),
                  const Text('RANK',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 10.5, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: WildcardRank.values.map((r) {
                      final selected = r == pickedRank;
                      return GestureDetector(
                        onTap: () => setSheetState(() => pickedRank = r),
                        child: Container(
                          width: 38, height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected ? AppColors.rose : AppColors.bgCard,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: selected ? AppColors.rose : AppColors.divider),
                          ),
                          child: Text(
                            r == WildcardRank.joker ? '🃏' : _rankLabel(r),
                            style: TextStyle(
                                color: selected ? Colors.white : AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (pickedRank != WildcardRank.joker) ...[
                    const SizedBox(height: 14),
                    const Text('SUIT',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 10.5, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    Row(
                      children: WildcardSuit.values.map((s) {
                        final selected = s == pickedSuit;
                        final suitColor = _suitColor(s);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setSheetState(() => pickedSuit = s),
                            child: Container(
                              width: 46, height: 46,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: selected
                                    ? suitColor.withValues(alpha: 0.18)
                                    : AppColors.bgCard,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: selected ? suitColor : AppColors.divider,
                                    width: selected ? 1.5 : 1),
                              ),
                              child: Text(_suitSymbol(s),
                                  style: TextStyle(color: suitColor, fontSize: 20)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: ctrl,
                  autofocus: !gifting,
                  maxLines: 3,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'What\'s the favor?',
                    hintStyle: TextStyle(color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _kFavorIdeas
                      .map((idea) => GestureDetector(
                            onTap: () => ctrl.text = idea,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.bgCard,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.divider, width: 0.5),
                              ),
                              child: Text(idea,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary, fontSize: 12)),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 20),
                GradientButton(
                  label: gifting ? 'Gift This Card 🎁' : 'Draw & Send 🎴',
                  cuteStickers: const ['🎴', '✨', '🃏'],
                  onTap: () {
                    final text = ctrl.text.trim();
                    if (text.isEmpty) return;
                    Navigator.pop(sheetCtx);
                    sendCard(
                      text,
                      gifting
                          ? (pickedRank,
                              pickedRank == WildcardRank.joker ? null : pickedSuit)
                          : null,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ModeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.rose : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ── Main screen ─────────────────────────────────────────────────────────

class WildcardsScreen extends ConsumerStatefulWidget {
  const WildcardsScreen({super.key});

  @override
  ConsumerState<WildcardsScreen> createState() => _WildcardsScreenState();
}

class _WildcardsScreenState extends ConsumerState<WildcardsScreen>
    with ActivityAnnouncer {
  @override
  void initState() {
    super.initState();
    announceActivity('Looking at Wildcards');
  }

  void _showComposeSheet({WildcardRequest? forRequest}) =>
      showGiveWildcardSheet(context, ref, forRequest: forRequest);

  void _showRequestSheet() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
        child: Container(
          padding: EdgeInsets.fromLTRB(
              24, 20, 24, MediaQuery.of(sheetCtx).padding.bottom + 24),
          decoration: const BoxDecoration(
            color: AppColors.bgMid,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Request a Wildcard',
                  style: TextStyle(
                      color: AppColors.textPrimary, fontSize: 19, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text("They'll need to approve it before it's sent ♡",
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLines: 2,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Add a note (optional)…',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 20),
              GradientButton(
                label: 'Send Request',
                cuteStickers: const ['🥺', '✨'],
                onTap: () async {
                  final coupleId = ref.read(coupleIdProvider);
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (coupleId == null || uid == null) return;
                  final req = WildcardRequest(
                    id: const Uuid().v4(),
                    note: ctrl.text.trim().isEmpty ? null : ctrl.text.trim(),
                    requestedBy: uid,
                    requestedAt: DateTime.now(),
                  );
                  await ref.read(firestoreServiceProvider).requestWildcard(coupleId, req);
                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCardActions(WildCard card) {
    final coupleId = ref.read(coupleIdProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetCtx).padding.bottom + 20),
        decoration: const BoxDecoration(
          color: AppColors.bgMid,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                card.redeemed ? Icons.undo_rounded : Icons.check_circle_outline_rounded,
                color: AppColors.textPrimary,
              ),
              title: Text(
                card.redeemed ? 'Mark as not redeemed' : 'Mark as redeemed',
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              ),
              onTap: () async {
                Navigator.pop(sheetCtx);
                if (coupleId == null) return;
                await ref
                    .read(firestoreServiceProvider)
                    .setWildcardRedeemed(coupleId, card.id, !card.redeemed);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.rose),
              title: const Text('Delete',
                  style: TextStyle(color: AppColors.rose, fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(sheetCtx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.bgCard,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text('Delete this card?',
                        style: TextStyle(color: AppColors.textPrimary)),
                    content: Text('"${card.favorText}"',
                        style: const TextStyle(color: AppColors.textSecondary)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete', style: TextStyle(color: AppColors.rose)),
                      ),
                    ],
                  ),
                );
                if (confirm == true && coupleId != null) {
                  await ref.read(firestoreServiceProvider).deleteWildcard(coupleId, card.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(wildcardsProvider).valueOrNull ?? [];
    final requests = ref.watch(wildcardRequestsProvider).valueOrNull ?? [];
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isGranter = isWildcardGranter();
    final pendingRequests =
        requests.where((r) => r.status == WildcardRequestStatus.pending).toList();
    final myPendingRequest = !isGranter
        ? requests
            .where((r) => r.requestedBy == uid && r.status == WildcardRequestStatus.pending)
            .toList()
        : const <WildcardRequest>[];
    final redeemedCount = cards.where((c) => c.redeemed).length;

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
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppColors.textPrimary),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text('🃏  Wildcards',
                              style: Theme.of(context)
                                  .textTheme
                                  .displayMedium
                                  ?.copyWith(fontSize: 22)),
                          const SizedBox(height: 2),
                          Text(
                            cards.isEmpty
                                ? 'Special favors, just for us'
                                : '${cards.length} given · $redeemedCount redeemed',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                  children: [
                    if (isGranter && pendingRequests.isNotEmpty) ...[
                      const Text('REQUESTED',
                          style: TextStyle(
                              color: AppColors.rose,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1)),
                      const SizedBox(height: 8),
                      for (final req in pendingRequests) _RequestTile(request: req, ref: ref, onApprove: () {
                        _showComposeSheet(forRequest: req);
                      }),
                      const SizedBox(height: 20),
                    ],
                    if (!isGranter) ...[
                      if (myPendingRequest.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(14),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.hourglass_top_rounded,
                                  color: AppColors.gold, size: 18),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text('Waiting for your card to be granted…',
                                    style: TextStyle(
                                        color: AppColors.textSecondary, fontSize: 13)),
                              ),
                            ],
                          ),
                        )
                      else
                        SquishyTap(
                          onTap: _showRequestSheet,
                          style: TapAnimationStyle.pulse,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: AppColors.bgCard,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppColors.divider, width: 0.5),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('🥺', style: TextStyle(fontSize: 18)),
                                SizedBox(width: 8),
                                Text('Request a Wildcard',
                                    style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                    ],
                    if (cards.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 60),
                        child: Column(
                          children: [
                            const Text('🃏', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 14),
                            Text(
                              isGranter
                                  ? 'No cards given yet.\nSurprise them with one ♡'
                                  : 'No cards yet.\nAsk for one, or wait for a surprise ♡',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 14, height: 1.6),
                            ),
                          ],
                        ),
                      )
                    else
                      for (final card in cards)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _PlayingCardTile(
                            card: card,
                            isMine: card.givenBy == uid,
                            onTap: () => _showCardActions(card),
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: isGranter
          ? FloatingActionButton.extended(
              onPressed: () => _showComposeSheet(),
              backgroundColor: AppColors.rose,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Give a Card', style: TextStyle(color: Colors.white)),
            )
          : null,
    );
  }
}

// ── Pending request row (granter view) ────────────────────────────────────

class _RequestTile extends StatelessWidget {
  final WildcardRequest request;
  final WidgetRef ref;
  final VoidCallback onApprove;

  const _RequestTile({required this.request, required this.ref, required this.onApprove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.rose.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🥺 ', style: TextStyle(fontSize: 16)),
              Expanded(
                child: Text(
                  request.note?.isNotEmpty == true ? request.note! : 'Asked for a Wildcard',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final coupleId = ref.read(coupleIdProvider);
                    if (coupleId == null) return;
                    await ref
                        .read(firestoreServiceProvider)
                        .respondToWildcardRequest(
                            coupleId, request.id, WildcardRequestStatus.declined);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.divider),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Decline', style: TextStyle(color: AppColors.textMuted)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.rose,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Approve', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Playing-card styled list tile ─────────────────────────────────────────

class _PlayingCardTile extends StatelessWidget {
  final WildCard card;
  final bool isMine;
  final VoidCallback onTap;

  const _PlayingCardTile({required this.card, required this.isMine, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isJoker = card.rank == WildcardRank.joker;
    final color = isJoker ? const Color(0xFF7B4E9E) : _suitColor(card.suit);
    final rankLabel = _rankLabel(card.rank);
    final suitSymbol = _suitSymbol(card.suit);

    return SquishyTap(
      onTap: onTap,
      style: TapAnimationStyle.wobble,
      child: Container(
        constraints: const BoxConstraints(minHeight: 150),
        decoration: BoxDecoration(
          color: const Color(0xFFFBF6EC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: card.redeemed ? const Color(0xFF4CAF50) : Colors.black12,
              width: card.redeemed ? 1.5 : 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6)),
          ],
        ),
        child: Stack(
          children: [
            // Center suit watermark
            Positioned.fill(
              child: Center(
                child: Opacity(
                  opacity: 0.08,
                  child: Text(isJoker ? '🃏' : suitSymbol,
                      style: TextStyle(fontSize: 90, color: color)),
                ),
              ),
            ),
            // Top-left corner mark
            Positioned(
              top: 10, left: 12,
              child: _CornerMark(isJoker: isJoker, rankLabel: rankLabel, suitSymbol: suitSymbol, color: color),
            ),
            // Bottom-right corner mark (rotated)
            Positioned(
              bottom: 10, right: 12,
              child: Transform.rotate(
                angle: math.pi,
                child: _CornerMark(isJoker: isJoker, rankLabel: rankLabel, suitSymbol: suitSymbol, color: color),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    card.favorText,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.caveat(
                        color: const Color(0xFF2A1A0A), fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(isMine ? 'From you' : 'For you',
                          style: const TextStyle(color: Color(0xFF8B7355), fontSize: 11)),
                      const Text('  ·  ', style: TextStyle(color: Color(0xFF8B7355), fontSize: 11)),
                      Text(DateFormat('MMM d').format(card.givenAt),
                          style: const TextStyle(color: Color(0xFF8B7355), fontSize: 11)),
                      if (card.redeemed) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 14),
                      ],
                    ],
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

class _CornerMark extends StatelessWidget {
  final bool isJoker;
  final String rankLabel;
  final String suitSymbol;
  final Color color;

  const _CornerMark({
    required this.isJoker,
    required this.rankLabel,
    required this.suitSymbol,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (isJoker) {
      return Text('🃏', style: const TextStyle(fontSize: 20));
    }
    return Column(
      children: [
        Text(rankLabel,
            style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800, height: 1)),
        Text(suitSymbol, style: TextStyle(color: color, fontSize: 13, height: 1)),
      ],
    );
  }
}

// ── Draw & reveal dialog ────────────────────────────────────────────────

class _CardRevealDialog extends StatefulWidget {
  final WildCard card;
  const _CardRevealDialog({required this.card});

  @override
  State<_CardRevealDialog> createState() => _CardRevealDialogState();
}

class _CardRevealDialogState extends State<_CardRevealDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _ctrl.forward().whenComplete(() {
      if (!mounted) return;
      setState(() => _revealed = true);
      HapticFeedback.mediumImpact();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final isJoker = card.rank == WildcardRank.joker;
    final color = isJoker ? const Color(0xFF7B4E9E) : _suitColor(card.suit);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, _) {
              final spin = _ctrl.value * math.pi;
              final showBack = spin < math.pi / 2;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.002)
                  ..rotateY(spin),
                child: Container(
                  width: 180,
                  height: 250,
                  decoration: BoxDecoration(
                    color: showBack ? const Color(0xFF6B1A2F) : const Color(0xFFFBF6EC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white24, width: 1),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 24),
                    ],
                  ),
                  child: showBack
                      ? const Center(
                          child: Text('🃏', style: TextStyle(fontSize: 48)),
                        )
                      : Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateY(math.pi),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(isJoker ? '🃏' : _suitSymbol(card.suit),
                                    style: TextStyle(fontSize: 56, color: color)),
                                const SizedBox(height: 8),
                                Text(
                                  isJoker
                                      ? 'Joker'
                                      : '${_rankName(card.rank)} of ${_suitName(card.suit)}',
                                  style: TextStyle(
                                      color: color, fontSize: 15, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              );
            },
          ),
          const SizedBox(height: 22),
          if (_revealed) ...[
            Container(
              constraints: const BoxConstraints(maxWidth: 260),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider, width: 0.5),
              ),
              child: Text(
                card.favorText,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.4),
              ),
            ),
            const SizedBox(height: 10),
            const CoupleCharacter(
              character: CoupleCharacterId.combo, pose: 'playful_boop', height: 90),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Nice! ♡',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}
