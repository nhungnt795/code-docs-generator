// lib/core/router/user_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/verify_otp_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/landing/presentation/landing_screen.dart';
import '../../features/generate/presentation/generate_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/info/presentation/about_screen.dart';
import '../../features/info/presentation/contact_screen.dart';
import '../../features/info/presentation/download_screen.dart';
import '../../features/info/presentation/privacy_screen.dart';
import '../../features/info/presentation/terms_screen.dart';
import '../../shared/layout/app_scaffold.dart';
import '../auth/auth_provider.dart';

class UserRoutes {
  static const landing = '/';
  static const login = '/login';
  static const generate = '/generate';
  static const history = '/history';
  static const profile = '/profile';
  static const about = '/about';
  static const contact = '/contact';
  static const download = '/download';
  static const privacy = '/privacy';
  static const terms = '/terms';
}

final userRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: UserRoutes.landing,
    refreshListenable: _AuthRefreshNotifier(ref),
    redirect: (context, state) {
      final user = ref.read(authProvider).user;
      final loc = state.matchedLocation;

      if (user == null && (loc == '/history' || loc == '/profile')) {
        return '/login';
      }
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
      GoRoute(
        path: '/verify-otp',
        builder: (context, state) {
          final email = state.extra as String? ?? '';
          return VerifyOtpScreen(email: email);
        },
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) {
          final email = state.extra as String? ?? '';
          return ResetPasswordScreen(prefillEmail: email);
        },
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
      GoRoute(
        path: UserRoutes.about,
        builder: (_, __) => const AboutScreen(),
      ),
      GoRoute(
        path: UserRoutes.contact,
        builder: (_, __) => const ContactScreen(),
      ),
      GoRoute(
        path: UserRoutes.download,
        builder: (_, __) => const DownloadScreen(),
      ),
      GoRoute(
        path: UserRoutes.privacy,
        builder: (_, __) => const PrivacyScreen(),
      ),
      GoRoute(
        path: UserRoutes.terms,
        builder: (_, __) => const TermsScreen(),
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