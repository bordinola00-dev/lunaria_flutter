import 'package:supabase_flutter/supabase_flutter.dart';

const lunariaSupabaseUrl = 'https://gtzzvklqnmndqfzgbmpd.supabase.co';
const _url = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: lunariaSupabaseUrl,
);
const _publishableKey = String.fromEnvironment('SUPABASE_ANON_KEY');

bool get isSupabaseConfigured =>
    _url.trim() == lunariaSupabaseUrl && _publishableKey.trim().isNotEmpty;

bool _initialized = false;
bool _disabledForSession = false;
Future<void>? _initialization;

bool get isSupabaseAvailable =>
    isSupabaseConfigured && _initialized && !_disabledForSession;

Future<void> initializeSupabase() {
  if (_url.trim() != lunariaSupabaseUrl) {
    throw StateError(
      'SUPABASE_URL debe coincidir con la URL oficial de Lunaria.',
    );
  }
  if (!isSupabaseConfigured) return Future<void>.value();
  _disabledForSession = false;
  if (_initialized) return Future<void>.value();
  return _initialization ??= _initialize();
}

Future<void> _initialize() async {
  try {
    await Supabase.initialize(
      url: lunariaSupabaseUrl,
      publishableKey: _publishableKey.trim(),
    );
    _initialized = true;
  } catch (_) {
    _initialization = null;
    rethrow;
  }
}

void useLocalModeForSession() {
  _disabledForSession = true;
}

SupabaseClient? get supabase =>
    isSupabaseAvailable ? Supabase.instance.client : null;
