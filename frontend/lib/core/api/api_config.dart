// lib/core/api/api_config.dart
//
// baseUrl KHÔNG được kết thúc bằng `/api`. Mọi đường dẫn trong code đã có
// tiền tố `/api/...` rồi (vd: `/api/auth/login`).
//
// Production: https://docgenvn.id.vn        → + /api/auth/login = https://docgenvn.id.vn/api/auth/login ✅
// Local web:   http://localhost:8000        → + /api/auth/login = http://localhost:8000/api/auth/login   ✅

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class ApiConfig {
  ApiConfig._();

  static String get baseUrl {
    return 'https://docgenvn.id.vn';
  }

  /// Asset base — dùng cho avatar được lưu phía server (`/data/avatars/...`)
  static String assetUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final p = path.startsWith('/') ? path : '/$path';
    return '$baseUrl$p';
  }

  static const Duration timeout = Duration(seconds: 60);
  static const Duration generateTimeout = Duration(minutes: 5);
}