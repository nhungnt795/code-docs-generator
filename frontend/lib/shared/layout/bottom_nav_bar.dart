import 'package:flutter/material.dart';
import '../../core/tokens/app_colors.dart';
import '../../core/tokens/app_typography.dart';

class _BottomItem {
  final String label;
  final IconData icon;
  final IconData iconActive;
  const _BottomItem(this.label, this.icon, this.iconActive);
}

const _memberItems = [
  _BottomItem('Sinh tài liệu', Icons.bolt_outlined,     Icons.bolt),
  _BottomItem('Lịch sử',       Icons.history,            Icons.history),
  _BottomItem('Cài đặt',       Icons.settings_outlined,  Icons.settings),
];

const _adminItems = [
  _BottomItem('Dashboard',  Icons.bar_chart_outlined, Icons.bar_chart),
  _BottomItem('Người dùng', Icons.people_outline,     Icons.people),
  _BottomItem('Cài đặt',    Icons.settings_outlined,  Icons.settings),
];

/// Bottom navigation bar cho mobile
/// Design: 1px top border, không dùng Material elevation
class DgBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final bool isAdmin;
  final ValueChanged<int> onTap;

  const DgBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final items = isAdmin ? _adminItems : _memberItems;
    final bg    = AppColors.card(brightness);
    final brd   = AppColors.border(brightness);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: brd, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: items.asMap().entries.map((e) {
              final selected = selectedIndex == e.key;
              return Expanded(
                child: _BottomTab(
                  item: e.value,
                  selected: selected,
                  onTap: () => onTap(e.key),
                  brightness: brightness,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _BottomTab extends StatelessWidget {
  final _BottomItem item;
  final bool selected;
  final VoidCallback onTap;
  final Brightness brightness;

  const _BottomTab({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppColors.primary
        : AppColors.fgSubtle(brightness);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Icon(
              selected ? item.iconActive : item.icon,
              key: ValueKey(selected),
              size: 22,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.label,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
