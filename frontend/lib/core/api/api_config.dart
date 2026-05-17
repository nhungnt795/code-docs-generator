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
    // 1. PRODUCTION
    if (!kDebugMode) {
      return 'https://docgenvn.id.vn';
    }

    // 2. LOCAL DEV
    if (kIsWeb) {
      return 'http://localhost:8000';
    }

    try {
      if (Platform.isAndroid) {
        // Android emulator dùng 10.0.2.2 để gọi tới host machine
        return 'http://10.0.2.2:8000';
      } else if (Platform.isIOS) {
        return 'http://localhost:8000';
      }
    } catch (_) {}

    return 'http://localhost:8000';
  }

  static const Duration timeout = Duration(seconds: 60);
  static const Duration generateTimeout = Duration(minutes: 5);
}
