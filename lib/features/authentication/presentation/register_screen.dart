import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/lunaria_colors.dart';
import '../../../core/providers.dart';
import '../../../core/services/supabase_config.dart';
import '../../../shared/widgets/lunaria_logo.dart';
import '../../../shared/widgets/lunaria_scaffold.dart';

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
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final email = _email.text.trim();
    if (_name.text.trim().length < 2 ||
        !email.contains('@') ||
        _password.text.length < 6) {
      setState(() {
        _error = 'Completa tu nombre, correo y una contraseña de al menos 6 caracteres.';
      });
      return;
    }

    if (supabase != null) {
      try {
        final response = await supabase!.auth.signUp(
          email: email,
          password: _password.text,
          data: {'name': _name.text.trim()},
        );
        if (response.session == null) {
          setState(() {
            _error = 'Revisa tu correo para confirmar la cuenta y luego inicia sesión.';
          });
          return;
        }
      } catch (_) {
        setState(
          () => _error = 'No pudimos crear la cuenta. Inténtalo de nuevo.',
        );
        return;
      }
    }

    await ref.read(lunariaStoreProvider).authenticate(_name.text);
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
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _register,
          child: const Text('Continuar hacia tu llave  →'),
        ),
        TextButton(
          onPressed: () => context.go('/login'),
          child: const Text('Ya tengo un santuario'),
        ),
      ],
    );
  }
}
