import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_config.dart';

// ─────────────────────────────────────────────────────────────────────────────
// API RESULT
// ─────────────────────────────────────────────────────────────────────────────

class ApiResult<T> {
  final bool success;
  final String message;
  final T? data;
  final dynamic raw;

  ApiResult({
    required this.success,
    required this.message,
    this.data,
    this.raw,
  });

  factory ApiResult.fromJson(
      Map<String, dynamic> json, {
        T Function(dynamic)? fromData,
      }) {
    return ApiResult<T>(
      success: json['success'] ?? true,
      message: json['message']?.toString() ?? '',
      data: fromData != null && json['data'] != null
          ? fromData(json['data'])
          : json['data'],
      raw: json,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// API EXCEPTION
// ─────────────────────────────────────────────────────────────────────────────

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(
      this.message, {
        this.statusCode,
      });

  @override
  String toString() {
    if (statusCode != null) {
      return '[$statusCode] $message';
    }
    return message;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// API CLIENT
// ─────────────────────────────────────────────────────────────────────────────

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  // ───────────────────────────────────────────────────────────────────────────
  // GET
  // ───────────────────────────────────────────────────────────────────────────

  Future<ApiResult<T>> get<T>(
      String path, {
        Map<String, dynamic>? query,
        T Function(dynamic)? fromData,
        Duration? timeout,
      }) async {
    final uri = _buildUri(path, query);

    try {
      final res = await http
          .get(
        uri,
        headers: _headers(),
      )
          .timeout(timeout ?? ApiConfig.timeout);

      return _handleResponse<T>(res, fromData);
    } on TimeoutException {
      throw const ApiException(
        'Server phản hồi quá lâu',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(e.toString());
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // GET BYTES
  // ───────────────────────────────────────────────────────────────────────────

  Future<Uint8List> getBytes(
      String path, {
        Map<String, dynamic>? query,
        Duration? timeout,
      }) async {
    final uri = _buildUri(path, query);

    try {
      final res = await http
          .get(
        uri,
        headers: _headers(),
      )
          .timeout(timeout ?? ApiConfig.timeout);

      if (res.statusCode >= 200 &&
          res.statusCode < 300) {
        return res.bodyBytes;
      }

      throw ApiException(
        'Không tải được file (${res.statusCode})',
        statusCode: res.statusCode,
      );
    } on TimeoutException {
      throw const ApiException(
        'Tải file quá lâu',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(e.toString());
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // POST
  // ───────────────────────────────────────────────────────────────────────────

  Future<ApiResult<T>> post<T>(
      String path, {
        Map<String, dynamic>? query,
        dynamic body,
        T Function(dynamic)? fromData,
        Duration? timeout,
      }) async {
    final uri = _buildUri(path, query);

    try {
      final res = await http
          .post(
        uri,
        headers: _headers(),
        body: body != null ? jsonEncode(body) : null,
      )
          .timeout(timeout ?? ApiConfig.timeout);

      return _handleResponse<T>(res, fromData);
    } on TimeoutException {
      throw const ApiException(
        'Server phản hồi quá lâu',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(e.toString());
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PUT
  // ───────────────────────────────────────────────────────────────────────────

  Future<ApiResult<T>> put<T>(
      String path, {
        Map<String, dynamic>? query,
        dynamic body,
        T Function(dynamic)? fromData,
        Duration? timeout,
      }) async {
    final uri = _buildUri(path, query);

    try {
      final res = await http
          .put(
        uri,
        headers: _headers(),
        body: body != null ? jsonEncode(body) : null,
      )
          .timeout(timeout ?? ApiConfig.timeout);

      return _handleResponse<T>(res, fromData);
    } on TimeoutException {
      throw const ApiException(
        'Server phản hồi quá lâu',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(e.toString());
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // DELETE
  // ───────────────────────────────────────────────────────────────────────────

  Future<ApiResult<T>> delete<T>(
      String path, {
        Map<String, dynamic>? query,
        dynamic body,
        T Function(dynamic)? fromData,
        Duration? timeout,
      }) async {
    final uri = _buildUri(path, query);

    try {
      final request = http.Request(
        'DELETE',
        uri,
      );

      request.headers.addAll(_headers());

      if (body != null) {
        request.body = jsonEncode(body);
      }

      final streamed =
      await request.send().timeout(timeout ?? ApiConfig.timeout);

      final res = await http.Response.fromStream(streamed);

      return _handleResponse<T>(res, fromData);
    } on TimeoutException {
      throw const ApiException(
        'Server phản hồi quá lâu',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(e.toString());
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // UPLOAD FILE
  // ───────────────────────────────────────────────────────────────────────────

  Future<ApiResult<T>> uploadFile<T>(
      String path, {
        Map<String, dynamic>? query,
        required Uint8List fileBytes,
        required String filename,
        required String mimeType,
        String fieldName = 'file',
        T Function(dynamic)? fromData,
        Duration? timeout,
      }) async {
    final uri = _buildUri(path, query);

    try {
      final request = http.MultipartRequest(
        'POST',
        uri,
      );

      request.headers.addAll({
        'Accept': 'application/json',
      });

      request.files.add(
        http.MultipartFile.fromBytes(
          fieldName,
          fileBytes,
          filename: filename,
        ),
      );

      final streamed =
      await request.send().timeout(timeout ?? ApiConfig.timeout);

      final res = await http.Response.fromStream(streamed);

      return _handleResponse<T>(res, fromData);
    } on TimeoutException {
      throw const ApiException(
        'Upload file quá lâu',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        'Lỗi upload file: $e',
      );
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // INTERNAL
  // ───────────────────────────────────────────────────────────────────────────

  Uri _buildUri(
      String path,
      Map<String, dynamic>? query,
      ) {
    return Uri.parse(
      '${ApiConfig.baseUrl}$path',
    ).replace(
      queryParameters: query?.map(
            (key, value) => MapEntry(
          key,
          value.toString(),
        ),
      ),
    );
  }

  Map<String, String> _headers() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  ApiResult<T> _handleResponse<T>(
      http.Response res,
      T Function(dynamic)? fromData,
      ) {
    dynamic jsonBody;

    try {
      jsonBody = jsonDecode(res.body);
    } catch (_) {
      jsonBody = {
        'success': false,
        'message': 'Response không hợp lệ',
      };
    }

    if (res.statusCode >= 200 &&
        res.statusCode < 300) {
      return ApiResult<T>.fromJson(
        jsonBody,
        fromData: fromData,
      );
    }

    throw ApiException(
      jsonBody['message']?.toString() ??
          'Server error (${res.statusCode})',
      statusCode: res.statusCode,
    );
  }
}