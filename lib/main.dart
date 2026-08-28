import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'navigation/app_router.dart';
import 'providers/app_providers.dart';
import 'screens/auth/lock_screen.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = await StorageService.init();

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storageService),
      ],
      child: const PocketApp(),
    ),
  );
}

class PocketApp extends ConsumerStatefulWidget {
  const PocketApp({super.key});

  @override
  ConsumerState<PocketApp> createState() => _PocketAppState();
}

class _PocketAppState extends ConsumerState<PocketApp> {
  late final _router = createRouter(
    ref.read(settingsProvider).isOnboarded,
  );
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    if (!settings.biometricEnabled && !settings.pinLockEnabled) {
      _isAuthenticated = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(effectiveThemeModeProvider);
    final settings = ref.watch(settingsProvider);
    final isLocked = (settings.biometricEnabled || settings.pinLockEnabled) && !_isAuthenticated;

    if (isLocked) {
      return MaterialApp(
        title: 'Pocket',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: LockScreen(
          onAuthenticated: () {
            setState(() => _isAuthenticated = true);
          },
        ),
      );
    }

    return MaterialApp.router(
      title: 'Pocket',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}
