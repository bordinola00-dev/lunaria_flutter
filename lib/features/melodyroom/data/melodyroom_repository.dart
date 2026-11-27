import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/spotify_config.dart';
import '../../../core/services/supabase_config.dart';
import '../domain/melodyroom_models.dart';

abstract interface class MelodyRoomRepository {
  bool get spotifyConfigured;
  bool get isLunariaAuthenticated;
  Future<bool> isSpotifyConnected();
  Future<void> connectSpotify();
  Future<void> disconnectSpotify();
  Future<List<MelodyFavorite>> fetchFavorites();
  Future<SpotifyPage<SpotifyTrack>> fetchSavedTracks({required int offset});
  Future<SpotifyPage<SpotifyPlaylist>> fetchPlaylists({required int offset});
  Future<SpotifyPage<SpotifyTrack>> fetchPlaylistTracks({
    required String playlistId,
    required int offset,
  });
  Future<void> addFavorite(String spotifyTrackId);
  Future<void> updateReflection({
    required String spotifyTrackId,
    required String reflection,
  });
  Future<void> removeFavorite(String spotifyTrackId);
}

class SupabaseMelodyRoomRepository implements MelodyRoomRepository {
  SupabaseMelodyRoomRepository();

  static const _tokenStorage = FlutterSecureStorage();
  static const _favoritesTable = 'songs';
  static const _pageSize = 50;

