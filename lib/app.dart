import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
import 'core/theme/lunaria_theme.dart';
import 'features/authentication/presentation/login_screen.dart';
import 'features/authentication/presentation/register_screen.dart';
import 'features/shell/presentation/main_shell.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/splash/presentation/splash_screen.dart';

class LunariaApp extends ConsumerStatefulWidget {
  const LunariaApp({super.key});

  @override
  ConsumerState<LunariaApp> createState() => _LunariaAppState();
}

class _LunariaAppState extends ConsumerState<LunariaApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final store = ref.read(lunariaStoreProvider);
    _router = GoRouter(
      initialLocation: '/splash',
      refreshListenable: store,
      routes: [
        GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
        GoRoute(
          path: '/onboarding',
          builder: (_, _) => const OnboardingScreen(),
        ),
        GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
        GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
        GoRoute(path: '/', builder: (_, _) => const MainShell()),
      ],
      redirect: (_, state) {
        final location = state.matchedLocation;
        if (location == '/splash') return null;

        if (!store.onboardingComplete && location != '/onboarding') {
          return '/onboarding';
        }
        if (store.onboardingComplete &&
            !store.authenticated &&
            location != '/login' &&
            location != '/register') {
          return '/login';
        }
        if (store.authenticated &&
            (location == '/login' || location == '/register')) {
          return '/';
        }
        return null;
      },
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Lunaria',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: LunariaTheme.light,
      darkTheme: LunariaTheme.dark,
      routerConfig: _router,
    );
  }
}
