import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/lunaria_colors.dart';
import '../../../core/providers.dart';
import '../../../shared/widgets/lunaria_card.dart';
import '../../../shared/widgets/lunaria_logo.dart';
import '../../../shared/widgets/lunaria_scaffold.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final selected = <String>{};

  @override
  Widget build(BuildContext context) {
    return LunariaScaffold(
      backgroundColor: LunariaColors.softPink,
      children: [
        const SizedBox(height: 24),
        const Center(child: LunariaLogo(size: 64)),
        const SizedBox(height: 8),
        Text(
          'Un espacio para sentir, crear y disfrutar',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displaySmall
              ?.copyWith(fontSize: 30),
        ),
        const SizedBox(height: 8),
        const Text(
          'Conoce Lunaria, tu pequeño universo personal.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        LunariaCard(
          color: LunariaColors.lavender,
          child: const ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.favorite_border),
            ),
            title: Text('MindSpace'),
            subtitle: Text('Tu mundo emocional'),
          ),
        ),
        const SizedBox(height: 10),
        LunariaCard(
          color: LunariaColors.blush,
          child: const ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.auto_awesome),
            ),
            title: Text('BeautyRoom'),
            subtitle: Text('Estilo e inspiración'),
          ),
        ),
        const SizedBox(height: 10),
        LunariaCard(
          color: const Color(0xFFF2DDEE),
          child: const ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.music_note),
            ),
            title: Text('MelodyRoom'),
            subtitle: Text('Tus canciones y recuerdos'),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '¿Qué te acompaña hoy?',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['Bienestar', 'Maquillaje', 'Música'].map((interest) {
            final active = selected.contains(interest);
            return FilterChip(
              label: Text(interest),
              selected: active,
              onSelected: (_) => setState(
                () =>
                    active ? selected.remove(interest) : selected.add(interest),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () async {
            await ref
                .read(lunariaStoreProvider)
                .completeOnboarding(selected.toList());
            if (context.mounted) context.go('/login');
          },
          child: const Text('Entrar a Lunaria'),
        ),
      ],
    );
  }
}
