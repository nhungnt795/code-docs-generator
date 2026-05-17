import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/user_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';

class DocGenUserApp extends ConsumerWidget {
  const DocGenUserApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(userRouterProvider);

    return MaterialApp.router(
      title: 'DocGen VN',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}