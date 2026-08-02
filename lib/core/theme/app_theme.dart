import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../delight/delight.dart';
import 'comfort_settings.dart';

class AppColors {
  static const Color defaultAccent = Color(0xFFFF6B8A);

  // Dark romantic palette
  static const Color bg = Color(0xFF12060E);
  static const Color bgMid = Color(0xFF1E0F1A);
  static const Color bgCard = Color(0xFF2A1422);
  static const Color bgCardLight = Color(0xFF341C2C);
  static const Color surface = Color(0xFF3D2035);

  // Accents
  static const Color rose = Color(0xFFFF6B8A);
  static const Color coral = Color(0xFFFF8C42);
  static const Color gold = Color(0xFFFFD166);
  static const Color lavender = Color(0xFFB8A0D9);

  // Text
  static const Color textPrimary = Color(0xFFFDF0F5);
  static const Color textSecondary = Color(0xFFAA8899);
  static const Color textMuted = Color(0xFF6B4D5E);

  // Divider
  static const Color divider = Color(0xFF3D2035);

  // Gradient stops
  static const List<Color> bgGradient = [Color(0xFF1A0810), Color(0xFF0D0408)];
  static const List<Color> accentGradient = [Color(0xFFFF6B8A), Color(0xFFFF8C42)];
  static const List<Color> cardGradient = [Color(0xFF2E1525), Color(0xFF1E0F1A)];

  // ── Light-mode palette ──────────────────────────────────────────────────
  // A genuinely light theme (previous "light" mode was a hardcoded dark-plum
  // variant that never actually got brighter than dark mode) — warm cream
  // background, the same rose/coral/gold family read as accents on a light
  // surface instead of a dark one.
  static const Color lightBg = Color(0xFFFDF6F3);
  static const Color lightBgMid = Color(0xFFFBEEE9);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCardAlt = Color(0xFFFFF3EE);
  static const Color lightTextPrimary = Color(0xFF3A2230);
  static const Color lightTextSecondary = Color(0xFF7A5A66);
  static const Color lightTextMuted = Color(0xFFAE8C96);
  static const Color lightDivider = Color(0xFFF0DDD5);
  static const List<Color> lightBgGradient = [Color(0xFFFFF8F5), Color(0xFFFBEAE3)];
}

class AppTheme {
  static ThemeData get darkTheme => build(AppColors.defaultAccent);
  static ThemeData get lightTheme => build(AppColors.defaultAccent, brightness: Brightness.light);

