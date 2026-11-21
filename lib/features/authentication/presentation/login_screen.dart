import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/lunaria_colors.dart';
import '../../../core/providers.dart';
import '../../../core/services/supabase_config.dart';
import '../../../shared/widgets/lunaria_logo.dart';
import '../../../shared/widgets/lunaria_scaffold.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _email.text.trim();
    if (!email.contains('@') || _password.text.length < 6) {
      setState(() {
        _error = 'Ingresa un correo válido y una contraseña de al menos 6 caracteres.';
      });
      return;
    }

    if (supabase != null) {
      try {
        await supabase!.auth.signInWithPassword(
          email: email,
          password: _password.text,
        );
      } catch (error) {
        setState(() => _error = 'No pudimos iniciar sesión. Revisa tus datos.');
        return;
      }
    }

    await ref.read(lunariaStoreProvider).authenticate(email.split('@').first);
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
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
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: LunariaColors.danger)),
        ],
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _login,
          child: const Text('Entrar al santuario  ✦'),
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
        if (supabase == null)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Modo local activo: no se requieren credenciales para probar Lunaria.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }
}
