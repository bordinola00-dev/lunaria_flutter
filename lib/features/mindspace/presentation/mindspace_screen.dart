import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/lunaria_colors.dart';
import '../../../core/services/supabase_config.dart';
import '../../../shared/models/lunaria_models.dart';
import '../../../shared/widgets/lunaria_card.dart';
import '../../../shared/widgets/lunaria_scaffold.dart';
import '../data/mindspace_repository.dart';
import 'mindspace_providers.dart';

class MindSpaceScreen extends ConsumerStatefulWidget {
  const MindSpaceScreen({super.key});

  @override
  ConsumerState<MindSpaceScreen> createState() => _MindSpaceScreenState();
}

class _MindSpaceScreenState extends ConsumerState<MindSpaceScreen> {
  static const _moods = [
    'Felicidad',
    'Tristeza',
    'Ansiedad',
    'Tranquilidad',
    'Enojo',
    'Cansancio',
  ];

  final _moodNote = TextEditingController();
  final _diaryTitle = TextEditingController();
  final _diaryBody = TextEditingController();
  final _diaryFormKey = GlobalKey<FormState>();
  String? _selectedMood = 'Tranquilidad';
  bool _diaryValidationStarted = false;
  bool _isRetrying = false;

  @override
  void dispose() {
    _moodNote.dispose();
    _diaryTitle.dispose();
    _diaryBody.dispose();
    super.dispose();
  }

  Future<void> _saveMood() async {
    final mood = _selectedMood;
    if (mood == null) return;

    try {
      await ref
          .read(mindSpaceControllerProvider)
          .addMood(mood: mood, note: _moodNote.text.trim());
      if (!mounted) return;
      setState(() {
        _selectedMood = null;
        _moodNote.clear();
      });
      _showMessage('Emoción registrada con cariño.');
    } catch (error) {
      if (mounted) {
        _showMessage(
          'No se pudo registrar la emoción: ${describeMindSpaceError(error)}',
        );
      }
    }
  }

