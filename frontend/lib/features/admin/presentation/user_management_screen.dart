// lib/features/admin/presentation/user_management_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/models.dart';
import '../../../core/tokens/app_colors.dart';
import '../../../core/tokens/app_spacing.dart';
import '../../../core/tokens/app_typography.dart';
import '../../../shared/widgets/dg_badge.dart';
import '../../../shared/widgets/dg_card.dart';
import '../../../shared/widgets/dg_input.dart';
import '../../../shared/widgets/dg_misc.dart';
import '../data/admin_repository.dart';

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
  String _roleFilter = 'all';

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

  // ── API: Nâng quyền user → admin ───────────────────────────────────────────
  Future<void> _promote(UserModel user) async {
    if (user.isAdmin) {
      DgToast.show(
        context,
        'Tài khoản này đã là Admin',
        type: ToastType.info,
      );
      return;
    }

    final confirmed = await DgConfirmDialog.show(
      context,
      title: 'Nâng quyền Admin',
      message:
          'Bạn có chắc muốn nâng quyền "${user.fullName ?? user.email}" thành Quản trị viên?',
      confirmLabel: 'Xác nhận',
    );
    if (!confirmed) return;

    try {
      await ref.read(adminRepoProvider).promoteToAdmin(user.userId);
      ref.invalidate(adminUsersProvider);
      ref.invalidate(adminStatsProvider);
      if (mounted) {
        DgToast.show(
          context,
          'Đã nâng quyền cho ${user.email}',
          type: ToastType.success,
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        DgToast.show(context, e.message, type: ToastType.error);
      }
    }
  }

  // ── Filter theo query + role ───────────────────────────────────────────────
  List<UserModel> _filter(List<UserModel> users) {
    return users.where((u) {
      final matchQ = _query.isEmpty ||
          (u.fullName ?? '').toLowerCase().contains(_query) ||
          u.email.toLowerCase().contains(_query);
      final matchRole = _roleFilter == 'all' ||
          (_roleFilter == 'admin' && u.isAdmin) ||
          (_roleFilter == 'user' && !u.isAdmin);
      return matchQ && matchRole;
    }).toList();
  }

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
            // ── Header ─────────────────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quản lý người dùng',
                    style: AppTypography.h2.copyWith(color: fg)),
                Text(
                  asyncUsers.maybeWhen(
                    data: (u) =>
                        '${u.length} tài khoản · ${u.where((x) => x.isAdmin).length} quản trị viên',
                    orElse: () => 'Đang tải...',
                  ),
                  style: AppTypography.body.copyWith(color: muted),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s5),

            // ── Filters ────────────────────────────────────────────────
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
                _FilterChip(
                  label: 'Tất cả',
                  selected: _roleFilter == 'all',
                  onTap: () => setState(() => _roleFilter = 'all'),
                ),
                _FilterChip(
                  label: 'Người dùng',
                  selected: _roleFilter == 'user',
                  onTap: () => setState(() => _roleFilter = 'user'),
                ),
                _FilterChip(
                  label: 'Quản trị viên',
                  selected: _roleFilter == 'admin',
                  onTap: () => setState(() => _roleFilter = 'admin'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),

            // ── Table ──────────────────────────────────────────────────
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
                    final filtered = _filter(users);
                    return Column(
                      children: [
                        if (isWide)
                          _TableHeader(
                              isDark: isDark, fg: fg, border: border),
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
                                  itemBuilder: (_, i) => _UserTableRow(
                                    user: filtered[i],
                                    isWide: isWide,
                                    isDark: isDark,
                                    fg: fg,
                                    muted: muted,
                                    border: border,
                                    onPromote: () => _promote(filtered[i]),
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

// ── Table header ─────────────────────────────────────────────────────────────
class _TableHeader extends StatelessWidget {
  final bool isDark;
  final Color fg, border;

  const _TableHeader({
    required this.isDark,
    required this.fg,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    final subtle = isDark ? AppColors.fgSubtleDark : AppColors.fgSubtleLight;
    final bg = isDark ? AppColors.bgDark : const Color(0xFFF9FAFB);

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s4, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: border)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          Expanded(
              flex: 3,
              child: Text('Người dùng',
                  style: AppTypography.label.copyWith(color: subtle))),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
              flex: 2,
              child: Text('Email',
                  style: AppTypography.label.copyWith(color: subtle))),
          const SizedBox(width: AppSpacing.s3),
          SizedBox(
              width: 140,
              child: Text('Vai trò',
                  style: AppTypography.label.copyWith(color: subtle))),
          const SizedBox(width: AppSpacing.s3),
          SizedBox(
              width: 120,
              child: Text('Ngày tham gia',
                  style: AppTypography.label.copyWith(color: subtle))),
          const SizedBox(width: AppSpacing.s3),
          const SizedBox(width: 120),
        ],
      ),
    );
  }
}

