// lib/shared/layout/topbar.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/tokens/app_colors.dart';
import '../../core/tokens/app_typography.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';

const _memberTitles = ['Sinh tài liệu', 'Lịch sử', 'Cài đặt'];
const _adminTitles  = ['Dashboard', 'Người dùng', 'Cài đặt'];

class TopBar extends ConsumerStatefulWidget {
  final int selectedIndex;
  final bool isAdmin;
  final bool showMenuButton;

  const TopBar({
    super.key,
    required this.selectedIndex,
    this.isAdmin = false,
    this.showMenuButton = false,
  });

  @override
  ConsumerState<TopBar> createState() => _TopBarState();
}

class _TopBarState extends ConsumerState<TopBar> {
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final themeMode  = ref.watch(themeModeProvider);
    final isMobile   = Responsive.isMobile(context);

    // XÁC ĐỊNH TRẠNG THÁI THỰC TẾ:
    // Nếu là system -> lấy theo brightness của context.
    // Nếu không -> lấy theo state của provider.
    final bool isActuallyDark = themeMode == ThemeMode.system
        ? brightness == Brightness.dark
        : themeMode == ThemeMode.dark;

    final bg     = AppColors.card(brightness);
    final border = AppColors.border(brightness);
    final fg     = AppColors.fg(brightness);
    final subtle = AppColors.fgSubtle(brightness);

    final titles = widget.isAdmin ? _adminTitles : _memberTitles;
    final title  = titles.elementAtOrNull(widget.selectedIndex) ?? '';

    return AnimatedContainer(
      duration: AppTheme.themeTransitionDuration,
      curve: AppTheme.themeCurve,
      color: bg,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      if (isMobile)
                        const _AppLogo()
                      else ...[
                        if (widget.showMenuButton)
                          IconButton(
                            icon: const Icon(Icons.menu, size: 20),
                            onPressed: () => Scaffold.of(context).openDrawer(),
                          ),
                        _Breadcrumb(title: title, fg: fg, subtle: subtle),
                      ],

                      const Spacer(),

                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _TopBarIconBtn(
                            // Hiển thị icon Mặt trời nếu App đang tối (để chuyển sang sáng) và ngược lại
                            icon: isActuallyDark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined,
                            onTap: () => ref.read(themeModeProvider.notifier).toggle(isActuallyDark),
                            brightness: brightness,
                          ),
                          const SizedBox(width: 8),
                          const _TopBarAvatar(),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, color: border),
            ],
          ),
        ),
      ),
    );
  }
}

// ... (Giữ nguyên các widget _AppLogo, _TopBarAvatar, _Breadcrumb, _TopBarIconBtn bên dưới)
class _AppLogo extends StatelessWidget {
  const _AppLogo();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
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
        const SizedBox(width: 10),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
            children: const [
              TextSpan(text: 'DocGen'),
              TextSpan(
                text: ' VN',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopBarAvatar extends StatelessWidget {
  const _TopBarAvatar();

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go('/profile'),
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(9999),
          ),
          alignment: Alignment.center,
          child: Text(
            'DV',
            style: AppTypography.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  final String title;
  final Color fg, subtle;
  const _Breadcrumb({required this.title, required this.fg, required this.subtle});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('DocGen VN', style: AppTypography.bodySmall.copyWith(color: subtle)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.chevron_right, size: 14, color: subtle),
        ),
        Text(title, style: AppTypography.bodySmall.copyWith(color: fg, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _TopBarIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Brightness brightness;
  const _TopBarIconBtn({required this.icon, required this.onTap, required this.brightness});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: AppColors.fgSubtle(brightness)),
      ),
    );
  }
}