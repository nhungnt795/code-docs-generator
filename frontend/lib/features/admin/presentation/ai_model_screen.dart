// lib/features/admin/presentation/ai_model_screen.dart
//
// FIX:
// 1. Switch màu rõ ràng: bật = xanh lá (success), tắt = xám
//    Dùng MaterialStateProperty để control thumbColor & trackColor đúng cả khi off
// 2. ListView dùng Key(cfg.modelType.name) để không nhảy thứ tự khi rebuild
// 3. Badge status rõ ràng hơn: Xanh "Đang hoạt động" / Đỏ "Đang tắt"

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/models.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/tokens/app_colors.dart';
import '../../../core/tokens/app_spacing.dart';
import '../../../core/tokens/app_typography.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/dg_badge.dart';
import '../../../shared/widgets/dg_card.dart';
import '../../../shared/widgets/dg_misc.dart';
import '../data/admin_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Metadata tĩnh về từng model
// ─────────────────────────────────────────────────────────────────────────────
class _ModelMeta {
  final String key, name, provider, description;
  final List<String> specs;
  final IconData icon;
  final Color accentColor;
  const _ModelMeta({
    required this.key, required this.name, required this.provider,
    required this.description, required this.specs,
    required this.icon, required this.accentColor,
  });
}

const _modelMeta = [
  _ModelMeta(
    key: 'GROQ_LLAMA3',
    name: 'Llama 3.1 8B Instant',
    provider: 'Groq Cloud',
    description:
    'Mô hình ngôn ngữ lớn Llama 3.1 8B chạy trên hạ tầng Groq Cloud với tốc độ suy luận cực cao (>800 tokens/s). Phù hợp cho sinh tài liệu code thời gian thực.',
    specs: ['8B tham số', '128K context window', 'Tốc độ: ~800 tokens/s', 'Hạ tầng: Groq LPU'],
    icon: Icons.bolt,
    accentColor: Color(0xFF4F46E5),
  ),
  _ModelMeta(
    key: 'KAGGLE_FINETUNED',
    name: 'Llama 3.1 Finetuned',
    provider: 'Kaggle (Local)',
    description:
    'Phiên bản Llama 3.1 đã được tinh chỉnh (finetune) trên bộ dữ liệu tài liệu hoá code tiếng Việt từ Kaggle. Cho chất lượng tài liệu cao hơn nhưng tốc độ chậm hơn.',
    specs: ['Finetuned on ViCode-Docs', '8B tham số', 'Tối ưu cho Tiếng Việt', 'Hạ tầng: Kaggle GPU'],
    icon: Icons.psychology_outlined,
    accentColor: Color(0xFFEC4899),
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
class AIModelScreen extends ConsumerStatefulWidget {
  const AIModelScreen({super.key});

  @override
  ConsumerState<AIModelScreen> createState() => _AIModelScreenState();
}

class _AIModelScreenState extends ConsumerState<AIModelScreen> {
  final Map<String, bool> _toggling = {};

  Future<void> _toggle(AIModelConfig cfg, bool newValue) async {
    final adminId = ref.read(currentUserProvider)?.userId;
    if (adminId == null) return;

    // Xác nhận khi TẮT model
    if (!newValue) {
      final ok = await DgConfirmDialog.show(
        context,
        title: 'Tắt mô hình',
        message:
        'Người dùng sẽ không thể sử dụng "${cfg.displayName}" sau khi tắt. '
            'Xác nhận tắt mô hình này?',
        confirmLabel: 'Tắt mô hình',
      );
      if (!ok) return;
    }

    final key = cfg.modelType.name;
    setState(() => _toggling[key] = true);

    try {
      // Gọi API toggle
      final updated = await ref.read(adminRepoProvider).toggleModel(adminId, key, newValue);

      // Cập nhật local state thay vì invalidate để tránh rebuild toàn bộ list
      // (invalidate gây re-fetch → thứ tự card có thể thay đổi thoáng qua)
      ref.invalidate(adminModelsProvider);

      if (mounted) {
        DgToast.show(
          context,
          newValue ? '${cfg.displayName} đã được bật' : '${cfg.displayName} đã bị tắt',
          type: newValue ? ToastType.success : ToastType.warning,
        );
      }
    } on ApiException catch (e) {
      if (mounted) DgToast.show(context, e.message, type: ToastType.error);
    } finally {
      // Xóa trạng thái loading SAU khi provider đã được invalidate
      // để tránh flash trạng thái cũ
      if (mounted) setState(() => _toggling.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final fg        = isDark ? AppColors.fgDark    : AppColors.fgLight;
    final muted     = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    final isDesktop = Responsive.isDesktop(context);
    final asyncModels = ref.watch(adminModelsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminModelsProvider),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text('Quản lý Mô hình AI',
                style: AppTypography.h2.copyWith(color: fg)),
            const SizedBox(height: 4),
            Text(
              'Bật/tắt mô hình ngôn ngữ lớn. '
                  'Mô hình bị tắt sẽ hiện thông báo "ngoài thời gian sử dụng" cho người dùng.',
              style: AppTypography.body.copyWith(color: muted),
            ),
            const SizedBox(height: AppSpacing.s5),

            // Banner hướng dẫn
            Container(
              padding: const EdgeInsets.all(AppSpacing.s4),
              decoration: BoxDecoration(
                color: AppColors.infoSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.info.withOpacity(0.3)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline, color: AppColors.info, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Khi một mô hình bị tắt, người dùng chọn mô hình đó sẽ nhận thông báo: '
                        '"Mô hình hiện đang ngoài thời gian sử dụng, hãy liên hệ chúng tôi."',
                    style: AppTypography.body.copyWith(color: AppColors.info),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: AppSpacing.s6),

            // Danh sách model
            asyncModels.when(
              loading: () => Column(
                children: List.generate(2, (_) =>
                    Padding(padding: const EdgeInsets.only(bottom: AppSpacing.s4),
                        child: DgSkeleton.card(height: 220))),
              ),
              error: (e, _) => DgEmptyState(
                icon: Icons.error_outline,
                message: 'Không tải được cấu hình model',
                description: e.toString(),
                actionLabel: 'Thử lại',
                onAction: () => ref.invalidate(adminModelsProvider),
              ),
              data: (models) {
                if (models.isEmpty) {
                  return DgEmptyState(
                    icon: Icons.smart_toy_outlined,
                    message: 'Chưa có model nào được cấu hình',
                    actionLabel: 'Làm mới',
                    onAction: () => ref.invalidate(adminModelsProvider),
                  );
                }

                // FIX: sắp xếp ổn định theo modelType để không nhảy thứ tự sau toggle
                final sortedModels = List<AIModelConfig>.from(models)
                  ..sort((a, b) => a.modelType.name.compareTo(b.modelType.name));
                // FIX: dùng key để Flutter không nhảy thứ tự card khi rebuild
                final cards = sortedModels.map((m) => _ModelCard(
                  key: ValueKey(m.modelType.name),  // ← KEY quan trọng
                  cfg: m,
                  toggling: _toggling[m.modelType.name] ?? false,
                  onToggle: (v) => _toggle(m, v),
                  isDark: isDark, fg: fg, muted: muted,
                )).toList();

                return isDesktop
                    ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: cards.asMap().entries.map((e) =>
                        Expanded(child: Padding(
                          padding: EdgeInsets.only(
                              right: e.key < cards.length - 1 ? AppSpacing.s4 : 0),
                          child: e.value,
                        ))).toList(),
                  ),
                )
                    : Column(children: cards.map((c) =>
                    Padding(padding: const EdgeInsets.only(bottom: AppSpacing.s4),
                        child: c)).toList());
              },
            ),

            const SizedBox(height: AppSpacing.s8),

            // Thông tin chi tiết
            Text('Thông tin chi tiết', style: AppTypography.h3.copyWith(color: fg)),
            const SizedBox(height: AppSpacing.s4),
            isDesktop
                ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _modelMeta.asMap().entries.map((e) =>
                  Expanded(child: Padding(
                    padding: EdgeInsets.only(
                        right: e.key < _modelMeta.length - 1 ? AppSpacing.s4 : 0),
                    child: _ModelInfoCard(meta: e.value, isDark: isDark, fg: fg, muted: muted),
                  ))).toList(),
            )
                : Column(children: _modelMeta.map((m) =>
                Padding(padding: const EdgeInsets.only(bottom: AppSpacing.s4),
                    child: _ModelInfoCard(meta: m, isDark: isDark, fg: fg, muted: muted))).toList()),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODEL CARD
// ─────────────────────────────────────────────────────────────────────────────
class _ModelCard extends StatelessWidget {
  final AIModelConfig cfg;
  final bool toggling;
  final ValueChanged<bool> onToggle;
  final bool isDark;
  final Color fg, muted;

  const _ModelCard({
    super.key,
    required this.cfg, required this.toggling, required this.onToggle,
    required this.isDark, required this.fg, required this.muted,
  });

  _ModelMeta get _meta => _modelMeta.firstWhere(
        (m) => m.key == cfg.modelType.name,
    orElse: () => _ModelMeta(
      key: cfg.modelType.name, name: cfg.displayName,
      provider: '', description: cfg.description ?? '',
      specs: [], icon: Icons.smart_toy_outlined, accentColor: AppColors.primary,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final border   = isDark ? AppColors.borderDark : AppColors.borderLight;
    final isActive = cfg.isActive;
    final meta     = _meta;

    return DgCard(
      padding: const EdgeInsets.all(AppSpacing.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: icon + tên + badge
          Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: meta.accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(meta.icon, color: meta.accentColor, size: 26),
            ),
            const SizedBox(width: AppSpacing.s3),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(meta.name, style: AppTypography.h4.copyWith(color: fg)),
              Text(meta.provider, style: AppTypography.caption.copyWith(color: muted)),
            ])),
            // Badge rõ ràng: xanh bật / đỏ tắt
            isActive
                ? _StatusBadge(label: 'Đang hoạt động', color: AppColors.success)
                : _StatusBadge(label: 'Đang tắt', color: AppColors.error),
          ]),
          const SizedBox(height: AppSpacing.s4),

          // Mô tả
          Text(meta.description,
              style: AppTypography.body.copyWith(color: muted, height: 1.6)),
          const SizedBox(height: AppSpacing.s4),

          // Cảnh báo khi tắt
          if (!isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: AppSpacing.s4),
              decoration: BoxDecoration(
                color: AppColors.warningSoft,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.warning.withOpacity(0.4)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber, color: AppColors.warning, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Người dùng chọn mô hình này sẽ nhận thông báo "ngoài thời gian sử dụng"',
                  style: AppTypography.caption.copyWith(color: AppColors.warning),
                )),
              ]),
            ),

          Divider(color: border),
          const SizedBox(height: AppSpacing.s3),

          // Toggle row
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                isActive ? 'Đang hoạt động' : 'Đang tắt',
                style: AppTypography.bodyMedium.copyWith(
                  color: isActive ? AppColors.success : AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                isActive
                    ? 'Người dùng có thể chọn mô hình này'
                    : 'Bật để cho phép người dùng sử dụng',
                style: AppTypography.caption.copyWith(color: muted),
              ),
            ])),
            const SizedBox(width: 12),
            if (toggling)
              const SizedBox(
                width: 36, height: 20,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
              )
            else
            // FIX: Switch màu rõ ràng bằng MaterialStateProperty
              Switch(
                value: isActive,
                onChanged: onToggle,
                // Thumb (nút tròn): trắng khi bật, trắng khi tắt
                thumbColor: WidgetStateProperty.all(Colors.white),
                // Track (nền): xanh lá khi bật, xám khi tắt
                trackColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppColors.success;        // bật → xanh
                  }
                  return isDark
                      ? AppColors.borderDark         // tắt dark → xám đậm
                      : const Color(0xFFCBD5E1);    // tắt light → xám nhạt
                }),
                // Viền track
                trackOutlineColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) return AppColors.success;
                  return isDark ? AppColors.borderDark : const Color(0xFFCBD5E1);
                }),
              ),
          ]),
        ],
      ),
    );
  }
}

