import 'package:flutter/material.dart';

/// Color tokens for Langgeng Sea - Clean Liquid Glass design system.
/// Ported from prototype/styles.css to Flutter.
class AppColors {
  AppColors._();

  // =========================================================
  // LIGHT MODE
  // =========================================================
  static const Color lightPrimary = Color(0xFF0277BD);
  static const Color lightPrimaryHover = Color(0xFF0288D1);
  static const Color lightPrimarySoft = Color(0xFFE1F5FE);

  static const Color lightAccent = Color(0xFFFF6F00);
  static const Color lightAccentSoft = Color(0xFFFFF3E0);

  static const Color lightSuccess = Color(0xFF2E7D32);
  static const Color lightDanger = Color(0xFFD32F2F);
  static const Color lightWarning = Color(0xFFF9A825);

  static const Color lightBg = Color(0xFFF4F8FB);
  static const Color lightBgGradientStart = Color(0xFFE8F4FA);
  static const Color lightBgGradientEnd = Color(0xFFF9FBFD);

  // Glass surfaces (semi-transparent)
  static const Color lightSurface1 = Color(0x99FFFFFF); // 0.60
  static const Color lightSurface2 = Color(0xB8FFFFFF); // 0.72
  static const Color lightSurface3 = Color(0xD9FFFFFF); // 0.85
  static const Color lightSurfaceSolid = Color(0xFFFFFFFF);

  static const Color lightBorder = Color(0x140F172A); // rgba(15,23,42,0.08)
  static const Color lightBorderStrong = Color(0x240F172A); // 0.14
  static const Color lightDivider = Color(0x0F0F172A); // 0.06

  static const Color lightText = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextTertiary = Color(0xFF94A3B8);
  static const Color lightTextOnPrimary = Color(0xFFFFFFFF);

  // =========================================================
  // DARK MODE
  // =========================================================
  static const Color darkPrimary = Color(0xFF4FC3F7);
  static const Color darkPrimaryHover = Color(0xFF81D4FA);
  static const Color darkPrimarySoft = Color(0x1F4FC3F7); // 0.12

  static const Color darkAccent = Color(0xFFFFB74D);
  static const Color darkAccentSoft = Color(0x1FFFB74D); // 0.12

  static const Color darkSuccess = Color(0xFF66BB6A);
  static const Color darkDanger = Color(0xFFEF5350);
  static const Color darkWarning = Color(0xFFFFD54F);

  static const Color darkBg = Color(0xFF050B18);
  static const Color darkBgGradientStart = Color(0xFF0A1628);
  static const Color darkBgGradientEnd = Color(0xFF050B18);

  // Glass surfaces
  static const Color darkSurface1 = Color(0x0AFFFFFF); // 0.04
  static const Color darkSurface2 = Color(0x0FFFFFFF); // 0.06
  static const Color darkSurface3 = Color(0x1AFFFFFF); // 0.10
  static const Color darkSurfaceSolid = Color(0xFF0F1B2E);

  static const Color darkBorder = Color(0x14FFFFFF); // 0.08
  static const Color darkBorderStrong = Color(0x29FFFFFF); // 0.16
  static const Color darkDivider = Color(0x0FFFFFFF); // 0.06

  static const Color darkText = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);
  static const Color darkTextTertiary = Color(0xFF64748B);
  static const Color darkTextOnPrimary = Color(0xFFFFFFFF);

  // =========================================================
  // Haul colors (for distinguishing multiple hauls on map)
  // =========================================================
  static const List<Color> haulColors = [
    Color(0xFF0277BD), // Primary blue
    Color(0xFFFF6F00), // Accent orange
    Color(0xFF2E7D32), // Green
    Color(0xFF6A1B9A), // Purple
    Color(0xFFC62828), // Red
    Color(0xFF00838F), // Teal
    Color(0xFFE65100), // Deep orange
    Color(0xFF283593), // Indigo
    Color(0xFF4E342E), // Brown
    Color(0xFF546E7A), // Blue grey
  ];

  /// Get deterministic color for haul by order index (1-based).
  static Color colorForHaul(int orderIndex) {
    return haulColors[(orderIndex - 1) % haulColors.length];
  }
}

/// Linear gradients used throughout the app.
class AppGradients {
  AppGradients._();

  static const LinearGradient primaryLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0288D1), Color(0xFF0277BD)],
  );

  static const LinearGradient primaryDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4FC3F7), Color(0xFF29B6F6)],
  );

  static const LinearGradient accentLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF8F00), Color(0xFFFF6F00)],
  );

  static const LinearGradient accentDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFB74D), Color(0xFFFFA726)],
  );

  static const LinearGradient successLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF43A047), Color(0xFF2E7D32)],
  );

  static const LinearGradient successDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
  );

  static const LinearGradient dangerLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE53935), Color(0xFFC62828)],
  );

  static const LinearGradient dangerDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEF5350), Color(0xFFE53935)],
  );

  static const LinearGradient ambientLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE8F4FA), Color(0xFFF9FBFD)],
  );

  static const LinearGradient ambientDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0A1628), Color(0xFF050B18)],
  );
}
