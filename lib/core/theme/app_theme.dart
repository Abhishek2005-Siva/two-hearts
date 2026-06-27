import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Time-of-Day ambient theme ─────────────────────────────────────────────

class RoomTod {
  static final _breakpoints = <int, List<Color>>{
    0:  [const Color(0xFF050215), const Color(0xFF04021A)],   // midnight: deep indigo
    5:  [const Color(0xFF0D1535), const Color(0xFF080A22)],   // dawn: cool blue
    8:  [const Color(0xFF1A0E28), const Color(0xFF0F0818)],   // morning: soft purple
    11: [const Color(0xFF130A14), const Color(0xFF0D0810)],   // midday: warm neutral
    17: [const Color(0xFF1C0A00), const Color(0xFF120808)],   // golden hour: amber
    19: [const Color(0xFF160610), const Color(0xFF0E0610)],   // dusk
    21: [const Color(0xFF08041A), const Color(0xFF060315)],   // night: indigo
  };

  static List<Color> bgGradient(DateTime now) {
    final h = now.hour;
    int prevKey = 0;
    for (final key in _breakpoints.keys) {
      if (h >= key) prevKey = key;
    }
    return _breakpoints[prevKey]!;
  }

  // Tinted overlay for the ceiling/sky zone
  static Color skyCeiling(DateTime now) {
    final h = now.hour;
    if (h >= 5 && h < 8)  return const Color(0x200D1535);   // dawn blue
    if (h >= 8 && h < 11) return const Color(0x181A0E28);   // morning purple
    if (h >= 11 && h < 17) return const Color(0x0AFFF5E0);  // midday warm
    if (h >= 17 && h < 20) return const Color(0x28FF7A00);  // golden amber
    if (h >= 20 && h < 22) return const Color(0x18200010);  // dusk deep
    return const Color(0x250D0630);                          // night indigo
  }

  // Glow brightness multiplier (1.0 = normal, >1.0 = brighter when partner online)
  static double glow(DateTime now) {
    final h = now.hour;
    if (h >= 10 && h < 18) return 1.0;
    if (h >= 6  && h < 10) return 0.85;
    if (h >= 18 && h < 21) return 0.9;
    return 0.70;
  }

  static String label(DateTime now) {
    final h = now.hour;
    if (h >= 5  && h < 9)  return 'dawn';
    if (h >= 9  && h < 17) return 'day';
    if (h >= 17 && h < 20) return 'dusk';
    return 'night';
  }
}

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
}

class AppTheme {
  static ThemeData build(Color accent) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: ColorScheme.dark(
        primary: accent,
        secondary: AppColors.coral,
        surface: AppColors.bgCard,
        onPrimary: Colors.white,
        onSurface: AppColors.textPrimary,
        outline: AppColors.divider,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.playfairDisplay(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          height: 1.1,
        ),
        displayMedium: GoogleFonts.playfairDisplay(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        titleLarge: GoogleFonts.playfairDisplay(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleMedium: GoogleFonts.lato(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          letterSpacing: 0.2,
        ),
        bodyLarge: GoogleFonts.lato(
          fontSize: 16,
          color: AppColors.textPrimary,
          height: 1.6,
        ),
        bodyMedium: GoogleFonts.lato(
          fontSize: 14,
          color: AppColors.textSecondary,
          height: 1.5,
        ),
        labelSmall: GoogleFonts.lato(
          fontSize: 11,
          letterSpacing: 1.2,
          color: AppColors.textMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgCard,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.divider),
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
          foregroundColor: Colors.white,
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
          color: AppColors.textPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.divider, space: 1, thickness: 0.5),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.bgMid,
        selectedItemColor: accent,
        unselectedItemColor: AppColors.textMuted,
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

// Reusable gradient button
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final double width;

  const GradientButton({
    super.key,
    required this.label,
    this.onTap,
    this.loading = false,
    this.width = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: width,
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
          child: loading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(
                  label,
                  style: GoogleFonts.lato(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
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
