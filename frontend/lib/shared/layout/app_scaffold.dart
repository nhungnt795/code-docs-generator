// lib/shared/layout/app_scaffold.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/tokens/app_colors.dart';
import '../../core/tokens/app_spacing.dart';
import '../../core/utils/responsive.dart';
import 'sidebar_nav.dart';
import 'topbar.dart';
import 'bottom_nav_bar.dart';

// ── Hàm hỗ trợ lấy danh sách Menu ────────────────────────────────────────────
List<(IconData, String, String)> _navItemsFor(bool isAdmin) => isAdmin
    ? [
  (Icons.bar_chart_outlined, '/', 'Dashboard'),
  (Icons.people_outline, '/users', 'Người dùng'),
  (Icons.settings_outlined, '/profile', 'Cài đặt'),
]
    : [
  (Icons.bolt_outlined, '/generate', 'Sinh tài liệu'),
  (Icons.history_outlined, '/history', 'Lịch sử'),
  (Icons.person_outline, '/profile', 'Cài đặt'),
];

// ── Hàm hỗ trợ tìm Index đang được chọn ───────────────────────────────────────
int _getSelectedIndex(String location, List<(IconData, String, String)> items) {
  int bestMatchIndex = 0;
  int longestMatchLength = -1;

  for (int i = 0; i < items.length; i++) {
    final path = items[i].$2;
    // So khớp path hiện tại với path của menu (ưu tiên path dài nhất, ví dụ '/admin/users' thay vì '/')
    if ((location == path || (path != '/' && location.startsWith(path))) && path.length > longestMatchLength) {
      longestMatchLength = path.length;
      bestMatchIndex = i;
    }
  }
  return bestMatchIndex;
}

// ════════════════════════════════════════════════════════════════════════════
// AppShell Main Wrapper
// ════════════════════════════════════════════════════════════════════════════
class AppShell extends ConsumerWidget {
  final String location;
  final Widget child;
  final bool isAdmin;
  final String? pageTitle;
  final List<String>? breadcrumbs;
  final List<Widget>? topbarActions;

  const AppShell({
    super.key,
    required this.location,
    required this.child,
    this.isAdmin = false,
    this.pageTitle,
    this.breadcrumbs,
    this.topbarActions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = _navItemsFor(isAdmin);
    final idx = _getSelectedIndex(location, items);

    return switch (Responsive.of(context)) {
      ScreenSize.desktop => _DesktopShell(
          child: child, isAdmin: isAdmin, items: items, idx: idx),
      ScreenSize.tablet => _TabletShell(
          child: child, isAdmin: isAdmin, items: items, idx: idx),
      ScreenSize.mobile => _MobileShell(
          child: child, isAdmin: isAdmin, items: items, idx: idx),
    };
  }
}

// ── Desktop (Sidebar đầy đủ) ─────────────────────────────────────────────────
class _DesktopShell extends StatelessWidget {
  final Widget child;
  final bool isAdmin;
  final List<(IconData, String, String)> items;
  final int idx;

  const _DesktopShell({
    required this.child,
    required this.isAdmin,
    required this.items,
    required this.idx,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SidebarNav(
            selectedIndex: idx,
            isAdmin: isAdmin,
            collapsed: false,
            onItemTap: (i) => context.go(items[i].$2),
          ),
          Expanded(
            child: Column(
              children: [
                TopBar(
                  selectedIndex: idx,
                  isAdmin: isAdmin,
                  showMenuButton: false,
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tablet (NavigationRail) ──────────────────────────────────────────────────
class _TabletShell extends StatelessWidget {
  final Widget child;
  final bool isAdmin;
  final List<(IconData, String, String)> items;
  final int idx;

  const _TabletShell({
    required this.child,
    required this.isAdmin,
    required this.items,
    required this.idx,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: AppSpacing.sidebarCollapsed,
            decoration: BoxDecoration(
              color: bg,
              border: Border(right: BorderSide(color: border)),
            ),
            child: NavigationRail(
              backgroundColor: Colors.transparent,
              selectedIndex: idx,
              labelType: NavigationRailLabelType.none,
              minWidth: AppSpacing.sidebarCollapsed,
              onDestinationSelected: (i) => context.go(items[i].$2),
              selectedIconTheme: const IconThemeData(color: AppColors.primary, size: 20),
              unselectedIconTheme: IconThemeData(
                color: isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight,
                size: 20,
              ),
              indicatorColor: AppColors.primarySoft,
              destinations: items
                  .map((item) => NavigationRailDestination(
                icon: Icon(item.$1),
                label: Text(item.$3),
              ))
                  .toList(),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                TopBar(
                  selectedIndex: idx,
                  isAdmin: isAdmin,
                  showMenuButton: false,
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mobile (BottomNav) ───────────────────────────────────────────────────────
class _MobileShell extends StatelessWidget {
  final Widget child;
  final bool isAdmin;
  final List<(IconData, String, String)> items;
  final int idx;

  const _MobileShell({
    required this.child,
    required this.isAdmin,
    required this.items,
    required this.idx,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: TopBar(
          selectedIndex: idx,
          isAdmin: isAdmin,
          showMenuButton: true,
        ),
      ),
      body: child,
      bottomNavigationBar: DgBottomNavBar(
        selectedIndex: idx,
        isAdmin: isAdmin,
        onTap: (i) => context.go(items[i].$2),
      ),
    );
  }
}