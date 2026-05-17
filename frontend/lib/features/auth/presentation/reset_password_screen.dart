import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/tokens/app_colors.dart';
import '../../../core/tokens/app_spacing.dart';
import '../../../core/tokens/app_typography.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/dg_button.dart';
import '../../../shared/widgets/dg_input.dart';
import '../../../shared/widgets/dg_misc.dart';
import '../data/auth_repository.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String prefillEmail;
  const ResetPasswordScreen({super.key, this.prefillEmail = ''});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _isOtpSent = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Nếu được truyền email từ ForgotPasswordScreen → OTP đã gửi rồi, bỏ qua bước nhập email
    if (widget.prefillEmail.isNotEmpty) {
      _emailController.text = widget.prefillEmail;
      _isOtpSent = true;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  // 1. Hàm yêu cầu gửi OTP Reset Password
  Future<void> _requestResetOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      DgToast.show(context, 'Vui lòng nhập email', type: ToastType.warning);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(authRepoProvider).forgotPassword(email); // Gửi OTP reset tới email
      if (!mounted) return;
      setState(() => _isOtpSent = true);
      DgToast.show(context, 'Mã xác thực đã được gửi tới email của bạn', type: ToastType.success);
    } catch (e) {
      if (!mounted) return;
      DgToast.show(context, e.toString(), type: ToastType.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. Hàm thiết lập lại mật khẩu
  Future<void> _submitNewPassword() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    final newPassword = _newPasswordController.text.trim();

    if (otp.length != 6 || newPassword.length < 6) {
      DgToast.show(context, 'Kiểm tra lại OTP (6 số) và Mật khẩu (tối thiểu 6 ký tự)', type: ToastType.warning);
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Gọi API reset mật khẩu
      await ref.read(authRepoProvider).resetPassword(email, otp, newPassword);
      if (!mounted) return;
      DgToast.show(context, 'Đổi mật khẩu thành công! Vui lòng đăng nhập lại.', type: ToastType.success);
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      DgToast.show(context, e.toString(), type: ToastType.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s5),
          child: Container(
            width: Responsive.isMobile(context) ? double.infinity : 400,
            padding: const EdgeInsets.all(AppSpacing.s6),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : AppColors.cardLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Khôi phục mật khẩu',
                  style: AppTypography.h3.copyWith(color: isDark ? AppColors.fgDark : AppColors.fgLight),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  _isOtpSent
                      ? 'Nhập mã OTP 6 số và mật khẩu mới của bạn.'
                      : 'Nhập email liên kết với tài khoản, chúng tôi sẽ gửi mã khôi phục cho bạn.',
                  style: AppTypography.body.copyWith(
                    color: isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.s6),

                // Nhập Email (Luôn hiển thị nhưng khóa lại nếu đã gửi OTP)
                DgInput(
                  controller: _emailController,
                  label: 'Email',
                  hintText: 'ví dụ: admin@docgenvn.id.vn',
                  enabled: !_isOtpSent,
                ),

                if (_isOtpSent) ...[
                  const SizedBox(height: AppSpacing.s4),
                  DgInput(
                    controller: _otpController,
                    label: 'Mã OTP',
                    hintText: 'Nhập 6 số',
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  DgInput(
                    controller: _newPasswordController,
                    label: 'Mật khẩu mới',
                    hintText: 'Tối thiểu 6 ký tự',
                    isPassword: true,
                  ),
                ],

                const SizedBox(height: AppSpacing.s6),

                DgButton.primary(
                  label: _isOtpSent ? 'Lưu mật khẩu mới' : 'Nhận mã OTP',
                  loading: _isLoading,
                  fullWidth: true,
                  onPressed: _isOtpSent ? _submitNewPassword : _requestResetOtp,
                ),
                const SizedBox(height: AppSpacing.s4),

                TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text('Quay lại Đăng nhập', style: AppTypography.body.copyWith(color: AppColors.primary)),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}