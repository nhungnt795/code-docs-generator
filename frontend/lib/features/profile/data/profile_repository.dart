// lib/features/profile/data/profile_repository.dart
//
// FIX uploadAvatar:
// http.MultipartFile.fromBytes KHÔNG tự suy contentType từ tên file.
// Backend kiểm tra file.content_type.startswith("image/") → lỗi nếu không set.
// Fix: dùng package:http_parser để set MediaType đúng.
//
// Endpoint đúng theo backend Cụm 1:
// POST /api/users/{id}/avatar   — upload avatar (multipart, field name: "file")
// PUT  /api/users/{id}/profile  — cập nhật tên/email
// PUT  /api/users/{id}/password — đổi mật khẩu
// POST /api/feedback?user_id=   — gửi feedback
// GET  /api/public/models       — danh sách model active

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/api/models.dart';

final profileRepoProvider = Provider<ProfileRepository>(
      (ref) => ProfileRepository(),
);

class ProfileRepository {
  // ── Helpers ─────────────────────────────────────────────────────────────────
  /// Suy MediaType từ tên file để backend nhận đúng content_type
  MediaType _mediaTypeFromName(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    final sub = switch (ext) {
      'jpg' || 'jpeg' => 'jpeg',
      'png'           => 'png',
      'webp'          => 'webp',
      'gif'           => 'gif',
      _               => 'jpeg',  // fallback
    };
    return MediaType('image', sub);
  }

  // ── Avatar ───────────────────────────────────────────────────────────────────
  Future<User> uploadAvatar(
      int userId,
      Uint8List bytes,
      String fileName,
      ) async {
    final uri = Uri.parse(
        '${ApiConfig.baseUrl}/api/users/$userId/avatar');
    final req = http.MultipartRequest('POST', uri);

    // FIX: set contentType rõ ràng → backend không báo "chỉ chấp nhận hình ảnh"
    req.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
        contentType: _mediaTypeFromName(fileName),
      ),
    );

    final streamed = await req.send().timeout(ApiConfig.timeout);
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode >= 400) {
      String detail;
      try {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        detail = (j['detail'] ?? j['message'] ?? 'Lỗi upload').toString();
      } catch (_) {
        detail = 'Lỗi ${res.statusCode} khi tải ảnh lên';
      }
      throw ApiException(detail, statusCode: res.statusCode);
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) throw const ApiException('Server không trả về thông tin user');
    return User.fromJson(data);
  }

  // ── Update profile ────────────────────────────────────────────────────────────
  Future<User> updateProfile({
    required int userId,
    required String fullName,
    required String email,
  }) async {
    final res = await ApiClient.instance.put<User>(
      '/api/users/$userId/profile',
      body: {
        if (fullName.isNotEmpty) 'full_name': fullName,
        if (email.isNotEmpty) 'email': email,
      },
      fromData: (d) => User.fromJson(d as Map<String, dynamic>),
    );
    if (!res.success || res.data == null) throw ApiException(res.message);
    return res.data!;
  }

  // ── Change password ───────────────────────────────────────────────────────────
  Future<void> changePassword({
    required int userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    final res = await ApiClient.instance.put<void>(
      '/api/users/$userId/password',
      body: {
        'old_password': oldPassword,
        'new_password': newPassword,
      },
    );
    if (!res.success) throw ApiException(res.message);
  }

  // ── Feedback ──────────────────────────────────────────────────────────────────
  Future<void> submitFeedback({
    required int userId,
    required int rating,
    required String content,
  }) async {
    final res = await ApiClient.instance.post<void>(
      '/api/feedback',
      query: {'user_id': userId},
      body: {'rating': rating, 'content': content},
    );
    if (!res.success) throw ApiException(res.message);
  }

  // ── Active models ─────────────────────────────────────────────────────────────
  Future<List<AIModelConfig>> fetchActiveModels() async {
    final res = await ApiClient.instance.get<List<AIModelConfig>>(
      '/api/public/models',
      fromData: (d) => (d as List)
          .map((e) => AIModelConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    if (!res.success) throw ApiException(res.message);
    return (res.data ?? []).where((m) => m.isActive).toList();
  }
}