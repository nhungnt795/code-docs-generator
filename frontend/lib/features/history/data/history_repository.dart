// lib/features/history/data/history_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/models.dart';
import '../../../core/auth/auth_provider.dart';

class HistoryRepository {
  HistoryRepository._();
  static final HistoryRepository instance = HistoryRepository._();

  Future<List<DocumentModel>> fetchHistory(int userId) async {
    final res = await ApiClient.instance.get<List<DocumentModel>>(
      '/api/docs/history/$userId',
      fromData: (d) => (d as List)
          .map((e) => DocumentModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

    if (!res.success) throw ApiException(res.message);
    return res.data ?? [];
  }

  Future<void> deleteDoc({required int docId, required int userId}) async {
    final res = await ApiClient.instance.delete(
      '/api/docs/$docId',
      query: {'user_id': userId},
    );
    if (!res.success) throw ApiException(res.message);
  }
}

final historyRepoProvider = Provider<HistoryRepository>(
  (ref) => HistoryRepository.instance,
);

/// FutureProvider auto-fetch history khi user đăng nhập
final historyListProvider = FutureProvider.autoDispose<List<DocumentModel>>(
  (ref) async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return [];
    return ref.watch(historyRepoProvider).fetchHistory(user.userId);
  },
);
