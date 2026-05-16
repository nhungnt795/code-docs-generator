// lib/shared/layout/topbar.dart
//
// FIX:
// 1. Logo (mobile) có thể click → context.go('/') về landing
// 2. _adminTitles thêm 'Model AI' (đồng bộ với adminNav 4 mục)
// 3. _TopBarAvatar watch currentUserProvider → đồng bộ khi đổi avatar/tên

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_config.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/tokens/app_colors.dart';
import '../../core/tokens/app_typography.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';

const _memberTitles = ['Sinh tài liệu', 'Lịch sử', 'Cài đặt'];
// Đồng bộ với _adminNav 4 mục: Dashboard / Người dùng / Model AI / Cài đặt
const _adminTitles = ['Dashboard', 'Người dùng', 'Model AI', 'Phản hồi', 'Cài đặt'];

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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      if (isMobile)
                        // Logo mobile có thể click về landing
                        GestureDetector(
                          onTap: () => context.go('/'),
                          child: const _AppLogo(),
                        )
                      else ...[
                        if (widget.showMenuButton)
                          IconButton(
                            icon: const Icon(Icons.menu, size: 20),
                            onPressed: () =>
                                Scaffold.of(context).openDrawer(),
                          ),
                        _Breadcrumb(
                            title: title, fg: fg, subtle: subtle),
                      ],
                      const Spacer(),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _TopBarIconBtn(
                            icon: isActuallyDark
                                ? Icons.wb_sunny_outlined
                                : Icons.dark_mode_outlined,
                            onTap: () => ref
                                .read(themeModeProvider.notifier)
                                .toggle(isActuallyDark),
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

// ─────────────────────────────────────────────────────────────────────────────
class _AppLogo extends StatelessWidget {
  const _AppLogo();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.auto_awesome,
              color: Colors.white, size: 16),
        ),
        const SizedBox(width: 10),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
            children: const [
              TextSpan(text: 'DocGen'),
              TextSpan(
                text: ' VN',
                style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatar topbar — watch currentUserProvider → đồng bộ ngay khi đổi avatar/tên
// ─────────────────────────────────────────────────────────────────────────────
class _TopBarAvatar extends ConsumerWidget {
  const _TopBarAvatar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final avatarUrl = user?.avatarUrl;
    final fullUrl = (avatarUrl != null && avatarUrl.isNotEmpty)
        ? (avatarUrl.startsWith('http')
            ? avatarUrl
            : '${ApiConfig.baseUrl}/$avatarUrl')
        : null;

    final initial = () {
      if (user?.fullName != null && user!.fullName!.trim().isNotEmpty) {
        return user.fullName![0].toUpperCase();
      }
      if (user?.email.isNotEmpty == true) {
        return user!.email[0].toUpperCase();
      }
      return 'U';
    }();

    return Tooltip(
      message: user?.fullName ?? user?.email ?? 'Tài khoản',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => context.go('/profile'),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(9999),
            ),
            clipBehavior: Clip.antiAlias,
            child: fullUrl != null
                ? Image.network(
                    fullUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _InitialAvatar(initial: initial),
                  )
                : _InitialAvatar(initial: initial),
          ),
        ),
      ),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  final String initial;
  const _InitialAvatar({required this.initial});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      color: AppColors.primary.withOpacity(0.15),
      child: Text(
        initial,
        style: AppTypography.caption.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _Breadcrumb extends StatelessWidget {
  final String title;
  final Color fg, subtle;
  const _Breadcrumb(
      {required this.title, required this.fg, required this.subtle});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo text click → landing
        GestureDetector(
          onTap: () => context.go('/'),
          child: Text(
            'DocGen VN',
            style: AppTypography.bodySmall.copyWith(color: subtle),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.chevron_right, size: 14, color: subtle),
        ),
        Text(
          title,
          style: AppTypography.bodySmall
              .copyWith(color: fg, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _TopBarIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Brightness brightness;
  const _TopBarIconBtn(
      {required this.icon,
      required this.onTap,
      required this.brightness});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        child: Icon(icon, size: 18,
            color: AppColors.fgSubtle(brightness)),
      ),
    );
  }
}
