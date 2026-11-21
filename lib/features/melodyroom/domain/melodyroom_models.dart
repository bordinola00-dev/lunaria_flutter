class SpotifyTrack {
  const SpotifyTrack({
    required this.id,
    required this.title,
    required this.artists,
    required this.album,
    required this.artworkUrl,
    required this.spotifyUrl,
  });

  final String id;
  final String title;
  final String artists;
  final String album;
  final String? artworkUrl;
  final String? spotifyUrl;
}

class SpotifyPlaylist {
  const SpotifyPlaylist({
    required this.id,
    required this.name,
    required this.description,
    required this.artworkUrl,
    required this.spotifyUrl,
    required this.trackCount,
  });

  final String id;
  final String name;
  final String description;
  final String? artworkUrl;
  final String? spotifyUrl;
  final int trackCount;
}

class MelodyFavorite {
  const MelodyFavorite({
    required this.id,
    required this.spotifyTrackId,
    required this.reflection,
    required this.createdAt,
  });

  final String id;
  final String spotifyTrackId;
  final String reflection;
  final DateTime createdAt;
}

class SpotifyPage<T> {
  const SpotifyPage({
    required this.items,
    required this.total,
    required this.nextOffset,
  });

  final List<T> items;
  final int total;
  final int nextOffset;

  bool get hasMore => nextOffset < total;
}
