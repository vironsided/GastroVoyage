import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/app/app_router.dart';
import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/features/auth/login_screen.dart';
import 'package:mobile/features/onboarding/theme_selector_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        gastroThemeProvider.overrideWith(
          (ref) => GastroThemeNotifier(prefs),
        ),
        authProvider.overrideWith(
          (ref) => AuthNotifier(prefs),
        ),
      ],
      child: const GastroVoyageApp(),
    ),
  );
}

class GastroVoyageApp extends ConsumerWidget {
  const GastroVoyageApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(gastroThemeProvider);

    // Step 1: No theme selected yet → onboarding selector
    if (themeMode == null) {
      return MaterialApp(
        title: 'GastroVoyage',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: const ThemeSelectorScreen(),
      );
    }

    final config = GastroThemeConfig.forMode(themeMode);

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          config.isDark ? Brightness.light : Brightness.dark,
    ));

    final auth = ref.watch(authProvider);

    // Step 2: Theme chosen but not logged in → login screen
    if (!auth.isLoggedIn) {
      return MaterialApp(
        title: 'GastroVoyage',
        debugShowCheckedModeBanner: false,
        theme: config.themeData,
        home: const LoginScreen(),
      );
    }

    // Step 3: Logged in → main app
    return MaterialApp.router(
      title: 'GastroVoyage',
      debugShowCheckedModeBanner: false,
      theme: config.themeData,
      routerConfig: appRouter,
    );
  }
}
