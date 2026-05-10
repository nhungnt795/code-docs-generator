// ─────────────────────────────────────────────────────────────────────────────
// dg_skeleton.dart  →  lib/shared/widgets/dg_misc.dart
// ─────────────────────────────────────────────────────────────────────────────
// (this file is a barrel – split into individual files if preferred)

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/tokens/app_colors.dart';
import '../../core/tokens/app_typography.dart';
import '../../core/tokens/app_spacing.dart';
import 'dg_button.dart';

// ════════════════════════════════════════════════════════════════════════════
// DgSkeleton
// ════════════════════════════════════════════════════════════════════════════
class DgSkeleton extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const DgSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
  });

  /// Multi-line text skeleton
  factory DgSkeleton.text({int lines = 3, double lineHeight = 14}) =>
      _TextSkeleton(lines: lines, lineHeight: lineHeight) as DgSkeleton;

  /// Card-shaped placeholder
  factory DgSkeleton.card({double height = 100}) =>
      DgSkeleton(
        width: double.infinity,
        height: height,
        borderRadius: BorderRadius.circular(8),
      );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base   = isDark ? const Color(0xFF1E293B) : const Color(0xFFE5E7EB);
    final shine  = isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6);

    return Shimmer.fromColors(
      baseColor:  base,
      highlightColor: shine,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: borderRadius ?? BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _TextSkeleton extends DgSkeleton {
  final int lines;
  final double lineHeight;

  const _TextSkeleton({required this.lines, required this.lineHeight})
      : super(height: 0);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(lines, (i) {
        final isLast = i == lines - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: i < lines - 1 ? 8 : 0),
          child: DgSkeleton(
            width: isLast ? 180 : double.infinity,
            height: lineHeight,
          ),
        );
      }),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// DgEmptyState
// ════════════════════════════════════════════════════════════════════════════
class DgEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const DgEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final fg      = isDark ? AppColors.fgDark       : AppColors.fgLight;
    final muted   = isDark ? AppColors.fgMutedDark  : AppColors.fgMutedLight;
    final subtle  = isDark ? AppColors.fgSubtleDark : AppColors.fgSubtleLight;
    final iconBg  = isDark ? AppColors.cardDark     : const Color(0xFFF3F4F6);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 24, color: subtle),
            ),
            const SizedBox(height: AppSpacing.s3),
            Text(
              message,
              style: AppTypography.bodyMedium.copyWith(color: fg),
              textAlign: TextAlign.center,
            ),
            if (description != null) ...[
              const SizedBox(height: 6),
              Text(
                description!,
                style: AppTypography.bodySmall.copyWith(color: muted),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.s4),
              DgButton.primary(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// DgConfirmDialog
// ════════════════════════════════════════════════════════════════════════════
class DgConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  const DgConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Xác nhận',
    this.cancelLabel  = 'Hủy',
    this.destructive  = false,
  });

  /// Show and return true if confirmed
  static Future<bool> show(
      BuildContext context, {
        required String title,
        required String message,
        String confirmLabel = 'Xác nhận',
        String cancelLabel  = 'Hủy',
        bool destructive = false,
      }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => DgConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted  = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;

    return Dialog(
      // Thêm giới hạn chiều rộng cho Dialog
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.s2),
              Text(
                message,
                style: AppTypography.body.copyWith(color: muted),
              ),
              const SizedBox(height: AppSpacing.s6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  DgButton.ghost(
                    label: cancelLabel,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  const SizedBox(width: AppSpacing.s2),
                  destructive
                      ? DgButton.destructive(
                    label: confirmLabel,
                    onPressed: () => Navigator.of(context).pop(true),
                  )
                      : DgButton.primary(
                    label: confirmLabel,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// DgToast — lightweight snackbar helper
// ════════════════════════════════════════════════════════════════════════════
enum ToastType { success, error, warning, info }

class DgToast {
  DgToast._();

  static void show(
      BuildContext context,
      String message, {
        ToastType type = ToastType.info,
        Duration duration = const Duration(seconds: 3),
      }) {
    final (icon, color) = switch (type) {
      ToastType.success => (Icons.check_circle_outline, AppColors.success),
      ToastType.error   => (Icons.error_outline,         AppColors.error),
      ToastType.warning => (Icons.warning_amber_outlined, AppColors.warning),
      ToastType.info    => (Icons.info_outline,           AppColors.info),
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(AppSpacing.s4),
          content: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.body.copyWith(color: AppColors.fgDark),
                ),
              ),
            ],
          ),
        ),
      );
  }
}