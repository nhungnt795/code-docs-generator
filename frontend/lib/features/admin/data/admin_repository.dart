// lib/features/admin/data/admin_repository.dart
//
// THAY ĐỔI:
// - fetchAllUsers: thêm tham số roleFilter (all|active|locked|inactive|admin|user)
// - fetchAllUsers: response trả về kèm doc_count từ backend
// - adminUpdateAvatar: endpoint mới cho admin cập nhật avatar user

import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/models.dart';
import '../../../core/auth/auth_provider.dart';

// ── Model mở rộng User kèm doc_count (chỉ dùng ở admin) ─────────────────────
class UserWithDocCount extends User {
  final int docCount;

  UserWithDocCount({
    required super.userId,
    required super.email,
    super.fullName,
    super.avatarUrl,
    required super.role,
    required super.isActive,
    required super.isLocked,
    required super.createdAt,
    required this.docCount,
  });

  factory UserWithDocCount.fromJson(Map<String, dynamic> json) {
    final base = User.fromJson(json);
    return UserWithDocCount(
      userId: base.userId,
      email: base.email,
      fullName: base.fullName,
      avatarUrl: base.avatarUrl,
      role: base.role,
      isActive: base.isActive,
      isLocked: base.isLocked,
      createdAt: base.createdAt,
      docCount: json['doc_count'] as int? ?? 0,
    );
  }

