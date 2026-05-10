// lib/core/router/admin_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/admin/presentation/dashboard_screen.dart';
import '../../features/admin/presentation/user_management_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../shared/layout/app_scaffold.dart';

class AdminRoutes {
  static const login     = '/login';
  static const dashboard = '/';
  static const users     = '/users';
  static const profile   = '/profile';
}

final adminRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AdminRoutes.login,
    routes: [
      GoRoute(
        path: AdminRoutes.login,
        builder: (_, __) => const LoginScreen(redirectPath: '/'), // Admin sau đăng nhập về Dashboard '/'
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(
          location: state.matchedLocation,
          isAdmin: true,
          child: child,
        ),
        routes: [
          GoRoute(
            path: AdminRoutes.dashboard,
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(
            path: AdminRoutes.users,
            builder: (_, __) => const UserManagementScreen(),
          ),
          // BÊN ADMIN: Ghi đè tham số để tinh chỉnh giao diện Profile
          GoRoute(
            path: AdminRoutes.profile,
            builder: (_, __) => const ProfileScreen(
              showUsageStats: false,
              title: 'Cài đặt hệ thống',
            ),
          ),
        ],
      ),
    ],
  );
});