import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/lunaria_colors.dart';
import '../../../core/providers.dart';
import '../../../core/services/supabase_config.dart';
import '../../../shared/widgets/lunaria_logo.dart';
import '../../../shared/widgets/lunaria_scaffold.dart';
import 'auth_error_messages.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _isBusy = false;
  bool _canResendVerification = false;
  String? _error;
  String? _status;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_isBusy) return;
    final email = _email.text.trim();
    if (_name.text.trim().length < 2 ||
        !email.contains('@') ||
        _password.text.length < 6) {
      setState(() {
        _error = 'Completa tu nombre, correo y una contraseña de al menos 6 caracteres.';
        _status = null;
      });
      return;
    }

    setState(() {
      _isBusy = true;
      _error = null;
      _status = null;
      _canResendVerification = false;
    });

    final client = supabase;
    if (client != null) {
      late final AuthResponse response;
      try {
        response = await client.auth.signUp(
          email: email,
          password: _password.text,
          data: {'name': _name.text.trim()},
        );
      } on AuthException catch (error) {
        if (!mounted) return;
        setState(() {
          _error = authErrorMessage(error, request: AuthRequest.signUp);
          _canResendVerification = shouldOfferVerificationResend(error);
          _isBusy = false;
        });
        return;
      }

      if (response.session == null) {
        if (!mounted) return;
        setState(() {
          _status = 'Cuenta creada. Revisa Recibidos y Spam para confirmar tu correo.';
          _canResendVerification = true;
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

    await ref.read(lunariaStoreProvider).authenticate(_name.text);
    if (!mounted) return;
    context.go('/');
  }

  Future<void> _resendVerification() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() {
        _error = 'Ingresa el correo electrónico de tu cuenta.';
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
    return LunariaScaffold(
      backgroundColor: LunariaColors.softPink,
      children: [
        const SizedBox(height: 38),
        const Center(child: LunariaLogo(size: 68)),
        Text(
          'Crea tu santuario personal',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displaySmall
              ?.copyWith(fontSize: 32),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _name,
          decoration: const InputDecoration(
            labelText: 'Nombre o pseudónimo',
            hintText: 'Sofía o Flor de Loto',
            prefixIcon: Icon(Icons.spa_outlined),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Correo electrónico',
            hintText: 'tu.alma@lunaria.com',
            prefixIcon: Icon(Icons.mail_outline),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _password,
          obscureText: _obscure,
          decoration: InputDecoration(
            labelText: 'Contraseña secreta',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: LunariaColors.danger)),
        ],
        if (_status != null) ...[
          const SizedBox(height: 10),
          Text(_status!, style: const TextStyle(color: LunariaColors.success)),
        ],
        if (_canResendVerification)
          TextButton.icon(
            onPressed: _isBusy ? null : _resendVerification,
            icon: const Icon(Icons.mark_email_read_outlined),
            label: const Text('Reenviar correo de verificación'),
          ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _isBusy ? null : _register,
          child: _isBusy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Continuar hacia tu llave  →'),
        ),
        TextButton(
          onPressed: () => context.go('/login'),
          child: const Text('Ya tengo un santuario'),
        ),
      ],
    );
  }
}
