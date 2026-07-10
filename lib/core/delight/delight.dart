// The "living world" layer — haptic identity, floating stickers, signature
// fly-away morphs and seasonal ambience.
//
// Governing rule (the Delight Budget): one delightful thing at a time.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

import '../theme/app_theme.dart';

// ── Haptic identity ───────────────────────────────────────────────────────
// Each meaningful event has its own touch signature, so the app can be
// "read" through the hand alone.

class DelightHaptics {
  DelightHaptics._();

  static Future<void> _pattern(List<int> pattern) async {
    try {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(pattern: pattern);
        return;
      }
    } catch (_) {}
    HapticFeedback.mediumImpact();
  }

  /// Soft lub-dub — thinking of you / partner walked in.
  static Future<void> heartbeat() => _pattern([0, 45, 110, 70]);

  /// A single soft thud — snap landed, memory saved.
  static Future<void> thud() async => HapticFeedback.heavyImpact();

  /// Crisp double tick — a letter sealing / unlocking.
  static Future<void> crack() => _pattern([0, 25, 45, 25]);

  /// Barely-there click for playful taps.
  static Future<void> soft() async => HapticFeedback.selectionClick();
}

// ── Top banner ────────────────────────────────────────────────────────────
// A single little "something happened" banner that drops down from the top
// and can be swiped away to the right. Only ever one on screen: calling
// show() again immediately replaces whatever's already showing instead of
// queueing behind it — the fix for a rapid burst of taps stacking up a pile
// of popups that then play out one after another for the next half minute.

class TopBanner {
  TopBanner._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context, {
    required String emoji,
    required String text,
    Duration duration = const Duration(seconds: 4),
  }) {
    _dismiss();
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    final key = GlobalKey<_TopBannerState>();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _TopBanner(
        key: key,
        emoji: emoji,
        text: text,
        onDismiss: () => _remove(entry),
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(duration, () => key.currentState?.exit());
  }

  static void _dismiss() {
    _timer?.cancel();
    final entry = _entry;
    _entry = null;
    if (entry != null) {
      try {
        entry.remove();
      } catch (_) {}
    }
  }

  static void _remove(OverlayEntry entry) {
    if (_entry == entry) {
      _timer?.cancel();
      _entry = null;
    }
    try {
      entry.remove();
    } catch (_) {}
  }
}

class _TopBanner extends StatefulWidget {
  final String emoji;
  final String text;
  final VoidCallback onDismiss;
  const _TopBanner({
    super.key,
    required this.emoji,
    required this.text,
    required this.onDismiss,
  });

  @override
  State<_TopBanner> createState() => _TopBannerState();
}

