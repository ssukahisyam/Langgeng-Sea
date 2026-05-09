/// Spacing, radius, and size tokens for Langgeng Sea.
/// Base unit: 4px. Pattern: geometric progression.
class AppSizes {
  AppSizes._();

  // Spacing (base 4)
  static const double sp1 = 4;
  static const double sp2 = 8;
  static const double sp3 = 12;
  static const double sp4 = 16;
  static const double sp5 = 20;
  static const double sp6 = 24;
  static const double sp8 = 32;
  static const double sp10 = 40;
  static const double sp12 = 48;

  // Radius
  static const double radiusSm = 12;
  static const double radiusMd = 18;
  static const double radiusLg = 24;
  static const double radiusXl = 28;
  static const double radius2xl = 32;
  static const double radiusPill = 999;

  // Blur amounts for glass
  static const double blurGlass1 = 16;
  static const double blurGlass2 = 24;
  static const double blurGlass3 = 32;

  // Touch targets (weatherproof UX per PRD NFR-03)
  static const double touchTargetMin = 48;
  static const double touchTargetPrimary = 60;
  static const double touchTargetCritical = 72; // MULAI TEBAR, ANGKAT TRAWL

  // Screen padding
  static const double screenPaddingPhone = 20;
  static const double screenPaddingTablet = 24;
}
