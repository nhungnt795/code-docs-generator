// lib/features/generate/data/generate_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/api/models.dart';

class GenerateRepository {
  GenerateRepository._();
  static final GenerateRepository instance = GenerateRepository._();

  /// Gọi API sinh tài liệu. Nếu [userId] = null thì là chế độ Khách (không lưu DB).
  Future<DocumentModel> generate({
    required String title,
    required String rawCode,
    required ProgrammingLanguage language,
    required SourceType sourceType,
    int? userId,
  }) async {
    final res = await ApiClient.instance.post<DocumentModel>(
      '/api/docs/generate',
      query: userId != null ? {'user_id': userId} : null,
      body: {
        'title': title,
        'source_type': sourceType.value,
        'language': language.value,
        'raw_code_context': rawCode,
      },
      fromData: (d) => DocumentModel.fromJson(d as Map<String, dynamic>),
      timeout: ApiConfig.generateTimeout,
    );

    if (!res.success || res.data == null) {
      throw ApiException(res.message);
    }
    return res.data!;
  }
}

final generateRepoProvider = Provider<GenerateRepository>(
  (ref) => GenerateRepository.instance,
);
