import 'package:flutter_test/flutter_test.dart';
import 'package:lunaria_flutter/core/services/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('daily mood selection updates instead of duplicating the day', () async {
    final store = LunariaStore();

    await store.setDailyMood('En calma');
    await store.setDailyMood('Radiante');

    expect(store.dailyMood, 'Radiante');
    expect(store.moods, hasLength(1));
    expect(store.moods.single.mood, 'Radiante');

    final restored = LunariaStore();
    await restored.load();
    expect(restored.dailyMood, 'Radiante');
    expect(restored.moods, hasLength(1));
  });

  test('routine completion is retained in the daily history', () async {
    final store = LunariaStore();

    await store.createRoutine(
      title: 'Leer diez minutos',
      description: 'Antes de dormir',
    );
    final routineId = store.routines.single.id;

    await store.completeRoutine(routineId);

    expect(store.routines.single.isCompleted, isTrue);
    expect(store.routines.single.title, 'Leer diez minutos');

    final restored = LunariaStore();
    await restored.load();
    expect(restored.routines, hasLength(1));
    expect(restored.routines.single.isCompleted, isTrue);
  });
}