  /// Single theme factory for both brightnesses — [accent] always comes
  /// from the couple's chosen color (`accentColorProvider`) so light mode
  /// picks it up too, unlike the old hand-duplicated `lightTheme` getter
  /// which was hardcoded to `AppColors.defaultAccent` regardless of what
  /// the couple had actually picked.
  static ThemeData build(Color accent, {Brightness brightness = Brightness.dark}) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? AppColors.bg : AppColors.lightBg;
    final bgMid = isDark ? AppColors.bgMid : AppColors.lightBgMid;
    final card = isDark ? AppColors.bgCard : AppColors.lightCard;
    final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final divider = isDark ? AppColors.divider : AppColors.lightDivider;
    final onPrimary = Colors.white;
    final onSurface = textPrimary;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: accent,
              secondary: AppColors.coral,
              surface: card,
              onPrimary: onPrimary,
              onSurface: onSurface,
              outline: divider,
            )
          : ColorScheme.light(
              primary: accent,
              secondary: AppColors.coral,
              surface: card,
              onPrimary: onPrimary,
              onSurface: onSurface,
              outline: divider,
            ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.playfairDisplay(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          height: 1.1,
        ),
        displayMedium: GoogleFonts.playfairDisplay(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        titleLarge: GoogleFonts.playfairDisplay(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: GoogleFonts.lato(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: 0.2,
        ),
        bodyLarge: GoogleFonts.lato(
          fontSize: 16,
          color: textPrimary,
          height: 1.6,
        ),
        bodyMedium: GoogleFonts.lato(
          fontSize: 14,
          color: textSecondary,
          height: 1.5,
        ),
        labelSmall: GoogleFonts.lato(
          fontSize: 11,
          letterSpacing: 1.2,
          color: textMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: divider, width: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        hintStyle: TextStyle(color: textMuted),
        labelStyle: TextStyle(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: isDark ? Colors.white : textPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.playfairDisplay(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      dividerTheme: DividerThemeData(color: divider, space: 1, thickness: 0.5),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? bgMid : card,
        selectedItemColor: accent,
        unselectedItemColor: textMuted,
      ),
    );
  }
}

const List<Map<String, dynamic>> kCoupleAccents = [
  {'name': 'Rose', 'color': Color(0xFFFF6B8A)},
  {'name': 'Coral', 'color': Color(0xFFFF8C42)},
  {'name': 'Lavender', 'color': Color(0xFFB8A0D9)},
  {'name': 'Sage', 'color': Color(0xFF6FBFA0)},
  {'name': 'Blue', 'color': Color(0xFF5B9BD5)},
  {'name': 'Gold', 'color': Color(0xFFFFD166)},
];

// Reusable gradient button — squishes like jelly when pressed 🍮
class GradientButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final double width;
  // See SquishyTap.cuteStickers — same playful jump-burst accent.
  final List<String>? cuteStickers;

  const GradientButton({
    super.key,
    required this.label,
    this.onTap,
    this.loading = false,
    this.width = double.infinity,
    this.cuteStickers,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    // Press → shrink; release → overshoot back like jelly.
    _scale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.93)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 25),
      TweenSequenceItem(
          tween: Tween(begin: 0.93, end: 1.0)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 75),
    ]).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.loading || widget.onTap == null) return;
    HapticFeedback.lightImpact();
    final reduceMotion = isReduceMotion(context);
    if (!reduceMotion) _ctrl.forward(from: 0);
    final stickers = widget.cuteStickers;
    if (!reduceMotion && stickers != null && stickers.isNotEmpty) {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final origin = box.localToGlobal(box.size.center(Offset.zero));
        FloatingStickers.burst(context, stickers: stickers, count: 3, origin: origin);
      }
    }
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: widget.width,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent, AppColors.coral],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: widget.loading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(
                    widget.label,
                    style: GoogleFonts.lato(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Distinct tap-animation "personalities" [SquishyTap] can play — one
/// consistent, tested set reused across the app rather than one-off
/// bespoke implementations per button (which would fight the delight
/// layer's own "one delightful thing at a time" rule at app-wide scale).
/// All of them are pure Transform math (scale/rotate/translate only, no
/// shape- or decoration-dependent effects like glows/shadows), so every
/// variant is safe to drop onto a child of any shape.
enum TapAnimationStyle {
  /// The original: a small dip-and-squish, mechanical-key feel. Default.
  squish,
  /// Bigger overshoot — shrink, pop past full size, settle. Good for
  /// primary/completing actions (send, save, give, post).
  bounce,
  /// A quick rotational wiggle. Good for playful/cosmetic taps (cards,
  /// stickers, wildcards).
  wobble,
  /// One smooth emphasis pulse, slower and softer than bounce. Good for
  /// toggles and selectors.
  pulse,
  /// Non-uniform squash-stretch, like a jelly wobble. Good for anything
  /// meant to feel extra soft/cute (mood pills, gift buttons).
  jelly,
  /// A quick double-thump scale, echoing a heartbeat. Reserve for the
  /// app's actual love-themed actions (heart/like/send-love buttons).
  heartBeat,
  /// A full rotation spin. Good for refresh/shuffle/randomize actions.
  spin,
  /// A horizontal shake. Good for destructive/decline actions (remove,
  /// delete, decline) — signals "careful" rather than "yay".
  shake,
}

/// Wrap ANY widget to give it a playful tap animation — [style] picks
/// which personality plays; defaults to the original squish so every
/// existing call site is unaffected.
class SquishyTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  // When set, a couple of these emoji "jump" up from the widget and fade
  // out on tap — a light, playful accent for primary actions. Keep it to
  // the app's real delightful moments, not every single tap everywhere.
  final List<String>? cuteStickers;
  final TapAnimationStyle style;

  const SquishyTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.cuteStickers,
    this.style = TapAnimationStyle.squish,
  });

  @override
  State<SquishyTap> createState() => _SquishyTapState();
}

