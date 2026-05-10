import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/tokens/app_colors.dart';
import '../../core/tokens/app_typography.dart';
import '../../core/theme/app_theme.dart';

class _NavItem {
  final String label;
  final IconData icon;
  final int? count;
  const _NavItem(this.label, this.icon, {this.count});
}

const _memberNav = [
  _NavItem('Sinh tài liệu', Icons.bolt_outlined),
  _NavItem('Lịch sử',       Icons.history),
  _NavItem('Cài đặt',       Icons.settings_outlined),
];

const _adminNav = [
  _NavItem('Dashboard',     Icons.bar_chart_outlined),
  _NavItem('Người dùng',    Icons.people_outline),
  _NavItem('Cài đặt',       Icons.settings_outlined),
];

class SidebarNav extends ConsumerWidget {
  final int selectedIndex;
  final bool isAdmin;
  final bool collapsed;
  final ValueChanged<int> onItemTap;
  final VoidCallback? onToggleCollapse;

  const SidebarNav({
    super.key,
    required this.selectedIndex,
    required this.collapsed,
    required this.onItemTap,
    this.isAdmin = false,
    this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final items = isAdmin ? _adminNav : _memberNav;
    final bg     = AppColors.card(brightness);
    final border = AppColors.border(brightness);

    return AnimatedContainer(
      duration: AppTheme.themeTransitionDuration,
      curve: AppTheme.themeCurve,
      width: collapsed ? 64.0 : 240.0,
      decoration: BoxDecoration(
        color: bg,
        border: Border(right: BorderSide(color: border)),
      ),
      child: Column(
        children: [
          _Brand(collapsed: collapsed),
          Divider(height: 1, color: border),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Column(
                children: items.asMap().entries.map((e) => _NavTile(
                  item: e.value,
                  selected: selectedIndex == e.key,
                  collapsed: collapsed,
                  onTap: () => onItemTap(e.key),
                  brightness: brightness,
                )).toList(),
              ),
            ),
          ),
          Divider(height: 1, color: border),
          _SidebarBottom(
            collapsed: collapsed,
            onToggleCollapse: onToggleCollapse,
            brightness: brightness,
          ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  final bool collapsed;
  const _Brand({required this.collapsed});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.code, color: Colors.white, size: 16),
            ),
            if (!collapsed) ...[
              const SizedBox(width: 10),
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                  children: const [
                    TextSpan(text: 'DocGen'),
                    TextSpan(text: ' VN', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;
  final Brightness brightness;

  const _NavTile({required this.item, required this.selected, required this.collapsed, required this.onTap, required this.brightness});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.fgMuted(brightness);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppTheme.themeTransitionDuration,
        padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: collapsed
            ? Center(child: Icon(item.icon, size: 20, color: color))
            : Row(
          children: [
            Icon(item.icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(item.label, style: AppTypography.bodySmall.copyWith(color: color, fontWeight: selected ? FontWeight.w600 : FontWeight.w500))),
          ],
        ),
      ),
    );
  }
}

class _SidebarBottom extends StatelessWidget {
  final bool collapsed;
  final VoidCallback? onToggleCollapse;
  final Brightness brightness;
  const _SidebarBottom({required this.collapsed, required this.onToggleCollapse, required this.brightness});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
              child: Row(
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(9999)),
                    alignment: Alignment.center,
                    child: Text('DV', style: AppTypography.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dev User', style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                        Text('dev@docgenvn.com', style: AppTypography.caption.copyWith(color: AppColors.fgSubtle(brightness))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (onToggleCollapse != null)
            IconButton(
              icon: Icon(collapsed ? Icons.keyboard_double_arrow_right : Icons.keyboard_double_arrow_left, size: 16),
              onPressed: onToggleCollapse,
            ),
        ],
      ),
    );
  }
}