// lib/features/admin/data/admin_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/models.dart';
import '../../../core/auth/auth_provider.dart';

class AdminRepository {
  AdminRepository._();
  static final AdminRepository instance = AdminRepository._();

  Future<List<UserModel>> fetchAllUsers(int adminId) async {
    final res = await ApiClient.instance.get<List<UserModel>>(
      '/api/admin/users',
      query: {'admin_id': adminId},
      fromData: (d) => (d as List)
          .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    if (!res.success) throw ApiException(res.message);
    return res.data ?? [];
  }

  Future<List<AuditLogModel>> fetchLogs(int adminId) async {
    final res = await ApiClient.instance.get<List<AuditLogModel>>(
      '/api/admin/logs',
      query: {'admin_id': adminId},
      fromData: (d) => (d as List)
          .map((e) => AuditLogModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    if (!res.success) throw ApiException(res.message);
    return res.data ?? [];
  }

  Future<AdminStatsModel> fetchStats(int adminId) async {
    final res = await ApiClient.instance.get<AdminStatsModel>(
      '/api/admin/stats',
      query: {'admin_id': adminId},
      fromData: (d) => AdminStatsModel.fromJson(d as Map<String, dynamic>),
    );
    if (!res.success || res.data == null) throw ApiException(res.message);
    return res.data!;
  }

  Future<UserModel> promoteToAdmin(int userId) async {
    final res = await ApiClient.instance.post<UserModel>(
      '/api/admin/promote/$userId',
      fromData: (d) => UserModel.fromJson(d as Map<String, dynamic>),
    );
    if (!res.success || res.data == null) throw ApiException(res.message);
    return res.data!;
  }
}

final adminRepoProvider = Provider<AdminRepository>(
  (ref) => AdminRepository.instance,
);

// ── Provider tự động fetch theo admin hiện tại ───────────────────────────────
final adminUsersProvider = FutureProvider.autoDispose<List<UserModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || !user.isAdmin) return Future.value([]);
  return ref.watch(adminRepoProvider).fetchAllUsers(user.userId);
});

final adminLogsProvider = FutureProvider.autoDispose<List<AuditLogModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || !user.isAdmin) return Future.value([]);
  return ref.watch(adminRepoProvider).fetchLogs(user.userId);
});

final adminStatsProvider = FutureProvider.autoDispose<AdminStatsModel>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || !user.isAdmin) {
    return Future.value(const AdminStatsModel(
      totalUsers: 0, totalDocs: 0, totalAdmins: 0, byLanguage: [],
    ));
  }
  return ref.watch(adminRepoProvider).fetchStats(user.userId);
});
