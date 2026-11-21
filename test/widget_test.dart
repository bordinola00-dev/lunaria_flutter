import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lunaria_flutter/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fresh launch leaves splash and opens onboarding', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: LunariaApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.text('Un espacio para sentir, crear y disfrutar'),
      findsOneWidget,
    );
    expect(find.text('lunaria'), findsNothing);
  });

  testWidgets('persisted session leaves splash and opens home', (tester) async {
    SharedPreferences.setMockInitialValues({
      'lunaria_store_v1': jsonEncode({
        'name': 'Elena',
        'interests': ['Música'],
        'onboardingComplete': true,
        'authenticated': true,
        'moods': [],
        'diaries': [],
        'products': [],
        'looks': [],
        'songs': [],
        'playlists': [],
      }),
    });

    await tester.pumpWidget(const ProviderScope(child: LunariaApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Rutinas de Hoy'), findsOneWidget);
    expect(find.text('lunaria'), findsNothing);
  });
}
