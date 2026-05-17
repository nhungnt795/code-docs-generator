import 'dart:async';
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
import '../data/auth_repository.dart'; // Đảm bảo import đúng đường dẫn

class VerifyOtpScreen extends ConsumerStatefulWidget {
  final String email;
  const VerifyOtpScreen({super.key, required this.email});

  @override
  ConsumerState<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends ConsumerState<VerifyOtpScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;

  // Logic đếm ngược Gửi lại OTP
  int _countdown = 60;
  Timer? _timer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    setState(() {
      _countdown = 60;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        setState(() => _canResend = true);
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      DgToast.show(context, 'Vui lòng nhập đủ mã OTP 6 số', type: ToastType.warning);
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Gọi API xác thực OTP
      await ref.read(authRepoProvider).verifyOtp(widget.email, otp);
      if (!mounted) return;
      DgToast.show(context, 'Xác thực thành công!', type: ToastType.success);
      context.go('/login'); // Chuyển về login hoặc home tuỳ logic
    } catch (e) {
      if (!mounted) return;
      DgToast.show(context, e.toString(), type: ToastType.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepoProvider).resendOtp(widget.email);
      if (!mounted) return;
      DgToast.show(context, 'Đã gửi lại mã OTP', type: ToastType.info);
      _startTimer();
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
      body: Center( // Chống overflow bằng Center + SingleChildScrollView
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
                Icon(Icons.mark_email_read_outlined, size: 48, color: AppColors.primary),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  'Xác thực Email',
                  style: AppTypography.h3.copyWith(color: isDark ? AppColors.fgDark : AppColors.fgLight),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  'Mã xác thực gồm 6 chữ số đã được gửi tới:\n${widget.email}',
                  style: AppTypography.body.copyWith(
                    color: isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.s6),

                DgInput(
                  controller: _otpController,
                  label: 'Mã OTP',
                  hintText: 'Nhập mã 6 số',
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                ),
                const SizedBox(height: AppSpacing.s6),

                DgButton.primary(
                  label: 'Xác nhận',
                  loading: _isLoading,
                  fullWidth: true,
                  onPressed: _verifyOtp,
                ),
                const SizedBox(height: AppSpacing.s4),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Chưa nhận được mã? ',
                      style: AppTypography.bodySmall.copyWith(
                        color: isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight,
                      ),
                    ),
                    _canResend
                        ? TextButton(
                      onPressed: _isLoading ? null : _resendOtp,
                      child: Text('Gửi lại', style: AppTypography.bodySmall.copyWith(color: AppColors.primary)),
                    )
                        : Text(
                      'Gửi lại sau ${_countdown}s',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.error),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}