class _TopBannerState extends State<_TopBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _ctrl.forward();
  }

  void exit() {
    if (!mounted) return;
    _ctrl.reverse().whenComplete(widget.onDismiss);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) {
          final t = Curves.easeOutBack.transform(_ctrl.value);
          return Opacity(
            opacity: _ctrl.value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, -70 * (1 - t)),
              child: child,
            ),
          );
        },
        child: Dismissible(
          key: const ValueKey('top_banner_swipe'),
          direction: DismissDirection.startToEnd,
          onDismissed: (_) => widget.onDismiss(),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.divider, width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(widget.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(widget.text,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Floating stickers ─────────────────────────────────────────────────────
// A small cluster of emoji that drifts up from a point and fades — the
// reward for a meaningful action. A few particles, never a firework.

class FloatingStickers {
  FloatingStickers._();

  static void burst(
    BuildContext context, {
    List<String> stickers = const ['💗', '✨'],
    int count = 6,
    Offset? origin,
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final n = count;
    final size = MediaQuery.of(context).size;
    final from = origin ?? Offset(size.width / 2, size.height * 0.7);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _StickerBurst(
        origin: from,
        stickers: stickers,
        count: n,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }
}

class _StickerBurst extends StatefulWidget {
  final Offset origin;
  final List<String> stickers;
  final int count;
  final VoidCallback onDone;

  const _StickerBurst({
    required this.origin,
    required this.stickers,
    required this.count,
    required this.onDone,
  });

  @override
  State<_StickerBurst> createState() => _StickerBurstState();
}

class _StickerBurstState extends State<_StickerBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_StickerParticle> _particles;

  @override
  void initState() {
    super.initState();
    final rng = math.Random();
    _particles = List.generate(widget.count, (i) {
      return _StickerParticle(
        emoji: widget.stickers[i % widget.stickers.length],
        dx: (rng.nextDouble() - 0.5) * 120,
        rise: 110 + rng.nextDouble() * 90,
        spin: (rng.nextDouble() - 0.5) * 1.2,
        delay: rng.nextDouble() * 0.25,
        size: 18 + rng.nextDouble() * 10,
      );
    });
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1300))
      ..forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) {
          return Stack(
            children: _particles.map((p) {
              final t =
                  ((_ctrl.value - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
              final eased = Curves.easeOut.transform(t);
              return Positioned(
                left: widget.origin.dx + p.dx * eased - p.size / 2,
                top: widget.origin.dy - p.rise * eased - p.size / 2,
                child: Opacity(
                  opacity: (1 - t).clamp(0.0, 1.0),
                  child: Transform.rotate(
                    angle: p.spin * eased,
                    child: Text(p.emoji,
                        style: TextStyle(fontSize: p.size)),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _StickerParticle {
  final String emoji;
  final double dx;
  final double rise;
  final double spin;
  final double delay;
  final double size;
  _StickerParticle({
    required this.emoji,
    required this.dx,
    required this.rise,
    required this.spin,
    required this.delay,
    required this.size,
  });
}

// ── Heart bombardment ─────────────────────────────────────────────────────
// The whole screen fills with rising hearts — reserved for big shared
// moments (a held thumb kiss). Deliberately over the top.

class HeartBombardment {
  HeartBombardment._();

  static void play(BuildContext context) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _HeartRain(onDone: () => entry.remove()),
    );
    overlay.insert(entry);
  }
}

class _HeartRain extends StatefulWidget {
  final VoidCallback onDone;
  const _HeartRain({required this.onDone});

  @override
  State<_HeartRain> createState() => _HeartRainState();
}

class _HeartRainState extends State<_HeartRain>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_StickerParticle> _hearts;

  @override
  void initState() {
    super.initState();
    const emojis = ['💗', '💕', '❤️', '💞', '💖', '😘'];
    final rng = math.Random();
    _hearts = List.generate(42, (i) {
      return _StickerParticle(
        emoji: emojis[i % emojis.length],
        dx: rng.nextDouble(), // 0–1 horizontal position
        rise: 0.85 + rng.nextDouble() * 0.5, // speed multiplier
        spin: (rng.nextDouble() - 0.5) * 1.6,
        delay: rng.nextDouble() * 0.45,
        size: 22 + rng.nextDouble() * 26,
      );
    });
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2800))
      ..forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) {
          return Stack(
            children: _hearts.map((p) {
              final t =
                  ((_ctrl.value - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
              final y = size.height + 40 -
                  (size.height + 120) * t * p.rise;
              final x = p.dx * size.width +
                  math.sin(t * 5 * math.pi + p.spin * 8) * 22;
              return Positioned(
                left: x,
                top: y,
                child: Opacity(
                  opacity: t > 0.75
                      ? ((1 - t) / 0.25).clamp(0.0, 1.0)
                      : 1.0,
                  child: Transform.rotate(
                    angle: p.spin * t * 2,
                    child:
                        Text(p.emoji, style: TextStyle(fontSize: p.size)),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

// ── Fly-away morph ────────────────────────────────────────────────────────
// A signature "the thing left your phone" moment: an emoji grows from the
// action point, then arcs up and off the screen. Used for sending a letter
// (💌 flies away), a snap, etc.

class FlyAway {
  FlyAway._();

  static void play(BuildContext context, String emoji, {Offset? from}) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    final size = MediaQuery.of(context).size;
    final origin = from ?? Offset(size.width / 2, size.height * 0.75);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _FlyAwayAnim(
        emoji: emoji,
        origin: origin,
        screen: size,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }
}

class _FlyAwayAnim extends StatefulWidget {
  final String emoji;
  final Offset origin;
  final Size screen;
  final VoidCallback onDone;

  const _FlyAwayAnim({
    required this.emoji,
    required this.origin,
    required this.screen,
    required this.onDone,
  });

  @override
  State<_FlyAwayAnim> createState() => _FlyAwayAnimState();
}

class _FlyAwayAnimState extends State<_FlyAwayAnim>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 950))
      ..forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) {
          final t = _ctrl.value;
          // Phase 1 (0–0.3): pop up and grow. Phase 2: arc up-right, shrink, fade.
          final grow = t < 0.3
              ? Curves.easeOutBack.transform(t / 0.3)
              : 1.0 - Curves.easeIn.transform((t - 0.3) / 0.7) * 0.5;
          final fly = t < 0.3 ? 0.0 : Curves.easeIn.transform((t - 0.3) / 0.7);
          final x = widget.origin.dx +
              (widget.screen.width * 0.65 - widget.origin.dx) * fly;
          final y = widget.origin.dy -
              40 * (t < 0.3 ? t / 0.3 : 1.0) -
              (widget.origin.dy + 60) * fly;
          return Positioned(
            left: x - 24,
            top: y - 24,
            child: Opacity(
              opacity: t > 0.85 ? ((1 - t) / 0.15).clamp(0.0, 1.0) : 1.0,
              child: Transform.rotate(
                angle: fly * 0.5,
                child: Transform.scale(
                  scale: 1.6 * grow,
                  child: Text(widget.emoji,
                      style: const TextStyle(fontSize: 30)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Seasons ───────────────────────────────────────────────────────────────
// Ambient seasonal decoration — Indian festivals first. Approximate fixed
// windows; Diwali moves year to year so it gets a generous mid-Oct–mid-Nov
// window rather than an exact date.

enum Season { none, valentines, spring, monsoon, diwali, halloween, christmas }

Season currentSeason([DateTime? when]) {
  final now = when ?? DateTime.now();
  final m = now.month, d = now.day;
  if (m == 2 && d >= 7 && d <= 15) return Season.valentines;
  if (m == 10 && d >= 29) return Season.halloween;
  if ((m == 10 && d >= 15) || (m == 11 && d <= 15)) return Season.diwali;
  if (m == 12 && d >= 15) return Season.christmas;
  if ((m == 6 && d >= 15) || m == 7 || m == 8 || (m == 9 && d <= 15)) {
    return Season.monsoon;
  }
  if (m == 3 || (m == 4 && d <= 15)) return Season.spring;
  return Season.none;
}

const Map<Season, List<String>> kSeasonStickers = {
  Season.valentines: ['💗', '🌹'],
  Season.spring: ['🌸', '🌺'],
  Season.monsoon: ['💧', '☔'],
  Season.diwali: ['🪔', '✨'],
  Season.halloween: ['🎃', '🦇'],
  Season.christmas: ['❄️', '⛄'],
};

/// Slow, low-opacity falling seasonal particles. Purely ambient — used on
/// the home room. Renders nothing outside a season.
class SeasonalDrift extends StatefulWidget {
  const SeasonalDrift({super.key});

  @override
  State<SeasonalDrift> createState() => _SeasonalDriftState();
}

class _SeasonalDriftState extends State<SeasonalDrift>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_DriftFlake> _flakes;

  @override
  void initState() {
    super.initState();
    final season = currentSeason();
    final stickers = kSeasonStickers[season] ?? const <String>[];
    final rng = math.Random();
    _flakes = stickers.isEmpty
        ? const []
        : List.generate(7, (i) {
            return _DriftFlake(
              emoji: stickers[i % stickers.length],
              x: rng.nextDouble(),
              phase: rng.nextDouble(),
              speed: 0.6 + rng.nextDouble() * 0.6,
              sway: 12 + rng.nextDouble() * 18,
              size: 13.0 + rng.nextDouble() * 8,
            );
          });
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 22));
    if (_flakes.isNotEmpty) _ctrl.repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_flakes.isEmpty) return const SizedBox.shrink();
    final size = MediaQuery.of(context).size;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) {
          return Stack(
            children: _flakes.map((f) {
              final t = (_ctrl.value * f.speed + f.phase) % 1.0;
              final y = t * (size.height + 60) - 40;
              final x = f.x * size.width +
                  math.sin(t * 6 * math.pi + f.phase * 10) * f.sway;
              return Positioned(
                left: x,
                top: y,
                child: Opacity(
                  opacity: 0.35,
                  child:
                      Text(f.emoji, style: TextStyle(fontSize: f.size)),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _DriftFlake {
  final String emoji;
  final double x;
  final double phase;
  final double speed;
  final double sway;
  final double size;
  _DriftFlake({
    required this.emoji,
    required this.x,
    required this.phase,
    required this.speed,
    required this.sway,
    required this.size,
  });
}
