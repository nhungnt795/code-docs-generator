import 'package:flutter/material.dart';

/// Breakpoints:
///   Mobile  < 600px  → BottomNavigationBar
///   Tablet  600-1023px → NavigationRail (collapsed sidebar 56px)
///   Desktop ≥ 1024px → Sidebar 240px full
enum ScreenSize { mobile, tablet, desktop }

class Responsive {
  Responsive._();

  static ScreenSize of(BuildContext ctx) {
    final w = MediaQuery.sizeOf(ctx).width;
    if (w < 600)  return ScreenSize.mobile;
    if (w < 1024) return ScreenSize.tablet;
    return ScreenSize.desktop;
  }

  static bool isMobile(BuildContext ctx)  => of(ctx) == ScreenSize.mobile;
  static bool isTablet(BuildContext ctx)  => of(ctx) == ScreenSize.tablet;
  static bool isDesktop(BuildContext ctx) => of(ctx) == ScreenSize.desktop;

  /// true khi tablet hoặc desktop (dùng để ẩn bottom nav)
  static bool isWide(BuildContext ctx) => of(ctx) != ScreenSize.mobile;

  /// Gutter: 24px desktop, 16px mobile
  static double gutter(BuildContext ctx) =>
      isDesktop(ctx) ? 24.0 : 16.0;

  /// Content max-width theo design system
  static const double contentMax = 1440;
  static const double readingMax = 760;
}

/// Extension tiện lợi — dùng: context.screenSize, context.isMobile
extension ResponsiveContext on BuildContext {
  ScreenSize get screenSize   => Responsive.of(this);
  bool get isMobile           => Responsive.isMobile(this);
  bool get isTablet           => Responsive.isTablet(this);
  bool get isDesktop          => Responsive.isDesktop(this);
  bool get isWide             => Responsive.isWide(this);
  double get gutter           => Responsive.gutter(this);
}
