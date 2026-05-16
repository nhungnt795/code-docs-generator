import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/models.dart';

/// Provider cung cấp instance của AuthRepository cho toàn bộ app
final authRepoProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ApiClient.instance);
});

class AuthRepository {
  final ApiClient _api;

  AuthRepository(this._api);

  // 1. Đăng nhập
  Future<ApiResult<User>> login(String email, String password) async {
    return _api.post<User>(
      '/api/auth/login',
      body: {
        'email': email,
        'password': password,
      },
      fromData: (json) => User.fromJson(json),
    );
  }

  // 2. Đăng ký
  Future<ApiResult<User>> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    return _api.post<User>(
      '/api/auth/register',
      body: {
        'email': email,
        'password': password,
        'full_name': fullName,
      },
      fromData: (json) => User.fromJson(json),
    );
  }

  // 3. Xác thực OTP (Kích hoạt tài khoản)
  Future<ApiResult<void>> verifyOtp(String email, String otp) async {
    return _api.post<void>(
      '/api/auth/verify',
      body: {
        'email': email,
        'otp': otp,
      },
    );
  }

  // 4. Gửi lại OTP (Dùng cho cả Kích hoạt và Quên mật khẩu)
  Future<ApiResult<void>> resendOtp(String email, {String purpose = 'ACTIVATE'}) async {
    return _api.post<void>(
      '/api/auth/resend-otp',
      body: {
        'email': email,
        'purpose': purpose,
      },
    );
  }

  // 5. Quên mật khẩu — gọi /forgot-password để gửi OTP reset
  Future<ApiResult<void>> forgotPassword(String email) async {
    return _api.post<void>(
      '/api/auth/forgot-password',
      body: {'email': email},
    );
  }

  // 6. Đặt lại mật khẩu mới
  Future<ApiResult<void>> resetPassword(String email, String otp, String newPassword) async {
    return _api.post<void>(
      '/api/auth/reset-password',
      body: {
        'email': email,
        'otp': otp,
        'new_password': newPassword,
      },
    );
  }
}