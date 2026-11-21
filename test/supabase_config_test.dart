import 'package:flutter_test/flutter_test.dart';
import 'package:lunaria_flutter/core/services/supabase_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(resetSupabaseConfigForTest);

  test('uses the official Supabase project URL as its exact base', () {
    expect(lunariaSupabaseUrl, 'https://gtzzvklqnmndqfzgbmpd.supabase.co');
    expect(Uri.parse(lunariaSupabaseUrl).path, isEmpty);
  });

  test('reports missing configuration when anon key is absent', () {
    debugSetSupabaseConfigForTest(url: lunariaSupabaseUrl, publishableKey: '');

    expect(isSupabaseConfigured, isFalse);
    expect(
      supabaseConfigurationError,
      contains('Falta la configuración de Supabase'),
    );
  });

  test(
    'reports invalid configuration when URL differs from official project',
    () {
      debugSetSupabaseConfigForTest(
        url: 'https://example.supabase.co',
        publishableKey: 'public-anon-key',
      );

      expect(isSupabaseConfigured, isFalse);
      expect(
        supabaseConfigurationError,
        contains('SUPABASE_URL debe ser exactamente'),
      );
    },
  );

  test('accepts official URL with a non-empty public key', () {
    debugSetSupabaseConfigForTest(
      url: lunariaSupabaseUrl,
      publishableKey: 'public-anon-key',
    );

    expect(isSupabaseConfigured, isTrue);
    expect(supabaseConfigurationError, isNull);
  });
}