  SupabaseClient get _client {
    final client = supabase;
    if (client == null) {
      throw StateError(
        'Supabase no está configurado. Configura SUPABASE_URL y '
        'SUPABASE_ANON_KEY para guardar tus favoritos.',
      );
    }
    return client;
  }

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError(
        'Inicia sesión con tu cuenta de Lunaria para sincronizar MelodyRoom.',
      );
    }
    return id;
  }

  @override
  bool get spotifyConfigured => isSpotifyConfigured;

  @override
  bool get isLunariaAuthenticated => supabase?.auth.currentUser != null;

  @override
  Future<bool> isSpotifyConnected() async {
    final userId = _userId;
    final tokens = await _readTokens(userId);
    return tokens != null &&
        (tokens.accessToken != null || tokens.refreshToken != null);
  }

  @override
  Future<void> connectSpotify() async {
    if (!spotifyConfigured) {
      throw const MelodyRoomException(
        'Falta SPOTIFY_CLIENT_ID o la URI de retorno no coincide con '
        'la configuración de esta plataforma.',
      );
    }
    final userId = _userId;
    final verifier = _randomUrlSafe(64);
    final state = _randomUrlSafe(32);
    final challenge = base64Url
        .encode(sha256.convert(utf8.encode(verifier)).bytes)
        .replaceAll('=', '');
    final authorizeUri = Uri.https('accounts.spotify.com', '/authorize', {
      'client_id': spotifyClientId,
      'response_type': 'code',
      'redirect_uri': spotifyRedirectUri,
      'scope': spotifyScopes.join(' '),
      'state': state,
      'code_challenge_method': 'S256',
      'code_challenge': challenge,
    });

    late final String callback;
    try {
      callback = await FlutterWebAuth2.authenticate(
        url: authorizeUri.toString(),
        callbackUrlScheme: spotifyCallbackScheme,
      );
    } on PlatformException catch (error) {
      throw MelodyRoomException(
        'Spotify no completó la autorización: '
        '${error.message ?? error.code}.',
      );
    }

    final callbackUri = Uri.tryParse(callback);
    if (callbackUri == null || callbackUri.queryParameters['state'] != state) {
      throw const MelodyRoomException(
        'La respuesta OAuth de Spotify no coincide con la solicitud. '
        'Inténtalo de nuevo.',
      );
    }
    final oauthError = callbackUri.queryParameters['error'];
    if (oauthError != null) {
      throw MelodyRoomException(
        oauthError == 'access_denied'
            ? 'Se canceló el permiso de Spotify.'
            : 'Spotify rechazó la autorización ($oauthError).',
      );
    }
    final code = callbackUri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw const MelodyRoomException(
        'Spotify no devolvió el código de autorización.',
      );
    }

    final response = await http
        .post(
          Uri.https('accounts.spotify.com', '/api/token'),
          headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'client_id': spotifyClientId,
            'grant_type': 'authorization_code',
            'code': code,
            'redirect_uri': spotifyRedirectUri,
            'code_verifier': verifier,
          },
        )
        .timeout(const Duration(seconds: 20));
    final tokenJson = _readTokenResponse(response);
    final tokens = _SpotifyTokens.fromJson(tokenJson);
    final grantedScopes = (tokens.scope ?? '').split(' ').toSet();
    final missingScopes = spotifyScopes
        .where((scope) => !grantedScopes.contains(scope))
        .toList();
    if (missingScopes.isNotEmpty) {
      throw MelodyRoomException(
        'Spotify no concedió todos los permisos necesarios: '
        '${missingScopes.join(', ')}. Vuelve a conectar y acepta los permisos.',
      );
    }
    await _writeTokens(userId, tokens);
  }

  @override
  Future<void> disconnectSpotify() async {
    final userId = _userId;
    await _client
        .from(_favoritesTable)
        .delete()
        .eq('user_id', userId)
        .not('spotify_track_id', 'is', null);
    await _deleteTokens(userId);
  }

  @override
  Future<List<MelodyFavorite>> fetchFavorites() async {
    final userId = _userId;
    final rows = await _client
        .from(_favoritesTable)
        .select('id, spotify_track_id, reflection, created_at')
        .eq('user_id', userId)
        .not('spotify_track_id', 'is', null)
        .order('created_at', ascending: false);
    return rows
        .map(
          (row) => MelodyFavorite(
            id: row['id'] as String,
            spotifyTrackId: row['spotify_track_id'] as String,
            reflection: row['reflection'] as String? ?? '',
            createdAt: DateTime.parse(row['created_at'] as String),
          ),
        )
        .toList();
  }

  @override
  Future<SpotifyPage<SpotifyTrack>> fetchSavedTracks({
    required int offset,
  }) async {
    final json = await _apiGet(
      '/me/tracks',
      query: {'limit': '$_pageSize', 'offset': '$offset'},
    );
    final rawItems = _items(json);
    final tracks = <SpotifyTrack>[];
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final trackJson = raw['track'];
      if (trackJson is Map) {
        final track = _trackFromJson(Map<String, dynamic>.from(trackJson));
        if (track != null) tracks.add(track);
      }
    }
    return SpotifyPage(
      items: tracks,
      total: _integer(json['total']),
      nextOffset: offset + rawItems.length,
    );
  }

  @override
  Future<SpotifyPage<SpotifyPlaylist>> fetchPlaylists({
    required int offset,
  }) async {
    final json = await _apiGet(
      '/me/playlists',
      query: {'limit': '$_pageSize', 'offset': '$offset'},
    );
    final rawItems = _items(json);
    final playlists = <SpotifyPlaylist>[];
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final id = item['id'];
      final name = item['name'];
      if (id is! String || id.isEmpty || name is! String || name.isEmpty) {
        continue;
      }
      playlists.add(
        SpotifyPlaylist(
          id: id,
          name: name,
          description: item['description'] as String? ?? '',
          artworkUrl: _firstImageUrl(item['images']),
          spotifyUrl: _spotifyUrl(item['external_urls']),
          trackCount: _playlistTrackCount(item),
        ),
      );
    }
    return SpotifyPage(
      items: playlists,
      total: _integer(json['total']),
      nextOffset: offset + rawItems.length,
    );
  }

  @override
  Future<SpotifyPage<SpotifyTrack>> fetchPlaylistTracks({
    required String playlistId,
    required int offset,
  }) async {
    final json = await _apiGet(
      '/playlists/$playlistId/items',
      query: {'limit': '$_pageSize', 'offset': '$offset'},
    );
    final rawItems = _items(json);
    final tracks = <SpotifyTrack>[];
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final trackJson = item['item'] ?? item['track'];
      if (trackJson is Map) {
        final track = _trackFromJson(Map<String, dynamic>.from(trackJson));
        if (track != null) tracks.add(track);
      }
    }
    return SpotifyPage(
      items: tracks,
      total: _integer(json['total']),
      nextOffset: offset + rawItems.length,
    );
  }

  @override
  Future<void> addFavorite(String spotifyTrackId) async {
    final userId = _userId;
    try {
      await _client.from(_favoritesTable).insert({
        'user_id': userId,
        'spotify_track_id': spotifyTrackId,
        'reflection': '',
      });
    } on PostgrestException catch (error) {
      if (error.code == '23505') return;
      rethrow;
    }
  }

  @override
  Future<void> updateReflection({
    required String spotifyTrackId,
    required String reflection,
  }) async {
    final row = await _client
        .from(_favoritesTable)
        .update({'reflection': reflection})
        .eq('user_id', _userId)
        .eq('spotify_track_id', spotifyTrackId)
        .select('id')
        .maybeSingle();
    if (row == null) {
      throw const MelodyRoomException(
        'La canción ya no está en tus favoritas. Actualiza la pantalla.',
      );
    }
  }

  @override
  Future<void> removeFavorite(String spotifyTrackId) async {
    final row = await _client
        .from(_favoritesTable)
        .delete()
        .eq('user_id', _userId)
        .eq('spotify_track_id', spotifyTrackId)
        .select('id')
        .maybeSingle();
    if (row == null) {
      throw const MelodyRoomException(
        'La canción ya no está en tus favoritas. Actualiza la pantalla.',
      );
    }
  }

  Future<Map<String, dynamic>> _apiGet(
    String path, {
    Map<String, String> query = const {},
  }) async {
    final userId = _userId;
    var accessToken = await _validAccessToken(userId);
    var response = await _getSpotify(path, query, accessToken);
    if (response.statusCode == 401) {
      accessToken = await _refreshAccessToken(userId);
      response = await _getSpotify(path, query, accessToken);
      if (response.statusCode == 401) {
        await _deleteTokens(userId);
        throw const SpotifyReauthorizationRequired(
          'Spotify rechazó la sesión renovada. Vuelve a conectar tu cuenta.',
        );
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _apiException(response);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const MelodyRoomException(
        'Spotify devolvió una respuesta con formato inesperado.',
      );
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<http.Response> _getSpotify(
    String path,
    Map<String, String> query,
    String accessToken,
  ) {
    final uri = Uri.https('api.spotify.com', '/v1$path', query);
    return http
        .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
        .timeout(const Duration(seconds: 20));
  }

  Future<String> _validAccessToken(String userId) async {
    final tokens = await _readTokens(userId);
    if (tokens == null) {
      throw const MelodyRoomException(
        'Conecta tu cuenta de Spotify para cargar esta información.',
      );
    }
    if (tokens.accessToken != null &&
        tokens.expiresAt != null &&
        tokens.expiresAt!.isAfter(
          DateTime.now().add(const Duration(seconds: 45)),
        )) {
      return tokens.accessToken!;
    }
    return _refreshAccessToken(userId, existing: tokens);
  }

  Future<String> _refreshAccessToken(
    String userId, {
    _SpotifyTokens? existing,
  }) async {
    final tokens = existing ?? await _readTokens(userId);
    final refreshToken = tokens?.refreshToken;
    if (tokens == null || refreshToken == null || refreshToken.isEmpty) {
      await _deleteTokens(userId);
      throw const SpotifyReauthorizationRequired(
        'La sesión de Spotify expiró. Vuelve a conectar tu cuenta.',
      );
    }
    final response = await http
        .post(
          Uri.https('accounts.spotify.com', '/api/token'),
          headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'client_id': spotifyClientId,
            'grant_type': 'refresh_token',
            'refresh_token': refreshToken,
          },
        )
        .timeout(const Duration(seconds: 20));
    final body = _decodeResponse(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (body['error'] == 'invalid_grant') {
        await _deleteTokens(userId);
        throw const SpotifyReauthorizationRequired(
          'Spotify revocó o venció la autorización. Vuelve a conectar tu cuenta.',
        );
      }
      throw _tokenException(response.statusCode, body);
    }
    final refreshed = _SpotifyTokens.fromJson(
      body,
      fallbackRefreshToken: refreshToken,
      fallbackScope: tokens.scope,
    );
    await _writeTokens(userId, refreshed);
    final accessToken = refreshed.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const MelodyRoomException(
        'Spotify no devolvió un token válido. Vuelve a conectar tu cuenta.',
      );
    }
    return accessToken;
  }

  Future<_SpotifyTokens?> _readTokens(String userId) async {
    final prefix = _keyPrefix(userId);
    final accessToken = await _tokenStorage.read(key: '${prefix}access');
    final refreshToken = await _tokenStorage.read(key: '${prefix}refresh');
    if (accessToken == null && refreshToken == null) return null;
    final expiry = await _tokenStorage.read(key: '${prefix}expires');
    final scope = await _tokenStorage.read(key: '${prefix}scope');
    return _SpotifyTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiry == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(int.parse(expiry)),
      scope: scope,
    );
  }

  Future<void> _writeTokens(String userId, _SpotifyTokens tokens) async {
    final prefix = _keyPrefix(userId);
    final accessToken = tokens.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const MelodyRoomException(
        'Spotify no devolvió un token de acceso válido.',
      );
    }
    await _tokenStorage.write(key: '${prefix}access', value: accessToken);
    final refreshToken = tokens.refreshToken;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _tokenStorage.write(key: '${prefix}refresh', value: refreshToken);
    }
    final expiresAt = tokens.expiresAt;
    if (expiresAt != null) {
      await _tokenStorage.write(
        key: '${prefix}expires',
        value: '${expiresAt.millisecondsSinceEpoch}',
      );
    }
    final scope = tokens.scope;
    if (scope != null && scope.isNotEmpty) {
      await _tokenStorage.write(key: '${prefix}scope', value: scope);
    }
  }

  Future<void> _deleteTokens(String userId) async {
    final prefix = _keyPrefix(userId);
    await Future.wait([
      _tokenStorage.delete(key: '${prefix}access'),
      _tokenStorage.delete(key: '${prefix}refresh'),
      _tokenStorage.delete(key: '${prefix}expires'),
      _tokenStorage.delete(key: '${prefix}scope'),
    ]);
  }

  String _keyPrefix(String userId) => 'lunaria.spotify.$userId.';

  MelodyRoomException _apiException(http.Response response) {
    final body = _decodeResponse(response.body);
    final message =
        (body['error'] is Map
                ? (body['error'] as Map)['message']
                : body['error_description'] ?? body['error'] ?? body['message'])
            ?.toString();
    return switch (response.statusCode) {
      401 => const MelodyRoomException(
        'Spotify rechazó la sesión. Vuelve a conectar tu cuenta.',
      ),
      403 => MelodyRoomException(
        'Spotify denegó el acceso${message == null ? '' : ': $message'}. '
        'Revisa los permisos y la lista de usuarios autorizados de tu app.',
      ),
      429 => const MelodyRoomException(
        'Spotify limitó temporalmente las solicitudes. Espera un momento y vuelve a intentar.',
      ),
      _ => MelodyRoomException(
        'Spotify respondió ${response.statusCode}'
        '${message == null ? '.' : ': $message'}',
      ),
    };
  }

  MelodyRoomException _tokenException(
    int statusCode,
    Map<String, dynamic> body,
  ) {
    final error = body['error']?.toString() ?? 'error desconocido';
    final description = body['error_description']?.toString();
    return MelodyRoomException(
      'No se pudieron renovar los permisos de Spotify ($statusCode): '
      '$error${description == null ? '' : ' — $description'}',
    );
  }

  Map<String, dynamic> _readTokenResponse(http.Response response) {
    final body = _decodeResponse(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _tokenException(response.statusCode, body);
    }
    return body;
  }

  Map<String, dynamic> _decodeResponse(String body) {
    final decoded = jsonDecode(body);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : const {};
  }

  List<dynamic> _items(Map<String, dynamic> json) =>
      json['items'] as List<dynamic>? ?? const [];

  int _integer(Object? value) => value is int ? value : 0;

  int _playlistTrackCount(Map<String, dynamic> json) {
    final items = json['items'] ?? json['tracks'];
    if (items is Map) return _integer(items['total']);
    return 0;
  }

  SpotifyTrack? _trackFromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['name'];
    if (id is! String ||
        id.isEmpty ||
        title is! String ||
        title.isEmpty ||
        json['type'] == 'episode' ||
        json['is_local'] == true) {
      return null;
    }
    final artistsJson = json['artists'];
    final artists = artistsJson is List
        ? artistsJson
              .whereType<Map>()
              .map((artist) => artist['name'])
              .whereType<String>()
              .where((name) => name.isNotEmpty)
              .join(', ')
        : '';
    final album = json['album'];
    return SpotifyTrack(
      id: id,
      title: title,
      artists: artists,
      album: album is Map ? album['name'] as String? ?? '' : '',
      artworkUrl: album is Map ? _firstImageUrl(album['images']) : null,
      spotifyUrl: _spotifyUrl(json['external_urls']),
    );
  }

  String? _firstImageUrl(Object? rawImages) {
    if (rawImages is! List) return null;
    for (final image in rawImages) {
      if (image is Map && image['url'] is String) return image['url'] as String;
    }
    return null;
  }

  String? _spotifyUrl(Object? rawUrls) {
    if (rawUrls is Map && rawUrls['spotify'] is String) {
      return rawUrls['spotify'] as String;
    }
    return null;
  }

  String _randomUrlSafe(int byteCount) {
    final random = Random.secure();
    final bytes = List<int>.generate(byteCount, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}

class MelodyRoomException implements Exception {
  const MelodyRoomException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SpotifyReauthorizationRequired extends MelodyRoomException {
  const SpotifyReauthorizationRequired(super.message);
}

class _SpotifyTokens {
  const _SpotifyTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.scope,
  });

  final String? accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  final String? scope;

  factory _SpotifyTokens.fromJson(
    Map<String, dynamic> json, {
    String? fallbackRefreshToken,
    String? fallbackScope,
  }) {
    final expiresIn = json['expires_in'];
    return _SpotifyTokens(
      accessToken: json['access_token'] as String?,
      refreshToken: json['refresh_token'] as String? ?? fallbackRefreshToken,
      expiresAt: expiresIn is num
          ? DateTime.now().add(Duration(seconds: expiresIn.toInt()))
          : null,
      scope: json['scope'] as String? ?? fallbackScope,
    );
  }
}
