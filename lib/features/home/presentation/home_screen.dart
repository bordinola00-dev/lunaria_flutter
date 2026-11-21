import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/lunaria_colors.dart';
import '../../../core/providers.dart';
import '../../../shared/models/lunaria_models.dart';
import '../../../shared/widgets/lunaria_card.dart';
import '../../../shared/widgets/lunaria_scaffold.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _moods = <({String label, IconData icon, Color color})>[
    (
      label: 'Radiante',
      icon: Icons.wb_sunny_outlined,
      color: Color(0xFFFFE9B8),
    ),
    (label: 'En calma', icon: Icons.spa_outlined, color: Color(0xFFDCEEDC)),
    (
      label: 'Creativa',
      icon: Icons.auto_awesome_outlined,
      color: Color(0xFFE9DDF7),
    ),
    (
      label: 'Cansada',
      icon: Icons.nightlight_outlined,
      color: Color(0xFFF8DCE9),
    ),
  ];

  final _routineTitle = TextEditingController();
  final _routineDescription = TextEditingController();
  bool _showHistory = false;
  bool _syncing = false;
  String? _syncError;

  @override
  void initState() {
    super.initState();
    unawaited(_loadRemoteHomeData());
  }

  @override
  void dispose() {
    _routineTitle.dispose();
    _routineDescription.dispose();
    super.dispose();
  }

  Future<void> _loadRemoteHomeData() async {
    setState(() {
      _syncing = true;
      _syncError = null;
    });
    try {
      await ref.read(lunariaStoreProvider).loadHomeData();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _syncError =
            'No pudimos sincronizar Home. Toca para volver a intentar.';
      });
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _addRoutine() async {
    final title = _routineTitle.text.trim();
    if (title.isEmpty) return;
    try {
      await ref
          .read(lunariaStoreProvider)
          .createRoutine(
            title: title,
            description: _routineDescription.text.trim(),
          );
      _routineTitle.clear();
      _routineDescription.clear();
      if (mounted) setState(() {});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar la rutina. Inténtalo de nuevo.'),
        ),
      );
    }
  }

  Future<void> _completeRoutine(DailyRoutine routine) async {
    try {
      await ref.read(lunariaStoreProvider).completeRoutine(routine.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo completar la rutina. Inténtalo de nuevo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(lunariaStoreProvider);
    final today = _dateKey(DateTime.now());
    final todayRoutines = store.routines
        .where((item) => item.routineDate == today)
        .toList();
    final activeRoutines = todayRoutines
        .where((item) => !item.isCompleted)
        .toList();
    final completedToday = todayRoutines
        .where((item) => item.isCompleted)
        .toList();
    final previousHistory = store.routines
        .where((item) => item.routineDate != today)
        .toList();
    final date =
        '${_weekday(DateTime.now().weekday)}, ${DateTime.now().day} DE ${_month(DateTime.now().month)}';

    return LunariaScaffold(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(date, style: Theme.of(context).textTheme.labelSmall),
                  Text(
                    'Buenos días, ${store.name} ✨',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const Text('Tu santuario personal despierta contigo.'),
                ],
              ),
            ),
            CircleAvatar(
              radius: 24,
              backgroundColor: LunariaColors.blush,
              child: Text(store.name.characters.first.toUpperCase()),
            ),
          ],
        ),
        const SizedBox(height: 18),
        LunariaCard(
          color: LunariaColors.softPink,
          child: Column(
            children: [
              Text(
                '¿Cómo te sientes hoy?',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceAround,
                spacing: 8,
                runSpacing: 10,
                children: _moods.map((mood) {
                  final selected = store.dailyMood == mood.label;
                  return Semantics(
                    button: true,
                    selected: selected,
                    label: mood.label,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () async {
                        try {
                          await store.setDailyMood(mood.label);
                        } catch (_) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'No se pudo guardar tu emoción. Inténtalo de nuevo.',
                              ),
                            ),
                          );
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        constraints: const BoxConstraints(
                          minWidth: 132,
                          minHeight: 52,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? LunariaColors.lavender
                              : Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: selected
                                ? LunariaColors.plum
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              mood.icon,
                              color: LunariaColors.plum,
                              size: 19,
                            ),
                            const SizedBox(width: 8),
                            Text(mood.label),
                            if (selected) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.check_circle,
                                size: 16,
                                color: LunariaColors.plum,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (store.dailyMood != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Hoy elegiste ${store.dailyMood}. Puedes cambiarlo cuando quieras.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                'Rutinas de Hoy',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (_syncing)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        if (_syncError != null)
          TextButton.icon(
            onPressed: _loadRemoteHomeData,
            icon: const Icon(Icons.refresh),
            label: Text(_syncError!),
          ),
        const SizedBox(height: 8),
        LunariaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (activeRoutines.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'No tienes rutinas pendientes. Añade una pequeña intención para hoy.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else
                ...activeRoutines.map(
                  (routine) => _RoutineRow(
                    routine: routine,
                    onComplete: () => _completeRoutine(routine),
                  ),
                ),
              TextField(
                controller: _routineTitle,
                onChanged: (_) => setState(() {}),
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Añadir una rutina',
                  hintText: 'Ej. Leer diez minutos',
                  prefixIcon: Icon(Icons.add_task),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _routineDescription,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _routineTitle.text.trim().isEmpty
                    ? null
                    : _addRoutine,
                icon: const Icon(Icons.add),
                label: const Text('Añadir rutina'),
              ),
            ],
          ),
        ),
        if (completedToday.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'Completadas hoy · ${completedToday.length}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          LunariaCard(
            child: Column(
              children: completedToday
                  .map((routine) => _RoutineRow(routine: routine))
                  .toList(),
            ),
          ),
        ],
        if (previousHistory.isNotEmpty) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => setState(() => _showHistory = !_showHistory),
            icon: Icon(_showHistory ? Icons.expand_less : Icons.history),
            label: Text(
              _showHistory
                  ? 'Ocultar historial'
                  : 'Ver historial · ${previousHistory.length}',
            ),
          ),
          if (_showHistory)
            LunariaCard(
              child: Column(
                children: previousHistory.map((routine) {
                  return _RoutineRow(
                    routine: routine,
                    trailing: routine.routineDate,
                  );
                }).toList(),
              ),
            ),
        ],
        const SizedBox(height: 18),
        _MusicCard(song: store.songs.isEmpty ? null : store.songs.first),
        const SizedBox(height: 16),
        LunariaCard(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          child: Text(
            'Alguien creó este pequeño universo pensando en ti.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontStyle: FontStyle.italic),
          ),
        ),
      ],
    );
  }

  static String _weekday(int value) => const [
    '',
    'LUNES',
    'MARTES',
    'MIÉRCOLES',
    'JUEVES',
    'VIERNES',
    'SÁBADO',
    'DOMINGO',
  ][value];
  static String _month(int value) => const [
    '',
    'ENERO',
    'FEBRERO',
    'MARZO',
    'ABRIL',
    'MAYO',
    'JUNIO',
    'JULIO',
    'AGOSTO',
    'SEPTIEMBRE',
    'OCTUBRE',
    'NOVIEMBRE',
    'DICIEMBRE',
  ][value];
}

