// lib/core/auth/auth_provider.dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../theme/theme_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AuthState — trạng thái đăng nhập hiện tại của App
// ─────────────────────────────────────────────────────────────────────────────
class AuthState {
  final UserModel? user;
  final bool loading;
  final String? error;

  const AuthState({this.user, this.loading = false, this.error});

  bool get isAuthenticated => user != null;
  bool get isAdmin => user?.isAdmin ?? false;

  AuthState copyWith({
    UserModel? user,
    bool? loading,
    String? error,
    bool clearUser = false,
    bool clearError = false,
  }) =>
      AuthState(
        user: clearUser ? null : (user ?? this.user),
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// AuthNotifier — đọc/ghi session từ SharedPreferences + gọi API login/register
// ─────────────────────────────────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AuthState> {
  final SharedPreferences _prefs;

  static const _kUserJsonKey = 'auth_user_json';

  AuthNotifier(this._prefs) : super(const AuthState()) {
    _restoreFromCache();
  }

  /// Phục hồi user từ SharedPreferences khi App khởi động
  void _restoreFromCache() {
    final raw = _prefs.getString(_kUserJsonKey);
    if (raw == null) return;
    try {
      final user = UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      state = state.copyWith(user: user);
    } catch (_) {
      // Cache hỏng — xóa luôn
      _prefs.remove(_kUserJsonKey);
    }
  }

  Future<void> _persist(UserModel user) async {
    await _prefs.setString(_kUserJsonKey, jsonEncode(user.toJson()));
  }

  // ── API: Đăng nhập ─────────────────────────────────────────────────────────
  Future<bool> login(String email, String password) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final res = await ApiClient.instance.post<UserModel>(
        '/api/auth/login',
        body: {'email': email, 'password': password},
        fromData: (d) => UserModel.fromJson(d as Map<String, dynamic>),
      );

      if (res.success && res.data != null) {
        await _persist(res.data!);
        state = state.copyWith(user: res.data, loading: false);
        return true;
      } else {
        state = state.copyWith(loading: false, error: res.message);
        return false;
      }
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(loading: false, error: 'Lỗi không xác định: $e');
      return false;
    }
  }

  // ── API: Đăng ký ───────────────────────────────────────────────────────────
  Future<bool> register({
    required String email,
    required String password,
    String? fullName,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final res = await ApiClient.instance.post<UserModel>(
        '/api/auth/register',
        body: {
          'email': email,
          'password': password,
          'full_name': fullName,
        },
        fromData: (d) => UserModel.fromJson(d as Map<String, dynamic>),
      );

      if (res.success && res.data != null) {
        // Đăng ký xong: KHÔNG tự đăng nhập, để user đăng nhập lại
        state = state.copyWith(loading: false);
        return true;
      } else {
        state = state.copyWith(loading: false, error: res.message);
        return false;
      }
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(loading: false, error: 'Lỗi không xác định: $e');
      return false;
    }
  }

  // ── Đăng xuất ──────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await _prefs.remove(_kUserJsonKey);
    state = const AuthState();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return AuthNotifier(prefs);
});

/// Shortcut provider để đọc user nhanh
final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authProvider).user;
});
