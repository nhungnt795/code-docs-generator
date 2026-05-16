// lib/main_user.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_user.dart';
import 'core/theme/theme_provider.dart';
import 'features/landing/presentation/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const _Bootstrap(),
    ),
  );
}

/// _Bootstrap: hiển thị SplashScreen trước, sau đó nhả vào DocGenUserApp
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  bool _ready = false;

  @override
  Widget build(BuildContext context) {
    if (_ready) return const DocGenUserApp();

    // Splash dùng MaterialApp riêng để không phụ thuộc router/theme provider.
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(
        duration: const Duration(milliseconds: 1500),
        onFinish: () => setState(() => _ready = true),
      ),
    );
  }
}