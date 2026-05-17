// lib/core/api/api_client.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Phản hồi chuẩn từ Backend: { success, message, data }
// Mirror lại schemas.ActionResult[T] bên Python
// ─────────────────────────────────────────────────────────────────────────────
class ApiResult<T> {
  final bool success;
  final String message;
  final T? data;

  const ApiResult({
    required this.success,
    required this.message,
    this.data,
  });

  factory ApiResult.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromData,
  ) {
    return ApiResult<T>(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: fromData != null && json['data'] != null
          ? fromData(json['data'])
          : json['data'] as T?,
    );
  }
}

/// Exception riêng để UI bắt và hiển thị toast
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// HTTP client thống nhất — wrap mọi request với error handling
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  final http.Client _http = http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
      };

  // ── GET ────────────────────────────────────────────────────────────────────
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(dynamic)? fromData,
    Duration? timeout,
  }) async {
    final uri = _buildUri(path, query);
    try {
      final res = await _http
          .get(uri, headers: _headers)
          .timeout(timeout ?? ApiConfig.timeout);
      return _handleResponse<T>(res, fromData);
    } on TimeoutException {
      throw const ApiException('Server phản hồi quá lâu, vui lòng thử lại');
    } catch (e) {
      throw ApiException('Lỗi kết nối: $e');
    }
  }

  // ── POST ───────────────────────────────────────────────────────────────────
  Future<ApiResult<T>> post<T>(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    T Function(dynamic)? fromData,
    Duration? timeout,
  }) async {
    final uri = _buildUri(path, query);
    try {
      final res = await _http
          .post(
            uri,
            headers: _headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout ?? ApiConfig.timeout);
      return _handleResponse<T>(res, fromData);
    } on TimeoutException {
      throw const ApiException('Server phản hồi quá lâu, vui lòng thử lại');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Lỗi kết nối: $e');
    }
  }

  // ── DELETE ─────────────────────────────────────────────────────────────────
  Future<ApiResult<T>> delete<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(dynamic)? fromData,
  }) async {
    final uri = _buildUri(path, query);
    try {
      final res = await _http
          .delete(uri, headers: _headers)
          .timeout(ApiConfig.timeout);
      return _handleResponse<T>(res, fromData);
    } on TimeoutException {
      throw const ApiException('Server phản hồi quá lâu, vui lòng thử lại');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Lỗi kết nối: $e');
    }
  }

  // ─── Internal helpers ──────────────────────────────────────────────────────
  Uri _buildUri(String path, Map<String, dynamic>? query) {
    final base = ApiConfig.baseUrl;
    final qs = query?.map((k, v) => MapEntry(k, v?.toString() ?? ''));
    return Uri.parse('$base$path').replace(queryParameters: qs);
  }

  ApiResult<T> _handleResponse<T>(
    http.Response res,
    T Function(dynamic)? fromData,
  ) {
    final body = utf8.decode(res.bodyBytes);

    Map<String, dynamic> json;
    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        'Dữ liệu trả về không hợp lệ: ${body.substring(0, body.length > 200 ? 200 : body.length)}',
        statusCode: res.statusCode,
      );
    }

    // Backend FastAPI trả lỗi ở key "detail"
    if (res.statusCode >= 400) {
      final detail = json['detail'] ?? json['message'] ?? 'Đã có lỗi xảy ra';
      throw ApiException(detail.toString(), statusCode: res.statusCode);
    }

    return ApiResult<T>.fromJson(json, fromData);
  }

  void dispose() => _http.close();
}
