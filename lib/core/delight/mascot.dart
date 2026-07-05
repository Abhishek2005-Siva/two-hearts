// The companion mascot — one small creature that lives at the screen edge.
// It idles (breathes, dozes at night), occasionally peeks or hops, and
// briefly reacts to real events (a new message from your partner). It is
// suppressed while typing, never covers content, and Calm Mode puts it
// permanently to sleep.
import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import 'delight.dart';

enum _MascotAction { none, hop, tilt, peek, react }

class MascotOverlay extends ConsumerStatefulWidget {
  const MascotOverlay({super.key});

  @override
  ConsumerState<MascotOverlay> createState() => _MascotOverlayState();
}

class _MascotOverlayState extends ConsumerState<MascotOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _breath;
  late final AnimationController _action;
  final _rng = math.Random();

  _MascotAction _current = _MascotAction.none;
  String? _bubble; // tiny speech bubble content ('❤️', '!', '💤')
  Timer? _idleTimer;
  Timer? _bubbleTimer;
  String? _lastMsgId;
  bool _seededMessages = false;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat(reverse: true);
    _action = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _scheduleIdle();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _bubbleTimer?.cancel();
    _breath.dispose();
    _action.dispose();
    super.dispose();
  }

  bool get _isNight {
    final h = DateTime.now().hour;
    return h >= 22 || h < 6;
  }

  void _scheduleIdle() {
    _idleTimer?.cancel();
    // Occasional, not constant — 20–45 s between idle antics.
    _idleTimer = Timer(Duration(seconds: 20 + _rng.nextInt(25)), () {
      if (!mounted) return;
      final calm = ref.read(calmModeProvider);
      final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
      if (!calm && !keyboardOpen && _current == _MascotAction.none) {
        if (_isNight && _rng.nextBool()) {
          _showBubble('💤', const Duration(seconds: 4));
        } else {
          _play([_MascotAction.hop, _MascotAction.tilt, _MascotAction.peek]
              [_rng.nextInt(3)]);
        }
      }
      _scheduleIdle();
    });
  }

  void _play(_MascotAction action) {
    setState(() => _current = action);
    _action.duration = action == _MascotAction.peek
        ? const Duration(milliseconds: 1600)
        : const Duration(milliseconds: 700);
    _action.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _current = _MascotAction.none);
    });
  }

  void _showBubble(String text, [Duration for_ = const Duration(seconds: 2)]) {
    _bubbleTimer?.cancel();
    setState(() => _bubble = text);
    _bubbleTimer = Timer(for_, () {
      if (mounted) setState(() => _bubble = null);
    });
  }

  void _onPartnerEvent(String bubble) {
    if (ref.read(calmModeProvider)) return;
    if (MediaQuery.of(context).viewInsets.bottom > 0) return;
    _showBubble(bubble);
    _play(_MascotAction.react);
  }

  void _onTap() {
    DelightHaptics.soft();
    _showBubble('♡');
    _play(_MascotAction.hop);
    final size = MediaQuery.of(context).size;
    FloatingStickers.burst(context,
        stickers: const ['💗', '✨'],
        count: 4,
        origin: Offset(size.width - 46, size.height - 140));
  }

  @override
  Widget build(BuildContext context) {
    final calm = ref.watch(calmModeProvider);
    final pet = ref.watch(mascotPetProvider);
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    // React when the partner's newest message arrives.
    ref.listen(messagesProvider, (_, next) {
      final msgs = next.valueOrNull;
      if (msgs == null || msgs.isEmpty) return;
      final last = msgs.last;
      if (!_seededMessages) {
        // Don't react to history on first load.
        _seededMessages = true;
        _lastMsgId = last.id;
        return;
      }
      if (last.id == _lastMsgId) return;
      _lastMsgId = last.id;
      final myUid = FirebaseAuth.instance.currentUser?.uid;
      if (myUid != null && last.senderId != myUid) _onPartnerEvent('❤️');
    });

    // Per-page personality: sleepier on chat, livelier at home. The resting
    // spot also shifts per page so it never sits on top of buttons — above
    // the chat input row, above the polaroid strip at home.
    final loc = GoRouterState.of(context).matchedLocation;
    final sleepy = loc.startsWith('/chat');
    final double restBottom = loc.startsWith('/chat')
        ? 150
        : loc.startsWith('/room')
            ? 210
            : 6;

    return Positioned(
      right: 10,
      bottom: restBottom,
      child: IgnorePointer(
        ignoring: keyboardOpen,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: keyboardOpen ? 0.0 : (calm ? 0.45 : 1.0),
          child: GestureDetector(
            onTap: calm ? null : _onTap,
            child: SizedBox(
              width: 64,
              height: 78,
              child: AnimatedBuilder(
                animation: Listenable.merge([_breath, _action]),
                builder: (_, _) {
                  final t = _action.value;
                  double dy = 0, dx = 0, angle = 0;
                  switch (_current) {
                    case _MascotAction.hop:
                    case _MascotAction.react:
                      // Two quick bounces.
                      dy = -math.sin(t * math.pi * 2).abs() * 14;
                      break;
                    case _MascotAction.tilt:
                      angle = math.sin(t * math.pi) * 0.28;
                      break;
                    case _MascotAction.peek:
                      // Slide half off the right edge and back.
                      dx = math.sin(t * math.pi) * 34;
                      break;
                    case _MascotAction.none:
                      break;
                  }
                  final breathScale =
                      1.0 + (sleepy || calm ? 0.015 : 0.04) * _breath.value;
                  return Transform.translate(
                    offset: Offset(dx, dy),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_bubble != null || calm || (sleepy && _isNight))
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            margin: const EdgeInsets.only(bottom: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _bubble ?? '💤',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        Transform.rotate(
                          angle: angle,
                          child: Transform.scale(
                            scale: breathScale,
                            child: Text(
                              pet,
                              style: TextStyle(
                                fontSize: 34,
                                shadows: [
                                  Shadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.35),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
