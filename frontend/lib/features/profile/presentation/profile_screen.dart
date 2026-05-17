// lib/features/profile/presentation/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_provider.dart';
import '../../../core/tokens/app_colors.dart';
import '../../../core/tokens/app_spacing.dart';
import '../../../core/tokens/app_typography.dart';
import '../../../shared/widgets/dg_button.dart';
import '../../../shared/widgets/dg_card.dart';
import '../../../shared/widgets/dg_input.dart';
import '../../../shared/widgets/dg_misc.dart';
import '../../history/data/history_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  // Cờ cấu hình từ Router (Admin tắt usage stats, đổi title)
  final bool showUsageStats;
  final String title;

  const ProfileScreen({
    super.key,
    this.showUsageStats = true,
    this.title = 'Cài đặt',
  });

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _initialized = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // Đổ dữ liệu từ user state vào controllers (chỉ 1 lần)
  void _initFromUser() {
    if (_initialized) return;
    final user = ref.read(currentUserProvider);
    if (user != null) {
      _nameCtrl.text = user.fullName ?? '';
      _emailCtrl.text = user.email;
      _initialized = true;
    }
  }

  Future<void> _saveProfile() async {
    // Backend chưa có endpoint update profile
    DgToast.show(
      context,
      'Tính năng cập nhật thông tin đang phát triển',
      type: ToastType.info,
    );
  }

  Future<void> _savePassword() async {
    if (_newPassCtrl.text != _confirmCtrl.text) {
      DgToast.show(context, 'Mật khẩu xác nhận không khớp', type: ToastType.error);
      return;
    }
    // Backend chưa có endpoint đổi mật khẩu
    DgToast.show(
      context,
      'Tính năng đổi mật khẩu đang phát triển',
      type: ToastType.info,
    );
  }

  Future<void> _logout() async {
    final confirmed = await DgConfirmDialog.show(
      context,
      title: 'Đăng xuất',
      message: 'Bạn có chắc chắn muốn đăng xuất khỏi hệ thống?',
      confirmLabel: 'Đăng xuất',
      destructive: true,
    );
    if (!confirmed) return;

    // Xóa session khỏi SharedPreferences và reset state
    await ref.read(authProvider.notifier).logout();

    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    _initFromUser();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppColors.fgDark : AppColors.fgLight;
    final muted = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    final user = ref.watch(currentUserProvider);
    final initial = (user?.fullName?.isNotEmpty ?? false)
        ? user!.fullName![0].toUpperCase()
        : (user?.email[0].toUpperCase() ?? 'U');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header với nút Đăng xuất ─────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title,
                          style: AppTypography.h2.copyWith(color: fg)),
                      Text(
                        user != null
                            ? 'Đăng nhập với ${user.email}'
                            : 'Quản lý thông tin tài khoản',
                        style: AppTypography.body.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
                DgButton.secondary(
                  label: 'Đăng xuất',
                  icon: Icons.logout,
                  onPressed: _logout,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s6),

            // ── Profile card ─────────────────────────────────────────────
            DgCard(
              padding: const EdgeInsets.all(AppSpacing.s6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Thông tin cá nhân',
                      style: AppTypography.h4.copyWith(color: fg)),
                  const SizedBox(height: AppSpacing.s5),
                  Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s4),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName ?? user?.email.split('@').first ?? '—',
                            style: AppTypography.bodySemibold.copyWith(color: fg),
                          ),
                          Text(
                            user?.email ?? '—',
                            style: AppTypography.caption.copyWith(color: muted),
                          ),
                          if (user?.isAdmin ?? false) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Quản trị viên',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s5),
                  Divider(color: border),
                  const SizedBox(height: AppSpacing.s5),
                  DgInput(
                    label: 'Họ và tên',
                    controller: _nameCtrl,
                    prefixIcon: Icons.person_outline,
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  DgInput(
                    label: 'Email',
                    controller: _emailCtrl,
                    readOnly: true,
                    helperText: 'Email không thể thay đổi',
                    prefixIcon: Icons.mail_outline,
                  ),
                  const SizedBox(height: AppSpacing.s5),
                  Align(
                    alignment: Alignment.centerRight,
                    child: DgButton.primary(
                      label: 'Lưu thay đổi',
                      onPressed: _saveProfile,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s4),

            // ── Đổi mật khẩu ────────────────────────────────────────────
            DgCard(
              padding: const EdgeInsets.all(AppSpacing.s6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Đổi mật khẩu',
                      style: AppTypography.h4.copyWith(color: fg)),
                  const SizedBox(height: AppSpacing.s5),
                  DgInput.password(
                    label: 'Mật khẩu hiện tại',
                    controller: _oldPassCtrl,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  DgInput.password(
                    label: 'Mật khẩu mới',
                    hint: 'Ít nhất 8 ký tự',
                    controller: _newPassCtrl,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  DgInput.password(
                    label: 'Xác nhận mật khẩu mới',
                    controller: _confirmCtrl,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: AppSpacing.s5),
                  Align(
                    alignment: Alignment.centerRight,
                    child: DgButton.primary(
                      label: 'Đổi mật khẩu',
                      onPressed: _savePassword,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s4),

            // ── Thống kê sử dụng ────────────────────────────────────────
            if (widget.showUsageStats && user != null) ...[
              _UsageStatsCard(user: user, fg: fg, muted: muted, border: border),
              const SizedBox(height: AppSpacing.s4),
            ],

            // ── Vùng nguy hiểm ─────────────────────────────────────────
            DgCard(
              padding: const EdgeInsets.all(AppSpacing.s6),
              backgroundColor: isDark
                  ? const Color(0xFF1C1420)
                  : AppColors.errorSoft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Vùng nguy hiểm',
                      style: AppTypography.h4.copyWith(color: AppColors.error)),
                  const SizedBox(height: AppSpacing.s2),
                  Text(
                    'Xóa tài khoản sẽ xóa toàn bộ dữ liệu và không thể khôi phục.',
                    style: AppTypography.body.copyWith(color: muted),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  DgButton.destructive(
                    label: 'Xóa tài khoản',
                    icon: Icons.delete_forever_outlined,
                    onPressed: () => DgToast.show(
                      context,
                      'Tính năng đang phát triển',
                      type: ToastType.info,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card thống kê (đếm số doc qua history provider) ──────────────────────────
class _UsageStatsCard extends ConsumerWidget {
  final dynamic user;
  final Color fg, muted, border;

  const _UsageStatsCard({
    required this.user,
    required this.fg,
    required this.muted,
    required this.border,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(historyListProvider);
    final docCount = asyncList.maybeWhen(
      data: (list) => list.length,
      orElse: () => 0,
    );

    return DgCard(
      padding: const EdgeInsets.all(AppSpacing.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Thống kê sử dụng',
              style: AppTypography.h4.copyWith(color: fg)),
          const SizedBox(height: AppSpacing.s4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tài liệu đã tạo',
                  style: AppTypography.body.copyWith(color: muted)),
              Text('$docCount',
                  style: AppTypography.bodyMedium.copyWith(color: fg)),
            ],
          ),
          Divider(height: AppSpacing.s4, color: border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Vai trò',
                  style: AppTypography.body.copyWith(color: muted)),
              Text(user.isAdmin ? 'Quản trị viên' : 'Người dùng',
                  style: AppTypography.bodyMedium.copyWith(color: fg)),
            ],
          ),
        ],
      ),
    );
  }
}
