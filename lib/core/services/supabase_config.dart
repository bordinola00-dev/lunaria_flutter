import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const lunariaSupabaseUrl = 'https://gtzzvklqnmndqfzgbmpd.supabase.co';

const _dartDefineUrl = String.fromEnvironment('SUPABASE_URL');
const _dartDefineKey = String.fromEnvironment('SUPABASE_ANON_KEY');

String _resolvedUrl = _dartDefineUrl.trim().isEmpty
    ? lunariaSupabaseUrl
    : _dartDefineUrl.trim();
String _resolvedPublishableKey = _dartDefineKey.trim();
bool _configLoaded = false;
Future<void>? _configLoad;

bool _initialized = false;
bool _disabledForSession = false;
Future<void>? _initialization;

String get configuredSupabaseUrl => _resolvedUrl;

bool get isSupabaseConfigured =>
    _resolvedUrl == lunariaSupabaseUrl && _resolvedPublishableKey.isNotEmpty;

String? get supabaseConfigurationError {
  if (_resolvedUrl != lunariaSupabaseUrl) {
    return 'La configuración de Supabase no es válida: SUPABASE_URL debe ser '
        'exactamente $lunariaSupabaseUrl.';
  }
  if (_resolvedPublishableKey.isEmpty) {
    return 'Falta la configuración de Supabase. Incluye SUPABASE_URL y '
        'SUPABASE_ANON_KEY en el archivo .env local o pásalas con '
        '--dart-define al compilar la app.';
  }
  return null;
}

bool get canUseLocalDevelopmentMode => !kReleaseMode;

bool get isSupabaseAvailable =>
    isSupabaseConfigured && _initialized && !_disabledForSession;

Future<void> loadSupabaseConfig() {
  return _configLoad ??= _loadSupabaseConfig();
}

Future<void> _loadSupabaseConfig() async {
  if (_configLoaded) return;

  if (kIsWeb) {
    _resolvedUrl = _dartDefineUrl.trim().isEmpty
        ? lunariaSupabaseUrl
        : _dartDefineUrl.trim();
    _resolvedPublishableKey = _dartDefineKey.trim();
    _configLoaded = true;
    return;
  }

  var envUrl = '';
  var envKey = '';
  try {
    if (!dotenv.isInitialized) {
      await dotenv.load(fileName: '.env', isOptional: true);
    }
    envUrl = (dotenv.maybeGet('SUPABASE_URL') ?? '').trim();
    envKey = (dotenv.maybeGet('SUPABASE_ANON_KEY') ?? '').trim();
  } on Object {
    // In tests or environments without bundled assets, fall back to
    // compile-time values without exposing credential details.
  }

  if (envUrl.isNotEmpty || envKey.isNotEmpty) {
    _resolvedUrl = envUrl.isEmpty ? lunariaSupabaseUrl : envUrl;
    _resolvedPublishableKey = envKey;
  } else {
    _resolvedUrl = _dartDefineUrl.trim().isEmpty
        ? lunariaSupabaseUrl
        : _dartDefineUrl.trim();
    _resolvedPublishableKey = _dartDefineKey.trim();
  }

  _configLoaded = true;
}

Future<void> initializeSupabase() async {
  await loadSupabaseConfig();

  final configError = supabaseConfigurationError;
  if (configError != null) {
    _disabledForSession = false;
    if (kReleaseMode) {
      throw StateError(configError);
    }
    return;
  }

  _disabledForSession = false;
  if (_initialized) return Future<void>.value();
  return _initialization ??= _initialize();
}

Future<void> _initialize() async {
  try {
    await Supabase.initialize(
      url: lunariaSupabaseUrl,
      publishableKey: _resolvedPublishableKey,
    );
    _initialized = true;
  } catch (_) {
    _initialization = null;
    rethrow;
  }
}

void useLocalModeForSession() {
  if (kReleaseMode) {
    throw StateError(
      'El modo local no está disponible en compilaciones release. '
      'Configura Supabase antes de usar Lunaria.',
    );
  }
  _disabledForSession = true;
}

SupabaseClient? get supabase =>
    isSupabaseAvailable ? Supabase.instance.client : null;

@visibleForTesting
void resetSupabaseConfigForTest() {
  _resolvedUrl = _dartDefineUrl.trim().isEmpty
      ? lunariaSupabaseUrl
      : _dartDefineUrl.trim();
  _resolvedPublishableKey = _dartDefineKey.trim();
  _configLoaded = false;
  _configLoad = null;
  _initialized = false;
  _disabledForSession = false;
  _initialization = null;
}

@visibleForTesting
void debugSetSupabaseConfigForTest({
  required String url,
  required String publishableKey,
  bool loaded = true,
}) {
  _resolvedUrl = url;
  _resolvedPublishableKey = publishableKey;
  _configLoaded = loaded;
  _configLoad = loaded ? Future<void>.value() : null;
}
