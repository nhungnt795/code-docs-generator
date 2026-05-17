// lib/features/profile/presentation/profile_screen.dart
//
// FIX:
// 1. _saveProfile và _savePassword gọi API thật → cập nhật authProvider
// 2. Avatar upload cập nhật lại user state → sidebar/topbar tự đồng bộ
// 3. Form phản hồi (feedback) ngay tại trang này
// 4. SingleChildScrollView bao toàn bộ để tránh overflow

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/api/models.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/tokens/app_colors.dart';
import '../../../core/tokens/app_spacing.dart';
import '../../../core/tokens/app_typography.dart';
import '../../../shared/widgets/dg_button.dart';
import '../../../shared/widgets/dg_card.dart';
import '../../../shared/widgets/dg_input.dart';
import '../../../shared/widgets/dg_misc.dart';
import '../../history/data/history_repository.dart';
import '../data/profile_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
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
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confPassCtrl= TextEditingController();

  // Feedback
  int _rating = 5;
  final _feedbackCtrl = TextEditingController();

  bool _initialized    = false;
  bool _savingProfile  = false;
  bool _savingPassword = false;
  bool _uploadingAvatar= false;
  bool _sendingFeedback= false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confPassCtrl.dispose();
    _feedbackCtrl.dispose();
    super.dispose();
  }

  void _initFromUser() {
    if (_initialized) return;
    final user = ref.read(currentUserProvider);
    if (user != null) {
      _nameCtrl.text  = user.fullName ?? '';
      _emailCtrl.text = user.email;
      _initialized    = true;
    }
  }

  // ── Avatar ────────────────────────────────────────────────────────────────
  Future<void> _pickAvatar() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (img == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final bytes = await img.readAsBytes();
      final user  = ref.read(currentUserProvider)!;
      final updatedUser = await ref
          .read(profileRepoProvider)
          .uploadAvatar(user.userId, bytes, img.name);

      // Cập nhật user trong authProvider để sidebar/topbar đồng bộ
      await ref.read(authProvider.notifier).updateUser(updatedUser);

      if (mounted) {
        DgToast.show(context, 'Cập nhật ảnh đại diện thành công',
            type: ToastType.success);
      }
    } on ApiException catch (e) {
      if (mounted) DgToast.show(context, e.message, type: ToastType.error);
    } catch (e) {
      if (mounted) DgToast.show(context, 'Lỗi: $e', type: ToastType.error);
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  // ── Profile ───────────────────────────────────────────────────────────────
  Future<void> _saveProfile() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _savingProfile = true);
    try {
      final updated = await ref.read(profileRepoProvider).updateProfile(
            userId: user.userId,
            fullName: _nameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
          );
      await ref.read(authProvider.notifier).updateUser(updated);
      if (mounted) {
        DgToast.show(context, 'Đã cập nhật thông tin', type: ToastType.success);
      }
    } on ApiException catch (e) {
      if (mounted) DgToast.show(context, e.message, type: ToastType.error);
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  // ── Password ──────────────────────────────────────────────────────────────
  Future<void> _savePassword() async {
    if (_newPassCtrl.text.length < 6) {
      DgToast.show(context, 'Mật khẩu mới phải có ít nhất 6 ký tự',
          type: ToastType.warning);
      return;
    }
    if (_newPassCtrl.text != _confPassCtrl.text) {
      DgToast.show(context, 'Mật khẩu xác nhận không khớp',
          type: ToastType.error);
      return;
    }
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _savingPassword = true);
    try {
      await ref.read(profileRepoProvider).changePassword(
            userId: user.userId,
            oldPassword: _oldPassCtrl.text,
            newPassword: _newPassCtrl.text,
          );
      _oldPassCtrl.clear();
      _newPassCtrl.clear();
      _confPassCtrl.clear();
      if (mounted) {
        DgToast.show(context, 'Đổi mật khẩu thành công',
            type: ToastType.success);
      }
    } on ApiException catch (e) {
      if (mounted) DgToast.show(context, e.message, type: ToastType.error);
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  // ── Feedback ──────────────────────────────────────────────────────────────
  Future<void> _sendFeedback() async {
    if (_feedbackCtrl.text.trim().isEmpty) {
      DgToast.show(context, 'Vui lòng nhập nội dung phản hồi',
          type: ToastType.warning);
      return;
    }
    final user = ref.read(currentUserProvider);
    if (user == null) {
      DgToast.show(context, 'Vui lòng đăng nhập để gửi phản hồi',
          type: ToastType.warning);
      return;
    }
    setState(() => _sendingFeedback = true);
    try {
      await ref.read(profileRepoProvider).submitFeedback(
            userId: user.userId,
            rating: _rating,
            content: _feedbackCtrl.text.trim(),
          );
      _feedbackCtrl.clear();
      setState(() => _rating = 5);
      if (mounted) {
        DgToast.show(context, 'Cảm ơn bạn đã gửi phản hồi!',
            type: ToastType.success);
      }
    } on ApiException catch (e) {
      if (mounted) DgToast.show(context, e.message, type: ToastType.error);
    } finally {
      if (mounted) setState(() => _sendingFeedback = false);
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> _logout() async {
    final ok = await DgConfirmDialog.show(
      context,
      title: 'Đăng xuất',
      message: 'Bạn có chắc muốn đăng xuất không?',
      confirmLabel: 'Đăng xuất',
    );
    if (!ok) return;
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/');
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    _initFromUser();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg   = isDark ? AppColors.fgDark   : AppColors.fgLight;
    final muted= isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    final user = ref.watch(currentUserProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s6),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title,
                  style: AppTypography.h2.copyWith(color: fg)),
              const SizedBox(height: AppSpacing.s6),

              // ── Avatar card ────────────────────────────────────────────
              _SectionCard(
                title: 'Ảnh đại diện',
                child: Row(
                  children: [
                    Stack(
                      children: [
                        _AvatarWidget(user: user, size: 72),
                        if (_uploadingAvatar)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: AppSpacing.s5),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?.fullName ?? user?.email ?? '',
                              style: AppTypography.h4.copyWith(color: fg),
                              overflow: TextOverflow.ellipsis),
                          Text(user?.email ?? '',
                              style: AppTypography.body
                                  .copyWith(color: muted),
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: AppSpacing.s3),
                          DgButton.secondary(
                            label: _uploadingAvatar
                                ? 'Đang tải...'
                                : 'Đổi ảnh đại diện',
                            icon: Icons.camera_alt_outlined,
                            onPressed:
                                _uploadingAvatar ? null : _pickAvatar,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s4),

              // ── Thông tin cá nhân ─────────────────────────────────────
              _SectionCard(
                title: 'Thông tin cá nhân',
                child: Column(
                  children: [
                    DgInput(
                      label: 'Họ và tên',
                      hint: 'Nguyễn Văn A',
                      controller: _nameCtrl,
                      prefixIcon: Icons.person_outline,
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    DgInput(
                      label: 'Email',
                      hint: 'email@example.com',
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.mail_outline,
                    ),
                    const SizedBox(height: AppSpacing.s5),
                    DgButton.primary(
                      label: _savingProfile
                          ? 'Đang lưu...'
                          : 'Lưu thông tin',
                      loading: _savingProfile,
                      fullWidth: true,
                      onPressed: _savingProfile ? null : _saveProfile,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s4),

              // ── Đổi mật khẩu ──────────────────────────────────────────
              _SectionCard(
                title: 'Đổi mật khẩu',
                child: Column(
                  children: [
                    DgInput.password(
                      label: 'Mật khẩu hiện tại',
                      controller: _oldPassCtrl,
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    DgInput.password(
                      label: 'Mật khẩu mới',
                      controller: _newPassCtrl,
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    DgInput.password(
                      label: 'Xác nhận mật khẩu mới',
                      controller: _confPassCtrl,
                    ),
                    const SizedBox(height: AppSpacing.s5),
                    DgButton.primary(
                      label: _savingPassword ? 'Đang lưu...' : 'Đổi mật khẩu',
                      loading: _savingPassword,
                      fullWidth: true,
                      onPressed: _savingPassword ? null : _savePassword,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s4),

              // ── Thống kê sử dụng ─────────────────────────────────────
              if (widget.showUsageStats)
                _UsageStatsCard(isDark: isDark, fg: fg, muted: muted),

              const SizedBox(height: AppSpacing.s4),

              // ── Phản hồi & đánh giá ───────────────────────────────────
              _SectionCard(
                title: 'Phản hồi & Đánh giá',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Đánh giá của bạn về DocGen VN:',
                        style:
                            AppTypography.bodySmall.copyWith(color: muted)),
                    const SizedBox(height: 10),
                    // Stars
                    Row(
                      children: List.generate(5, (i) {
                        final star = i + 1;
                        return IconButton(
                          icon: Icon(
                            star <= _rating
                                ? Icons.star
                                : Icons.star_border,
                            color: star <= _rating
                                ? AppColors.warning
                                : muted,
                            size: 28,
                          ),
                          onPressed: () =>
                              setState(() => _rating = star),
                          padding: const EdgeInsets.all(2),
                          constraints: const BoxConstraints(),
                        );
                      }),
                    ),
                    const SizedBox(height: AppSpacing.s3),
                    DgInput(
                      label: 'Nội dung phản hồi',
                      hint:
                          'Chia sẻ trải nghiệm của bạn, góp ý cải thiện...',
                      controller: _feedbackCtrl,
                      maxLines: 4,
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    DgButton.secondary(
                      label: _sendingFeedback
                          ? 'Đang gửi...'
                          : 'Gửi phản hồi',
                      icon: Icons.send_outlined,
                      fullWidth: true,
                      onPressed:
                          _sendingFeedback ? null : _sendFeedback,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s4),

              // ── Đăng xuất ─────────────────────────────────────────────
              DgButton.danger(
                label: 'Đăng xuất',
                icon: Icons.logout,
                fullWidth: true,
                onPressed: _logout,
              ),
              const SizedBox(height: AppSpacing.s8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatar widget — hỗ trợ url hoặc initials
// ─────────────────────────────────────────────────────────────────────────────
class _AvatarWidget extends StatelessWidget {
  final User? user;
  final double size;
  const _AvatarWidget({required this.user, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final name = user?.fullName ?? user?.email ?? '?';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final avatarUrl = user?.avatarUrl;

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      // avatarUrl đã được xử lý thành full URL trong User.fromJson → dùng trực tiếp
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(avatarUrl),
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.primary,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppColors.fgDark : AppColors.fgLight;
    return DgCard(
      padding: const EdgeInsets.all(AppSpacing.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppTypography.h4
                  .copyWith(color: fg, fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.s4),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _UsageStatsCard extends ConsumerWidget {
  final bool isDark;
  final Color fg, muted;
  const _UsageStatsCard(
      {required this.isDark, required this.fg, required this.muted});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(historyListProvider);
    return _SectionCard(
      title: 'Thống kê sử dụng',
      child: asyncList.when(
        loading: () => const Center(
            child: CircularProgressIndicator(strokeWidth: 2)),
        error: (_, __) => Text('Không tải được thống kê',
            style: AppTypography.body.copyWith(color: muted)),
        data: (list) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatBox(
              icon: Icons.description_outlined,
              label: 'Tài liệu đã tạo',
              value: '${list.length}',
              fg: fg,
              muted: muted,
            ),
            if (list.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s3),
              _StatBox(
                icon: Icons.calendar_today_outlined,
                label: 'Lần sử dụng gần nhất',
                value: _fmtDate(list.first.createdAt),
                fg: fg,
                muted: muted,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '—';
    final l = dt.isUtc ? dt.toLocal() : dt;
    return '${l.day.toString().padLeft(2, '0')}/'
        '${l.month.toString().padLeft(2, '0')}/'
        '${l.year}';
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color fg, muted;
  const _StatBox(
      {required this.icon,
      required this.label,
      required this.value,
      required this.fg,
      required this.muted});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final boxBg = isDark
        ? AppColors.primary.withOpacity(0.12)
        : AppColors.primarySoft;
    final iconBg = AppColors.primary.withOpacity(0.15);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s4, vertical: AppSpacing.s3),
      decoration: BoxDecoration(
        color: boxBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: AppTypography.h4.copyWith(
                      color: fg, fontWeight: FontWeight.w700)),
              Text(label,
                  style: AppTypography.caption.copyWith(color: muted)),
            ],
          ),
        ],
      ),
    );
  }
}
