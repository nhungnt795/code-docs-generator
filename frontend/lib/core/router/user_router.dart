// lib/core/router/user_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/landing/presentation/landing_screen.dart';
import '../../features/generate/presentation/generate_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../shared/layout/app_scaffold.dart';

class UserRoutes {
  static const landing  = '/';
  static const login    = '/login';
  static const generate = '/generate';
  static const history  = '/history';
  static const profile  = '/profile';
}

final userRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: UserRoutes.landing,
    routes: [
      GoRoute(
        path: UserRoutes.landing,
        builder: (_, __) => const LandingScreen(),
      ),
      GoRoute(
        path: UserRoutes.login,
        builder: (_, __) => const LoginScreen(redirectPath: '/generate'), // User sau khi đăng nhập về /generate
        routes: [
          GoRoute(path: 'register', builder: (_, __) => const RegisterScreen()),
          GoRoute(path: 'forgot',   builder: (_, __) => const ForgotPasswordScreen()),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(
          location: state.matchedLocation,
          isAdmin: false,
          child: child,
        ),
        routes: [
          GoRoute(
            path: UserRoutes.generate,
            builder: (_, __) => const GenerateScreen(),
          ),
          GoRoute(
            path: UserRoutes.history,
            builder: (_, __) => const HistoryScreen(),
          ),
          // BÊN USER: Dùng cấu hình mặc định (showUsageStats: true, title: 'Cài đặt')
          GoRoute(
            path: UserRoutes.profile,
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
});