// lib/core/auth/auth_provider.dart
//
// Thêm updateUser() để profile screen có thể cập nhật user state
// → sidebar và topbar tự rebuild hiển thị đúng thông tin mới.

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../theme/theme_provider.dart';

class AuthState {
  final User? user;
  final bool loading;
  final String? error;

  const AuthState({this.user, this.loading = false, this.error});

  bool get isAuthenticated => user != null;
  bool get isAdmin => user?.isAdmin ?? false;

  AuthState copyWith({
    User? user,
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

class AuthNotifier extends StateNotifier<AuthState> {
  final SharedPreferences _prefs;
  static const _kUserJsonKey = 'auth_user_json';

  AuthNotifier(this._prefs) : super(const AuthState()) {
    _restoreFromCache();
  }

  void _restoreFromCache() {
    final raw = _prefs.getString(_kUserJsonKey);
    if (raw == null) return;
    try {
      final user = User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      state = state.copyWith(user: user);
    } catch (_) {
      _prefs.remove(_kUserJsonKey);
    }
  }

  Future<void> _persist(User user) async {
    await _prefs.setString(_kUserJsonKey, jsonEncode(user.toJson()));
  }

  // ── Login ──────────────────────────────────────────────────────────────────
  Future<bool> login(String email, String password) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final res = await ApiClient.instance.post<User>(
        '/api/auth/login',
        body: {'email': email, 'password': password},
        fromData: (d) => User.fromJson(d as Map<String, dynamic>),
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

  // ── Register ───────────────────────────────────────────────────────────────
  Future<bool> register({
    required String email,
    required String password,
    String? fullName,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final res = await ApiClient.instance.post<User>(
        '/api/auth/register',
        body: {
          'email': email,
          'password': password,
          'full_name': fullName,
        },
        fromData: (d) => User.fromJson(d as Map<String, dynamic>),
      );
      if (res.success) {
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

  // ── Update user (cập nhật tên/avatar/email sau khi thay đổi profile) ───────
  // Gọi sau khi uploadAvatar, updateProfile thành công
  // → toàn bộ widget watch currentUserProvider tự rebuild
  Future<void> updateUser(User updatedUser) async {
    await _persist(updatedUser);
    state = state.copyWith(user: updatedUser);
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await _prefs.remove(_kUserJsonKey);
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return AuthNotifier(prefs);
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});
