// lib/features/landing/presentation/splash_screen.dart
//
// Splash/Loading screen hiển thị ngay khi app vào, tránh "màn hình trắng".
// Sau 1.2 giây tự gọi onFinish() để chuyển sang route chính.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/tokens/app_colors.dart';
import '../../../core/tokens/app_typography.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onFinish;
  final Duration duration;

  const SplashScreen({
    super.key,
    required this.onFinish,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoCtrl;
  late final AnimationController _fadeCtrl;
  late final AnimationController _orbitCtrl;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<double> _barProgress;

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _orbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _logoScale = CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut);
    _logoOpacity =
        CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut);
    _textOpacity = CurvedAnimation(
      parent: _fadeCtrl,
      curve: const Interval(0.35, 0.7, curve: Curves.easeOut),
    );
    _barProgress = CurvedAnimation(
      parent: _fadeCtrl,
      curve: const Interval(0.4, 1.0, curve: Curves.easeInOut),
    );

    _logoCtrl.forward();
    _fadeCtrl.forward().whenComplete(() {
      if (mounted) widget.onFinish();
    });
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _fadeCtrl.dispose();
    _orbitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF8F9FF),
              Color(0xFFEEF2FF),
              Color(0xFFE0E7FF),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Vòng tròn quỹ đạo trang trí
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _orbitCtrl,
                builder: (_, __) => CustomPaint(
                  painter: _OrbitPainter(progress: _orbitCtrl.value),
                ),
              ),
            ),
            // Nội dung chính
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo có animation scale + glow
                  ScaleTransition(
                    scale: _logoScale,
                    child: FadeTransition(
                      opacity: _logoOpacity,
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF7C3AED),
                              Color(0xFF4F46E5),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.35),
                              blurRadius: 32,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Tên app
                  FadeTransition(
                    opacity: _textOpacity,
                    child: RichText(
                      text: TextSpan(
                        style: AppTypography.h1.copyWith(
                          color: AppColors.fgLight,
                          fontSize: 36,
                        ),
                        children: const [
                          TextSpan(text: 'DocGen'),
                          TextSpan(
                            text: ' VN',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FadeTransition(
                    opacity: _textOpacity,
                    child: Text(
                      'Sinh tài liệu mã nguồn bằng Tiếng Việt',
                      style: AppTypography.body.copyWith(
                        color: AppColors.fgMutedLight,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Loading bar
                  SizedBox(
                    width: 180,
                    child: AnimatedBuilder(
                      animation: _barProgress,
                      builder: (_, __) => ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _barProgress.value > 0
                              ? _barProgress.value
                              : null,
                          backgroundColor: AppColors.primary.withOpacity(0.15),
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.primary,
                          ),
                          minHeight: 4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Footer
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: FadeTransition(
                opacity: _textOpacity,
                child: Center(
                  child: Text(
                    'Học phần Khai phá Dữ liệu · Trường Đại học Khoa học Tự nhiên · ĐHQGHN',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.fgSubtleLight,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vẽ 2 vòng tròn quỹ đạo xoay nhẹ trên nền — hiệu ứng "đang tải"
class _OrbitPainter extends CustomPainter {
  final double progress;
  _OrbitPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = AppColors.primary.withOpacity(0.08);

    final r1 = math.min(size.width, size.height) * 0.35;
    final r2 = r1 * 1.4;

    canvas.drawCircle(center, r1, paint);
    canvas.drawCircle(center, r2, paint);

    // Dot di chuyển trên quỹ đạo
    final dotPaint = Paint()..color = AppColors.primary.withOpacity(0.6);
    final angle1 = progress * 2 * math.pi;
    final angle2 = -progress * 2 * math.pi + math.pi / 2;
    canvas.drawCircle(
      center + Offset(r1 * math.cos(angle1), r1 * math.sin(angle1)),
      4,
      dotPaint,
    );
    canvas.drawCircle(
      center + Offset(r2 * math.cos(angle2), r2 * math.sin(angle2)),
      3,
      dotPaint..color = const Color(0xFF7C3AED).withOpacity(0.5),
    );
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.progress != progress;
}