class MelodySong {
  const MelodySong({
    required this.id,
    required this.spotifyTrackId,
    required this.title,
    required this.artist,
    required this.spotifyUrl,
    required this.coverUrl,
    required this.isFavorite,
    required this.reflection,
    required this.createdAt,
  });

  final String id;
  final String? spotifyTrackId;
  final String? title;
  final String? artist;
  final String? spotifyUrl;
  final String? coverUrl;
  final bool isFavorite;
  final String reflection;
  final DateTime createdAt;

  bool get hasManualDetails =>
      (title?.trim().isNotEmpty ?? false) &&
      (artist?.trim().isNotEmpty ?? false) &&
      (spotifyUrl?.trim().isNotEmpty ?? false);

  factory MelodySong.fromJson(Map<String, dynamic> json) => MelodySong(
    id: json['id'] as String,
    spotifyTrackId: json['spotify_track_id'] as String?,
    title: json['title'] as String?,
    artist: json['artist'] as String?,
    spotifyUrl: json['url'] as String?,
    coverUrl: json['cover_url'] as String?,
    isFavorite: json['is_favorite'] as bool? ?? false,
    reflection: json['reflection'] as String? ?? '',
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

class MelodyPlaylist {
  const MelodyPlaylist({
    required this.id,
    required this.name,
    required this.description,
    required this.songIds,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String description;
  final List<String> songIds;
  final DateTime createdAt;
}

class SpotifyTrackLink {
  const SpotifyTrackLink({required this.trackId, required this.canonicalUrl});

  final String trackId;
  final String canonicalUrl;

  static SpotifyTrackLink? parse(String value) {
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;

    String? trackId;
    if (trimmed.startsWith('spotify:track:')) {
      trackId = trimmed.substring('spotify:track:'.length);
    } else if (uri.scheme == 'https' && uri.host == 'open.spotify.com') {
      final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
      final path = segments.toList(growable: false);
      if (path.length == 2 && path[0] == 'track') {
        trackId = path[1];
      } else if (path.length == 3 &&
          RegExp(r'^intl-[a-z]{2}$').hasMatch(path[0]) &&
          path[1] == 'track') {
        trackId = path[2];
      }
    }

    if (trackId == null || !RegExp(r'^[A-Za-z0-9]{22}$').hasMatch(trackId)) {
      return null;
    }
    return SpotifyTrackLink(
      trackId: trackId,
      canonicalUrl: 'https://open.spotify.com/track/$trackId',
    );
  }
}

bool isValidCoverUrl(String value) {
  if (value.trim().isEmpty) return true;
  final uri = Uri.tryParse(value.trim());
  return uri != null &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      (uri.host.isNotEmpty);
}
