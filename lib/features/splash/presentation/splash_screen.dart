import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/lunaria_colors.dart';
import '../../../core/providers.dart';
import '../../../core/services/supabase_config.dart';
import '../../../shared/widgets/lunaria_logo.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  String? _errorMessage;
  bool _isLoading = true;
  bool _canContinueLocally = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _start();
  }

  Future<void> _start({bool localOnly = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (localOnly) {
        if (!canUseLocalDevelopmentMode) {
          throw StateError(
            'El modo local no está disponible en compilaciones release. '
            'Configura Supabase antes de usar Lunaria.',
          );
        }
        useLocalModeForSession();
      } else {
        await initializeSupabase().timeout(const Duration(seconds: 15));
      }

      final store = ref.read(lunariaStoreProvider);
      await store.load().timeout(const Duration(seconds: 10));
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      context.go(
        !store.onboardingComplete
            ? '/onboarding'
            : store.authenticated
            ? '/'
            : '/login',
      );
    } on StateError catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _canContinueLocally = canUseLocalDevelopmentMode;
        _errorMessage = error.message;
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _canContinueLocally = canUseLocalDevelopmentMode;
        _errorMessage = 'No pudimos terminar la inicialización. Revisa tu conexión y configuración, o vuelve a intentarlo.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _canContinueLocally = canUseLocalDevelopmentMode;
        _errorMessage = 'Ocurrió un problema al abrir tus datos locales. Puedes volver a intentarlo.';
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LunariaColors.softPink,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) => Transform.scale(
                    scale: .96 + (_controller.value * .04),
                    child: child,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const LunariaLogo(size: 72),
                      Text(
                        'lunaria',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ],
                  ),
                ),
                if (_isLoading) ...[
                  const SizedBox(height: 24),
                  const SizedBox(width: 140, child: LinearProgressIndicator()),
                ] else ...[
                  const SizedBox(height: 18),
                  Text(
                    _errorMessage ?? 'No se pudo iniciar Lunaria.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _start,
                    child: const Text('Intentar de nuevo'),
                  ),
                  if (_canContinueLocally && canUseLocalDevelopmentMode) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => _start(localOnly: true),
                      child: const Text('Continuar en modo local (desarrollo)'),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
