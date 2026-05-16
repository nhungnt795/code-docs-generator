// lib/features/admin/presentation/feedback_screen.dart
// Trang admin: Phản hồi (đánh giá sao) + Tin nhắn Liên hệ — 2 tab

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/models.dart' as app_models;
import '../../../core/auth/auth_provider.dart';
import '../../../core/tokens/app_colors.dart';
import '../../../core/tokens/app_spacing.dart';
import '../../../core/tokens/app_typography.dart';
import '../../../shared/widgets/dg_card.dart';
import '../../../shared/widgets/dg_misc.dart';
import '../data/admin_repository.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _unreadOnly = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg     = isDark ? AppColors.fgDark     : AppColors.fgLight;
    final muted  = isDark ? AppColors.fgMutedDark : AppColors.fgMutedLight;
    final border = isDark ? AppColors.borderDark  : AppColors.borderLight;

    final feedbackAsync = ref.watch(adminFeedbacksProvider);
    final contactAsync  = ref.watch(adminContactMessagesProvider);

    // Đếm tin nhắn chưa đọc để hiện badge
    final unreadCount = contactAsync.maybeWhen(
      data: (list) => list.where((m) => !m.isRead).length,
      orElse: () => 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header + TabBar ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.s6, AppSpacing.s6, AppSpacing.s6, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Phản hồi', style: AppTypography.h2.copyWith(color: fg)),
              const SizedBox(height: AppSpacing.s4),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.bgDark : AppColors.sunkenLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: border),
                ),
                padding: const EdgeInsets.all(4),
                child: TabBar(
                  controller: _tab,
                  indicator: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: fg,
                  unselectedLabelColor: muted,
                  labelStyle: AppTypography.bodySmall
                      .copyWith(fontWeight: FontWeight.w600),
                  unselectedLabelStyle: AppTypography.bodySmall,
                  tabs: [
                    const Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.star_outline, size: 16),
                          SizedBox(width: 6),
                          Text('Đánh giá'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.mail_outline, size: 16),
                          const SizedBox(width: 6),
                          const Text('Tin nhắn liên hệ'),
                          if (unreadCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$unreadCount',
                                style: AppTypography.caption.copyWith(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Tab views ────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              // ── Tab 0: Đánh giá sao ──────────────────────────────
              RefreshIndicator(
                onRefresh: () async => ref.invalidate(adminFeedbacksProvider),
                child: feedbackAsync.when(
                  loading: () => _skeletonList(4, 90),
                  error: (e, _) => DgEmptyState(
                    icon: Icons.error_outline,
                    message: 'Không tải được phản hồi',
                    description: e.toString(),
                    actionLabel: 'Thử lại',
                    onAction: () => ref.invalidate(adminFeedbacksProvider),
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return const DgEmptyState(
                        icon: Icons.star_outline,
                        message: 'Chưa có đánh giá nào',
                        description:
                        'Khi người dùng gửi đánh giá, chúng sẽ hiện ở đây.',
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.s6),
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.s3),
                      itemBuilder: (_, i) => _FeedbackCard(
                        fb: items[i],
                        isDark: isDark,
                        fg: fg,
                        muted: muted,
                      ),
                    );
                  },
                ),
              ),

              // ── Tab 1: Tin nhắn liên hệ ──────────────────────────
              RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(adminContactMessagesProvider),
                child: Column(
                  children: [
                    // Filter "Chưa đọc"
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.s6, AppSpacing.s4, AppSpacing.s6, 0),
                      child: Row(
                        children: [
                          contactAsync.maybeWhen(
                            data: (list) {
                              final unread =
                                  list.where((m) => !m.isRead).length;
                              return Text(
                                '${list.length} tin nhắn'
                                    '${unread > 0 ? ' · $unread chưa đọc' : ''}',
                                style:
                                AppTypography.body.copyWith(color: muted),
                              );
                            },
                            orElse: () => const SizedBox.shrink(),
                          ),
                          const Spacer(),
                          Text('Chưa đọc',
                              style:
                              AppTypography.bodySmall.copyWith(color: muted)),
                          const SizedBox(width: 6),
                          Switch(
                            value: _unreadOnly,
                            onChanged: (v) => setState(() => _unreadOnly = v),
                            activeColor: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: contactAsync.when(
                        loading: () => _skeletonList(4, 110),
                        error: (e, _) => DgEmptyState(
                          icon: Icons.error_outline,
                          message: 'Không tải được tin nhắn',
                          description: e.toString(),
                          actionLabel: 'Thử lại',
                          onAction: () =>
                              ref.invalidate(adminContactMessagesProvider),
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
                                  : 'Khi khách hàng gửi form Liên hệ, tin nhắn sẽ hiện ở đây.',
                            );
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.all(AppSpacing.s6),
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
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _markRead(app_models.ContactMessage msg) async {
    if (msg.isRead) return;
    final admin = ref.read(currentUserProvider);
    if (admin == null) return;
    try {
      await ref.read(adminRepoProvider).markContactRead(admin.userId, msg.id);
      ref.invalidate(adminContactMessagesProvider);
    } catch (e) {
      if (mounted) {
        DgToast.show(context, 'Không thể cập nhật: $e',
            type: ToastType.error);
      }
    }
  }

  Widget _skeletonList(int count, double h) => ListView.separated(
    padding: const EdgeInsets.all(AppSpacing.s6),
    itemCount: count,
    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s3),
    itemBuilder: (_, __) => DgSkeleton.card(height: h),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Card đánh giá sao
// ─────────────────────────────────────────────────────────────────────────────
class _FeedbackCard extends StatelessWidget {
  final app_models.Feedback fb;
  final bool isDark;
  final Color fg, muted;
  const _FeedbackCard(
      {required this.fb,
        required this.isDark,
        required this.fg,
        required this.muted});

  String _fmt(DateTime? dt) {
    if (dt == null) return '';
    final l = dt.isUtc ? dt.toLocal() : dt;
    return DateFormat('dd/MM/yyyy HH:mm').format(l);
  }

  @override
  Widget build(BuildContext context) {
    return DgCard(
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            ...List.generate(
              5,
                  (i) => Icon(
                i < fb.rating ? Icons.star : Icons.star_border,
                color: AppColors.warning,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'User #${fb.userId}',
                style: AppTypography.bodyMedium.copyWith(color: fg),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(_fmt(fb.createdAt),
                style: AppTypography.caption.copyWith(color: muted)),
          ]),
          if (fb.content != null && fb.content!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(fb.content!,
                style: AppTypography.body.copyWith(color: muted)),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card tin nhắn liên hệ
// ─────────────────────────────────────────────────────────────────────────────
class _ContactMsgCard extends StatelessWidget {
  final app_models.ContactMessage msg;
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
    final fmt      = DateFormat('dd/MM/yyyy HH:mm');
    final isUnread = !msg.isRead;

    return DgCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s4, vertical: AppSpacing.s3),
            decoration: BoxDecoration(
              color: isUnread ? AppColors.primarySoft : Colors.transparent,
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(10)),
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
                      Flexible(
                        child: Text(
                          msg.name ?? '(Không có tên)',
                          style: AppTypography.bodyMedium.copyWith(
                            color: fg,
                            fontWeight: isUnread
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
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
                          child: Text(
                            'Mới',
                            style: AppTypography.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ]),
                    Text(msg.email,
                        style: AppTypography.caption.copyWith(color: muted)),
                  ],
                ),
              ),
              Text(fmt.format(msg.createdAt.toLocal()),
                  style: AppTypography.caption.copyWith(color: muted)),
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

          // Nội dung tin nhắn
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s4),
            child: Text(
              msg.content,
              style: AppTypography.body.copyWith(color: muted, height: 1.65),
            ),
          ),
        ],
      ),
    );
  }
}