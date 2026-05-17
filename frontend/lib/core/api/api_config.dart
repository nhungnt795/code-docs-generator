import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class ApiConfig {
  ApiConfig._();

  static String get baseUrl {
    // 1. MÔI TRƯỜNG PRODUCTION (Đã có Domain và HTTPS)
    // Gọi thẳng vào tên miền, Nginx sẽ tự điều hướng "/api/" về Backend 8000
    if (!kDebugMode) {
      return 'https://docgenvn.id.vn/api';
    }

    // 2. MÔI TRƯỜNG LOCAL DEV (Khi đang code)
    if (kIsWeb) {
      return 'http://localhost:8000';
    }

    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8000';
      } else if (Platform.isIOS) {
        return 'http://localhost:8000';
      }
    } catch (e) {
      return 'http://localhost:8000';
    }

    return 'http://localhost:8000';
  }

  static const Duration timeout = Duration(seconds: 60);
  static const Duration generateTimeout = Duration(minutes: 5);
}