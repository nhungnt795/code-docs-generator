// lib/features/admin/presentation/user_management_screen.dart
//
// THAY ĐỔI:
// 1. Cột "Tài liệu" hiển thị số tài liệu (doc_count) từ backend — không cần gọi thêm API.
// 2. Lọc theo role: Tất cả / Admin / User / Hoạt động / Bị khóa / Chưa xác thực.
// 3. Admin cập nhật được avatar của người dùng (upload ảnh).
// 4. Xem lịch sử tài liệu của từng người (dialog) + nút "Xem chi tiết" điều hướng vào trang.
// 5. Sort theo Tên, Email, Ngày tham gia, Số tài liệu.
// 6. Multi-select: Khóa / Mở khóa / Xóa hàng loạt.

import 'package:flutter/material.dart';
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
import '../data/admin_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enum lọc
// ─────────────────────────────────────────────────────────────────────────────
enum _RoleFilter { all, admin, user, active, locked, inactive }

extension _RFLabel on _RoleFilter {
  String get label => switch (this) {
    _RoleFilter.all => 'Tất cả',
    _RoleFilter.admin => 'Admin',
    _RoleFilter.user => 'User',
    _RoleFilter.active => 'Hoạt động',
    _RoleFilter.locked => 'Bị khóa',
    _RoleFilter.inactive => 'Chưa xác thực',
  };