  Future<void> _saveDiary() async {
    final form = _diaryFormKey.currentState;
    if (form == null) return;
    if (!form.validate()) {
      setState(() => _diaryValidationStarted = true);
      return;
    }

    try {
      await ref
          .read(mindSpaceControllerProvider)
          .addDiary(
            title: _diaryTitle.text.trim(),
            body: _diaryBody.text.trim(),
          );
      if (!mounted) return;
      form.reset();
      _diaryTitle.clear();
      _diaryBody.clear();
      setState(() => _diaryValidationStarted = false);
      _showMessage('Entrada guardada solo para ti.');
    } catch (error) {
      if (mounted) {
        _showMessage(
          'No se pudo guardar la entrada: ${describeMindSpaceError(error)}',
        );
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _retryMindSpace() async {
    setState(() => _isRetrying = true);
    try {
      await initializeSupabase().timeout(const Duration(seconds: 15));
      if (!mounted) return;
      ref.invalidate(mindSpaceControllerProvider);
    } catch (error) {
      if (mounted) {
        _showMessage(
          'No se pudo inicializar Supabase: ${describeMindSpaceError(error)}',
        );
      }
    } finally {
      if (mounted) setState(() => _isRetrying = false);
    }
  }

  Future<void> _openDiaryEntry(DiaryEntry entry) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _DiaryDetailSheet(
        entry: entry,
        onEdit: () {
          Navigator.of(sheetContext).pop();
          _editDiaryEntry(entry);
        },
        onDelete: () {
          Navigator.of(sheetContext).pop();
          _confirmDeleteDiaryEntry(entry);
        },
      ),
    );
  }

  Future<void> _editDiaryEntry(DiaryEntry entry) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _DiaryEditDialog(entry: entry),
    );
    if (updated == true && mounted) {
      _showMessage('Tu entrada fue actualizada.');
    }
  }

  Future<void> _confirmDeleteDiaryEntry(DiaryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar entrada'),
        content: const Text(
          'Esta acción no se puede deshacer. ¿Quieres continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(mindSpaceControllerProvider).deleteDiary(entry.id);
      if (mounted) _showMessage('La entrada fue eliminada.');
    } catch (error) {
      if (mounted) {
        _showMessage(
          'No se pudo eliminar la entrada: ${describeMindSpaceError(error)}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mindSpace = ref.watch(mindSpaceControllerProvider);
    final busy = mindSpace.isLoading;

    return LunariaScaffold(
      backgroundColor: const Color(0xFFFBF8FD),
      children: [
        Text('MindSpace', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        const Text('Tu santuario de calma y autoconocimiento'),
        const SizedBox(height: 18),
        if (mindSpace.loadError != null) ...[
          _SyncErrorCard(
            error: mindSpace.loadError!,
            onRetry: _retryMindSpace,
            isLoading: mindSpace.isLoading || _isRetrying,
          ),
          const SizedBox(height: 16),
        ],
        LunariaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Cómo te sientes?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _moods.map((mood) {
                  return ChoiceChip(
                    label: Text(mood),
                    selected: _selectedMood == mood,
                    onSelected: busy || mindSpace.isSavingMood
                        ? null
                        : (selected) {
                            if (selected) {
                              setState(() => _selectedMood = mood);
                            }
                          },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _moodNote,
                enabled: !busy && !mindSpace.isSavingMood,
                minLines: 2,
                maxLines: 4,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Una nota opcional',
                  hintText: '¿Qué necesitas hoy?',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      _selectedMood == null || busy || mindSpace.isSavingMood
                      ? null
                      : _saveMood,
                  child: Text(
                    mindSpace.isSavingMood ? 'Guardando…' : 'Registrar emoción',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LunariaCard(
          color: LunariaColors.cream,
          child: Form(
            key: _diaryFormKey,
            autovalidateMode: _diaryValidationStarted
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Diario privado',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _diaryTitle,
                  enabled: !busy && !mindSpace.isSavingDiary,
                  maxLength: 120,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    hintText: 'Nombre de esta reflexión',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Escribe un título para tu entrada.'
                      : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _diaryBody,
                  enabled: !busy && !mindSpace.isSavingDiary,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 10000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Tu nota',
                    hintText: 'Escribe sin juzgarte...',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Escribe el contenido de tu reflexión.'
                      : null,
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: busy || mindSpace.isSavingDiary
                        ? null
                        : _saveDiary,
                    child: Text(
                      mindSpace.isSavingDiary ? 'Guardando…' : 'Solo guardar',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Tus reflexiones', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Text('Emociones', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (busy)
          const _ReflectionLoadingPlaceholder()
        else if (mindSpace.moods.isEmpty && mindSpace.loadError != null)
          const _EmptyReflection(
            icon: Icons.cloud_off_outlined,
            message: 'No pudimos cargar tus emociones. Revisa la conexión e inténtalo de nuevo.',
          )
        else if (mindSpace.moods.isEmpty)
          const _EmptyReflection(
            icon: Icons.spa_outlined,
            message: 'Todavía no hay emociones registradas. Aquí encontrarás tu historia, día a día.',
          )
        else
          ..._moodGroups(mindSpace.moods).entries.map((group) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LunariaCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dateLabel(group.key),
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: LunariaColors.plum),
                    ),
                    const SizedBox(height: 8),
                    for (
                      var index = 0;
                      index < group.value.length;
                      index++
                    ) ...[
                      _MoodReflectionRow(entry: group.value[index]),
                      if (index < group.value.length - 1)
                        const Divider(height: 20),
                    ],
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 12),
        Text('Diario personal', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (busy)
          const _ReflectionLoadingPlaceholder()
        else if (mindSpace.diaries.isEmpty && mindSpace.loadError != null)
          const _EmptyReflection(
            icon: Icons.cloud_off_outlined,
            message: 'No pudimos cargar tu diario. Revisa la conexión e inténtalo de nuevo.',
          )
        else if (mindSpace.diaries.isEmpty)
          const _EmptyReflection(
            icon: Icons.menu_book_outlined,
            message: 'Tu cuaderno está en calma. Cuando quieras, guarda aquí lo que llevas dentro.',
          )
        else
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            child: Column(
              key: ValueKey(mindSpace.diaries.map((entry) => entry.id).join()),
              children: [
                for (final entry in mindSpace.diaries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _NotebookEntryCard(
                      entry: entry,
                      onTap: () => _openDiaryEntry(entry),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        LunariaCard(
          color: LunariaColors.lavender,
          child: const Text(
            'Un momento para ti: respira suavemente durante cuatro segundos.',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _MoodReflectionRow extends StatelessWidget {
  const _MoodReflectionRow({required this.entry});

  final MoodEntry entry;

  @override
  Widget build(BuildContext context) {
    final time = _timeLabel(entry.createdAt);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.nightlight_round, size: 18, color: LunariaColors.plum),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.mood,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Text(time, style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
              if (entry.note.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(entry.note),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _NotebookEntryCard extends StatelessWidget {
  const _NotebookEntryCard({required this.entry, required this.onTap});

  final DiaryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFFCF7),
      borderRadius: BorderRadius.circular(18),
      elevation: 1.5,
      shadowColor: LunariaColors.plum.withValues(alpha: 0.12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(17, 15, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.menu_book_outlined,
                    size: 19,
                    color: LunariaColors.plum,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: LunariaColors.plum),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  _dateLabel(DateUtils.dateOnly(entry.createdAt)),
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: LunariaColors.plum),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                entry.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiaryDetailSheet extends StatelessWidget {
  const _DiaryDetailSheet({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  final DiaryEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      builder: (context, scrollController) => Material(
        color: const Color(0xFFFFFCF7),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: LunariaColors.mauve,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(entry.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '${_dateLabel(DateUtils.dateOnly(entry.createdAt))} · ${_timeLabel(entry.createdAt)}',
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: LunariaColors.plum),
            ),
            const SizedBox(height: 22),
            Text(entry.body, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Eliminar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DiaryEditDialog extends ConsumerStatefulWidget {
  const _DiaryEditDialog({required this.entry});

  final DiaryEntry entry;

  @override
  ConsumerState<_DiaryEditDialog> createState() => _DiaryEditDialogState();
}

class _DiaryEditDialogState extends ConsumerState<_DiaryEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _body;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.entry.title);
    _body = TextEditingController(text: widget.entry.body);
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await ref
          .read(mindSpaceControllerProvider)
          .updateDiary(
            id: widget.entry.id,
            title: _title.text.trim(),
            body: _body.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo actualizar: ${describeMindSpaceError(error)}',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar reflexión'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                enabled: !_isSaving,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Escribe un título.'
                    : null,
              ),
              TextFormField(
                controller: _body,
                enabled: !_isSaving,
                minLines: 4,
                maxLines: 8,
                maxLength: 10000,
                decoration: const InputDecoration(labelText: 'Tu nota'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Escribe el contenido.'
                    : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: LunariaColors.danger),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: Text(_isSaving ? 'Guardando…' : 'Guardar cambios'),
        ),
      ],
    );
  }
}

class _SyncErrorCard extends StatelessWidget {
  const _SyncErrorCard({
    required this.error,
    required this.onRetry,
    required this.isLoading,
  });

  final Object error;
  final VoidCallback onRetry;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return LunariaCard(
      color: const Color(0xFFFFF3F0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No se pudo sincronizar MindSpace',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(describeMindSpaceError(error)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: isLoading ? null : onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(isLoading ? 'Conectando…' : 'Volver a intentar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyReflection extends StatelessWidget {
  const _EmptyReflection({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return LunariaCard(
      color: const Color(0xFFFFFCF7),
      child: Row(
        children: [
          Icon(icon, color: LunariaColors.plum),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _ReflectionLoadingPlaceholder extends StatelessWidget {
  const _ReflectionLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return LunariaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 110,
            height: 14,
            decoration: BoxDecoration(
              color: LunariaColors.lavender,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 12,
            decoration: BoxDecoration(
              color: LunariaColors.softPink,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 180,
            height: 12,
            decoration: BoxDecoration(
              color: LunariaColors.softPink,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }
}

Map<DateTime, List<MoodEntry>> _moodGroups(List<MoodEntry> entries) {
  final groups = <DateTime, List<MoodEntry>>{};
  for (final entry in entries) {
    final date = DateUtils.dateOnly(entry.createdAt.toLocal());
    groups.putIfAbsent(date, () => []).add(entry);
  }
  return groups;
}

String _dateLabel(DateTime date) {
  final today = DateUtils.dateOnly(DateTime.now());
  final day = DateUtils.dateOnly(date);
  if (day == today) return 'Hoy';
  if (day == today.subtract(const Duration(days: 1))) return 'Ayer';
  const months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  return '${day.day} de ${months[day.month - 1]} de ${day.year}';
}

String _timeLabel(DateTime dateTime) {
  final local = dateTime.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
