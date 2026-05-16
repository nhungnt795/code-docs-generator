// lib/shared/layout/app_scaffold.dart
// Admin nav: Dashboard / Người dùng / Model AI / Phản hồi / Cài đặt

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/tokens/app_colors.dart';
import '../../core/tokens/app_spacing.dart';
import '../../core/utils/responsive.dart';
import 'sidebar_nav.dart';
import 'topbar.dart';
import 'bottom_nav_bar.dart';

List<(IconData, String, String)> _navItemsFor(bool isAdmin) => isAdmin
    ? [
        (Icons.bar_chart_outlined,   '/',         'Dashboard'),
        (Icons.people_outline,       '/users',    'Người dùng'),
        (Icons.smart_toy_outlined,   '/models',   'Model AI'),
        (Icons.star_outline,         '/feedback', 'Phản hồi'),
        (Icons.settings_outlined,    '/profile',  'Cài đặt'),
      ]
    : [
        (Icons.bolt_outlined,        '/generate', 'Sinh tài liệu'),
        (Icons.history_outlined,     '/history',  'Lịch sử'),
        (Icons.person_outline,       '/profile',  'Cài đặt'),
      ];

int _getSelectedIndex(
    String location, List<(IconData, String, String)> items) {
  int bestIdx = 0;
  int bestLen = -1;
  for (int i = 0; i < items.length; i++) {
    final path = items[i].$2;
    if ((location == path ||
            (path != '/' && location.startsWith(path))) &&
        path.length > bestLen) {
      bestLen = path.length;
      bestIdx = i;
    }
  }
  return bestIdx;
}

class AppShell extends ConsumerWidget {
  final String location;
  final Widget child;
  final bool isAdmin;
  final String? pageTitle;

  const AppShell({
    super.key,
    required this.location,
    required this.child,
    this.isAdmin = false,
    this.pageTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = _navItemsFor(isAdmin);
    final idx   = _getSelectedIndex(location, items);

    return switch (Responsive.of(context)) {
      ScreenSize.desktop => _DesktopShell(child: child, isAdmin: isAdmin, items: items, idx: idx),
      ScreenSize.tablet  => _TabletShell(child: child,  isAdmin: isAdmin, items: items, idx: idx),
      ScreenSize.mobile  => _MobileShell(child: child,  isAdmin: isAdmin, items: items, idx: idx),
    };
  }
}

class _DesktopShell extends StatelessWidget {
  final Widget child; final bool isAdmin;
  final List<(IconData, String, String)> items; final int idx;
  const _DesktopShell({required this.child, required this.isAdmin, required this.items, required this.idx});

  @override Widget build(BuildContext context) {
    return Scaffold(body: Row(children: [
      SidebarNav(selectedIndex: idx, isAdmin: isAdmin, collapsed: false,
          onItemTap: (i) => context.go(items[i].$2)),
      Expanded(child: Column(children: [
        TopBar(selectedIndex: idx, isAdmin: isAdmin, showMenuButton: false),
        Expanded(child: child),
      ])),
    ]));
  }
}

class _TabletShell extends StatelessWidget {
  final Widget child; final bool isAdmin;
  final List<(IconData, String, String)> items; final int idx;
  const _TabletShell({required this.child, required this.isAdmin, required this.items, required this.idx});

  @override Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bg      = isDark ? AppColors.cardDark  : AppColors.cardLight;
    final border  = isDark ? AppColors.borderDark : AppColors.borderLight;
    return Scaffold(body: Row(children: [
      Container(
        width: AppSpacing.sidebarCollapsed,
        decoration: BoxDecoration(color: bg, border: Border(right: BorderSide(color: border))),
        child: NavigationRail(
          backgroundColor: Colors.transparent,
          selectedIndex: idx,
          labelType: NavigationRailLabelType.none,
          minWidth: AppSpacing.sidebarCollapsed,
          onDestinationSelected: (i) => context.go(items[i].$2),
          selectedIconTheme: const IconThemeData(color: AppColors.primary, size: 20),
          unselectedIconTheme: IconThemeData(
              color: isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight, size: 20),
          indicatorColor: AppColors.primarySoft,
          destinations: items.map((item) =>
              NavigationRailDestination(icon: Icon(item.$1), label: Text(item.$3))).toList(),
        ),
      ),
      Expanded(child: Column(children: [
        TopBar(selectedIndex: idx, isAdmin: isAdmin, showMenuButton: false),
        Expanded(child: child),
      ])),
    ]));
  }
}

class _MobileShell extends StatelessWidget {
  final Widget child; final bool isAdmin;
  final List<(IconData, String, String)> items; final int idx;
  const _MobileShell({required this.child, required this.isAdmin, required this.items, required this.idx});

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: TopBar(selectedIndex: idx, isAdmin: isAdmin, showMenuButton: true),
      ),
      body: child,
      bottomNavigationBar: DgBottomNavBar(
          selectedIndex: idx, isAdmin: isAdmin, onTap: (i) => context.go(items[i].$2)),
    );
  }
}
