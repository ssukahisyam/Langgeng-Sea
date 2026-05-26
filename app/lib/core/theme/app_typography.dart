import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography for Styra using Plus Jakarta Sans.
/// Tabular numerals enabled for metrics (distance, speed, area).
class AppTypography {
  AppTypography._();

  static const List<FontFeature> _tabularFeatures = [
    FontFeature.tabularFigures(),
  ];

  static TextTheme textTheme(Color textColor, Color secondaryColor) {
    final base = GoogleFonts.plusJakartaSansTextTheme();
    return base.copyWith(
      // Display (hero stats)
      displayLarge: GoogleFonts.plusJakartaSans(
        fontSize: 46,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.5,
        height: 1.0,
        color: textColor,
        fontFeatures: _tabularFeatures,
      ),
      displayMedium: GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        height: 1.15,
        color: textColor,
        fontFeatures: _tabularFeatures,
      ),
      displaySmall: GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.2,
        color: textColor,
        fontFeatures: _tabularFeatures,
      ),

      // Headlines
      headlineLarge: GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.25,
        color: textColor,
      ),
      headlineMedium: GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: textColor,
      ),
      headlineSmall: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: textColor,
      ),

      // Titles (card title)
      titleLarge: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      titleSmall: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),

      // Body
      bodyLarge: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: textColor,
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: textColor,
      ),
      bodySmall: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: secondaryColor,
      ),

      // Labels (button, caption)
      labelLarge: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: textColor,
      ),
      labelMedium: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      labelSmall: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
        color: secondaryColor,
      ),
    );
  }

  /// Special style for metric values - always tabular for no-jitter live update.
  static TextStyle metric({
    required Color color,
    double size = 22,
    FontWeight weight = FontWeight.w800,
  }) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: -0.3,
        fontFeatures: _tabularFeatures,
      );
}
