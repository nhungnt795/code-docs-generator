// lib/features/admin/presentation/user_management_screen.dart
import 'package:flutter/material.dart';

import '../../../core/tokens/app_colors.dart';
import '../../../core/tokens/app_spacing.dart';
import '../../../core/tokens/app_typography.dart';
import '../../../shared/widgets/dg_badge.dart';
import '../../../shared/widgets/dg_button.dart';
import '../../../shared/widgets/dg_card.dart';
import '../../../shared/widgets/dg_input.dart';
import '../../../shared/widgets/dg_misc.dart';

// ── Mock data ──
enum _UserStatus { active, locked }

class _UserRow {
  final String id, name, email;
  String role;
  final int docsCount, tokens;
  final DateTime joinedAt;
  _UserStatus status;

  _UserRow({
    required this.id, required this.name, required this.email,
    required this.role, required this.docsCount, required this.tokens,
    required this.joinedAt, required this.status,
  });
}

List<_UserRow> _mockUsers = [
  _UserRow(id: '1', name: 'Nguyễn Văn A', email: 'nva@example.com', role: 'user', docsCount: 24, tokens: 12480, joinedAt: DateTime(2024, 3, 15), status: _UserStatus.active),
  _UserRow(id: '2', name: 'Trần Thị B', email: 'ttb@example.com', role: 'user', docsCount: 56, tokens: 28900, joinedAt: DateTime(2024, 2, 8), status: _UserStatus.active),
  _UserRow(id: '3', name: 'Lê Minh C', email: 'lmc@example.com', role: 'user', docsCount: 8, tokens: 3200, joinedAt: DateTime(2024, 5, 1), status: _UserStatus.locked),
  _UserRow(id: '4', name: 'Phạm Quốc D', email: 'pqd@example.com', role: 'admin', docsCount: 142, tokens: 78000, joinedAt: DateTime(2023, 11, 20), status: _UserStatus.active),
  _UserRow(id: '5', name: 'Hoàng Thị E', email: 'hte@example.com', role: 'user', docsCount: 31, tokens: 15600, joinedAt: DateTime(2024, 4, 12), status: _UserStatus.active),
  _UserRow(id: '6', name: 'Vũ Thanh F', email: 'vtf@example.com', role: 'user', docsCount: 5, tokens: 1800, joinedAt: DateTime(2024, 6, 3), status: _UserStatus.locked),
];

