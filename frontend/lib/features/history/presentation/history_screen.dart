import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../core/tokens/app_colors.dart';
import '../../../core/tokens/app_spacing.dart';
import '../../../core/tokens/app_typography.dart';
import '../../../shared/widgets/dg_badge.dart';
import '../../../shared/widgets/dg_button.dart';
import '../../../shared/widgets/dg_card.dart';
import '../../../shared/widgets/dg_input.dart';
import '../../../shared/widgets/dg_misc.dart';

// ── Mock data ─────────────────────────────────────────────────────────────────
// TODO: thay bằng dữ liệu thực từ API GET /history
class _HistoryItem {
  final String id;
  final String name;
  final String language;
  final String preview;
  final String content;
  final DateTime createdAt;
  final int tokens;

  const _HistoryItem({
    required this.id, required this.name, required this.language,
    required this.preview, required this.content,
    required this.createdAt, required this.tokens,
  });
}

final _mockHistory = [
  _HistoryItem(
    id: '1', name: 'UserService.ts', language: 'TypeScript',
    preview: 'Lớp xử lý nghiệp vụ người dùng, bao gồm CRUD và xác thực.',
    content: '## UserService\n\nLớp xử lý nghiệp vụ người dùng.\n\n### getUser(id)\nLấy người dùng theo ID.',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    tokens: 420,
  ),
  _HistoryItem(
    id: '2', name: 'payment_gateway.py', language: 'Python',
    preview: 'Module xử lý thanh toán tích hợp với Stripe và MoMo.',
    content: '## PaymentGateway\n\nModule xử lý thanh toán.\n\n### process_payment(amount)\nXử lý giao dịch thanh toán.',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    tokens: 680,
  ),
  _HistoryItem(
    id: '3', name: 'AuthController.java', language: 'Java',
    preview: 'Controller xác thực người dùng với JWT và refresh token.',
    content: '## AuthController\n\nXử lý endpoint xác thực.\n\n### login()\nĐăng nhập và trả về JWT.',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    tokens: 310,
  ),
  _HistoryItem(
    id: '4', name: 'report_engine.go', language: 'Go',
    preview: 'Engine sinh báo cáo PDF và Excel từ dữ liệu động.',
    content: '## ReportEngine\n\nSinh báo cáo đa định dạng.\n\n### GeneratePDF(data)\nXuất báo cáo PDF.',
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
    tokens: 540,
  ),
  _HistoryItem(
    id: '5', name: 'mobile_sdk.dart', language: 'Dart',
    preview: 'SDK Flutter cho ứng dụng mobile với các utility widget.',
    content: '## MobileSDK\n\nFlutter SDK.\n\n### initSDK()\nKhởi tạo SDK với config.',
    createdAt: DateTime.now().subtract(const Duration(days: 5)),
    tokens: 290,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _searchCtrl = TextEditingController();
  List<_HistoryItem> _items = List.from(_mockHistory);
  List<_HistoryItem> _filtered = List.from(_mockHistory);

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.from(_items)
          : _items
              .where((i) =>
                  i.name.toLowerCase().contains(q) ||
                  i.language.toLowerCase().contains(q) ||
                  i.preview.toLowerCase().contains(q))
              .toList();
    });
  }

  Future<void> _delete(String id) async {
    final confirmed = await DgConfirmDialog.show(
      context,
      title: 'Xóa tài liệu',
      message: 'Tài liệu này sẽ bị xóa vĩnh viễn. Bạn có chắc không?',
      confirmLabel: 'Xóa',
      destructive: true,
    );
    if (!confirmed) return;
    // TODO: gọi API DELETE /history/:id
    setState(() {
      _items.removeWhere((i) => i.id == id);
      _filtered.removeWhere((i) => i.id == id);
    });
    if (mounted) {
      DgToast.show(context, 'Đã xóa tài liệu', type: ToastType.success);
    }
  }

  void _viewDetail(_HistoryItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DocDetailSheet(item: item),
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24)   return '${diff.inHours} giờ trước';
    if (diff.inDays == 1)    return 'Hôm qua';
    return '${diff.inDays} ngày trước';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg     = isDark ? AppColors.fgDark     : AppColors.fgLight;
    final muted  = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    final subtle = isDark ? AppColors.fgSubtleDark : AppColors.fgSubtleLight;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Lịch sử', style: AppTypography.h2.copyWith(color: fg)),
                  Text(
                    '${_items.length} tài liệu đã tạo',
                    style: AppTypography.bodySmall.copyWith(color: muted),
                  ),
                ],
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
            child: _filtered.isEmpty
                ? DgEmptyState(
                    icon: Icons.history,
                    message: _searchCtrl.text.isEmpty
                        ? 'Chưa có tài liệu nào'
                        : 'Không tìm thấy kết quả',
                    description: _searchCtrl.text.isEmpty
                        ? 'Tài liệu bạn tạo sẽ xuất hiện ở đây.'
                        : 'Thử từ khóa khác.',
                  )
                : ListView.separated(
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.s2),
                    itemBuilder: (_, i) {
                      final item = _filtered[i];
                      return _HistoryCard(
                        item: item,
                        onView:   () => _viewDetail(item),
                        onDelete: () => _delete(item.id),
                        formatDate: _formatDate,
                        isDark: isDark,
                        fg: fg, muted: muted, subtle: subtle,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── History card ─────────────────────────────────────────────────────────────
class _HistoryCard extends StatelessWidget {
  final _HistoryItem item;
  final VoidCallback onView;
  final VoidCallback onDelete;
  final String Function(DateTime) formatDate;
  final bool isDark;
  final Color fg, muted, subtle;

  const _HistoryCard({
    required this.item, required this.onView, required this.onDelete,
    required this.formatDate, required this.isDark,
    required this.fg, required this.muted, required this.subtle,
  });

  @override
  Widget build(BuildContext context) {
    return DgCard(
      onTap: onView,
      child: Row(
        children: [
          // File icon
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.description_outlined, size: 20, color: AppColors.primary,
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
                        item.name,
                        style: AppTypography.bodyMedium.copyWith(color: fg),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    DgBadge.neutral(label: item.language),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.preview,
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
                      formatDate(item.createdAt),
                      style: AppTypography.caption.copyWith(color: subtle),
                    ),
                    const SizedBox(width: AppSpacing.s3),
                    Icon(Icons.toll, size: 11, color: subtle),
                    const SizedBox(width: 3),
                    Text(
                      '${item.tokens} tokens',
                      style: AppTypography.caption.copyWith(
                        color: subtle, fontFamily: 'JetBrainsMono',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Actions
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'view')   onView();
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
                    const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                    const SizedBox(width: 8),
                    Text(
                      'Xóa',
                      style: AppTypography.body.copyWith(color: AppColors.error),
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

// ── Doc detail bottom sheet ───────────────────────────────────────────────────
class _DocDetailSheet extends StatelessWidget {
  final _HistoryItem item;
  const _DocDetailSheet({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? AppColors.cardDark   : AppColors.cardLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final fg     = isDark ? AppColors.fgDark     : AppColors.fgLight;
    final h      = MediaQuery.sizeOf(context).height * 0.85;

    return Container(
      height: h,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: border, borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
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
                      Text(item.name,
                          style: AppTypography.h4.copyWith(color: fg)),
                      Text(
                        item.language,
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
          // Markdown content
          Expanded(
            child: Markdown(
              data: item.content,
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
