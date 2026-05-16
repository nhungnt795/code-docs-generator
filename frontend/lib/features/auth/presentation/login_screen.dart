// lib/features/auth/presentation/login_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// File chứa 3 màn hình: Login · Register · ForgotPassword
// Đã kết nối API backend thực tế.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_provider.dart';
import '../../../core/tokens/app_colors.dart';
import '../../../core/tokens/app_spacing.dart';
import '../../../core/tokens/app_typography.dart';
import '../../../shared/widgets/dg_button.dart';
import '../../../shared/widgets/dg_input.dart';
import '../../../shared/widgets/dg_misc.dart';
import '../data/auth_repository.dart';

// ════════════════════════════════════════════════════════════════════════════
// Shared auth layout wrapper
// ════════════════════════════════════════════════════════════════════════════
class _AuthShell extends StatelessWidget {
  final Widget child;
  const _AuthShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? AppColors.bgDark    : AppColors.bgLight;
    final card   = isDark ? AppColors.cardDark  : AppColors.cardLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.s8),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: border),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowBase,
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Logo mark ────────────────────────────────────────────────────────────────
class _AuthLogo extends StatelessWidget {
  const _AuthLogo();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.code, color: Colors.white, size: 22),
        ),
        const SizedBox(height: AppSpacing.s3),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontFamily: 'Inter', fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.fgLight,
            ),
            children: const [
              TextSpan(text: 'DocGen'),
              TextSpan(
                text: ' VN',
                style: TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 1. LoginScreen
// ════════════════════════════════════════════════════════════════════════════
class LoginScreen extends ConsumerStatefulWidget {
  final String redirectPath;
  final bool requireAdmin;

  const LoginScreen({
    super.key,
    this.redirectPath = '/generate',
    this.requireAdmin = false,
  });

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  String? _emailError;
  String? _passError;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() { _emailError = null; _passError = null; });

    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text;

    if (email.isEmpty) {
      setState(() => _emailError = 'Vui lòng nhập email');
      return;
    }
    if (pass.isEmpty) {
      setState(() => _passError = 'Vui lòng nhập mật khẩu');
      return;
    }

    final ok = await ref.read(authProvider.notifier).login(email, pass);

    if (!mounted) return;

    if (!ok) {
      final err = ref.read(authProvider).error ?? 'Đăng nhập thất bại';
      DgToast.show(context, err, type: ToastType.error);
      return;
    }

    final user = ref.read(authProvider).user;

    // Xử lý kiểm tra tài khoản đã kích hoạt (Verify OTP)
    if (user != null && !user.isActive) {
      context.push('/verify-otp', extra: email);
      return;
    }

    // Nếu màn hình login đang ở app Admin mà tài khoản không phải admin → từ chối
    if (widget.requireAdmin && user != null && !user.isAdmin) {
      await ref.read(authProvider.notifier).logout();
      if (mounted) {
        DgToast.show(
          context,
          'Tài khoản này không có quyền truy cập trang Admin',
          type: ToastType.error,
        );
      }
      return;
    }

    DgToast.show(context, 'Đăng nhập thành công', type: ToastType.success);
    context.go(widget.redirectPath);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted  = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    final loading = ref.watch(authProvider).loading;

    return _AuthShell(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _AuthLogo(),
            const SizedBox(height: AppSpacing.s6),
            Text(
              widget.requireAdmin ? 'Đăng nhập Admin' : 'Đăng nhập',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s1),
            Text(
              'Chào mừng trở lại',
              style: AppTypography.bodySmall.copyWith(color: muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s6),

            DgInput(
              label: 'Email',
              hint: 'ban@email.com',
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.mail_outline,
              errorText: _emailError,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.s4),

            DgInput.password(
              controller: _passCtrl,
              errorText: _passError,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: AppSpacing.s2),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push('/login/forgot'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Quên mật khẩu?',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s5),

            DgButton.primary(
              label: loading ? 'Đang đăng nhập...' : 'Đăng nhập',
              loading: loading,
              fullWidth: true,
              onPressed: loading ? null : _login,
            ),

            const SizedBox(height: AppSpacing.s6),

            if (!widget.requireAdmin)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Chưa có tài khoản? ', style: AppTypography.bodySmall.copyWith(color: muted)),
                  GestureDetector(
                    onTap: () => context.push('/login/register'),
                    child: Text(
                      'Đăng ký',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 2. RegisterScreen
// ════════════════════════════════════════════════════════════════════════════
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _pass2Ctrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose();
    _passCtrl.dispose(); _pass2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text;
    final pass2 = _pass2Ctrl.text;
    final name  = _nameCtrl.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      DgToast.show(context, 'Vui lòng nhập đầy đủ email và mật khẩu', type: ToastType.warning);
      return;
    }
    if (pass.length < 6) {
      DgToast.show(context, 'Mật khẩu phải có ít nhất 6 ký tự', type: ToastType.warning);
      return;
    }
    if (pass != pass2) {
      DgToast.show(context, 'Mật khẩu không khớp', type: ToastType.error);
      return;
    }

    final ok = await ref.read(authProvider.notifier).register(
      email: email,
      password: pass,
      fullName: name.isEmpty ? null : name,
    );

    if (!mounted) return;

    if (!ok) {
      final err = ref.read(authProvider).error ?? 'Đăng ký thất bại';
      DgToast.show(context, err, type: ToastType.error);
      return;
    }

    DgToast.show(
      context,
      'Đăng ký thành công! Vui lòng kiểm tra email để lấy mã OTP.',
      type: ToastType.success,
    );
    // Chuyển sang màn xác thực OTP, truyền email theo
    context.push('/verify-otp', extra: _emailCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted  = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    final loading = ref.watch(authProvider).loading;

    return _AuthShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _AuthLogo(),
          const SizedBox(height: AppSpacing.s6),
          Text(
            'Tạo tài khoản',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s6),

          DgInput(
            label: 'Họ và tên',
            hint: 'Nguyễn Văn A',
            controller: _nameCtrl,
            prefixIcon: Icons.person_outline,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.s4),
          DgInput(
            label: 'Email',
            hint: 'ban@email.com',
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.mail_outline,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.s4),
          DgInput.password(
            label: 'Mật khẩu',
            controller: _passCtrl,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.s4),
          DgInput.password(
            label: 'Xác nhận mật khẩu',
            controller: _pass2Ctrl,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: AppSpacing.s6),

          DgButton.primary(
            label: loading ? 'Đang tạo tài khoản...' : 'Đăng ký',
            loading: loading,
            fullWidth: true,
            onPressed: loading ? null : _register,
          ),
          const SizedBox(height: AppSpacing.s5),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Đã có tài khoản? ', style: AppTypography.bodySmall.copyWith(color: muted)),
              GestureDetector(
                onTap: () => context.pop(),
                child: Text(
                  'Đăng nhập',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 3. ForgotPasswordScreen — gọi API /forgot-password, sau đó sang reset
// ════════════════════════════════════════════════════════════════════════════
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _loading    = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      DgToast.show(context, 'Vui lòng nhập email', type: ToastType.warning);
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authRepoProvider).forgotPassword(email);
      if (!mounted) return;
      DgToast.show(
        context,
        'Mã OTP đã được gửi tới email của bạn',
        type: ToastType.success,
      );
      // Chuyển sang màn đặt lại mật khẩu, truyền email theo
      context.push('/reset-password', extra: email);
    } catch (e) {
      if (!mounted) return;
      DgToast.show(context, e.toString(), type: ToastType.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted  = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;

    return _AuthShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _AuthLogo(),
          const SizedBox(height: AppSpacing.s6),
          Text(
            'Quên mật khẩu',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            'Nhập email tài khoản để nhận mã OTP đặt lại mật khẩu',
            style: AppTypography.bodySmall.copyWith(color: muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s6),

          DgInput(
            label: 'Email',
            hint: 'ban@email.com',
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.mail_outline,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: AppSpacing.s5),
          DgButton.primary(
            label: 'Gửi mã OTP',
            loading: _loading,
            fullWidth: true,
            onPressed: _loading ? null : _send,
          ),

          const SizedBox(height: AppSpacing.s5),
          GestureDetector(
            onTap: () => context.pop(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.arrow_back, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  'Quay lại đăng nhập',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}