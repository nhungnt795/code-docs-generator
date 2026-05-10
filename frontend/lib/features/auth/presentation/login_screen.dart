// lib/features/auth/presentation/login_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// File chứa 3 màn hình: Login · Register · ForgotPassword
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/tokens/app_colors.dart';
import '../../../core/tokens/app_spacing.dart';
import '../../../core/tokens/app_typography.dart';
import '../../../shared/widgets/dg_button.dart';
import '../../../shared/widgets/dg_input.dart';
import '../../../shared/widgets/dg_misc.dart';

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
class LoginScreen extends StatefulWidget {
  final String redirectPath;

  const LoginScreen({
    super.key,
    // Mặc định là /generate (dành cho app User)
    this.redirectPath = '/generate',
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _loading    = false;
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
    if (_emailCtrl.text.isEmpty) {
      setState(() => _emailError = 'Vui lòng nhập email');
      return;
    }
    if (_passCtrl.text.isEmpty) {
      setState(() => _passError = 'Vui lòng nhập mật khẩu');
      return;
    }

    setState(() => _loading = true);
    // Giả lập call API đăng nhập
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;
    setState(() => _loading = false);

    // Chuyển hướng tới đường dẫn được truyền từ Router
    context.go(widget.redirectPath);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted  = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;

    return _AuthShell(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _AuthLogo(),
            const SizedBox(height: AppSpacing.s6),
            Text(
              'Đăng nhập',
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
              label: _loading ? 'Đang đăng nhập...' : 'Đăng nhập',
              loading: _loading,
              fullWidth: true,
              onPressed: _loading ? null : _login,
            ),

            const SizedBox(height: AppSpacing.s6),

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
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  bool _loading    = false;

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose();
    _passCtrl.dispose(); _pass2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_passCtrl.text != _pass2Ctrl.text) {
      DgToast.show(context, 'Mật khẩu không khớp', type: ToastType.error);
      return;
    }
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() => _loading = false);
    DgToast.show(context, 'Đăng ký thành công! Vui lòng đăng nhập.', type: ToastType.success);
    context.go('/login');
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
            label: _loading ? 'Đang tạo tài khoản...' : 'Đăng ký',
            loading: _loading,
            fullWidth: true,
            onPressed: _loading ? null : _register,
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
// 3. ForgotPasswordScreen
// ════════════════════════════════════════════════════════════════════════════
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _loading    = false;
  bool _sent       = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_emailCtrl.text.isEmpty) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    setState(() { _loading = false; _sent = true; });
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
            'Khôi phục mật khẩu',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            'Nhập email để nhận link đặt lại mật khẩu',
            style: AppTypography.bodySmall.copyWith(color: muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s6),

          if (_sent)
            Container(
              padding: const EdgeInsets.all(AppSpacing.s4),
              decoration: BoxDecoration(
                color: AppColors.successSoft,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: AppColors.success, size: 18),
                  const SizedBox(width: AppSpacing.s2),
                  Expanded(
                    child: Text(
                      'Đã gửi email khôi phục. Vui lòng kiểm tra hộp thư.',
                      style: AppTypography.body.copyWith(color: AppColors.success),
                    ),
                  ),
                ],
              ),
            )
          else ...[
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
              label: _loading ? 'Đang gửi...' : 'Gửi link khôi phục',
              loading: _loading,
              fullWidth: true,
              onPressed: _loading ? null : _send,
            ),
          ],

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