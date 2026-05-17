// lib/features/admin/presentation/contact_messages_screen.dart
// Trang admin xem tin nhắn từ form Liên hệ trên landing page

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/models.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/tokens/app_colors.dart';
import '../../../core/tokens/app_spacing.dart';
import '../../../core/tokens/app_typography.dart';
import '../../../shared/widgets/dg_card.dart';
import '../../../shared/widgets/dg_misc.dart';
import '../data/admin_repository.dart';

class ContactMessagesScreen extends ConsumerStatefulWidget {
  const ContactMessagesScreen({super.key});

  @override
  ConsumerState<ContactMessagesScreen> createState() =>
      _ContactMessagesScreenState();
}

class _ContactMessagesScreenState
    extends ConsumerState<ContactMessagesScreen> {
  bool _unreadOnly = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppColors.fgDark : AppColors.fgLight;
    final muted = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    final async = ref.watch(adminContactMessagesProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminContactMessagesProvider),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tin nhắn Liên hệ',
                          style: AppTypography.h2.copyWith(color: fg)),
                      Text(
                        async.maybeWhen(
                          data: (list) {
                            final unread =
                                list.where((m) => !m.isRead).length;
                            return '${list.length} tin nhắn'
                                '${unread > 0 ? ' · $unread chưa đọc' : ''}';
                          },
                          orElse: () => 'Đang tải...',
                        ),
                        style: AppTypography.body.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
                // Filter toggle
                Row(children: [
                  Text('Chưa đọc', style: AppTypography.body.copyWith(color: muted)),
                  const SizedBox(width: 8),
                  Switch(
                    value: _unreadOnly,
                    onChanged: (v) {
                      setState(() => _unreadOnly = v);
                      ref.invalidate(adminContactMessagesProvider);
                    },
                    activeColor: AppColors.primary,
                  ),
                ]),
              ],
            ),
            const SizedBox(height: AppSpacing.s5),

            // List
            Expanded(
              child: async.when(
                loading: () => ListView.separated(
                  itemCount: 4,
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.s3),
                  itemBuilder: (_, __) => DgSkeleton.card(height: 100),
                ),
                error: (e, _) => DgEmptyState(
                  icon: Icons.error_outline,
                  message: 'Không tải được tin nhắn',
                  description: e.toString(),
                  actionLabel: 'Thử lại',
                  onAction: () => ref.invalidate(adminContactMessagesProvider),
                ),
                data: (items) {
                  final filtered = _unreadOnly
                      ? items.where((m) => !m.isRead).toList()
                      : items;

                  if (filtered.isEmpty) {
                    return DgEmptyState(
                      icon: Icons.mail_outline,
                      message: _unreadOnly
                          ? 'Không có tin nhắn chưa đọc'
                          : 'Chưa có tin nhắn nào',
                      description: _unreadOnly
                          ? 'Tất cả tin nhắn đã được đọc.'
                          : 'Khi có người gửi form Liên hệ, tin nhắn sẽ hiện ở đây.',
                    );
                  }

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.s3),
                    itemBuilder: (_, i) => _ContactMsgCard(
                      msg: filtered[i],
                      isDark: isDark,
                      fg: fg,
                      muted: muted,
                      onMarkRead: () => _markRead(filtered[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markRead(ContactMessage msg) async {
    if (msg.isRead) return;
    final admin = ref.read(currentUserProvider);
    if (admin == null) return;
    try {
      await ref
          .read(adminRepoProvider)
          .markContactRead(admin.userId, msg.id);
      ref.invalidate(adminContactMessagesProvider);
    } catch (e) {
      if (mounted) {
        DgToast.show(context, 'Không thể cập nhật: $e',
            type: ToastType.error);
      }
    }
  }
}

class _ContactMsgCard extends StatelessWidget {
  final ContactMessage msg;
  final bool isDark;
  final Color fg, muted;
  final VoidCallback onMarkRead;

  const _ContactMsgCard({
    required this.msg,
    required this.isDark,
    required this.fg,
    required this.muted,
    required this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final isUnread = !msg.isRead;

    // Luôn dùng màu phù hợp với theme, không phụ thuộc vào nền header
    final nameFg = isDark ? AppColors.fgDark : AppColors.fgLight;
    final subFg = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    final contentFg = isDark ? AppColors.fgDark : AppColors.fgLight;

    // Nền header: dark mode dùng overlay tím nhạt, light mode dùng primarySoft
    final headerBg = isUnread
        ? (isDark
        ? AppColors.primary.withOpacity(0.15)
        : AppColors.primarySoft)
        : Colors.transparent;

    return DgCard(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          border: isUnread
              ? Border(left: BorderSide(color: AppColors.primary, width: 3))
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top bar
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s4, vertical: AppSpacing.s3),
              decoration: const BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              ),
              child: Row(children: [
                // Avatar initials
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(isUnread ? 0.2 : 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      (msg.name ?? msg.email)[0].toUpperCase(),
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(
                          msg.name ?? '(Không có tên)',
                          style: AppTypography.bodyMedium.copyWith(
                            color: nameFg,
                            fontWeight: isUnread
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('Mới',
                                style: AppTypography.caption.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10)),
                          ),
                        ],
                      ]),
                      Text(msg.email,
                          style: AppTypography.caption.copyWith(color: subFg)),
                    ],
                  ),
                ),
                Text(fmt.format(msg.createdAt),
                    style: AppTypography.caption.copyWith(color: subFg)),
                if (isUnread) ...[
                  const SizedBox(width: AppSpacing.s3),
                  Tooltip(
                    message: 'Đánh dấu đã đọc',
                    child: InkWell(
                      onTap: onMarkRead,
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.done_all,
                            size: 18, color: AppColors.primary),
                      ),
                    ),
                  ),
                ],
              ]),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s4),
              child: Text(
                msg.content,
                style: AppTypography.body
                    .copyWith(color: contentFg, height: 1.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}