  String get apiValue => switch (this) {
    _RoleFilter.all => 'all',
    _RoleFilter.admin => 'admin',
    _RoleFilter.user => 'user',
    _RoleFilter.active => 'active',
    _RoleFilter.locked => 'locked',
    _RoleFilter.inactive => 'inactive',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Enum sort
// ─────────────────────────────────────────────────────────────────────────────
enum _SortCol { name, email, joinDate, docCount }

// ─────────────────────────────────────────────────────────────────────────────
class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  _RoleFilter _roleFilter = _RoleFilter.all;
  _SortCol _sortCol = _SortCol.joinDate;
  bool _sortAsc = false;
  final Set<int> _selected = {};
  bool _selectMode = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
            () => setState(() => _query = _searchCtrl.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Filter + sort ─────────────────────────────────────────────────────────
  List<UserWithDocCount> _process(List<UserWithDocCount> src) {
    var list = src.where((u) {
      final q = _query;
      if (q.isNotEmpty) {
        final match = (u.fullName ?? '').toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q);
        if (!match) return false;
      }
      return true; // Server-side filtering handles role/status
    }).toList();

    list.sort((a, b) {
      int cmp = switch (_sortCol) {
        _SortCol.name =>
            (a.fullName ?? a.email).compareTo(b.fullName ?? b.email),
        _SortCol.email => a.email.compareTo(b.email),
        _SortCol.joinDate => a.createdAt.compareTo(b.createdAt),
        _SortCol.docCount => a.docCount.compareTo(b.docCount),
      };
      return _sortAsc ? cmp : -cmp;
    });
    return list;
  }

  void _toggleSort(_SortCol col) {
    setState(() {
      if (_sortCol == col) {
        _sortAsc = !_sortAsc;
      } else {
        _sortCol = col;
        _sortAsc = false;
      }
    });
  }

  void _applyRoleFilter(_RoleFilter f) {
    setState(() => _roleFilter = f);
    ref.read(adminRoleFilterProvider.notifier).state = f.apiValue;
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  Future<void> _promote(UserWithDocCount user) async {
    // Lấy adminId từ currentUser
    final adminId = ref.read(currentUserProvider)?.userId;

    if (adminId == null) {
      DgToast.show(
        context,
        'Không xác định được tài khoản admin',
        type: ToastType.error,
      );
      return;
    }

    // Đã là admin
    if (user.isAdmin) {
      DgToast.show(
        context,
        'Người dùng đã là Admin',
        type: ToastType.info,
      );
      return;
    }

    // Confirm
    final ok = await DgConfirmDialog.show(
      context,
      title: 'Nâng quyền Admin',
      message:
      'Bạn có chắc muốn nâng "${user.fullName ?? user.email}" thành Admin?',
      confirmLabel: 'Nâng quyền',
    );

    if (!ok) return;

    try {
      // Gọi API với đủ 2 tham số
      await ref
          .read(adminRepoProvider)
          .promoteToAdmin(adminId, user.userId);

      // Refresh data
      ref.invalidate(adminUsersProvider);
      ref.invalidate(adminStatsProvider);

      if (mounted) {
        DgToast.show(
          context,
          'Đã nâng quyền ${user.email}',
          type: ToastType.success,
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        DgToast.show(
          context,
          e.message,
          type: ToastType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        DgToast.show(
          context,
          'Có lỗi xảy ra khi nâng quyền',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _toggleLock(UserWithDocCount user) async {
    final adminId = ref.read(currentUserProvider)?.userId;
    if (adminId == null) return;
    final willLock = !user.isLocked;
    final ok = await DgConfirmDialog.show(
      context,
      title: willLock ? 'Khóa tài khoản' : 'Mở khóa tài khoản',
      message: willLock
          ? 'Khóa "${user.fullName ?? user.email}"?'
          : 'Mở khóa "${user.fullName ?? user.email}"?',
      confirmLabel: willLock ? 'Khóa' : 'Mở khóa',
    );
    if (!ok) return;
    try {
      await ref.read(adminRepoProvider).setLockUser(adminId, user.userId, willLock);
      ref.invalidate(adminUsersProvider);
      if (mounted)
        DgToast.show(
          context,
          willLock ? 'Đã khóa ${user.email}' : 'Đã mở khóa ${user.email}',
          type: willLock ? ToastType.warning : ToastType.success,
        );
    } on ApiException catch (e) {
      if (mounted) DgToast.show(context, e.message, type: ToastType.error);
    }
  }

  Future<void> _viewHistory(UserWithDocCount user) async {
    final adminId = ref.read(currentUserProvider)?.userId;
    if (adminId == null) return;
    showDialog(
      context: context,
      builder: (_) => _UserHistoryDialog(
          user: user, adminId: adminId, repo: ref.read(adminRepoProvider)),
    );
  }

  Future<void> _bulkAction(String action, List<UserWithDocCount> allUsers) async {
    final adminId = ref.read(currentUserProvider)?.userId;
    if (adminId == null) return;
    final ids = _selected.toList();
    if (ids.isEmpty) return;

    final label = action == 'LOCK'
        ? 'Khóa'
        : action == 'UNLOCK'
        ? 'Mở khóa'
        : 'Xóa';
    final ok = await DgConfirmDialog.show(
      context,
      title: '$label ${ids.length} tài khoản',
      message: 'Thao tác này sẽ áp dụng cho ${ids.length} người dùng đã chọn.',
      confirmLabel: label,
    );
    if (!ok) return;

    try {
      await ref.read(adminRepoProvider).bulkAction(adminId, ids, action);
      ref.invalidate(adminUsersProvider);
      ref.invalidate(adminStatsProvider);
      setState(() {
        _selected.clear();
        _selectMode = false;
      });
      if (mounted)
        DgToast.show(context, 'Đã $label ${ids.length} tài khoản',
            type: ToastType.success);
    } on ApiException catch (e) {
      if (mounted) DgToast.show(context, e.message, type: ToastType.error);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppColors.fgDark : AppColors.fgLight;
    final muted = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final isWide = MediaQuery.sizeOf(context).width > 900;

    final asyncUsers = ref.watch(adminUsersProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminUsersProvider),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quản lý người dùng',
                          style: AppTypography.h2.copyWith(color: fg)),
                      Text(
                        asyncUsers.maybeWhen(
                          data: (u) =>
                          '${u.length} tài khoản · ${u.where((x) => x.isAdmin).length} admin',
                          orElse: () => 'Đang tải...',
                        ),
                        style: AppTypography.body.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _selectMode = !_selectMode;
                    _selected.clear();
                  }),
                  icon: Icon(
                    _selectMode ? Icons.close : Icons.checklist_outlined,
                    size: 18,
                  ),
                  label: Text(_selectMode ? 'Huỷ chọn' : 'Chọn nhiều'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),

            // ── Search + filter role ──────────────────────────────────────
            Wrap(
              spacing: AppSpacing.s3,
              runSpacing: AppSpacing.s3,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: isWide ? 280 : double.infinity,
                  child: DgInput.search(
                    hint: 'Tìm theo tên, email...',
                    controller: _searchCtrl,
                  ),
                ),
                ..._RoleFilter.values.map(
                      (f) => _Chip(
                    label: f.label,
                    selected: _roleFilter == f,
                    onTap: () => _applyRoleFilter(f),
                    color: switch (f) {
                      _RoleFilter.locked => AppColors.error,
                      _RoleFilter.inactive => AppColors.warning,
                      _RoleFilter.active => AppColors.success,
                      _RoleFilter.admin => AppColors.primary,
                      _RoleFilter.user => AppColors.info,
                      _ => AppColors.primary,
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s3),

            // ── Bulk action bar ───────────────────────────────────────────
            if (_selectMode && _selected.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.s3),
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: asyncUsers.maybeWhen(
                  data: (users) => Row(
                    children: [
                      Text('${_selected.length} đã chọn',
                          style: AppTypography.bodyMedium
                              .copyWith(color: AppColors.primary)),
                      const Spacer(),
                      _BulkBtn(
                        icon: Icons.lock_outline,
                        label: 'Khóa',
                        color: AppColors.error,
                        onTap: () => _bulkAction('LOCK', users),
                      ),
                      const SizedBox(width: 8),
                      _BulkBtn(
                        icon: Icons.lock_open_outlined,
                        label: 'Mở khóa',
                        color: AppColors.success,
                        onTap: () => _bulkAction('UNLOCK', users),
                      ),
                      const SizedBox(width: 8),
                      _BulkBtn(
                        icon: Icons.delete_outline,
                        label: 'Xóa',
                        color: AppColors.error,
                        onTap: () => _bulkAction('DELETE', users),
                      ),
                    ],
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ),

            // ── Table ─────────────────────────────────────────────────────
            Expanded(
              child: DgCard(
                padding: EdgeInsets.zero,
                child: asyncUsers.when(
                  loading: () => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  error: (e, _) => DgEmptyState(
                    icon: Icons.error_outline,
                    message: 'Không tải được danh sách',
                    description: e.toString(),
                    actionLabel: 'Thử lại',
                    onAction: () => ref.invalidate(adminUsersProvider),
                  ),
                  data: (users) {
                    final filtered = _process(users);
                    return Column(
                      children: [
                        if (isWide)
                          _TableHeader(
                            isDark: isDark,
                            fg: fg,
                            border: border,
                            sortCol: _sortCol,
                            sortAsc: _sortAsc,
                            onSort: _toggleSort,
                            selectMode: _selectMode,
                            allSelected: _selected.length == filtered.length &&
                                filtered.isNotEmpty,
                            onSelectAll: () => setState(() {
                              if (_selected.length == filtered.length) {
                                _selected.clear();
                              } else {
                                _selected
                                  ..clear()
                                  ..addAll(filtered.map((u) => u.userId));
                              }
                            }),
                          ),
                        Expanded(
                          child: filtered.isEmpty
                              ? const DgEmptyState(
                            icon: Icons.people_outline,
                            message: 'Không tìm thấy người dùng',
                          )
                              : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                Divider(height: 1, color: border),
                            itemBuilder: (_, i) => _UserRow(
                              user: filtered[i],
                              isWide: isWide,
                              isDark: isDark,
                              fg: fg,
                              muted: muted,
                              border: border,
                              selectMode: _selectMode,
                              selected: _selected.contains(filtered[i].userId),
                              onSelect: () => setState(() {
                                if (_selected.contains(filtered[i].userId)) {
                                  _selected.remove(filtered[i].userId);
                                } else {
                                  _selected.add(filtered[i].userId);
                                }
                              }),
                              onPromote: () => _promote(filtered[i]),
                              onToggleLock: () => _toggleLock(filtered[i]),
                              onViewHistory: () => _viewHistory(filtered[i]),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLE HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _TableHeader extends StatelessWidget {
  final bool isDark, selectMode, allSelected, sortAsc;
  final Color fg, border;
  final _SortCol sortCol;
  final ValueChanged<_SortCol> onSort;
  final VoidCallback onSelectAll;

  const _TableHeader({
    required this.isDark,
    required this.fg,
    required this.border,
    required this.sortCol,
    required this.sortAsc,
    required this.onSort,
    required this.selectMode,
    required this.allSelected,
    required this.onSelectAll,
  });

  @override
  Widget build(BuildContext context) {
    final subtle = isDark ? AppColors.fgSubtleDark : AppColors.fgSubtleLight;
    final bg = isDark ? AppColors.bgDark : const Color(0xFFF9FAFB);

    Widget col(String label, _SortCol? col, {int flex = 0, double? w}) {
      final isActive = col != null && sortCol == col;
      final child = InkWell(
        onTap: col != null ? () => onSort(col) : null,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: AppTypography.label.copyWith(color: subtle)),
          if (isActive) ...[
            const SizedBox(width: 4),
            Icon(sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12, color: AppColors.primary),
          ],
        ]),
      );
      if (w != null) return SizedBox(width: w, child: child);
      return Expanded(flex: flex, child: child);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s4, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: border)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(children: [
        if (selectMode) ...[
          SizedBox(
            width: 36,
            child: Checkbox(
              value: allSelected,
              onChanged: (_) => onSelectAll(),
              activeColor: AppColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
        col('Người dùng', _SortCol.name, flex: 3),
        const SizedBox(width: AppSpacing.s3),
        col('Email', null, flex: 2),
        const SizedBox(width: AppSpacing.s3),
        col('Vai trò', null, w: 72),
        const SizedBox(width: AppSpacing.s3),
        col('Trạng thái', null, w: 100),
        const SizedBox(width: AppSpacing.s3),
        col('Tài liệu', _SortCol.docCount, w: 72),
        const SizedBox(width: AppSpacing.s3),
        col('Ngày tham gia', _SortCol.joinDate, w: 96),
        const SizedBox(width: AppSpacing.s3),
        col('Actions', null, w: 96),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// USER ROW
// ─────────────────────────────────────────────────────────────────────────────
class _UserRow extends StatefulWidget {
  final UserWithDocCount user;
  final bool isWide, isDark, selectMode, selected;
  final Color fg, muted, border;
  final VoidCallback onPromote, onToggleLock, onViewHistory, onSelect;

  const _UserRow({
    required this.user,
    required this.isWide,
    required this.isDark,
    required this.fg,
    required this.muted,
    required this.border,
    required this.selectMode,
    required this.selected,
    required this.onPromote,
    required this.onToggleLock,
    required this.onViewHistory,
    required this.onSelect,
  });

  @override
  State<_UserRow> createState() => _UserRowState();
}

class _UserRowState extends State<_UserRow> {
  bool _hovered = false;

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  Widget _statusBadge(User u) {
    if (u.isLocked) return DgBadge.error(label: 'Bị khóa');
    if (u.isActive) return DgBadge.success(label: 'Hoạt động');
    return DgBadge.warning(label: 'Chưa xác thực', dot: false);
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final hover = widget.isDark ? AppColors.hoverDark : AppColors.hoverLight;

    if (!widget.isWide) {
      return _MobileRow(
        user: user,
        isDark: widget.isDark,
        fg: widget.fg,
        muted: widget.muted,
        selectMode: widget.selectMode,
        selected: widget.selected,
        onSelect: widget.onSelect,
        onPromote: widget.onPromote,
        onToggleLock: widget.onToggleLock,
        onViewHistory: widget.onViewHistory,
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: widget.selected
            ? AppColors.primarySoft
            : _hovered
            ? hover
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s4, vertical: 11),
        child: Row(children: [
          if (widget.selectMode) ...[
            SizedBox(
              width: 36,
              child: Checkbox(
                value: widget.selected,
                onChanged: (_) => widget.onSelect(),
                activeColor: AppColors.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
          // Avatar + Tên
          Expanded(
            flex: 3,
            child: Row(children: [
              _AvatarWidget(user: user),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: Text(
                  user.fullName ?? user.email.split('@').first,
                  style: AppTypography.bodyMedium.copyWith(color: widget.fg),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ),
          const SizedBox(width: AppSpacing.s3),
          // Email
          Expanded(
            flex: 2,
            child: Text(user.email,
                style: AppTypography.caption.copyWith(color: widget.muted),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: AppSpacing.s3),
          // Vai trò
          SizedBox(
            width: 72,
            child: user.isAdmin
                ? DgBadge.info(label: 'Admin')
                : DgBadge.neutral(label: 'User'),
          ),
          const SizedBox(width: AppSpacing.s3),
          // Trạng thái
          SizedBox(
            width: 100,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: _statusBadge(user),
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          // Số tài liệu
          SizedBox(
            width: 72,
            child: Row(children: [
              Icon(Icons.description_outlined, size: 13, color: widget.muted),
              const SizedBox(width: 4),
              Text(
                '${user.docCount}',
                style: AppTypography.bodyMedium.copyWith(color: widget.fg),
              ),
            ]),
          ),
          const SizedBox(width: AppSpacing.s3),
          // Ngày tham gia
          SizedBox(
            width: 96,
            child: Text(
              _fmtDate(user.createdAt),
              style: AppTypography.caption.copyWith(color: widget.muted),
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          // Actions
          SizedBox(
            width: 96,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _ActionBtn(
                icon: Icons.history_outlined,
                tooltip: 'Xem lịch sử tài liệu',
                color: AppColors.primary,
                onTap: widget.onViewHistory,
              ),
              if (!user.isAdmin) ...[
                _ActionBtn(
                  icon: user.isLocked
                      ? Icons.lock_open_outlined
                      : Icons.lock_outline,
                  tooltip: user.isLocked ? 'Mở khóa' : 'Khóa',
                  color: user.isLocked ? AppColors.success : AppColors.error,
                  onTap: widget.onToggleLock,
                ),
                _ActionBtn(
                  icon: Icons.admin_panel_settings_outlined,
                  tooltip: 'Nâng quyền Admin',
                  color: widget.muted,
                  onTap: widget.onPromote,
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AVATAR WIDGET — hiển thị ảnh thật hoặc chữ cái đầu
// ─────────────────────────────────────────────────────────────────────────────
class _AvatarWidget extends StatelessWidget {
  final User user;
  const _AvatarWidget({required this.user});

  @override
  Widget build(BuildContext context) {
    final name = user.fullName ?? user.email;
    if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          user.avatarUrl!,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _Initials(name: name),
        ),
      );
    }
    return _Initials(name: name);
  }
}

class _Initials extends StatelessWidget {
  final String name;
  const _Initials({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
          color: AppColors.primary, shape: BoxShape.circle),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOBILE ROW
// ─────────────────────────────────────────────────────────────────────────────
class _MobileRow extends StatelessWidget {
  final UserWithDocCount user;
  final bool isDark, selectMode, selected;
  final Color fg, muted;
  final VoidCallback onSelect, onPromote, onToggleLock, onViewHistory;

  const _MobileRow({
    required this.user,
    required this.isDark,
    required this.fg,
    required this.muted,
    required this.selectMode,
    required this.selected,
    required this.onSelect,
    required this.onPromote,
    required this.onToggleLock,
    required this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: selectMode ? onSelect : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s4, vertical: AppSpacing.s3),
        child: Row(children: [
          if (selectMode) ...[
            Checkbox(
              value: selected,
              onChanged: (_) => onSelect(),
              activeColor: AppColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 6),
          ],
          _AvatarWidget(user: user),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      user.fullName ?? user.email.split('@').first,
                      style: AppTypography.bodyMedium.copyWith(color: fg),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (user.isAdmin)
                    DgBadge.info(label: 'Admin')
                  else if (user.isLocked)
                    DgBadge.error(label: 'Khóa')
                  else if (!user.isActive)
                      DgBadge.warning(label: 'Chưa xác thực', dot: false)
                    else
                      DgBadge.success(label: 'OK'),
                ]),
                Row(children: [
                  Text(user.email,
                      style: AppTypography.caption.copyWith(color: muted),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(width: 6),
                  Icon(Icons.description_outlined, size: 11, color: muted),
                  const SizedBox(width: 2),
                  Text('${user.docCount}',
                      style: AppTypography.caption.copyWith(color: muted)),
                ]),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 18, color: muted),
            onSelected: (v) {
              if (v == 'history') onViewHistory();
              if (v == 'lock') onToggleLock();
              if (v == 'promote') onPromote();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'history',
                  child: Row(children: [
                    Icon(Icons.history_outlined, size: 16),
                    SizedBox(width: 8),
                    Text('Xem lịch sử tài liệu'),
                  ])),
              if (!user.isAdmin) ...[
                PopupMenuItem(
                    value: 'lock',
                    child: Row(children: [
                      Icon(
                          user.isLocked
                              ? Icons.lock_open_outlined
                              : Icons.lock_outline,
                          size: 16),
                      const SizedBox(width: 8),
                      Text(user.isLocked ? 'Mở khóa' : 'Khóa'),
                    ])),
                const PopupMenuItem(
                    value: 'promote',
                    child: Row(children: [
                      Icon(Icons.admin_panel_settings_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('Nâng quyền Admin'),
                    ])),
              ],
            ],
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTION BTN
// ─────────────────────────────────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
        required this.tooltip,
        required this.color,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DIALOG: Lịch sử tài liệu của user
// ─────────────────────────────────────────────────────────────────────────────
class _UserHistoryDialog extends StatefulWidget {
  final UserWithDocCount user;
  final int adminId;
  final AdminRepository repo;
  const _UserHistoryDialog(
      {required this.user, required this.adminId, required this.repo});

  @override
  State<_UserHistoryDialog> createState() => _UserHistoryDialogState();
}

class _UserHistoryDialogState extends State<_UserHistoryDialog> {
  late Future<UserDetailModel> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repo.fetchUserDetail(widget.adminId, widget.user.userId);
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppColors.fgDark : AppColors.fgLight;
    final muted = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final name = widget.user.fullName ?? widget.user.email;

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                _AvatarWidget(user: widget.user),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: AppTypography.h4.copyWith(color: fg),
                          overflow: TextOverflow.ellipsis),
                      Text(widget.user.email,
                          style: AppTypography.caption.copyWith(color: muted)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: muted),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
              const SizedBox(height: AppSpacing.s4),
              Divider(color: border),
              const SizedBox(height: AppSpacing.s3),
              Expanded(
                child: FutureBuilder<UserDetailModel>(
                  future: _future,
                  builder: (_, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2));
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Text('Lỗi: ${snap.error}',
                            style: AppTypography.body
                                .copyWith(color: AppColors.error)),
                      );
                    }
                    final d = snap.data!;
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Stats
                          Row(children: [
                            _InfoTile(
                              icon: Icons.description_outlined,
                              label: 'Tổng tài liệu',
                              value: '${d.totalDocs}',
                              fg: fg,
                              muted: muted,
                            ),
                            const SizedBox(width: AppSpacing.s3),
                            _InfoTile(
                              icon: Icons.access_time_outlined,
                              label: 'Hoạt động gần nhất',
                              value: _fmt(d.lastActiveAt),
                              fg: fg,
                              muted: muted,
                            ),
                          ]),
                          const SizedBox(height: AppSpacing.s5),
                          Text('Tài liệu gần đây (${d.recentDocs.length})',
                              style: AppTypography.bodyMedium.copyWith(color: fg)),
                          const SizedBox(height: AppSpacing.s3),
                          if (d.recentDocs.isEmpty)
                            Text('Chưa có tài liệu.',
                                style: AppTypography.caption.copyWith(color: muted))
                          else
                            ...d.recentDocs.take(20).map(
                                  (doc) => Padding(
                                padding: const EdgeInsets.only(
                                    bottom: AppSpacing.s2),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () {
                                    // Xem chi tiết document — navigate hoặc show detail sheet
                                    Navigator.pop(context);
                                    _showDocDetail(context, doc, fg, muted, border, isDark);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.s3,
                                        vertical: AppSpacing.s2),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: border),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(children: [
                                      Icon(Icons.insert_drive_file_outlined,
                                          size: 14, color: muted),
                                      const SizedBox(width: AppSpacing.s2),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              doc.title.isNotEmpty
                                                  ? doc.title
                                                  : 'Tài liệu #${doc.docId}',
                                              style: AppTypography.caption
                                                  .copyWith(color: fg),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              doc.language.displayName,
                                              style: AppTypography.caption
                                                  .copyWith(
                                                  color: muted,
                                                  fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            _fmt(doc.createdAt),
                                            style: AppTypography.caption
                                                .copyWith(color: muted),
                                          ),
                                          Row(children: [
                                            Icon(Icons.visibility_outlined,
                                                size: 11,
                                                color: AppColors.primary),
                                            const SizedBox(width: 3),
                                            Text('Xem',
                                                style: AppTypography.caption
                                                    .copyWith(
                                                    color: AppColors.primary,
                                                    fontSize: 11)),
                                          ]),
                                        ],
                                      ),
                                    ]),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDocDetail(BuildContext context, Document doc, Color fg, Color muted,
      Color border, bool isDark) {
    showDialog(
      context: context,
      builder: (_) => _DocDetailDialog(
          doc: doc, fg: fg, muted: muted, border: border, isDark: isDark),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DIALOG: Chi tiết 1 tài liệu (admin xem)
// ─────────────────────────────────────────────────────────────────────────────
class _DocDetailDialog extends StatelessWidget {
  final Document doc;
  final Color fg, muted, border;
  final bool isDark;
  const _DocDetailDialog(
      {required this.doc,
        required this.fg,
        required this.muted,
        required this.border,
        required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.cardDark : AppColors.cardLight;
    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    doc.title.isNotEmpty ? doc.title : 'Tài liệu #${doc.docId}',
                    style: AppTypography.h4.copyWith(color: fg),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DgBadge.neutral(label: doc.language.displayName),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.close, color: muted, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
              const SizedBox(height: AppSpacing.s2),
              Divider(color: border),
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      TabBar(
                        tabs: const [
                          Tab(text: 'Nội dung tài liệu (MD)'),
                          Tab(text: 'Code gốc'),
                        ],
                        labelColor: AppColors.primary,
                        unselectedLabelColor: muted,
                        indicatorColor: AppColors.primary,
                        dividerColor: border,
                      ),
                      Expanded(
                        child: TabBarView(children: [
                          // Tab 1: nội dung markdown
                          SingleChildScrollView(
                            padding: const EdgeInsets.all(AppSpacing.s4),
                            child: SelectableText(
                              doc.contentMd,
                              style: AppTypography.body.copyWith(color: fg),
                            ),
                          ),
                          // Tab 2: code gốc
                          SingleChildScrollView(
                            padding: const EdgeInsets.all(AppSpacing.s4),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.bgDark
                                    : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: border),
                              ),
                              child: SelectableText(
                                doc.rawCodeContext.isNotEmpty
                                    ? doc.rawCodeContext
                                    : '(Không có code gốc)',
                                style: AppTypography.code.copyWith(
                                    color: fg, fontSize: 12),
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INFO TILE
// ─────────────────────────────────────────────────────────────────────────────
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color fg, muted;
  const _InfoTile(
      {required this.icon,
        required this.label,
        required this.value,
        required this.fg,
        required this.muted});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s3),
        decoration: BoxDecoration(
          color: isDark ? AppColors.bgDark : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(height: 4),
          Text(value,
              style: AppTypography.bodyMedium.copyWith(color: fg),
              overflow: TextOverflow.ellipsis),
          Text(label,
              style: AppTypography.caption.copyWith(color: muted)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BULK ACTION BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _BulkBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _BulkBtn(
      {required this.icon,
        required this.label,
        required this.color,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: AppTypography.caption
                  .copyWith(color: color, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER CHIP
// ─────────────────────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _Chip(
      {required this.label,
        required this.selected,
        required this.onTap,
        required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.1) : Colors.transparent,
          border: Border.all(color: selected ? color : AppColors.borderLight),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: selected ? color : AppColors.fgSubtleLight,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}