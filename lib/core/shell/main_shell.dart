import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vibration/vibration.dart';
import '../delight/delight.dart';
import '../delight/presence_layer.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../../features/chat/video_call_screen.dart';
import '../../features/cinema/screen_share_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  const MainShell({super.key, required this.navigationShell});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  bool _dialogShowing = false;

  // Presence heartbeat — writes "I'm online, in this section" every 30 s
  // and on every tab change; cleared when the app goes to background.
  Timer? _presenceTimer;
  String _mySection = 'room';

  // Paw-walk transition when the partner moves between sections.
  late final AnimationController _pawCtrl;
  int? _pawFrom;
  int? _pawTo;
  String? _lastPartnerSection;

  // System back button: from any tab, land on Home first rather than
  // exiting straight away; from Home, a second press within the window
  // actually exits.
  DateTime? _lastBackPress;

  static const _tabs = [
    _Tab(icon: Icons.house_rounded, label: 'Home', path: '/room'),
    _Tab(icon: Icons.chat_bubble_rounded, label: 'Chat', path: '/chat'),
    _Tab(icon: Icons.photo_library_rounded, label: 'Memories', path: '/memory'),
    _Tab(icon: Icons.calendar_month_rounded, label: 'Calendar', path: '/calendar'),
    _Tab(icon: Icons.favorite_rounded, label: 'Fun', path: '/together'),
  ];

  static int? _sectionIndex(String? section) {
    if (section == null) return null;
    final i = _tabs.indexWhere((t) => t.path == '/$section');
    return i == -1 ? null : i;
  }

  int _currentIndex(BuildContext context) => widget.navigationShell.currentIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pawCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    _startHeartbeat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _presenceTimer?.cancel();
    _pawCtrl.dispose();
    super.dispose();
  }

  void _startHeartbeat() {
    _writePresence();
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(
        const Duration(seconds: 30), (_) => _writePresence());
  }

  void _writePresence() {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null) return;
    ref
        .read(firestoreServiceProvider)
        .setPresence(coupleId, section: _mySection)
        .ignore();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final coupleId = ref.read(coupleIdProvider);
    if (state == AppLifecycleState.resumed) {
      _startHeartbeat();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _presenceTimer?.cancel();
      if (coupleId != null) {
        ref.read(firestoreServiceProvider).clearPresence(coupleId).ignore();
      }
    }
  }

  void _onPartnerSectionChanged(String? section, bool online) {
    if (section == _lastPartnerSection) return;
    final from = _sectionIndex(_lastPartnerSection);
    final to = _sectionIndex(section);
    _lastPartnerSection = section;
    if (!online || from == null || to == null || from == to) return;
    setState(() {
      _pawFrom = from;
      _pawTo = to;
    });
    _pawCtrl.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _pawFrom = null);
    });
  }

  /// Only reached when we're exactly at a tab root (nothing pushed on top
  /// within that tab, since [canPop] is true otherwise and the system just
  /// pops normally). From any tab but Home, land on Home; from Home, a
  /// second press within 2 seconds actually exits the app.
  void _handleBackPress(BuildContext context, String currentLocation) {
    if (currentLocation != '/room') {
      widget.navigationShell.goBranch(0);
      return;
    }
    final now = DateTime.now();
    if (_lastBackPress != null &&
        now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBackPress = now;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Press back again to exit'),
      duration: Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showIncomingCall(BuildContext context, Map<String, dynamic> call) {
    if (_dialogShowing) return;
    _dialogShowing = true;

    final coupleId = ref.read(coupleIdProvider);
    final partnerName =
        ref.read(partnerUserProvider).valueOrNull?.displayName ?? 'Your Person';
    final isScreen = call['mode'] == 'screen';

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogCtx) => _IncomingCallDialog(
        partnerName: partnerName,
        isScreenShare: isScreen,
        onAccept: () {
          Navigator.of(dialogCtx).pop();
          _dialogShowing = false;
          if (coupleId == null || !mounted) return;
          Navigator.of(context).push(MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => isScreen
                ? ScreenShareScreen(
                    coupleId: coupleId,
                    callId: call['id'] as String,
                    isSharer: false,
                    partnerName: partnerName,
                  )
                : VideoCallScreen(
                    coupleId: coupleId,
                    callId: call['id'] as String,
                    isCaller: false,
                    partnerName: partnerName,
                  ),
          ));
        },
        onDecline: () {
          Navigator.of(dialogCtx).pop();
          _dialogShowing = false;
          if (coupleId == null) return;
          FirebaseFirestore.instance
              .collection('couples')
              .doc(coupleId)
              .collection('calls')
              .doc(call['id'] as String)
              .update({'status': 'declined'}).ignore();
        },
      ),
    ).then((_) => _dialogShowing = false);
  }

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(accentColorProvider);
    final idx = _currentIndex(context);

    // Keep my presence section in sync with the tab I'm on.
    final section = _tabs[idx].path.substring(1);
    if (section != _mySection) {
      _mySection = section;
      WidgetsBinding.instance.addPostFrameCallback((_) => _writePresence());
    }

    final partnerOnline = ref.watch(partnerOnlineProvider).valueOrNull ?? false;
    final partnerSection = ref.watch(partnerSectionProvider).valueOrNull;
    final partnerAvatar =
        ref.watch(partnerUserProvider).valueOrNull?.avatarUrl;
    final unread = ref.watch(unreadChatCountProvider);
    final partnerTabIdx =
        partnerOnline ? _sectionIndex(partnerSection) : null;

    ref.listen<AsyncValue<String?>>(partnerSectionProvider, (_, next) {
      _onPartnerSectionChanged(next.valueOrNull,
          ref.read(partnerOnlineProvider).valueOrNull ?? false);
    });

    ref.listen<AsyncValue<Map<String, dynamic>?>>(
      incomingCallProvider,
      (_, next) {
        final call = next.valueOrNull;
        if (call != null && !_dialogShowing && mounted) {
          _showIncomingCall(context, call);
        } else if (call == null && _dialogShowing) {
          // Partner cancelled before we answered
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          _dialogShowing = false;
        }
      },
    );

    final currentLocation = GoRouterState.of(context).matchedLocation;
    final atTabRoot = _tabs.any((t) => t.path == currentLocation);

    return PopScope(
      canPop: !atTabRoot,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress(context, currentLocation);
      },
      child: Scaffold(
      body: Stack(
        children: [
          widget.navigationShell,
          const PresenceLayer(),
          const _GiftOverlay(),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.bgMid.withValues(alpha: 0.78),
              AppColors.bgCard.withValues(alpha: 0.68),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(_tabs.length, (i) {
                    final selected = idx == i;
                    return SquishyTap(
                      onTap: () => widget.navigationShell.goBranch(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? accent.withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.35),
                                    blurRadius: 14,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  _tabs[i].icon,
                                  color: selected
                                      ? accent
                                      : AppColors.textMuted,
                                  size: 22,
                                ),
                                // A little "pinned" dot on the active tab —
                                // echoes the push-pin used on memory cards.
                                if (selected)
                                  Positioned(
                                    top: -8,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: Container(
                                        width: 5,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: accent,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                                color: accent.withValues(
                                                    alpha: 0.6),
                                                blurRadius: 4),
                                          ],
                                        ),
                                      ),
                                    ).animate().scale(
                                        begin: const Offset(0, 0),
                                        end: const Offset(1, 1),
                                        duration: 200.ms,
                                        curve: Curves.easeOutBack),
                                  ),
                                // Partner's pfp — shows on the tab they're
                                // in right now, only while online.
                                if (partnerTabIdx == i)
                                  Positioned(
                                    top: -10,
                                    right: -12,
                                    child: _PartnerDot(
                                        avatarUrl: partnerAvatar,
                                        accent: accent),
                                  ),
                                // Unread badge on the Chat tab: 1…4, then 4+
                                if (i == 1 && unread > 0)
                                  Positioned(
                                    top: -8,
                                    left: -14,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: AppColors.rose,
                                        borderRadius:
                                            BorderRadius.circular(9),
                                      ),
                                      child: Text(
                                        unread > 4 ? '4+' : '$unread',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _tabs[i].label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color:
                                    selected ? accent : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
              // Paw prints walking from the partner's old tab to the new one
              if (_pawFrom != null && _pawTo != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: _PawWalk(
                      ctrl: _pawCtrl,
                      fromIdx: _pawFrom!,
                      toIdx: _pawTo!,
                      tabCount: _tabs.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

// ── Partner presence dot (mini pfp on the tab they're in) ─────────────────

class _PartnerDot extends StatelessWidget {
  final String? avatarUrl;
  final Color accent;
  const _PartnerDot({required this.avatarUrl, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 17,
      height: 17,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: accent, width: 1.4),
        color: AppColors.bgCardLight,
        boxShadow: [
          BoxShadow(
              color: accent.withValues(alpha: 0.5), blurRadius: 6),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl != null && avatarUrl!.isNotEmpty
          ? CachedNetworkImage(imageUrl: avatarUrl!, fit: BoxFit.cover)
          : Icon(Icons.favorite_rounded, color: accent, size: 10),
    );
  }
}

// ── Paw walk (partner moved from one section to another) ─────────────────

class _PawWalk extends StatelessWidget {
  final AnimationController ctrl;
  final int fromIdx;
  final int toIdx;
  final int tabCount;

  const _PawWalk({
    required this.ctrl,
    required this.fromIdx,
    required this.toIdx,
    required this.tabCount,
  });

  @override
  Widget build(BuildContext context) {
    const pawCount = 6;
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        final t = ctrl.value;
        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final x0 = w * (fromIdx + 0.5) / tabCount;
            final x1 = w * (toIdx + 0.5) / tabCount;
            final dir = x1 >= x0 ? 1.0 : -1.0;
            return Stack(
              clipBehavior: Clip.none,
              children: List.generate(pawCount, (k) {
                final f = k / (pawCount - 1);
                // Each print appears in sequence, then fades as the next lands.
                final appear = f * 0.55;
                final local = ((t - appear) / 0.45).clamp(0.0, 1.0);
                final opacity = local == 0
                    ? 0.0
                    : (local < 0.3
                            ? local / 0.3
                            : (1 - (local - 0.3) / 0.7)) *
                        0.45;
                if (opacity <= 0) return const SizedBox.shrink();
                final x = x0 + (x1 - x0) * f;
                // Alternate left/right feet like a real walk.
                final side = k.isEven ? -7.0 : 7.0;
                return Positioned(
                  left: x - 11,
                  top: 14 + side,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.rotate(
                      angle: dir * math.pi / 2,
                      child: Image.asset(
                        'assets/images/paw_print.png',
                        width: 22,
                        height: 22,
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        );
      },
    );
  }
}

// ── Gift overlay (wild idea present box → letter) ─────────────────────────

class _GiftOverlay extends ConsumerStatefulWidget {
  const _GiftOverlay();

  @override
  ConsumerState<_GiftOverlay> createState() => _GiftOverlayState();
}

class _GiftOverlayState extends ConsumerState<_GiftOverlay> {
  bool _opening = false;

  Future<void> _openGift(Map<String, dynamic> gift) async {
    if (_opening) return;
    setState(() => _opening = true);
    final coupleId = ref.read(coupleIdProvider);
    final partnerName = ref
            .read(partnerUserProvider)
            .valueOrNull
            ?.displayLabel
            .split(' ')
            .first ??
        'Your person';
    DelightHaptics.crack();
    HeartBombardment.play(context);
    // Consume the signal so it never re-appears.
    if (coupleId != null) {
      ref
          .read(firestoreServiceProvider)
          .deleteSignal(coupleId, gift['id'] as String)
          .ignore();
    }
    final message = (gift['message'] as String?) ?? '♡';
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => _GiftLetterDialog(
          message: message, fromName: partnerName),
    );
    if (mounted) setState(() => _opening = false);
  }

  @override
  Widget build(BuildContext context) {
    final gift = ref.watch(incomingGiftProvider).valueOrNull;
    if (gift == null || _opening) return const SizedBox.shrink();

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: SquishyTap(
            onTap: () => _openGift(gift),
            style: TapAnimationStyle.jelly,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎁', style: TextStyle(fontSize: 110))
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.08, 1.08),
                        duration: 700.ms,
                        curve: Curves.easeInOut)
                    .shake(hz: 2, rotation: 0.03, duration: 1400.ms),
                const SizedBox(height: 18),
                const Text(
                  'A present just for you!',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tap to unwrap ♡',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GiftLetterDialog extends StatelessWidget {
  final String message;
  final String fromName;
  const _GiftLetterDialog({required this.message, required this.fromName});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(26, 30, 26, 24),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8EE),
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
                child: Text('💌', style: TextStyle(fontSize: 34))),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                color: Color(0xFF4A3428),
                fontSize: 17,
                height: 1.6,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '— $fromName ♡',
                style: const TextStyle(
                    color: Color(0xFF8A6A50),
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Keep it forever ♡',
                    style: TextStyle(
                        color: Color(0xFFD4667A),
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    ).animate().scale(
        begin: const Offset(0.7, 0.7),
        curve: Curves.easeOutBack,
        duration: 350.ms);
  }
}

// ── Incoming call dialog ──────────────────────────────────────────────────

class _IncomingCallDialog extends StatefulWidget {
  final String partnerName;
  final bool isScreenShare;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _IncomingCallDialog({
    required this.partnerName,
    this.isScreenShare = false,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<_IncomingCallDialog> createState() => _IncomingCallDialogState();
}

class _IncomingCallDialogState extends State<_IncomingCallDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _startRinging();
  }

  Future<void> _startRinging() async {
    if (await Vibration.hasVibrator()) {
      // ring-ring … pause … repeats while the dialog is up
      Vibration.vibrate(
        pattern: [0, 400, 200, 400, 1200, 400, 200, 400, 1200, 400, 200, 400],
      );
    }
  }

  @override
  void dispose() {
    Vibration.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
        decoration: BoxDecoration(
          color: const Color(0xFF120509),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white12, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD4667A).withValues(alpha: 0.15),
              blurRadius: 40,
              spreadRadius: 8,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: Tween<double>(begin: 0.88, end: 1.0).animate(
                CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
              ),
              child: Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFE8896A), Color(0xFFD4667A)],
                  ),
                ),
                child: Icon(
                    widget.isScreenShare
                        ? Icons.screen_share_rounded
                        : Icons.videocam_rounded,
                    color: Colors.white,
                    size: 38),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.isScreenShare
                  ? 'wants to share their screen'
                  : 'Incoming video call',
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  letterSpacing: 0.8),
            ),
            const SizedBox(height: 6),
            Text(
              widget.partnerName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CallBtn(
                  icon: Icons.call_end_rounded,
                  label: 'Decline',
                  color: const Color(0xFFE53935),
                  onTap: widget.onDecline,
                ),
                _CallBtn(
                  icon: widget.isScreenShare
                      ? Icons.visibility_rounded
                      : Icons.videocam_rounded,
                  label: widget.isScreenShare ? 'Watch' : 'Accept',
                  color: const Color(0xFF43A047),
                  onTap: widget.onAccept,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CallBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CallBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SquishyTap(
      onTap: onTap,
      style: TapAnimationStyle.pulse,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }
}

class _Tab {
  final IconData icon;
  final String label;
  final String path;
  const _Tab({required this.icon, required this.label, required this.path});
}
