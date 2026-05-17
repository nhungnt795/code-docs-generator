// ─────────────────────────────────────────────────────────────────────────────
// app_spacing.dart
// ─────────────────────────────────────────────────────────────────────────────
// Save as: lib/core/tokens/app_spacing.dart

/// 4px base grid — all spacing is a multiple of 4.
class AppSpacing {
  AppSpacing._();
  static const double s1  = 4;
  static const double s2  = 8;
  static const double s3  = 12;
  static const double s4  = 16;
  static const double s5  = 20;
  static const double s6  = 24;
  static const double s8  = 32;
  static const double s10 = 40;
  static const double s12 = 48;
  static const double s16 = 64;

  // Named aliases for readability
  static const double pagePadding      = s6;   // 24px — desktop gutter
  static const double pagePaddingMobile= s4;   // 16px — mobile gutter
  static const double sidebarWidth     = 240;
  static const double sidebarCollapsed = 56;
  static const double topbarHeight     = 56;
  static const double cardPadding      = s4;   // 16px compact
  static const double cardPaddingLg    = s6;   // 24px default
}
