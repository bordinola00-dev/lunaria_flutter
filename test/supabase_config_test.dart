import 'package:flutter_test/flutter_test.dart';
import 'package:lunaria_flutter/core/services/supabase_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'compile-time Supabase values initialize and restore remote mode',
    () async {
      expect(isSupabaseConfigured, isTrue);

      useLocalModeForSession();
      expect(supabase, isNull);

      await initializeSupabase();

      expect(isSupabaseAvailable, isTrue);
      expect(supabase, isNotNull);
    },
    skip: !isSupabaseConfigured,
  );
}
