// lib/core/router/user_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/landing/presentation/landing_screen.dart';
import '../../features/generate/presentation/generate_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../shared/layout/app_scaffold.dart';
import '../auth/auth_provider.dart';

class UserRoutes {
  static const landing = '/';
  static const login = '/login';
  static const generate = '/generate';
  static const history = '/history';
  static const profile = '/profile';
}

final userRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: UserRoutes.landing,
    refreshListenable: _AuthRefreshNotifier(ref),
    redirect: (context, state) {
      final user = ref.read(authProvider).user;
      final loc = state.matchedLocation;

      final isAuthRoute =
          loc.startsWith('/login') || loc == '/' /* landing */;

      // Chưa đăng nhập + đang vào route cần auth → đẩy về login
      // Cho phép xem /generate ở chế độ Khách, nên không bắt buộc đăng nhập
      if (user == null && (loc == '/history' || loc == '/profile')) {
        return '/login';
      }

      // Đã đăng nhập rồi mà còn ở /login → đẩy vào /generate
      if (user != null && loc.startsWith('/login')) {
        return '/generate';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: UserRoutes.landing,
        builder: (_, __) => const LandingScreen(),
      ),
      GoRoute(
        path: UserRoutes.login,
        builder: (_, __) => const LoginScreen(redirectPath: '/generate'),
        routes: [
          GoRoute(
            path: 'register',
            builder: (_, __) => const RegisterScreen(),
          ),
          GoRoute(
            path: 'forgot',
            builder: (_, __) => const ForgotPasswordScreen(),
          ),
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
          GoRoute(
            path: UserRoutes.profile,
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
});

/// Bridge giữa Riverpod auth state và GoRouter refresh
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}
