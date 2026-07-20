import 'package:flutter/material.dart';

/// Which of the three character asset sets to draw from — the two
/// original partner illustrations ("Asher" / "Wren") or their combined
/// two-person poses ("combo"). These are real commissioned artwork
/// (`assets/characters/`), not procedurally drawn like [MascotCreature].
enum CoupleCharacterId { asher, wren, combo }

/// Displays one named pose for a character (e.g. `asher` + `idle` loads
/// `assets/characters/asher_idle.png`), crossfading smoothly whenever
/// [pose] changes. Each screen picks its own character/pose/trigger —
/// see CLAUDE.md's "Couple character placements" note for the full map
/// of where each pose is used and why.
class CoupleCharacter extends StatelessWidget {
  final CoupleCharacterId character;
  final String pose;
  final double height;
  final VoidCallback? onTap;

  const CoupleCharacter({
    super.key,
    required this.character,
    required this.pose,
    this.height = 120,
    this.onTap,
  });

  String get _assetPath => 'assets/characters/${character.name}_$pose.png';

  @override
  Widget build(BuildContext context) {
    final image = AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween(begin: 0.92, end: 1.0).animate(anim),
          child: child,
        ),
      ),
      child: Image.asset(
        _assetPath,
        key: ValueKey(_assetPath),
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );
    if (onTap == null) return image;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: image);
  }
}

/// Wraps a [CoupleCharacter] (or anything) with the same gentle idle
/// breathing bob used by [MascotCreature], for placements that sit still
/// on screen for a while (e.g. Room) rather than appearing only briefly
/// for one triggered moment.
class BobbingCharacter extends StatefulWidget {
  final Widget child;
  const BobbingCharacter({super.key, required this.child});

  @override
  State<BobbingCharacter> createState() => _BobbingCharacterState();
}

class _BobbingCharacterState extends State<BobbingCharacter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -(Curves.easeInOut.transform(_ctrl.value) * 3)),
        child: child,
      ),
      child: widget.child,
    );
  }
}
