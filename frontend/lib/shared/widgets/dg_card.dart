import 'package:flutter/material.dart';
import '../../core/tokens/app_colors.dart';
import '../../core/tokens/app_spacing.dart';
import '../../core/theme/app_theme.dart';

class DgCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool elevated;
  final Color? backgroundColor;

  const DgCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.elevated = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bg      = backgroundColor ?? (isDark ? AppColors.cardDark  : AppColors.cardLight);
    final border  = isDark ? AppColors.borderDark : AppColors.borderLight;

    return AnimatedContainer(
      duration: AppTheme.themeTransitionDuration,
      curve: AppTheme.themeCurve,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
        boxShadow: elevated ? AppTheme.shadowMd : AppTheme.shadowSm,
      ),
      child: onTap != null
          ? Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
            child: child,
          ),
        ),
      )
          : Padding(
        padding: padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
        child: child,
      ),
    );
  }
}