import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Default couple accent — overridden per-couple from Firestore
  static const Color defaultAccent = Color(0xFFE8896A); // warm terracotta
  static const Color warmCream = Color(0xFFFDF6EE);
  static const Color softPeach = Color(0xFFFDE8D8);
  static const Color deepRose = Color(0xFF8B3A52);
  static const Color dustyMauve = Color(0xFFB07C8A);
  static const Color warmGray = Color(0xFF8C7B75);
  static const Color darkBrown = Color(0xFF2C1810);
  static const Color cardSurface = Color(0xFFFFF9F4);
  static const Color divider = Color(0xFFEDD9C8);
}

class AppTheme {
  static ThemeData build(Color accent) {
    final cs = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
      surface: AppColors.warmCream,
      primary: accent,
    ).copyWith(
      surface: AppColors.warmCream,
      surfaceContainerHighest: AppColors.cardSurface,
      onSurface: AppColors.darkBrown,
      outline: AppColors.divider,
    );

    final base = GoogleFonts.latoTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: AppColors.warmCream,
      textTheme: base.copyWith(
        displayLarge: GoogleFonts.playfairDisplay(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.darkBrown,
        ),
        displayMedium: GoogleFonts.playfairDisplay(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.darkBrown,
        ),
        titleLarge: GoogleFonts.playfairDisplay(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.darkBrown,
        ),
        titleMedium: GoogleFonts.lato(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.darkBrown,
        ),
        bodyLarge: GoogleFonts.lato(
          fontSize: 16,
          color: AppColors.darkBrown,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.lato(
          fontSize: 14,
          color: AppColors.warmGray,
          height: 1.5,
        ),
        labelSmall: GoogleFonts.lato(
          fontSize: 11,
          letterSpacing: 0.5,
          color: AppColors.warmGray,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
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
          borderSide: BorderSide(color: accent, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.lato(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: GoogleFonts.lato(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: accent,
        unselectedItemColor: AppColors.warmGray,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.lato(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.lato(fontSize: 11),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.warmCream,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.divider,
        centerTitle: true,
        titleTextStyle: GoogleFonts.playfairDisplay(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.darkBrown,
        ),
        iconTheme: const IconThemeData(color: AppColors.darkBrown),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        space: 1,
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.softPeach,
        labelStyle: GoogleFonts.lato(fontSize: 13, color: AppColors.darkBrown),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

// Predefined couple palette choices
const List<Map<String, dynamic>> kCoupleAccents = [
  {'name': 'Terracotta', 'color': Color(0xFFE8896A)},
  {'name': 'Rose', 'color': Color(0xFFD4688A)},
  {'name': 'Lavender', 'color': Color(0xFF9B7EC8)},
  {'name': 'Sage', 'color': Color(0xFF6A9B7E)},
  {'name': 'Cerulean', 'color': Color(0xFF5B8FB9)},
  {'name': 'Amber', 'color': Color(0xFFCF9E4A)},
];