class _SquishyTapState extends State<SquishyTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _scaleY;
  // A mechanical-key feel — the button dips down (or shakes side to side,
  // for `shake`) as it plays, like it's being pressed into the surface.
  late Animation<double> _dip;
  late Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _duration);
    _scale = const AlwaysStoppedAnimation(1.0);
    _scaleY = const AlwaysStoppedAnimation(1.0);
    _dip = const AlwaysStoppedAnimation(0.0);
    _rotation = const AlwaysStoppedAnimation(0.0);
    _buildAnimations();
  }

  Duration get _duration => switch (widget.style) {
        TapAnimationStyle.bounce => const Duration(milliseconds: 380),
        TapAnimationStyle.heartBeat => const Duration(milliseconds: 500),
        TapAnimationStyle.shake => const Duration(milliseconds: 400),
        TapAnimationStyle.spin => const Duration(milliseconds: 420),
        TapAnimationStyle.pulse => const Duration(milliseconds: 380),
        _ => const Duration(milliseconds: 300),
      };

  void _buildAnimations() {
    switch (widget.style) {
      case TapAnimationStyle.squish:
        _scale = TweenSequence<double>([
          TweenSequenceItem(
              tween: Tween(begin: 1.0, end: 0.95).chain(CurveTween(curve: Curves.easeOut)),
              weight: 30),
          TweenSequenceItem(
              tween: Tween(begin: 0.95, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
              weight: 70),
        ]).animate(_ctrl);
        _dip = TweenSequence<double>([
          TweenSequenceItem(
              tween: Tween(begin: 0.0, end: 2.5).chain(CurveTween(curve: Curves.easeOut)),
              weight: 30),
          TweenSequenceItem(
              tween: Tween(begin: 2.5, end: 0.0).chain(CurveTween(curve: Curves.elasticOut)),
              weight: 70),
        ]).animate(_ctrl);
      case TapAnimationStyle.bounce:
        _scale = TweenSequence<double>([
          TweenSequenceItem(
              tween: Tween(begin: 1.0, end: 0.85).chain(CurveTween(curve: Curves.easeOut)),
              weight: 25),
          TweenSequenceItem(
              tween: Tween(begin: 0.85, end: 1.12).chain(CurveTween(curve: Curves.easeOut)),
              weight: 35),
          TweenSequenceItem(
              tween: Tween(begin: 1.12, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
              weight: 40),
        ]).animate(_ctrl);
      case TapAnimationStyle.wobble:
        _rotation = TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.09), weight: 20),
          TweenSequenceItem(tween: Tween(begin: -0.09, end: 0.09), weight: 30),
          TweenSequenceItem(tween: Tween(begin: 0.09, end: -0.045), weight: 25),
          TweenSequenceItem(tween: Tween(begin: -0.045, end: 0.0), weight: 25),
        ]).chain(CurveTween(curve: Curves.easeOut)).animate(_ctrl);
      case TapAnimationStyle.pulse:
        _scale = TweenSequence<double>([
          TweenSequenceItem(
              tween: Tween(begin: 1.0, end: 1.14).chain(CurveTween(curve: Curves.easeOut)),
              weight: 45),
          TweenSequenceItem(
              tween: Tween(begin: 1.14, end: 1.0).chain(CurveTween(curve: Curves.easeInOutCubic)),
              weight: 55),
        ]).animate(_ctrl);
      case TapAnimationStyle.jelly:
        _scale = TweenSequence<double>([
          TweenSequenceItem(
              tween: Tween(begin: 1.0, end: 1.18).chain(CurveTween(curve: Curves.easeOut)),
              weight: 25),
          TweenSequenceItem(
              tween: Tween(begin: 1.18, end: 0.9).chain(CurveTween(curve: Curves.easeInOut)),
              weight: 35),
          TweenSequenceItem(
              tween: Tween(begin: 0.9, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
              weight: 40),
        ]).animate(_ctrl);
        _scaleY = TweenSequence<double>([
          TweenSequenceItem(
              tween: Tween(begin: 1.0, end: 0.85).chain(CurveTween(curve: Curves.easeOut)),
              weight: 25),
          TweenSequenceItem(
              tween: Tween(begin: 0.85, end: 1.12).chain(CurveTween(curve: Curves.easeInOut)),
              weight: 35),
          TweenSequenceItem(
              tween: Tween(begin: 1.12, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
              weight: 40),
        ]).animate(_ctrl);
      case TapAnimationStyle.heartBeat:
        _scale = TweenSequence<double>([
          TweenSequenceItem(
              tween: Tween(begin: 1.0, end: 1.16).chain(CurveTween(curve: Curves.easeOut)),
              weight: 15),
          TweenSequenceItem(
              tween: Tween(begin: 1.16, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
              weight: 15),
          TweenSequenceItem(
              tween: Tween(begin: 1.0, end: 1.22).chain(CurveTween(curve: Curves.easeOut)),
              weight: 15),
          TweenSequenceItem(
              tween: Tween(begin: 1.22, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
              weight: 55),
        ]).animate(_ctrl);
      case TapAnimationStyle.spin:
        _rotation = Tween<double>(begin: 0.0, end: 2 * math.pi)
            .chain(CurveTween(curve: Curves.easeOutCubic))
            .animate(_ctrl);
      case TapAnimationStyle.shake:
        _dip = TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: -6.0), weight: 12),
          TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 20),
          TweenSequenceItem(tween: Tween(begin: 6.0, end: -4.0), weight: 20),
          TweenSequenceItem(tween: Tween(begin: -4.0, end: 4.0), weight: 20),
          TweenSequenceItem(tween: Tween(begin: 4.0, end: 0.0), weight: 28),
        ]).animate(_ctrl);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _isHorizontalShake => widget.style == TapAnimationStyle.shake;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              final reduceMotion = isReduceMotion(context);
              if (!reduceMotion) _ctrl.forward(from: 0);
              final stickers = widget.cuteStickers;
              if (!reduceMotion && stickers != null && stickers.isNotEmpty) {
                final box = context.findRenderObject() as RenderBox?;
                if (box != null && box.hasSize) {
                  final origin = box.localToGlobal(box.size.center(Offset.zero));
                  FloatingStickers.burst(context, stickers: stickers, count: 3, origin: origin);
                }
              }
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Transform.translate(
          offset: _isHorizontalShake ? Offset(_dip.value, 0) : Offset(0, _dip.value),
          child: Transform.rotate(
            angle: _rotation.value,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(_scale.value, _scaleY.value, 1.0),
              child: child,
            ),
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

// Glassmorphism card
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double radius;
  final Color? borderColor;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 24,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.cardGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? AppColors.divider,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