  @override
  UserWithDocCount copyWith({
    String? fullName,
    String? avatarUrl,
    String? email,
    bool? isLocked,
    bool? isActive,
    int? docCount,
  }) =>
      UserWithDocCount(
        userId: userId,
        email: email ?? this.email,
        fullName: fullName ?? this.fullName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        role: role,
        isActive: isActive ?? this.isActive,
        isLocked: isLocked ?? this.isLocked,
        createdAt: createdAt,
        docCount: docCount ?? this.docCount,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
class AdminRepository {
  AdminRepository._();
  static final AdminRepository instance = AdminRepository._();

  /// Lấy danh sách user kèm doc_count.
  /// [roleFilter]: all | active | locked | inactive | admin | user
  Future<List<UserWithDocCount>> fetchAllUsers(
      int adminId, {
        String? roleFilter,
        String? period,
      }) async {
    final res = await ApiClient.instance.get<List<UserWithDocCount>>(
      '/api/admin/users',
      query: {
        'admin_id': adminId,
        if (roleFilter != null && roleFilter != 'all') 'status': roleFilter,
        if (period != null) 'period': period,
      },
      fromData: (d) => (d as List)
          .map((e) => UserWithDocCount.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    if (!res.success) throw ApiException(res.message);
    return res.data ?? [];
  }

  Future<List<AuditLogModel>> fetchLogs(int adminId, {String? period}) async {
    final res = await ApiClient.instance.get<List<AuditLogModel>>(
      '/api/admin/logs',
      query: {
        'admin_id': adminId,
        if (period != null) 'period': period,
      },
      fromData: (d) => (d as List)
          .map((e) => AuditLogModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    if (!res.success) throw ApiException(res.message);
    return res.data ?? [];
  }

  Future<AdminStatsModel> fetchStats(int adminId,
      {String? period, String? from, String? to}) async {
    final res = await ApiClient.instance.get<AdminStatsModel>(
      '/api/admin/dashboard',
      query: {
        'admin_id': adminId,
        if (period != null && period != 'all') 'range_key': period,
        if (from != null) 'start_date': from,
        if (to != null) 'end_date': to,
      },
      fromData: (d) => AdminStatsModel.fromJson(d as Map<String, dynamic>),
    );
    if (!res.success || res.data == null) throw ApiException(res.message);
    return res.data!;
  }

  Future<User> promoteToAdmin(int adminId, int userId) async {
    final res = await ApiClient.instance.post<User>(
      '/api/admin/promote/$userId',
      query: {'admin_id': adminId},   // ← thêm dòng này
      fromData: (d) => User.fromJson(d as Map<String, dynamic>),
    );
    if (!res.success || res.data == null) throw ApiException(res.message);
    return res.data!;
  }

  Future<User> setLockUser(int adminId, int userId, bool lock) async {
    final endpoint = lock
        ? '/api/admin/users/$userId/lock'
        : '/api/admin/users/$userId/unlock';
    final res = await ApiClient.instance.post<User>(
      endpoint,
      query: {'admin_id': adminId},
      fromData: (d) => User.fromJson(d as Map<String, dynamic>),
    );
    if (!res.success || res.data == null) throw ApiException(res.message);
    return res.data!;
  }

  Future<void> bulkAction(int adminId, List<int> userIds, String action) async {
    final res = await ApiClient.instance.post<void>(
      '/api/admin/users/bulk',
      query: {'admin_id': adminId},
      body: {'user_ids': userIds, 'action': action},
    );
    if (!res.success) throw ApiException(res.message);
  }

  Future<UserDetailModel> fetchUserDetail(int adminId, int userId) async {
    final res = await ApiClient.instance.get<UserDetailModel>(
      '/api/admin/users/$userId',
      query: {'admin_id': adminId},
      fromData: (d) => UserDetailModel.fromJson(d as Map<String, dynamic>),
    );
    if (!res.success || res.data == null) throw ApiException(res.message);
    return res.data!;
  }

  /// Admin upload avatar cho user bất kỳ
  Future<User> adminUpdateAvatar(
      int adminId,
      int userId,
      Uint8List imageBytes,
      String filename,
      String mimeType,
      ) async {
    final res = await ApiClient.instance.uploadFile<User>(
      '/api/admin/users/$userId/avatar',
      query: {'admin_id': adminId},
      fileBytes: imageBytes,
      filename: filename,
      mimeType: mimeType,
      fieldName: 'file',
      fromData: (d) => User.fromJson(d as Map<String, dynamic>),
    );
    if (!res.success || res.data == null) throw ApiException(res.message);
    return res.data!;
  }

  Future<List<AIModelConfig>> fetchModels(int adminId) async {
    final res = await ApiClient.instance.get<List<AIModelConfig>>(
      '/api/admin/models',
      query: {'admin_id': adminId},
      fromData: (d) => (d as List)
          .map((e) => AIModelConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    if (!res.success) throw ApiException(res.message);
    return res.data ?? [];
  }

  Future<AIModelConfig> toggleModel(int adminId, String modelType, bool isActive) async {
    final res = await ApiClient.instance.put<AIModelConfig>(
      '/api/admin/models/$modelType',
      query: {'admin_id': adminId},
      body: {'is_active': isActive},
      fromData: (d) => AIModelConfig.fromJson(d as Map<String, dynamic>),
    );
    if (!res.success || res.data == null) throw ApiException(res.message);
    return res.data!;
  }

  Future<List<Feedback>> fetchFeedbacks(int adminId) async {
    final res = await ApiClient.instance.get<List<Feedback>>(
      '/api/admin/feedbacks',
      query: {'admin_id': adminId},
      fromData: (d) => (d as List)
          .map((e) => Feedback.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    if (!res.success) throw ApiException(res.message);
    return res.data ?? [];
  }

  /// Lấy danh sách tin nhắn liên hệ từ landing page
  Future<List<ContactMessage>> fetchContactMessages(int adminId,
      {bool unreadOnly = false}) async {
    final res = await ApiClient.instance.get<List<ContactMessage>>(
      '/api/admin/contact-messages',
      query: {
        'admin_id': adminId,
        if (unreadOnly) 'unread_only': true,
      },
      fromData: (d) => (d as List)
          .map((e) => ContactMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    if (!res.success) throw ApiException(res.message);
    return res.data ?? [];
  }

  /// Đánh dấu tin nhắn liên hệ đã đọc
  Future<void> markContactRead(int adminId, int messageId) async {
    final res = await ApiClient.instance.post<void>(
      '/api/admin/contact-messages/$messageId/read',
      query: {'admin_id': adminId},
    );
    if (!res.success) throw ApiException(res.message);
  }
}

final adminRepoProvider = Provider<AdminRepository>(
      (ref) => AdminRepository.instance,
);

final adminPeriodProvider = StateProvider<String>((ref) => 'all');
final adminDateFromProvider = StateProvider<DateTime?>((ref) => null);
final adminDateToProvider = StateProvider<DateTime?>((ref) => null);

/// Provider lọc role (all | active | locked | inactive | admin | user)
final adminRoleFilterProvider = StateProvider<String>((ref) => 'all');

final adminUsersProvider =
FutureProvider.autoDispose<List<UserWithDocCount>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || !user.isAdmin) return Future.value([]);
  final period = ref.watch(adminPeriodProvider);
  final roleFilter = ref.watch(adminRoleFilterProvider);
  return ref.watch(adminRepoProvider).fetchAllUsers(
    user.userId,
    roleFilter: roleFilter == 'all' ? null : roleFilter,
    period: period == 'all' ? null : period,
  );
});

final adminLogsProvider =
FutureProvider.autoDispose<List<AuditLogModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || !user.isAdmin) return Future.value([]);
  final period = ref.watch(adminPeriodProvider);
  return ref.watch(adminRepoProvider).fetchLogs(user.userId,
      period: period == 'all' ? null : period);
});

final adminStatsProvider =
FutureProvider.autoDispose<AdminStatsModel>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || !user.isAdmin) {
    return Future.value(const AdminStatsModel(
        totalUsers: 0, totalDocs: 0, totalAdmins: 0, byLanguage: []));
  }
  final period = ref.watch(adminPeriodProvider);
  final from = ref.watch(adminDateFromProvider);
  final to = ref.watch(adminDateToProvider);
  return ref.watch(adminRepoProvider).fetchStats(
    user.userId,
    period: period == 'all' ? null : period,
    from: from?.toIso8601String(),
    to: to?.toIso8601String(),
  );
});

final adminModelsProvider =
FutureProvider.autoDispose<List<AIModelConfig>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || !user.isAdmin) return Future.value([]);
  return ref.watch(adminRepoProvider).fetchModels(user.userId);
});

final adminFeedbacksProvider =
FutureProvider.autoDispose<List<Feedback>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || !user.isAdmin) return Future.value([]);
  return ref.watch(adminRepoProvider).fetchFeedbacks(user.userId);
});

final adminContactMessagesProvider =
    FutureProvider.autoDispose<List<ContactMessage>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || !user.isAdmin) return Future.value([]);
  return ref.watch(adminRepoProvider).fetchContactMessages(user.userId);
});