// Badge màu tùy chỉnh (xanh / đỏ)
class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 6, height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTypography.caption.copyWith(
            color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODEL INFO CARD
// ─────────────────────────────────────────────────────────────────────────────
class _ModelInfoCard extends StatelessWidget {
  final _ModelMeta meta;
  final bool isDark;
  final Color fg, muted;
  const _ModelInfoCard({required this.meta, required this.isDark, required this.fg, required this.muted});

  @override
  Widget build(BuildContext context) {
    return DgCard(
      padding: const EdgeInsets.all(AppSpacing.s5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: meta.accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(meta.icon, size: 18, color: meta.accentColor),
          ),
          const SizedBox(width: 10),
          Text(meta.name, style: AppTypography.h4.copyWith(color: fg, fontSize: 15)),
        ]),
        const SizedBox(height: AppSpacing.s3),
        Text('Thông số kỹ thuật', style: AppTypography.bodyMedium.copyWith(color: muted)),
        const SizedBox(height: 8),
        ...meta.specs.map((s) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              margin: const EdgeInsets.only(top: 7, right: 10),
              width: 4, height: 4,
              decoration: BoxDecoration(color: meta.accentColor, shape: BoxShape.circle),
            ),
            Expanded(child: Text(s, style: AppTypography.body.copyWith(color: muted, fontSize: 13))),
          ]),
        )),
      ]),
    );
  }
}