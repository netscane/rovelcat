import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/settings_provider.dart';
import 'features/home/home_page.dart';
import 'features/login/login_page.dart';

/// 应用程序主入口
class RovelcatApp extends ConsumerWidget {
  const RovelcatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isInitialized = ref.watch(isSettingsInitializedProvider);
    final isServerConfigured = ref.watch(isServerConfiguredProvider);

    return MaterialApp(
      title: 'Rovelcat',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      home: !isInitialized
          ? const _SplashScreen()
          : isServerConfigured
              ? const HomePage()
              : const LoginPage(),
    );
  }
}

/// 启动画面
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colorScheme.primary, colorScheme.tertiary],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.auto_stories,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
