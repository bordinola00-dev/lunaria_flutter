import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_config.dart';
import '../domain/library_models.dart';

abstract interface class LibraryRepository {
  Future<List<MelodySong>> fetchSongs();
  Future<List<MelodyPlaylist>> fetchPlaylists();
  Future<MelodySong> addSong({
    required String title,
    required String artist,
    required String spotifyUrl,
    required String? coverUrl,
  });
  Future<MelodySong> updateSong({
    required MelodySong song,
    required String title,
    required String artist,
    required String spotifyUrl,
    required String? coverUrl,
  });
  Future<void> deleteSong(String songId);
  Future<void> setFavorite(String songId, bool value);
  Future<void> setReflection(String songId, String reflection);
  Future<MelodyPlaylist> createPlaylist({
    required String name,
    required String description,
  });
  Future<void> updatePlaylist({
    required String playlistId,
    required String name,
    required String description,
  });
  Future<void> deletePlaylist(String playlistId);
  Future<void> addSongToPlaylist(String playlistId, String songId);
  Future<void> removeSongFromPlaylist(String playlistId, String songId);
}

class SupabaseLibraryRepository implements LibraryRepository {
  SupabaseLibraryRepository();

  static const _songColumns =
      'id, user_id, spotify_track_id, title, artist, url, cover_url, '
      'is_favorite, reflection, created_at';

  SupabaseClient get _client {
    final client = supabase;
    if (client == null) {
      throw StateError(
        'La biblioteca necesita una conexión activa con Supabase.',
      );
    }
    return client;
  }

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Inicia sesión en Lunaria para sincronizar tu música.');
    }
    return id;
  }

  @override
  Future<List<MelodySong>> fetchSongs() async {
    final rows = await _client
        .from('songs')
        .select(_songColumns)
        .eq('user_id', _userId)
        .order('created_at', ascending: false);
    return rows
        .map((row) => MelodySong.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  @override
  Future<List<MelodyPlaylist>> fetchPlaylists() async {
    final userId = _userId;
    final rows = await _client
        .from('playlists')
        .select('id, name, description, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    if (rows.isEmpty) return const [];

    final ids = rows.map((row) => row['id'] as String).toList();
    final links = await _client
        .from('playlist_songs')
        .select('playlist_id, song_id')
        .eq('user_id', userId)
        .inFilter('playlist_id', ids);
    final songsByPlaylist = <String, List<String>>{};
    for (final link in links) {
      songsByPlaylist
          .putIfAbsent(link['playlist_id'] as String, () => [])
          .add(link['song_id'] as String);
    }
    return rows.map((row) {
      final id = row['id'] as String;
      return MelodyPlaylist(
        id: id,
        name: row['name'] as String,
        description: row['description'] as String? ?? '',
        songIds: List.unmodifiable(songsByPlaylist[id] ?? const []),
        createdAt: DateTime.parse(row['created_at'] as String),
      );
    }).toList();
  }

  @override
  Future<MelodySong> addSong({
    required String title,
    required String artist,
    required String spotifyUrl,
    required String? coverUrl,
  }) async {
    final userId = _userId;
    final link = SpotifyTrackLink.parse(spotifyUrl);
    if (link == null) {
      throw ArgumentError('Agrega un enlace válido a una canción de Spotify.');
    }
    final data = {
      'user_id': userId,
      'spotify_track_id': link.trackId,
      'title': title.trim(),
      'artist': artist.trim(),
      'url': link.canonicalUrl,
      'cover_url': coverUrl?.trim().isEmpty == true ? null : coverUrl?.trim(),
      'library_source': 'manual',
    };

    try {
      final row = await _client
          .from('songs')
          .insert(data)
          .select(_songColumns)
          .single();
      return MelodySong.fromJson(row);
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
      final existing = await _client
          .from('songs')
          .select(_songColumns)
          .eq('user_id', userId)
          .eq('spotify_track_id', link.trackId)
          .maybeSingle();
      if (existing == null) rethrow;
      final updated = await _client
          .from('songs')
          .update({
            'title': data['title'],
            'artist': data['artist'],
            'url': data['url'],
            'cover_url': data['cover_url'],
            'library_source': 'manual',
          })
          .eq('id', existing['id'] as String)
          .eq('user_id', userId)
          .select(_songColumns)
          .single();
      return MelodySong.fromJson(updated);
    }
  }

  @override
  Future<MelodySong> updateSong({
    required MelodySong song,
    required String title,
    required String artist,
    required String spotifyUrl,
    required String? coverUrl,
  }) async {
    final link = SpotifyTrackLink.parse(spotifyUrl);
    if (link == null) {
      throw ArgumentError('Agrega un enlace válido a una canción de Spotify.');
    }
    final row = await _client
        .from('songs')
        .update({
          'spotify_track_id': link.trackId,
          'title': title.trim(),
          'artist': artist.trim(),
          'url': link.canonicalUrl,
          'cover_url': coverUrl?.trim().isEmpty == true ? null : coverUrl?.trim(),
          'library_source': 'manual',
        })
        .eq('id', song.id)
        .eq('user_id', _userId)
        .select(_songColumns)
        .single();
    return MelodySong.fromJson(row);
  }

  @override
  Future<void> deleteSong(String songId) async {
    await _client
        .from('songs')
        .delete()
        .eq('id', songId)
        .eq('user_id', _userId);
  }

  @override
  Future<void> setFavorite(String songId, bool value) async {
    await _client
        .from('songs')
        .update({'is_favorite': value})
        .eq('id', songId)
        .eq('user_id', _userId)
        .select('id')
        .single();
  }

  @override
  Future<void> setReflection(String songId, String reflection) async {
    await _client
        .from('songs')
        .update({'reflection': reflection.trim()})
        .eq('id', songId)
        .eq('user_id', _userId)
        .select('id')
        .single();
  }

  @override
  Future<MelodyPlaylist> createPlaylist({
    required String name,
    required String description,
  }) async {
    final row = await _client
        .from('playlists')
        .insert({
          'user_id': _userId,
          'name': name.trim(),
          'description': description.trim(),
          'url': '',
        })
        .select('id, name, description, created_at')
        .single();
    return MelodyPlaylist(
      id: row['id'] as String,
      name: row['name'] as String,
      description: row['description'] as String? ?? '',
      songIds: const [],
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  @override
  Future<void> updatePlaylist({
    required String playlistId,
    required String name,
    required String description,
  }) async {
    await _client
        .from('playlists')
        .update({'name': name.trim(), 'description': description.trim()})
        .eq('id', playlistId)
        .eq('user_id', _userId)
        .select('id')
        .single();
  }

  @override
  Future<void> deletePlaylist(String playlistId) async {
    await _client
        .from('playlists')
        .delete()
        .eq('id', playlistId)
        .eq('user_id', _userId);
  }

  @override
  Future<void> addSongToPlaylist(String playlistId, String songId) async {
    await _client.from('playlist_songs').upsert(
      {
        'playlist_id': playlistId,
        'song_id': songId,
        'user_id': _userId,
      },
      onConflict: 'playlist_id,song_id',
      ignoreDuplicates: true,
    );
  }

  @override
  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    await _client
        .from('playlist_songs')
        .delete()
        .eq('playlist_id', playlistId)
        .eq('song_id', songId)
        .eq('user_id', _userId);
  }
}
