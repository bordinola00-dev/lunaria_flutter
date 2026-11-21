import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lunaria_flutter/features/mindspace/data/mindspace_repository.dart';
import 'package:lunaria_flutter/features/mindspace/presentation/mindspace_controller.dart';
import 'package:lunaria_flutter/features/mindspace/presentation/mindspace_providers.dart';
import 'package:lunaria_flutter/features/mindspace/presentation/mindspace_screen.dart';
import 'package:lunaria_flutter/shared/models/lunaria_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'mood with an optional note appears in the reflection history',
    () async {
      final repository = _MemoryMindSpaceRepository();
      final controller = MindSpaceController(repository);

      await controller.load();
      await controller.addMood(mood: 'Felicidad', note: 'Un día luminoso.');

      expect(repository.moods, hasLength(1));
      expect(repository.moods.single.mood, 'Felicidad');
      expect(repository.moods.single.note, 'Un día luminoso.');
      expect(controller.moods.single.id, repository.moods.single.id);

      final reopenedSession = MindSpaceController(repository);
      await reopenedSession.load();
      expect(reopenedSession.moods.single.note, 'Un día luminoso.');
    },
  );

  test(
    'diary entries reload, update, and delete through the repository',
    () async {
      final repository = _MemoryMindSpaceRepository();
      final firstSession = MindSpaceController(repository);
      await firstSession.load();
      await firstSession.addDiary(title: 'Mi día', body: 'Una reflexión.');

      final entryId = repository.diaries.single.id;
      final reopenedSession = MindSpaceController(repository);
      await reopenedSession.load();
      expect(reopenedSession.diaries.single.title, 'Mi día');

      await reopenedSession.updateDiary(
        id: entryId,
        title: 'Mi día, revisado',
        body: 'Una reflexión editada.',
      );
      expect(reopenedSession.diaries.single.body, 'Una reflexión editada.');

      await reopenedSession.deleteDiary(entryId);
      expect(reopenedSession.diaries, isEmpty);
      expect(repository.diaries, isEmpty);
    },
  );

  test('Supabase repository refuses private access without configuration', () {
    final repository = SupabaseMindSpaceRepository();

    expect(repository.fetchMoods(), throwsA(isA<MindSpaceAccessException>()));
  });

  test('Supabase errors identify missing tables and RLS denials', () {
    expect(
      describeMindSpaceError(
        const PostgrestException(
          message: "Could not find table 'public.mood_entries'",
          code: 'PGRST205',
        ),
      ),
      contains('migración 004'),
    );
    expect(
      describeMindSpaceError(
        const PostgrestException(
          message: 'new row violates row-level security policy',
          code: '42501',
        ),
      ),
      contains('RLS'),
    );
  });

  testWidgets('emotion chip selection and note form submit reactively', (
    tester,
  ) async {
    final repository = _MemoryMindSpaceRepository();
    await tester.pumpWidget(_mindSpaceApp(repository));
    await tester.pumpAndSettle();

    expect(find.byType(ChoiceChip), findsNWidgets(6));
    final happinessChip = find.ancestor(
      of: find.text('Felicidad'),
      matching: find.byType(ChoiceChip),
    );
    expect(tester.widget<ChoiceChip>(happinessChip).selected, isFalse);

    await tester.tap(find.text('Felicidad'));
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(happinessChip).selected, isTrue);

    await tester.enterText(find.byType(TextField).first, 'Me siento en paz.');
    await tester.tap(find.text('Registrar emoción'));
    await tester.pumpAndSettle();

    expect(repository.moods.single.mood, 'Felicidad');
    expect(repository.moods.single.note, 'Me siento en paz.');
    expect(find.text('Emoción registrada con cariño.'), findsOneWidget);
    expect(tester.widget<ChoiceChip>(happinessChip).selected, isFalse);
  });

  testWidgets('MindSpace fits a small phone viewport without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_mindSpaceApp(_MemoryMindSpaceRepository()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('diary validates, saves, edits, and deletes entries', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _MemoryMindSpaceRepository();
    await tester.pumpWidget(_mindSpaceApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Solo guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe un título para tu entrada.'), findsOneWidget);
    expect(find.text('Escribe el contenido de tu reflexión.'), findsOneWidget);
    expect(repository.diaries, isEmpty);

    await tester.enterText(find.byType(TextFormField).at(0), 'Un momento');
    await tester.enterText(find.byType(TextFormField).at(1), 'Lo que aprendí.');
    await tester.tap(find.text('Solo guardar'));
    await tester.pumpAndSettle();

    expect(repository.diaries.single.title, 'Un momento');
    expect(repository.diaries.single.body, 'Lo que aprendí.');
    expect(find.text('Entrada guardada solo para ti.'), findsOneWidget);
    expect(find.text('Un momento'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(0))
          .controller!
          .text,
      isEmpty,
    );
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(1))
          .controller!
          .text,
      isEmpty,
    );

    await tester.tap(find.text('Un momento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'Un momento revisado',
    );
    await tester.enterText(
      find.byType(TextFormField).at(3),
      'Una reflexión corregida.',
    );
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(repository.diaries.single.title, 'Un momento revisado');
    expect(repository.diaries.single.body, 'Una reflexión corregida.');

    await tester.tap(find.text('Un momento revisado'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();
    expect(repository.diaries, isEmpty);
  });
}

Widget _mindSpaceApp(_MemoryMindSpaceRepository repository) => ProviderScope(
  overrides: [mindSpaceRepositoryProvider.overrideWithValue(repository)],
  child: const MaterialApp(home: MindSpaceScreen()),
);

class _MemoryMindSpaceRepository implements MindSpaceRepository {
  final List<MoodEntry> moods = [];
  final List<DiaryEntry> diaries = [];
  var _nextId = 0;

  @override
  Future<List<MoodEntry>> fetchMoods() async => List.of(moods);

  @override
  Future<List<DiaryEntry>> fetchDiaryEntries() async => List.of(diaries);

  @override
  Future<MoodEntry> createMood({
    required String mood,
    required String note,
  }) async {
    final entry = MoodEntry(
      id: 'mood-${_nextId++}',
      mood: mood,
      note: note,
      createdAt: DateTime.now(),
    );
    moods.insert(0, entry);
    return entry;
  }

  @override
  Future<DiaryEntry> createDiary({
    required String title,
    required String body,
  }) async {
    final entry = DiaryEntry(
      id: 'diary-${_nextId++}',
      title: title,
      body: body,
      createdAt: DateTime.now(),
    );
    diaries.insert(0, entry);
    return entry;
  }

  @override
  Future<DiaryEntry> updateDiary({
    required String id,
    required String title,
    required String body,
  }) async {
    final index = diaries.indexWhere((entry) => entry.id == id);
    if (index < 0) throw StateError('Entry not found');
    final original = diaries[index];
    final updated = DiaryEntry(
      id: id,
      title: title,
      body: body,
      createdAt: original.createdAt,
    );
    diaries[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteDiary(String id) async {
    diaries.removeWhere((entry) => entry.id == id);
  }
}
