// lib/features/history/data/history_repository.dart
//
// FIX export endpoints:
// Backend: GET /api/docs/{doc_id}/export?format=pdf&user_id=...
// Bản cũ gọi: /api/docs/{id}/export/pdf  (sai → 404)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/models.dart';
import '../../../core/auth/auth_provider.dart';

class HistoryRepository {
  HistoryRepository._();
  static final HistoryRepository instance = HistoryRepository._();

  Future<List<Document>> fetchHistory(int userId) async {
    final res = await ApiClient.instance.get<List<Document>>(
      '/api/docs/history/$userId',
      fromData: (d) => (d as List)
          .map((e) => Document.fromJson(e as Map<String, dynamic>))
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

  /// Lưu tài liệu đã chỉnh sửa
  Future<Document> updateDoc({
    required int docId,
    required int userId,
    required String contentMd,
    String? title,
  }) async {
    final res = await ApiClient.instance.put<Document>(
      '/api/docs/$docId',
      query: {'user_id': userId},
      body: {
        'content_md': contentMd,
        if (title != null) 'title': title,
      },
      fromData: (d) => Document.fromJson(d as Map<String, dynamic>),
    );
    if (!res.success || res.data == null) throw ApiException(res.message);
    return res.data!;
  }

  /// Xuất PDF — GET /api/docs/{id}/export?format=pdf&user_id=...
  Future<List<int>> exportPdf(
      {required int docId, required int userId}) async {
    return ApiClient.instance.getBytes(
      '/api/docs/$docId/export',
      query: {'format': 'pdf', 'user_id': userId},
    );
  }

  /// Xuất DOCX
  Future<List<int>> exportDocx(
      {required int docId, required int userId}) async {
    return ApiClient.instance.getBytes(
      '/api/docs/$docId/export',
      query: {'format': 'docx', 'user_id': userId},
    );
  }
}

final historyRepoProvider = Provider<HistoryRepository>(
  (ref) => HistoryRepository.instance,
);

final historyListProvider = FutureProvider.autoDispose<List<Document>>(
  (ref) async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return [];
    return ref.watch(historyRepoProvider).fetchHistory(user.userId);
  },
);
