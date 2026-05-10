// lib/shared/widgets/dg_badge.dart
import 'package:flutter/material.dart';
import '../../core/tokens/app_colors.dart';
import '../../core/tokens/app_radius.dart';
import '../../core/tokens/app_typography.dart';

class DgBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color? bgColor;
  final IconData? icon;
  final bool dot;
  final double? width; // Thêm thuộc tính width

  const DgBadge({
    super.key,
    required this.label,
    required this.color,
    this.bgColor,
    this.icon,
    this.dot = true,
    this.width, // Thêm vào constructor
  });

  factory DgBadge.success({required String label, bool dot = true, double? width}) => DgBadge(
    label: label, color: AppColors.success,
    bgColor: AppColors.successSoft, dot: dot, width: width,
  );

  factory DgBadge.warning({required String label, bool dot = true, double? width}) => DgBadge(
    label: label, color: AppColors.warning,
    bgColor: AppColors.warningSoft, dot: dot, width: width,
  );

  factory DgBadge.error({required String label, bool dot = true, double? width}) => DgBadge(
    label: label, color: AppColors.error,
    bgColor: AppColors.errorSoft, dot: dot, width: width,
  );

  factory DgBadge.info({required String label, bool dot = true, double? width}) => DgBadge(
    label: label, color: AppColors.info,
    bgColor: AppColors.infoSoft, dot: dot, width: width,
  );

  factory DgBadge.neutral({required String label, double? width}) => DgBadge(
    label: label,
    color: AppColors.fgDisabled,
    bgColor: const Color(0xFFF3F4F6),
    dot: false,
    width: width,
  );

  @override
  Widget build(BuildContext context) {
    final bg = bgColor ?? color.withOpacity(0.1);
    return Container(
      width: width, // Áp dụng chiều rộng cố định nếu có
      alignment: width != null ? Alignment.center : null, // Căn giữa nội dung
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.rBadge,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center, // Đảm bảo căn giữa cho Row
        children: [
          if (dot) ...[
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ] else if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTypography.label.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DgStatusDot — just a colored dot (inline in tables / list rows)
// ─────────────────────────────────────────────────────────────────────────────
class DgStatusDot extends StatelessWidget {
  final Color color;
  final bool pulse; // animated pulse for "running" states

  const DgStatusDot({super.key, required this.color, this.pulse = false});

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 8, height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    if (!pulse) return dot;
    return _PulsingDot(color: color);
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.8, end: 1.3).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 8, height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