class _RoutineRow extends StatelessWidget {
  const _RoutineRow({required this.routine, this.onComplete, this.trailing});

  final DailyRoutine routine;
  final VoidCallback? onComplete;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          if (onComplete != null)
            IconButton(
              tooltip: 'Marcar como completada',
              onPressed: onComplete,
              icon: const Icon(Icons.radio_button_unchecked),
            )
          else
            const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.check_circle, color: LunariaColors.plum),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  routine.title,
                  style: TextStyle(
                    decoration: routine.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (routine.description.isNotEmpty)
                  Text(
                    routine.description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          if (trailing != null)
            Text(trailing!, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _MusicCard extends StatelessWidget {
  const _MusicCard({required this.song});

  final Song? song;

  Future<void> _openSong(BuildContext context) async {
    final uri = Uri.tryParse(song?.url ?? '');
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace musical.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LunariaCard(
      color: const Color(0xFFE9E0EF),
      child: Row(
        children: [
          const Icon(Icons.music_note, color: LunariaColors.plum, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song == null
                      ? 'SPOTIFY · NO CONECTADO'
                      : 'TU CANCIÓN GUARDADA',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: LunariaColors.plum,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  song?.title ?? 'Tu espacio musical',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  song?.artist ?? 'No se reproduce música desde Lunaria.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (song?.url.isNotEmpty == true)
            IconButton(
              tooltip: 'Abrir canción',
              onPressed: () => _openSong(context),
              icon: const Icon(Icons.open_in_new),
            ),
        ],
      ),
    );
  }
}
