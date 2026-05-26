import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// ThemeData for Styra - Clean Liquid Glass.
/// Contains light + dark variants, plus helpers to access custom tokens.
class AppTheme {
  AppTheme._();

  // =========================================================
  // LIGHT THEME
  // =========================================================
  static ThemeData light() {
    const colorScheme = ColorScheme.light(
      primary: AppColors.lightPrimary,
      onPrimary: AppColors.lightTextOnPrimary,
      secondary: AppColors.lightAccent,
      onSecondary: AppColors.lightTextOnPrimary,
      error: AppColors.lightDanger,
      onError: AppColors.lightTextOnPrimary,
      surface: AppColors.lightSurfaceSolid,
      onSurface: AppColors.lightText,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.lightBg,
      textTheme: AppTypography.textTheme(
        AppColors.lightText,
        AppColors.lightTextSecondary,
      ),
      iconTheme: const IconThemeData(
        color: AppColors.lightTextSecondary,
        size: 24,
      ),
      dividerColor: AppColors.lightDivider,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.lightText),
        titleTextStyle: AppTypography.textTheme(
          AppColors.lightText,
          AppColors.lightTextSecondary,
        ).headlineSmall,
      ),
      extensions: const <ThemeExtension<dynamic>>[_lightTokens],
    );
  }

  // =========================================================
  // DARK THEME
  // =========================================================
  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      primary: AppColors.darkPrimary,
      onPrimary: AppColors.darkTextOnPrimary,
      secondary: AppColors.darkAccent,
      onSecondary: AppColors.darkTextOnPrimary,
      error: AppColors.darkDanger,
      onError: AppColors.darkTextOnPrimary,
      surface: AppColors.darkSurfaceSolid,
      onSurface: AppColors.darkText,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.darkBg,
      textTheme: AppTypography.textTheme(
        AppColors.darkText,
        AppColors.darkTextSecondary,
      ),
      iconTheme: const IconThemeData(
        color: AppColors.darkTextSecondary,
        size: 24,
      ),
      dividerColor: AppColors.darkDivider,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.darkText),
        titleTextStyle: AppTypography.textTheme(
          AppColors.darkText,
          AppColors.darkTextSecondary,
        ).headlineSmall,
      ),
      extensions: const <ThemeExtension<dynamic>>[_darkTokens],
    );
  }

  static const _lightTokens = LangTokens(
    surface1: AppColors.lightSurface1,
    surface2: AppColors.lightSurface2,
    surface3: AppColors.lightSurface3,
    border: AppColors.lightBorder,
    borderStrong: AppColors.lightBorderStrong,
    textSecondary: AppColors.lightTextSecondary,
    textTertiary: AppColors.lightTextTertiary,
    primarySoft: AppColors.lightPrimarySoft,
    accentSoft: AppColors.lightAccentSoft,
    success: AppColors.lightSuccess,
    danger: AppColors.lightDanger,
    warning: AppColors.lightWarning,
    primaryGradient: AppGradients.primaryLight,
    accentGradient: AppGradients.accentLight,
    successGradient: AppGradients.successLight,
    dangerGradient: AppGradients.dangerLight,
    ambientGradient: AppGradients.ambientLight,
    glowPrimary: Color(0x59027DB8), // primary with alpha for shadow
    shadowMd: Color(0x140F172A),
  );

  static const _darkTokens = LangTokens(
    surface1: AppColors.darkSurface1,
    surface2: AppColors.darkSurface2,
    surface3: AppColors.darkSurface3,
    border: AppColors.darkBorder,
    borderStrong: AppColors.darkBorderStrong,
    textSecondary: AppColors.darkTextSecondary,
    textTertiary: AppColors.darkTextTertiary,
    primarySoft: AppColors.darkPrimarySoft,
    accentSoft: AppColors.darkAccentSoft,
    success: AppColors.darkSuccess,
    danger: AppColors.darkDanger,
    warning: AppColors.darkWarning,
    primaryGradient: AppGradients.primaryDark,
    accentGradient: AppGradients.accentDark,
    successGradient: AppGradients.successDark,
    dangerGradient: AppGradients.dangerDark,
    ambientGradient: AppGradients.ambientDark,
    glowPrimary: Color(0x404FC3F7),
    shadowMd: Color(0x66000000),
  );
}

/// Custom tokens not covered by Material's ColorScheme.
/// Access via: `Theme.of(context).extension<LangTokens>()!`
class LangTokens extends ThemeExtension<LangTokens> {
  const LangTokens({
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.border,
    required this.borderStrong,
    required this.textSecondary,
    required this.textTertiary,
    required this.primarySoft,
    required this.accentSoft,
    required this.success,
    required this.danger,
    required this.warning,
    required this.primaryGradient,
    required this.accentGradient,
    required this.successGradient,
    required this.dangerGradient,
    required this.ambientGradient,
    required this.glowPrimary,
    required this.shadowMd,
  });

  final Color surface1;
  final Color surface2;
  final Color surface3;
  final Color border;
  final Color borderStrong;
  final Color textSecondary;
  final Color textTertiary;
  final Color primarySoft;
  final Color accentSoft;
  final Color success;
  final Color danger;
  final Color warning;
  final LinearGradient primaryGradient;
  final LinearGradient accentGradient;
  final LinearGradient successGradient;
  final LinearGradient dangerGradient;
  final LinearGradient ambientGradient;
  final Color glowPrimary;
  final Color shadowMd;

  @override
  ThemeExtension<LangTokens> copyWith() => this;

  @override
  ThemeExtension<LangTokens> lerp(
    covariant ThemeExtension<LangTokens>? other,
    double t,
  ) {
    // Not animating between themes for simplicity (instant switch).
    return this;
  }
}

/// Convenience accessor.
extension LangTokensContext on BuildContext {
  LangTokens get tokens => Theme.of(this).extension<LangTokens>()!;

  /// Shortcut for common theme values.
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  Brightness get brightness => Theme.of(this).brightness;
  bool get isDark => brightness == Brightness.dark;
}