// ─────────────────────────────────────────────────────────────────────────────
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _searchCtrl = TextEditingController();
  List<_UserRow> _filtered = List.from(_mockUsers);
  String _roleFilter = 'all';
  String _statusFilter = 'all';

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
      _filtered = _mockUsers.where((u) {
        final matchQ = q.isEmpty ||
            u.name.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q);
        final matchRole   = _roleFilter == 'all'   || u.role == _roleFilter;
        final matchStatus = _statusFilter == 'all' ||
            (_statusFilter == 'active' && u.status == _UserStatus.active) ||
            (_statusFilter == 'locked' && u.status == _UserStatus.locked);
        return matchQ && matchRole && matchStatus;
      }).toList();
    });
  }

  Future<void> _toggleLock(_UserRow user) async {
    final isLocking = user.status == _UserStatus.active;
    final confirmed = await DgConfirmDialog.show(
      context,
      title: isLocking ? 'Khóa tài khoản' : 'Mở khóa tài khoản',
      message: isLocking
          ? 'Tài khoản "${user.name}" sẽ bị khóa và không thể đăng nhập.'
          : 'Tài khoản "${user.name}" sẽ được mở khóa.',
      confirmLabel: isLocking ? 'Khóa' : 'Mở khóa',
      destructive: isLocking,
    );
    if (!confirmed) return;
    setState(() {
      user.status = isLocking ? _UserStatus.locked : _UserStatus.active;
    });
    if (mounted) {
      DgToast.show(
        context,
        isLocking ? 'Đã khóa tài khoản ${user.name}' : 'Đã mở khóa ${user.name}',
        type: isLocking ? ToastType.warning : ToastType.success,
      );
    }
  }

  Future<void> _toggleRole(_UserRow user) async {
    final isPromoting = user.role == 'user';
    final confirmed = await DgConfirmDialog.show(
      context,
      title: 'Thay đổi vai trò',
      message: 'Bạn có chắc muốn chuyển "${user.name}" thành ${isPromoting ? "Quản trị viên" : "Người dùng thường"}?',
      confirmLabel: 'Xác nhận',
    );
    if (!confirmed) return;

    setState(() {
      user.role = isPromoting ? 'admin' : 'user';
    });
    if (mounted) {
      DgToast.show(context, 'Đã cập nhật vai trò cho ${user.name}', type: ToastType.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg     = isDark ? AppColors.fgDark     : AppColors.fgLight;
    final muted  = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final isWide = MediaQuery.sizeOf(context).width > 900;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quản lý người dùng', style: AppTypography.h2.copyWith(color: fg)),
                    Text(
                      '${_mockUsers.length} tài khoản · ${_mockUsers.where((u) => u.status == _UserStatus.locked).length} đang bị khóa',
                      style: AppTypography.body.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s5),

          Wrap(
            spacing: AppSpacing.s3,
            runSpacing: AppSpacing.s3,
            crossAxisAlignment: WrapCrossAlignment.center, // Bắt buộc giữ dòng này để căn giữa trục ngang
            children: [
              SizedBox(
                width: isWide ? 280 : double.infinity,
                // Không dùng height ở đây
                child: DgInput.search(hint: 'Tìm theo tên, email...', controller: _searchCtrl),
              ),
              _FilterChip(label: 'Tất cả', selected: _roleFilter == 'all', onTap: () { _roleFilter = 'all'; _filter(); }),
              _FilterChip(label: 'Người dùng', selected: _roleFilter == 'user', onTap: () { _roleFilter = 'user'; _filter(); }),
              _FilterChip(label: 'Quản trị viên', selected: _roleFilter == 'admin', onTap: () { _roleFilter = 'admin'; _filter(); }),
              _FilterChip(label: 'Đang hoạt động', selected: _statusFilter == 'active', onTap: () { _statusFilter = _statusFilter == 'active' ? 'all' : 'active'; _filter(); }, color: AppColors.success),
              _FilterChip(label: 'Bị khóa', selected: _statusFilter == 'locked', onTap: () { _statusFilter = _statusFilter == 'locked' ? 'all' : 'locked'; _filter(); }, color: AppColors.error),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),

          Expanded(
            child: DgCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  if (isWide) _TableHeader(isDark: isDark, fg: fg, border: border),
                  Expanded(
                    child: _filtered.isEmpty
                        ? const DgEmptyState(icon: Icons.people_outline, message: 'Không tìm thấy người dùng')
                        : ListView.separated(
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: border),
                      itemBuilder: (_, i) => _UserTableRow(
                        user: _filtered[i],
                        isWide: isWide,
                        isDark: isDark,
                        fg: fg, muted: muted, border: border,
                        onToggleLock: () => _toggleLock(_filtered[i]),
                        onToggleRole: () => _toggleRole(_filtered[i]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Table header ─────────────────────────────────────────────────────────────
class _TableHeader extends StatelessWidget {
  final bool isDark;
  final Color fg, border;

  const _TableHeader({required this.isDark, required this.fg, required this.border});

  @override
  Widget build(BuildContext context) {
    final subtle = isDark ? AppColors.fgSubtleDark : AppColors.fgSubtleLight;
    final bg     = isDark ? AppColors.bgDark : const Color(0xFFF9FAFB);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: border)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('Người dùng', style: AppTypography.label.copyWith(color: subtle))),
          const SizedBox(width: AppSpacing.s3),
          Expanded(flex: 2, child: Text('Email', style: AppTypography.label.copyWith(color: subtle))),
          const SizedBox(width: AppSpacing.s3),
          SizedBox(width: 80, child: Text('Tài liệu', style: AppTypography.label.copyWith(color: subtle))),
          const SizedBox(width: AppSpacing.s3),
          SizedBox(width: 140, child: Text('Vai trò', style: AppTypography.label.copyWith(color: subtle))),
          const SizedBox(width: AppSpacing.s3),
          SizedBox(width: 100, child: Text('Trạng thái', style: AppTypography.label.copyWith(color: subtle))),
          const SizedBox(width: AppSpacing.s3),
          const SizedBox(width: 100), // Cột hành động (Khoá)
        ],
      ),
    );
  }
}

// ── Table row ─────────────────────────────────────────────────────────────────
class _UserTableRow extends StatefulWidget {
  final _UserRow user;
  final bool isWide, isDark;
  final Color fg, muted, border;
  final VoidCallback onToggleLock;
  final VoidCallback onToggleRole;

  const _UserTableRow({
    required this.user, required this.isWide, required this.isDark,
    required this.fg, required this.muted, required this.border,
    required this.onToggleLock, required this.onToggleRole,
  });

  @override
  State<_UserTableRow> createState() => _UserTableRowState();
}

class _UserTableRowState extends State<_UserTableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final user   = widget.user;
    final hover  = widget.isDark ? AppColors.hoverDark : AppColors.hoverLight;
    final locked = user.status == _UserStatus.locked;

    if (!widget.isWide) {
      return _MobileUserRow(
        user: user, isDark: widget.isDark,
        fg: widget.fg, muted: widget.muted,
        onToggleLock: widget.onToggleLock,
        onToggleRole: widget.onToggleRole, // Lỗi ở đây đã được sửa (truyền parameter)
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _hovered ? hover : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  _Avatar(name: user.name, locked: locked),
                  const SizedBox(width: AppSpacing.s2),
                  Expanded(
                    child: Text(
                      user.name,
                      style: AppTypography.body.copyWith(
                        color: locked ? widget.muted : widget.fg,
                        decoration: locked ? TextDecoration.lineThrough : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              flex: 2,
              child: Text(user.email, style: AppTypography.caption.copyWith(color: widget.muted), overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: AppSpacing.s3),
            SizedBox(
              width: 80,
              child: Text('${user.docsCount}', style: AppTypography.code.copyWith(color: widget.fg, fontSize: 13)),
            ),
            const SizedBox(width: AppSpacing.s3),

            SizedBox(
              width: 140,
              child: Row(
                children: [
                  user.role == 'admin'
                      ? DgBadge.info(label: 'Admin', width: 72)
                      : DgBadge.neutral(label: 'User', width: 72),
                  IconButton(
                    icon: const Icon(Icons.swap_horiz, size: 16),
                    onPressed: widget.onToggleRole,
                    tooltip: 'Đổi vai trò',
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s3),
            SizedBox(
              width: 100,
              child: locked ? DgBadge.error(label: 'Bị khóa') : DgBadge.success(label: 'Hoạt động'),
            ),
            const SizedBox(width: AppSpacing.s3),
            SizedBox(
              width: 100,
              child: DgButton.ghost(
                label: locked ? 'Mở khóa' : 'Khóa',
                onPressed: widget.onToggleLock,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileUserRow extends StatelessWidget {
  final _UserRow user;
  final bool isDark;
  final Color fg, muted;
  final VoidCallback onToggleLock;
  final VoidCallback onToggleRole;

  const _MobileUserRow({
    required this.user, required this.isDark,
    required this.fg, required this.muted,
    required this.onToggleLock,
    required this.onToggleRole, // Đã bổ sung trong constructor
  });

  @override
  Widget build(BuildContext context) {
    final locked = user.status == _UserStatus.locked;
    final isAdmin = user.role == 'admin';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: AppSpacing.s3),
      child: Row(
        children: [
          _Avatar(name: user.name, locked: locked),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text(
                          user.name,
                          style: AppTypography.bodyMedium.copyWith(color: fg),
                          overflow: TextOverflow.ellipsis,
                        )
                    ),
                    const SizedBox(width: 8),
                    if (isAdmin) DgBadge.info(label: 'Admin') else DgBadge.neutral(label: 'User'),
                    if (locked) ...[const SizedBox(width: 4), DgBadge.error(label: 'Khóa')]
                  ],
                ),
                Text(user.email, style: AppTypography.caption.copyWith(color: muted)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: muted),
            onSelected: (val) {
              if (val == 'role') onToggleRole();
              if (val == 'lock') onToggleLock();
            },
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'role',
                child: Row(
                  children: [
                    const Icon(Icons.swap_horiz, size: 18),
                    const SizedBox(width: 8),
                    Text(isAdmin ? 'Hạ quyền xuống User' : 'Nâng cấp lên Admin', style: AppTypography.body),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'lock',
                child: Row(
                  children: [
                    Icon(locked ? Icons.lock_open : Icons.lock_outline, size: 18, color: locked ? AppColors.success : AppColors.error),
                    const SizedBox(width: 8),
                    Text(locked ? 'Mở khóa tài khoản' : 'Khóa tài khoản', style: AppTypography.body.copyWith(color: locked ? AppColors.success : AppColors.error)),
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

class _Avatar extends StatelessWidget {
  final String name;
  final bool locked;
  const _Avatar({required this.name, required this.locked});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(color: locked ? AppColors.fgDisabled : AppColors.primary, shape: BoxShape.circle),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip({required this.label, required this.selected, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        // Tuyệt chiêu ở đây: Dùng padding dọc 12px để chiều cao tự động nở ra đúng 43px
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? c.withOpacity(0.1) : Colors.transparent,
          border: Border.all(color: selected ? c : AppColors.borderLight),
          borderRadius: BorderRadius.circular(6),
        ),
        // Trả lại child đơn giản là Text, không cần bọc Column hay gì khác
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: selected ? c : AppColors.fgSubtleLight,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            height: 1.4, // Đảm bảo cố định line-height
          ),
        ),
      ),
    );
  }
}