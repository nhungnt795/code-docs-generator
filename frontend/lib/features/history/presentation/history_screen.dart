// lib/features/history/presentation/history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/models.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/tokens/app_colors.dart';
import '../../../core/tokens/app_spacing.dart';
import '../../../core/tokens/app_typography.dart';
import '../../../shared/widgets/dg_badge.dart';
import '../../../shared/widgets/dg_card.dart';
import '../../../shared/widgets/dg_input.dart';
import '../../../shared/widgets/dg_misc.dart';
import '../data/history_repository.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _delete(DocumentModel doc) async {
    final confirmed = await DgConfirmDialog.show(
      context,
      title: 'Xóa tài liệu',
      message: 'Tài liệu này sẽ bị xóa vĩnh viễn. Bạn có chắc không?',
      confirmLabel: 'Xóa',
      destructive: true,
    );
    if (!confirmed) return;

    final user = ref.read(currentUserProvider);
    if (user == null || doc.docId == null) return;

    try {
      await ref.read(historyRepoProvider).deleteDoc(
            docId: doc.docId!,
            userId: user.userId,
          );
      // Refresh provider
      ref.invalidate(historyListProvider);
      if (mounted) {
        DgToast.show(context, 'Đã xóa tài liệu', type: ToastType.success);
      }
    } on ApiException catch (e) {
      if (mounted) {
        DgToast.show(context, e.message, type: ToastType.error);
      }
    }
  }

  void _viewDetail(DocumentModel doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DocDetailSheet(doc: doc),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays == 1) return 'Hôm qua';
    if (diff.inDays < 30) return '${diff.inDays} ngày trước';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  List<DocumentModel> _filter(List<DocumentModel> items) {
    if (_query.isEmpty) return items;
    return items.where((d) {
      return d.title.toLowerCase().contains(_query) ||
          d.language.value.toLowerCase().contains(_query) ||
          d.contentMd.toLowerCase().contains(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppColors.fgDark : AppColors.fgLight;
    final muted = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    final subtle = isDark ? AppColors.fgSubtleDark : AppColors.fgSubtleLight;

    final asyncList = ref.watch(historyListProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(historyListProvider),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lịch sử',
                    style: AppTypography.h2.copyWith(color: fg)),
                Text(
                  asyncList.maybeWhen(
                    data: (list) => '${list.length} tài liệu đã tạo',
                    orElse: () => 'Đang tải...',
                  ),
                  style: AppTypography.bodySmall.copyWith(color: muted),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s5),

            // ── Search ─────────────────────────────────────────────────
            DgInput.search(
              hint: 'Tìm theo tên tệp, ngôn ngữ...',
              controller: _searchCtrl,
            ),
            const SizedBox(height: AppSpacing.s4),

            // ── List ───────────────────────────────────────────────────
            Expanded(
              child: asyncList.when(
                loading: () => const _LoadingList(),
                error: (e, _) => DgEmptyState(
                  icon: Icons.error_outline,
                  message: 'Không tải được lịch sử',
                  description: e.toString(),
                  actionLabel: 'Thử lại',
                  onAction: () => ref.invalidate(historyListProvider),
                ),
                data: (items) {
                  final filtered = _filter(items);
                  if (filtered.isEmpty) {
                    return DgEmptyState(
                      icon: Icons.history,
                      message: _query.isEmpty
                          ? 'Chưa có tài liệu nào'
                          : 'Không tìm thấy kết quả',
                      description: _query.isEmpty
                          ? 'Tài liệu bạn tạo sẽ xuất hiện ở đây.'
                          : 'Thử từ khóa khác.',
                    );
                  }
                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.s2),
                    itemBuilder: (_, i) {
                      final doc = filtered[i];
                      return _HistoryCard(
                        doc: doc,
                        onView: () => _viewDetail(doc),
                        onDelete: () => _delete(doc),
                        formatDate: _formatDate,
                        isDark: isDark,
                        fg: fg,
                        muted: muted,
                        subtle: subtle,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Loading list ─────────────────────────────────────────────────────────────
class _LoadingList extends StatelessWidget {
  const _LoadingList();
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s2),
      itemBuilder: (_, __) => DgSkeleton.card(height: 80),
    );
  }
}

// ── History card ─────────────────────────────────────────────────────────────
class _HistoryCard extends StatelessWidget {
  final DocumentModel doc;
  final VoidCallback onView;
  final VoidCallback onDelete;
  final String Function(DateTime?) formatDate;
  final bool isDark;
  final Color fg, muted, subtle;

  const _HistoryCard({
    required this.doc,
    required this.onView,
    required this.onDelete,
    required this.formatDate,
    required this.isDark,
    required this.fg,
    required this.muted,
    required this.subtle,
  });

  @override
  Widget build(BuildContext context) {
    // Lấy 1 dòng preview từ markdown (loại bỏ ## ## ...)
    final preview = doc.contentMd
        .replaceAll(RegExp(r'#+\s'), '')
        .replaceAll(RegExp(r'\*\*'), '')
        .split('\n')
        .firstWhere((line) => line.trim().isNotEmpty, orElse: () => '');

    return DgCard(
      onTap: onView,
      child: Row(
        children: [
          // File icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.description_outlined,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        doc.title,
                        style: AppTypography.bodyMedium.copyWith(color: fg),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    DgBadge.neutral(label: doc.language.displayName),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  preview,
                  style: AppTypography.caption.copyWith(color: muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 11, color: subtle),
                    const SizedBox(width: 3),
                    Text(
                      formatDate(doc.createdAt),
                      style: AppTypography.caption.copyWith(color: subtle),
                    ),
                    if (doc.timeTakenMs != null) ...[
                      const SizedBox(width: AppSpacing.s3),
                      Icon(Icons.timer_outlined, size: 11, color: subtle),
                      const SizedBox(width: 3),
                      Text(
                        '${doc.timeTakenMs} ms',
                        style: AppTypography.caption.copyWith(
                          color: subtle,
                          fontFamily: 'JetBrainsMono',
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'view') onView();
              if (v == 'delete') onDelete();
            },
            elevation: 0,
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            icon: Icon(Icons.more_vert, size: 18, color: muted),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'view',
                child: Row(
                  children: [
                    const Icon(Icons.visibility_outlined, size: 16),
                    const SizedBox(width: 8),
                    Text('Xem', style: AppTypography.body),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline,
                        size: 16, color: AppColors.error),
                    const SizedBox(width: 8),
                    Text(
                      'Xóa',
                      style:
                          AppTypography.body.copyWith(color: AppColors.error),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Doc detail bottom sheet ──────────────────────────────────────────────────
class _DocDetailSheet extends StatelessWidget {
  final DocumentModel doc;
  const _DocDetailSheet({required this.doc});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final fg = isDark ? AppColors.fgDark : AppColors.fgLight;
    final h = MediaQuery.sizeOf(context).height * 0.85;

    return Container(
      height: h,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s5, AppSpacing.s4, AppSpacing.s3, AppSpacing.s3,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doc.title,
                          style: AppTypography.h4.copyWith(color: fg)),
                      Text(
                        doc.language.displayName,
                        style: AppTypography.caption.copyWith(
                          color: isDark
                              ? AppColors.fgSubtleDark
                              : AppColors.fgSubtleLight,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  iconSize: 20,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: border),
          Expanded(
            child: Markdown(
              data: doc.contentMd,
              padding: const EdgeInsets.all(AppSpacing.s5),
              styleSheet: MarkdownStyleSheet(
                p: AppTypography.body.copyWith(color: fg),
                h2: AppTypography.h3.copyWith(color: fg),
                h3: AppTypography.h4.copyWith(color: fg),
                code: AppTypography.code.copyWith(color: fg),
                codeblockDecoration: BoxDecoration(
                  color: isDark ? AppColors.bgDark : AppColors.sunkenLight,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: border),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
