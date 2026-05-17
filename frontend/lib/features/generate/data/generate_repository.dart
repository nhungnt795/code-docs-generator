// lib/features/generate/data/generate_repository.dart
//
// FIX:
// 1. activeModels gọi /api/public/models (thay vì /api/models/active — 404)
// 2. generate dùng đúng endpoint + pass ignore_syntax_warning
// 3. parseDocument bổ sung trường raw_code_context

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/api/models.dart';

class GenerateRepository {
  GenerateRepository._();
  static final GenerateRepository instance = GenerateRepository._();

  /// Sinh tài liệu (user đã đăng nhập → lưu vào lịch sử)
  /// Trả về (Document, SyntaxCheckResult?) — warning nếu user bỏ qua lỗi syntax
  Future<(Document, SyntaxCheckResult?)> generate({
    required String title,
    required String rawCode,
    required ProgrammingLanguage language,
    required SourceType sourceType,
    int? userId,
    AIModelType? modelType,
    bool ignoreSyntaxWarning = false,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'source_type': sourceType.value,
      'language': language.value,
      'raw_code_context': rawCode,
      'ai_model': (modelType ?? AIModelType.GROQ_LLAMA3).name,
      'ignore_syntax_warning': ignoreSyntaxWarning,
    };

    // Endpoint khác nhau tùy user có login hay không
    final path = userId != null
        ? '/api/docs/generate'
        : '/api/docs/generate/guest';
    final query = userId != null ? {'user_id': userId} : null;

    final res = await ApiClient.instance.post<Map<String, dynamic>>(
      path,
      query: query,
      body: body,
      fromData: (d) => Map<String, dynamic>.from(d as Map),
      timeout: ApiConfig.generateTimeout,
    );

    if (!res.success || res.data == null) {
      throw ApiException(res.message);
    }

    // Backend trả { document: {...}, syntax_warning: {...} }
    final docMap = res.data!['document'] as Map<String, dynamic>?;
    if (docMap == null) throw const ApiException('Không nhận được tài liệu từ server');

    // Gắn lại rawCode vào docMap (backend không trả về raw_code_context cho guest)
    final merged = {
      ...docMap,
      'raw_code_context': docMap['raw_code_context'] ?? rawCode,
      'doc_id': docMap['doc_id'],
      'user_id': docMap['user_id'],
      'created_at': docMap['created_at'] ?? DateTime.now().toIso8601String(),
      'updated_at': docMap['updated_at'] ?? DateTime.now().toIso8601String(),
    };

    final doc = Document.fromJson(merged);

    // Parse syntax_warning nếu có (khi user đã bỏ qua cảnh báo)
    SyntaxCheckResult? warning;
    final warnMap = res.data!['syntax_warning'] as Map<String, dynamic>?;
    if (warnMap != null && (warnMap['has_error'] as bool? ?? false)) {
      warning = SyntaxCheckResult.fromJson(warnMap);
    }

    return (doc, warning);
  }

  /// Kiểm tra syntax — endpoint /api/docs/check-syntax
  Future<SyntaxCheckResult> checkSyntax({
    required String code,
    required ProgrammingLanguage language,
  }) async {
    final res = await ApiClient.instance.post<SyntaxCheckResult>(
      '/api/docs/check-syntax',
      body: {
        'title': 'check',
        'source_type': SourceType.DIRECT_TEXT.value,
        'language': language.value,
        'raw_code_context': code,
      },
      fromData: (d) => SyntaxCheckResult.fromJson(d as Map<String, dynamic>),
      timeout: const Duration(seconds: 30),
    );
    if (!res.success || res.data == null) throw ApiException(res.message);
    return res.data!;
  }

  /// Lấy danh sách model đang hoạt động — /api/public/models
  Future<List<AIModelConfig>> fetchActiveModels() async {
    final res = await ApiClient.instance.get<List<AIModelConfig>>(
      '/api/public/models',
      fromData: (d) => (d as List)
          .map((e) => AIModelConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    if (!res.success) throw ApiException(res.message);
    // Chỉ trả về model đang active
    return (res.data ?? []).where((m) => m.isActive).toList();
  }
}

/// Kết quả kiểm tra syntax
class SyntaxCheckResult {
  final bool hasError;
  final String? errorMessage;
  final String? detail;

  const SyntaxCheckResult({
    required this.hasError,
    this.errorMessage,
    this.detail,
  });

  factory SyntaxCheckResult.fromJson(Map<String, dynamic> json) {
    return SyntaxCheckResult(
      hasError:     json['has_error'] as bool? ?? false,
      errorMessage: json['message']   as String?,
      detail:       json['detail']    as String?,
    );
  }
}

final generateRepoProvider = Provider<GenerateRepository>(
      (ref) => GenerateRepository.instance,
);

final selectedModelProvider = StateProvider<AIModelType?>((ref) => null);

final activeModelsProvider =
FutureProvider.autoDispose<List<AIModelConfig>>(
      (ref) => GenerateRepository.instance.fetchActiveModels(),
);