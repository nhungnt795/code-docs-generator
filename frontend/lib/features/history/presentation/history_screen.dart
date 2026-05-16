// lib/features/history/presentation/history_screen.dart
//
// THAY ĐỔI:
// 1. Đổi tên tài liệu: nút edit trên card, dialog nhập tên mới.
// 2. Xem code gốc (raw_code_context): tab "Code gốc" trong bottom sheet chi tiết.
// 3. Giữ nguyên tất cả tính năng cũ: xem/sửa nội dung MD, xuất PDF/DOCX/MD, xóa.

import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html_lib;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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

// ─────────────────────────────────────────────────────────────────────────────
// Download helpers (web)
// ─────────────────────────────────────────────────────────────────────────────
void _downloadString(String content, String filename) {
  if (kIsWeb) {
    _downloadBytes(utf8.encode(content), filename);
  }
}

void _downloadBytes(List<int> bytes, String filename) {
  if (kIsWeb) {
    final blob = html_lib.Blob([bytes], 'application/octet-stream');
    final url = html_lib.Url.createObjectUrlFromBlob(blob);
    final anchor = html_lib.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html_lib.Url.revokeObjectUrl(url);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HistoryScreen
// ─────────────────────────────────────────────────────────────────────────────
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

  Future<void> _delete(Document doc) async {
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
      await ref
          .read(historyRepoProvider)
          .deleteDoc(docId: doc.docId!, userId: user.userId);
      ref.invalidate(historyListProvider);
      if (mounted) {
        DgToast.show(context, 'Đã xóa tài liệu', type: ToastType.success);
      }
    } on ApiException catch (e) {
      if (mounted) DgToast.show(context, e.message, type: ToastType.error);
    }
  }

  /// Đổi tên tài liệu — hiện dialog nhập tên mới
  Future<void> _rename(Document doc) async {
    final user = ref.read(currentUserProvider);
    if (user == null || doc.docId == null) return;

    final ctrl = TextEditingController(text: doc.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi tên tài liệu'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Tên mới',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    ctrl.dispose();

    if (newTitle == null || newTitle.isEmpty || newTitle == doc.title) return;

    try {
      await ref.read(historyRepoProvider).updateDoc(
        docId: doc.docId!,
        userId: user.userId,
        contentMd: doc.contentMd,
        title: newTitle,
      );
      ref.invalidate(historyListProvider);
      if (mounted) {
        DgToast.show(context, 'Đã đổi tên thành "$newTitle"',
            type: ToastType.success);
      }
    } on ApiException catch (e) {
      if (mounted) DgToast.show(context, e.message, type: ToastType.error);
    }
  }

  void _viewDetail(Document doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DocDetailSheet(doc: doc),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.isUtc ? dt.toLocal() : dt;
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays == 1) return 'Hôm qua';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return DateFormat('dd/MM/yyyy HH:mm').format(local);
  }

  List<Document> _filter(List<Document> items) {
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
    final user = ref.watch(currentUserProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(historyListProvider),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lịch sử', style: AppTypography.h2.copyWith(color: fg)),
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
            DgInput.search(
              hint: 'Tìm theo tên tệp, ngôn ngữ...',
              controller: _searchCtrl,
            ),
            const SizedBox(height: AppSpacing.s4),
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
                        isAdmin: user?.isAdmin ?? false,
                        onView: () => _viewDetail(doc),
                        onDelete: () => _delete(doc),
                        onRename: () => _rename(doc),
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

// ─────────────────────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
class _HistoryCard extends StatelessWidget {
  final Document doc;
  final bool isAdmin;
  final VoidCallback onView;
  final VoidCallback onDelete;
  final VoidCallback onRename;
  final String Function(DateTime?) formatDate;
  final bool isDark;
  final Color fg, muted, subtle;

  const _HistoryCard({
    required this.doc,
    required this.isAdmin,
    required this.onView,
    required this.onDelete,
    required this.onRename,
    required this.formatDate,
    required this.isDark,
    required this.fg,
    required this.muted,
    required this.subtle,
  });

  @override
  Widget build(BuildContext context) {
    final preview = doc.contentMd
        .replaceAll(RegExp(r'#+\s'), '')
        .replaceAll(RegExp(r'\*\*'), '')
        .split('\n')
        .firstWhere((line) => line.trim().isNotEmpty, orElse: () => '');

    return DgCard(
      onTap: onView,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.description_outlined,
                size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(doc.title,
                          style:
                          AppTypography.bodyMedium.copyWith(color: fg),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    DgBadge.neutral(label: doc.language.displayName),
                  ],
                ),
                const SizedBox(height: 4),
                Text(preview,
                    style: AppTypography.caption.copyWith(color: muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
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
                      Text('${doc.timeTakenMs} ms',
                          style: AppTypography.caption.copyWith(
                            color: subtle,
                            fontFamily: 'JetBrainsMono',
                          )),
                    ],
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'view') onView();
              if (v == 'rename') onRename();
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
                child: Row(children: [
                  const Icon(Icons.visibility_outlined, size: 16),
                  const SizedBox(width: 8),
                  Text('Xem & chỉnh sửa', style: AppTypography.body),
                ]),
              ),
              PopupMenuItem(
                value: 'rename',
                child: Row(children: [
                  const Icon(Icons.drive_file_rename_outline,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('Đổi tên',
                      style: AppTypography.body
                          .copyWith(color: AppColors.primary)),
                ]),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  const Icon(Icons.delete_outline,
                      size: 16, color: AppColors.error),
                  const SizedBox(width: 8),
                  Text('Xóa',
                      style: AppTypography.body
                          .copyWith(color: AppColors.error)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Doc detail bottom sheet — Xem MD, Xem Code gốc, Sửa, Xuất
// ─────────────────────────────────────────────────────────────────────────────
class _DocDetailSheet extends ConsumerStatefulWidget {
  final Document doc;
  const _DocDetailSheet({required this.doc});

  @override
  ConsumerState<_DocDetailSheet> createState() => _DocDetailSheetState();
}

class _DocDetailSheetState extends ConsumerState<_DocDetailSheet>
    with SingleTickerProviderStateMixin {
  late Document _doc;
  bool _editMode = false;
  bool _saving = false;
  bool _renaming = false;
  late final TextEditingController _editCtrl;
  late final TextEditingController _titleCtrl;
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _doc = widget.doc;
    _editCtrl = TextEditingController(text: _doc.contentMd);
    _titleCtrl = TextEditingController(text: _doc.title);
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    _titleCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider);
    if (user == null || _doc.docId == null) return;

    setState(() => _saving = true);
    try {
      final updated = await ref.read(historyRepoProvider).updateDoc(
        docId: _doc.docId!,
        userId: user.userId,
        contentMd: _editCtrl.text,
      );
      setState(() {
        _doc = updated;
        _editMode = false;
        _saving = false;
      });
      ref.invalidate(historyListProvider);
      if (mounted) {
        DgToast.show(context, 'Đã lưu tài liệu', type: ToastType.success);
      }
    } on ApiException catch (e) {
      setState(() => _saving = false);
      if (mounted) DgToast.show(context, e.message, type: ToastType.error);
    }
  }

  Future<void> _saveTitle() async {
    final user = ref.read(currentUserProvider);
    if (user == null || _doc.docId == null) return;
    final newTitle = _titleCtrl.text.trim();
    if (newTitle.isEmpty || newTitle == _doc.title) {
      setState(() => _renaming = false);
      return;
    }
    setState(() => _saving = true);
    try {
      final updated = await ref.read(historyRepoProvider).updateDoc(
        docId: _doc.docId!,
        userId: user.userId,
        contentMd: _doc.contentMd,
        title: newTitle,
      );
      setState(() {
        _doc = updated;
        _titleCtrl.text = updated.title;
        _renaming = false;
        _saving = false;
      });
      ref.invalidate(historyListProvider);
      if (mounted) {
        DgToast.show(context, 'Đã đổi tên thành "$newTitle"',
            type: ToastType.success);
      }
    } on ApiException catch (e) {
      setState(() => _saving = false);
      if (mounted) DgToast.show(context, e.message, type: ToastType.error);
    }
  }

  void _copyContent() {
    final text = _editMode ? _editCtrl.text : _doc.contentMd;
    Clipboard.setData(ClipboardData(text: text));
    DgToast.show(context, 'Đã sao chép', type: ToastType.success);
  }

  void _exportMd() {
    final content = _editMode ? _editCtrl.text : _doc.contentMd;
    final name =
        '${_doc.title.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_')}.md';
    _downloadString(content, name);
    DgToast.show(context, 'Đang tải xuống Markdown...', type: ToastType.info);
  }

  Future<void> _exportPdf() async {
    final user = ref.read(currentUserProvider);
    if (user == null || _doc.docId == null) return;
    try {
      DgToast.show(context, 'Đang tạo PDF...', type: ToastType.info);
      final bytes = await ref.read(historyRepoProvider).exportPdf(
        docId: _doc.docId!,
        userId: user.userId,
      );
      _downloadBytes(bytes, '${_doc.title}.pdf');
      if (mounted) {
        DgToast.show(context, 'Đã tải xuống PDF', type: ToastType.success);
      }
    } on ApiException catch (e) {
      if (mounted) DgToast.show(context, e.message, type: ToastType.error);
    }
  }

  Future<void> _exportDocx() async {
    final user = ref.read(currentUserProvider);
    if (user == null || _doc.docId == null) return;
    try {
      DgToast.show(context, 'Đang tạo Word...', type: ToastType.info);
      final bytes = await ref.read(historyRepoProvider).exportDocx(
        docId: _doc.docId!,
        userId: user.userId,
      );
      _downloadBytes(bytes, '${_doc.title}.docx');
      if (mounted) {
        DgToast.show(context, 'Đã tải xuống Word (.docx)',
            type: ToastType.success);
      }
    } on ApiException catch (e) {
      if (mounted) DgToast.show(context, e.message, type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final fg = isDark ? AppColors.fgDark : AppColors.fgLight;
    final muted = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    final h = MediaQuery.sizeOf(context).height * 0.92;
    final user = ref.watch(currentUserProvider);
    final canEdit = user != null;

    return Container(
      height: h,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          // ── Handle bar ───────────────────────────────────────────────
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration:
              BoxDecoration(color: border, borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // ── Header ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.s5, AppSpacing.s4, AppSpacing.s3, AppSpacing.s2),
            child: Row(
              children: [
                Expanded(
                  child: _renaming
                      ? Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _titleCtrl,
                        autofocus: true,
                        style: AppTypography.h4.copyWith(color: fg),
                        decoration: InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: border),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                        ),
                        onSubmitted: (_) => _saveTitle(),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: _saving
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                        CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(Icons.check,
                          size: 18, color: AppColors.success),
                      onPressed: _saving ? null : _saveTitle,
                      tooltip: 'Lưu tên',
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 18, color: muted),
                      onPressed: () => setState(() {
                        _renaming = false;
                        _titleCtrl.text = _doc.title;
                      }),
                      tooltip: 'Huỷ',
                    ),
                  ])
                      : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(_doc.title,
                              style: AppTypography.h4.copyWith(color: fg),
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (canEdit)
                          IconButton(
                            icon: Icon(
                                Icons.drive_file_rename_outline,
                                size: 16,
                                color: muted),
                            tooltip: 'Đổi tên',
                            onPressed: () =>
                                setState(() => _renaming = true),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ]),
                      Text(
                        '${_doc.language.displayName} · ${_formatDate(_doc.updatedAt)}',
                        style:
                        AppTypography.caption.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
                // Toolbar
                Row(mainAxisSize: MainAxisSize.min, children: [
                  if (canEdit && !_renaming) ...[
                    IconButton(
                      icon: Icon(
                        _editMode
                            ? Icons.visibility_outlined
                            : Icons.edit_outlined,
                        size: 18,
                        color: _editMode ? AppColors.primary : muted,
                      ),
                      tooltip: _editMode ? 'Xem' : 'Chỉnh sửa',
                      onPressed: () {
                        setState(() {
                          _editMode = !_editMode;
                          if (!_editMode) _editCtrl.text = _doc.contentMd;
                        });
                      },
                    ),
                    if (_editMode)
                      IconButton(
                        icon: _saving
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                          CircularProgressIndicator(strokeWidth: 2),
                        )
                            : Icon(Icons.save_outlined,
                            size: 18, color: AppColors.primary),
                        tooltip: 'Lưu',
                        onPressed: _saving ? null : _save,
                      ),
                  ],
                  IconButton(
                    icon: Icon(Icons.copy_outlined, size: 18, color: muted),
                    tooltip: 'Sao chép',
                    onPressed: _copyContent,
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'md') _exportMd();
                      if (v == 'pdf') _exportPdf();
                      if (v == 'docx') _exportDocx();
                    },
                    icon: Icon(Icons.download_outlined, size: 18, color: muted),
                    tooltip: 'Xuất file',
                    elevation: 0,
                    color: bg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: border),
                    ),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'md',
                        height: 40,
                        child: Row(children: [
                          const Icon(Icons.description_outlined, size: 16),
                          const SizedBox(width: 8),
                          Text('Markdown (.md)', style: AppTypography.bodySmall),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'pdf',
                        height: 40,
                        child: Row(children: [
                          const Icon(Icons.picture_as_pdf_outlined,
                              size: 16, color: Colors.red),
                          const SizedBox(width: 8),
                          Text('PDF (.pdf)', style: AppTypography.bodySmall),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'docx',
                        height: 40,
                        child: Row(children: [
                          const Icon(Icons.article_outlined,
                              size: 16, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text('Word (.docx)', style: AppTypography.bodySmall),
                        ]),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: muted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ]),
              ],
            ),
          ),

          // ── Tabs: Nội dung MD | Code gốc ─────────────────────────────
          TabBar(
            controller: _tabCtrl,
            tabs: const [
              Tab(text: 'Nội dung tài liệu'),
              Tab(text: 'Code gốc'),
            ],
            labelColor: AppColors.primary,
            unselectedLabelColor: muted,
            indicatorColor: AppColors.primary,
            dividerColor: border,
          ),

          // ── Content ──────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                // Tab 1: Nội dung markdown (xem / chỉnh sửa)
                _editMode
                    ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.s4),
                  child: TextField(
                    controller: _editCtrl,
                    maxLines: null,
                    minLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: AppTypography.code
                        .copyWith(color: fg, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Chỉnh sửa nội dung Markdown...',
                      hintStyle: AppTypography.code
                          .copyWith(color: muted, fontSize: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide:
                        const BorderSide(color: AppColors.primary),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                )
                    : Markdown(
                  data: _doc.contentMd,
                  padding: const EdgeInsets.all(AppSpacing.s5),
                  styleSheet: MarkdownStyleSheet(
                    p: AppTypography.body.copyWith(color: fg),
                    h2: AppTypography.h3.copyWith(color: fg),
                    h3: AppTypography.h4.copyWith(color: fg),
                    code: AppTypography.code.copyWith(color: fg),
                    codeblockDecoration: BoxDecoration(
                      color: isDark
                          ? AppColors.bgDark
                          : AppColors.sunkenLight,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: border),
                    ),
                  ),
                ),

                // Tab 2: Code gốc (raw_code_context)
                _doc.rawCodeContext.isNotEmpty
                    ? SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.s5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.code, size: 16, color: muted),
                        const SizedBox(width: 6),
                        Text(
                          'Code ${_doc.language.displayName} gốc đã dán/upload',
                          style: AppTypography.caption.copyWith(color: muted),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.copy_outlined,
                              size: 15, color: muted),
                          tooltip: 'Sao chép code gốc',
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: _doc.rawCodeContext));
                            DgToast.show(context, 'Đã sao chép',
                                type: ToastType.success);
                          },
                        ),
                      ]),
                      const SizedBox(height: AppSpacing.s3),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.bgDark
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: border),
                        ),
                        child: SelectableText(
                          _doc.rawCodeContext,
                          style: AppTypography.code
                              .copyWith(color: fg, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                )
                    : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.code_off_outlined,
                          size: 48, color: muted),
                      const SizedBox(height: AppSpacing.s3),
                      Text('Không có code gốc',
                          style:
                          AppTypography.body.copyWith(color: muted)),
                      const SizedBox(height: 4),
                      Text(
                        'Tài liệu này không đính kèm code nguồn.',
                        style: AppTypography.caption.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.isUtc ? dt.toLocal() : dt;
    return DateFormat('dd/MM/yyyy HH:mm').format(local);
  }
}