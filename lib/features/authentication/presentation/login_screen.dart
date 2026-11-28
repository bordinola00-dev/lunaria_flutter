import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/lunaria_colors.dart';
import '../../../core/providers.dart';
import '../../../core/services/lunaria_authorization.dart';
import '../../../core/services/supabase_config.dart';
import '../../../shared/widgets/lunaria_logo.dart';
import '../../../shared/widgets/lunaria_scaffold.dart';
import 'auth_error_messages.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _isBusy = false;
  String? _error;
  String? _status;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isBusy) return;
    final email = _email.text.trim();
    if (!email.contains('@') || _password.text.length < 6) {
      setState(() {
        _error = 'Ingresa un correo válido y una contraseña de al menos 6 caracteres.';
        _status = null;
      });
      return;
    }

    setState(() {
      _isBusy = true;
      _error = null;
      _status = null;
    });
    ref.read(lunariaStoreProvider).clearAuthorizationDenied();

    final client = supabase;
    if (client != null) {
      try {
        await client.auth.signInWithPassword(
          email: email,
          password: _password.text,
        );
      } on AuthException catch (error) {
        if (!mounted) return;
        setState(() {
          _error = authErrorMessage(error, request: AuthRequest.signIn);
          _isBusy = false;
        });
        return;
      }
    } else if (kReleaseMode) {
      if (!mounted) return;
      setState(() {
        _error =
            supabaseConfigurationError ??
            'Supabase no está disponible. Revisa la configuración de la app.';
        _isBusy = false;
      });
      return;
    }

    try {
      await ref.read(lunariaStoreProvider).authenticate(email.split('@').first);
    } on LunariaAuthorizationException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _isBusy = false;
      });
      return;
    } on AuthException {
      if (!mounted) return;
      setState(() {
        _error =
            'No se pudo cerrar una sesión no autorizada. Inténtalo de nuevo.';
        _isBusy = false;
      });
      return;
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo verificar la autorización de esta cuenta.';
        _isBusy = false;
      });
      return;
    } on PostgrestException {
      if (!mounted) return;
      setState(() {
        _error =
            'No se pudo verificar la autorización en Supabase. '
            'Inténtalo más tarde.';
        _isBusy = false;
      });
      return;
    }
    if (!mounted) return;
    context.go('/');
  }

  Future<void> _resendVerification() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() {
        _error = 'Ingresa tu correo para solicitar la verificación.';
        _status = null;
      });
      return;
    }

    final client = supabase;
    if (client == null) {
      setState(() {
        _error = 'La verificación por correo requiere conexión con Supabase.';
        _status = null;
      });
      return;
    }

    setState(() {
      _isBusy = true;
      _error = null;
      _status = null;
    });
    try {
      await client.auth.resend(type: OtpType.signup, email: email);
      if (!mounted) return;
      setState(() {
        _status =
            'Si la cuenta está pendiente, enviaremos un nuevo enlace. '
            'Revisa Spam; si no llega, el proyecto necesita SMTP personalizado.';
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(
        () => _error = authErrorMessage(
          error,
          request: AuthRequest.resendVerification,
        ),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authorizationDenied = ref
        .watch(lunariaStoreProvider)
        .authorizationDenied;
    return LunariaScaffold(
      backgroundColor: LunariaColors.softPink,
      children: [
        const SizedBox(height: 38),
        const Center(child: LunariaLogo(size: 68)),
        Text(
          'Bienvenida a tu santuario',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displaySmall
              ?.copyWith(fontSize: 32),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ingresa a tu pequeño universo de calma, belleza y armonía.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Text('Correo o usuario', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.mail_outline),
            hintText: 'elena@lunaria.space',
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Contraseña secreta',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            TextButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'La recuperación se habilita con el backend Supabase.',
                  ),
                ),
              ),
              child: const Text('¿Olvidaste tu llave?'),
            ),
          ],
        ),
        TextField(
          controller: _password,
          obscureText: _obscure,
          autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
            ),
          ),
        ),
        if (_error != null || authorizationDenied) ...[
          const SizedBox(height: 10),
          Text(
            _error ?? 'Esta cuenta no está autorizada para usar Lunaria.',
            style: const TextStyle(color: LunariaColors.danger),
          ),
        ],
        if (_status != null) ...[
          const SizedBox(height: 10),
          Text(_status!, style: const TextStyle(color: LunariaColors.success)),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _isBusy ? null : _resendVerification,
            icon: const Icon(Icons.mark_email_read_outlined),
            label: const Text('Reenviar correo de verificación'),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _isBusy ? null : _login,
          child: _isBusy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Entrar al santuario  ✦'),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () => context.go('/register'),
          child: const Text.rich(
            TextSpan(
              text: '¿Aún no tienes tu espacio? ',
              children: [
                TextSpan(
                  text: 'Crear cuenta',
                  style: TextStyle(
                    color: LunariaColors.rose,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!kReleaseMode && supabase == null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              supabaseConfigurationError == null
                  ? 'Modo local de desarrollo activo: los datos no se sincronizan con Supabase.'
                  : 'Configuración de Supabase incompleta en desarrollo: se usará modo local y los datos no se sincronizarán.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }
}