// ── Table row ────────────────────────────────────────────────────────────────
class _UserTableRow extends StatefulWidget {
  final UserModel user;
  final bool isWide, isDark;
  final Color fg, muted, border;
  final VoidCallback onPromote;

  const _UserTableRow({
    required this.user,
    required this.isWide,
    required this.isDark,
    required this.fg,
    required this.muted,
    required this.border,
    required this.onPromote,
  });

  @override
  State<_UserTableRow> createState() => _UserTableRowState();
}

class _UserTableRowState extends State<_UserTableRow> {
  bool _hovered = false;

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final hover = widget.isDark ? AppColors.hoverDark : AppColors.hoverLight;

    if (!widget.isWide) {
      return _MobileUserRow(
        user: user,
        isDark: widget.isDark,
        fg: widget.fg,
        muted: widget.muted,
        onPromote: widget.onPromote,
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _hovered ? hover : Colors.transparent,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s4, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  _Avatar(name: user.fullName ?? user.email),
                  const SizedBox(width: AppSpacing.s2),
                  Expanded(
                    child: Text(
                      user.fullName ?? user.email.split('@').first,
                      style: AppTypography.body.copyWith(color: widget.fg),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              flex: 2,
              child: Text(
                user.email,
                style: AppTypography.caption.copyWith(color: widget.muted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.s3),
            SizedBox(
              width: 140,
              child: user.isAdmin
                  ? DgBadge.info(label: 'Admin', width: 72)
                  : DgBadge.neutral(label: 'User', width: 72),
            ),
            const SizedBox(width: AppSpacing.s3),
            SizedBox(
              width: 120,
              child: Text(
                _formatDate(user.createdAt),
                style: AppTypography.caption.copyWith(color: widget.muted),
              ),
            ),
            const SizedBox(width: AppSpacing.s3),
            SizedBox(
              width: 120,
              child: user.isAdmin
                  ? Text('—',
                      style: AppTypography.caption
                          .copyWith(color: widget.muted))
                  : TextButton.icon(
                      onPressed: widget.onPromote,
                      icon: const Icon(Icons.arrow_upward, size: 14),
                      label: const Text('Lên Admin'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileUserRow extends StatelessWidget {
  final UserModel user;
  final bool isDark;
  final Color fg, muted;
  final VoidCallback onPromote;

  const _MobileUserRow({
    required this.user,
    required this.isDark,
    required this.fg,
    required this.muted,
    required this.onPromote,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s4, vertical: AppSpacing.s3),
      child: Row(
        children: [
          _Avatar(name: user.fullName ?? user.email),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.fullName ?? user.email.split('@').first,
                        style: AppTypography.bodyMedium.copyWith(color: fg),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (user.isAdmin)
                      DgBadge.info(label: 'Admin')
                    else
                      DgBadge.neutral(label: 'User'),
                  ],
                ),
                Text(user.email,
                    style: AppTypography.caption.copyWith(color: muted)),
              ],
            ),
          ),
          if (!user.isAdmin)
            IconButton(
              icon: const Icon(Icons.arrow_upward, size: 18),
              tooltip: 'Nâng quyền Admin',
              onPressed: onPromote,
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? c.withOpacity(0.1) : Colors.transparent,
          border: Border.all(color: selected ? c : AppColors.borderLight),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: selected ? c : AppColors.fgSubtleLight,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
