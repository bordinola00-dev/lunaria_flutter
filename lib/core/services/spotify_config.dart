import 'package:flutter/foundation.dart';

const spotifyClientId = String.fromEnvironment('SPOTIFY_CLIENT_ID');
const _spotifyRedirectUri = String.fromEnvironment('SPOTIFY_REDIRECT_URI');

const spotifyCallbackScheme = 'lunaria-spotify';
const spotifyScopes = [
  'user-library-read',
  'playlist-read-private',
  'playlist-read-collaborative',
];

String get spotifyRedirectUri {
  if (_spotifyRedirectUri.trim().isNotEmpty) {
    return _spotifyRedirectUri.trim();
  }
  return kIsWeb
      ? Uri.base.resolve('/auth.html').toString()
      : 'lunaria-spotify://callback';
}

bool get isSpotifyConfigured {
  final uri = Uri.tryParse(spotifyRedirectUri);
  if (spotifyClientId.trim().isEmpty || uri == null) return false;

  if (kIsWeb) {
    final isSecureRedirect = uri.scheme == 'https';
    final isLocalDevelopmentRedirect =
        uri.scheme == 'http' &&
        (uri.host == 'localhost' || uri.host == '127.0.0.1');
    return uri.hasAuthority &&
        uri.host.isNotEmpty &&
        uri.path == '/auth.html' &&
        (isSecureRedirect || isLocalDevelopmentRedirect);
  }

  return uri.scheme == spotifyCallbackScheme && uri.host.isNotEmpty;
}
