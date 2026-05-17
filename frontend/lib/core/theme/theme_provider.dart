// lib/core/theme/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());

// ── ThemeMode Notifier ────────────────────────────────────────────────────────
class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.system);

  void setLight()  => state = ThemeMode.light;
  void setDark()   => state = ThemeMode.dark;
  void setSystem() => state = ThemeMode.system;

  /// Chuyển đổi thông minh: Nếu đang ở System, dựa vào độ sáng thực tế để nhảy sang chế độ ngược lại
  /// currentIsDark: Trạng thái hiển thị thực tế (bao gồm cả chế độ hệ thống)
  void toggle(bool currentIsDark) {
    if (state == ThemeMode.system) {
      // Nếu đang dùng hệ thống, ta ép sang chế độ thủ công ngược lại với hiện tại
      state = currentIsDark ? ThemeMode.light : ThemeMode.dark;
    } else {
      // Nếu đã ở chế độ thủ công, chỉ cần đảo ngược
      state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    }
  }

  bool get isDark => state == ThemeMode.dark;
}

final themeModeProvider =
StateNotifierProvider<ThemeNotifier, ThemeMode>(
      (ref) => ThemeNotifier(),
);