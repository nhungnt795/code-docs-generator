// lib/features/info/presentation/_info_shell.dart
// Layout chung cho các trang info: about/contact/privacy/terms.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/tokens/app_colors.dart';
import '../../../core/tokens/app_spacing.dart';
import '../../../core/tokens/app_typography.dart';
import '../../../core/utils/responsive.dart';

class InfoShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;
  final List<Color> gradient;

  const InfoShell({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.child,
    this.gradient = const [Color(0xFF4F46E5), Color(0xFF7C3AED)],
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final fg = isDark ? AppColors.fgDark : AppColors.fgLight;
    final w = MediaQuery.sizeOf(context).width;
    final hPad = w > 900 ? 80.0 : (w > 600 ? 40.0 : 20.0);

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: bg,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
            ),
            titleSpacing: 0,
            title: Text('DocGen VN',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.primary)),
          ),
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: hPad,
                vertical: 40,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient.map((c) => c.withOpacity(0.08)).toList(),
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: gradient.first.withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(icon, color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 20),
                      Text(title,
                          style: AppTypography.h1.copyWith(
                              color: fg, fontSize: w > 600 ? 36 : 28)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 8),
                        Text(subtitle!,
                            style: AppTypography.body.copyWith(
                                color: isDark
                                    ? AppColors.fgMutedDark
                                    : AppColors.fgMutedLight,
                                fontSize: 16)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: hPad, vertical: AppSpacing.s8),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Helper widgets dùng chung
class InfoSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const InfoSection({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppColors.fgDark : AppColors.fgLight;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppTypography.h2.copyWith(color: fg, fontSize: 22)),
          const SizedBox(height: AppSpacing.s4),
          ...children,
        ],
      ),
    );
  }
}

class InfoParagraph extends StatelessWidget {
  final String text;
  const InfoParagraph(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s3),
      child: Text(text,
          style: AppTypography.body
              .copyWith(color: muted, fontSize: 15, height: 1.7)),
    );
  }
}

class InfoBullet extends StatelessWidget {
  final String text;
  const InfoBullet(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, right: 12),
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(text,
                style: AppTypography.body
                    .copyWith(color: muted, fontSize: 15, height: 1.7)),
          ),
        ],
      ),
    );
  }
}