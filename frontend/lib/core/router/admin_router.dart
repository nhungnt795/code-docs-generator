// lib/core/router/admin_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/admin/presentation/dashboard_screen.dart';
import '../../features/admin/presentation/user_management_screen.dart';
import '../../features/admin/presentation/ai_model_screen.dart';
import '../../features/admin/presentation/feedback_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../shared/layout/app_scaffold.dart';
import '../auth/auth_provider.dart';

class AdminRoutes {
  static const login     = '/login';
  static const dashboard = '/';
  static const users     = '/users';
  static const models    = '/models';
  static const feedback  = '/feedback';
  static const profile   = '/profile';
}

final adminRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AdminRoutes.login,
    refreshListenable: _AuthRefreshNotifier(ref),
    redirect: (context, state) {
      final user = ref.read(authProvider).user;
      final loc  = state.matchedLocation;

      if (user == null) return loc == '/login' ? null : '/login';
      if (!user.isAdmin) {
        Future.microtask(() => ref.read(authProvider.notifier).logout());
        return '/login';
      }
      if (loc == '/login') return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: AdminRoutes.login,
        builder: (_, __) => const LoginScreen(redirectPath: '/', requireAdmin: true),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(
          location: state.matchedLocation,
          isAdmin: true,
          child: child,
        ),
        routes: [
          GoRoute(path: AdminRoutes.dashboard, builder: (_, __) => const DashboardScreen()),
          GoRoute(path: AdminRoutes.users,     builder: (_, __) => const UserManagementScreen()),
          GoRoute(path: AdminRoutes.models,    builder: (_, __) => const AIModelScreen()),
          GoRoute(path: AdminRoutes.feedback,  builder: (_, __) => const FeedbackScreen()),
          GoRoute(
            path: AdminRoutes.profile,
            builder: (_, __) => const ProfileScreen(
                showUsageStats: false, title: 'Cài đặt hệ thống'),
          ),
        ],
      ),
    ],
  );
});

class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}
