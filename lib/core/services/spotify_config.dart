const spotifyClientId = String.fromEnvironment('SPOTIFY_CLIENT_ID');
const spotifyRedirectUri = String.fromEnvironment(
  'SPOTIFY_REDIRECT_URI',
  defaultValue: 'lunaria-spotify://callback',
);

const spotifyCallbackScheme = 'lunaria-spotify';
const spotifyScopes = [
  'user-library-read',
  'playlist-read-private',
  'playlist-read-collaborative',
];

bool get isSpotifyConfigured {
  final uri = Uri.tryParse(spotifyRedirectUri);
  return spotifyClientId.trim().isNotEmpty &&
      uri != null &&
      uri.scheme == spotifyCallbackScheme &&
      uri.host.isNotEmpty;
}
