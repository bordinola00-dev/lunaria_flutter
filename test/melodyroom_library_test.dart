// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lunaria_flutter/features/melodyroom/data/library_repository.dart';
import 'package:lunaria_flutter/features/melodyroom/domain/library_models.dart';
import 'package:lunaria_flutter/features/melodyroom/presentation/library_controller.dart';
import 'package:lunaria_flutter/features/melodyroom/presentation/library_providers.dart';
import 'package:lunaria_flutter/features/melodyroom/presentation/melodyroom_screen.dart';

const _spotifyUrl = 'https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC';

void main() {
  test('only valid Spotify track links are accepted', () {
    expect(
      SpotifyTrackLink.parse(_spotifyUrl)?.trackId,
      '4uLU6hMCjMI75M1A2tKUQC',
    );
    expect(
      SpotifyTrackLink.parse(
        'https://open.spotify.com/intl-es/track/4uLU6hMCjMI75M1A2tKUQC?si=abc',
      )?.canonicalUrl,
      _spotifyUrl,
    );
    expect(
      SpotifyTrackLink.parse(
        'https://spotify.com/track/4uLU6hMCjMI75M1A2tKUQC',
      ),
      isNull,
    );
    expect(
      SpotifyTrackLink.parse(
        'https://open.spotify.com/playlist/4uLU6hMCjMI75M1A2tKUQC',
      ),
      isNull,
    );
    expect(SpotifyTrackLink.parse('javascript:alert(1)'), isNull);
  });

  test(
    'songs, favorites, reflections, and playlist membership persist',
    () async {
      final repository = _MemoryLibraryRepository();
      final controller = LibraryController(repository);
      await controller.load();
      await controller.addSong(
        title: 'Canción de prueba',
        artist: 'Artista de prueba',
        spotifyUrl: _spotifyUrl,
        coverUrl: null,
      );
      final song = controller.songs.single;
      await controller.toggleFavorite(song);
      await controller.saveReflection(
        song.id,
        'Me recuerda una tarde tranquila.',
      );
      await controller.createPlaylist(
        name: 'Momentos',
        description: 'Música para mí.',
      );
      final playlist = controller.playlists.single;
      await controller.addSongToPlaylist(playlist.id, song.id);

      final reopened = LibraryController(repository);
      await reopened.load();

      expect(reopened.songs, hasLength(1));
      expect(
        reopened.favorites.single.reflection,
        'Me recuerda una tarde tranquila.',
      );
      expect(reopened.playlists.single.songIds, [song.id]);
    },
  );

  test('duplicate Spotify track links reuse the existing song', () async {
    final repository = _MemoryLibraryRepository();
    final controller = LibraryController(repository);
    await controller.load();

    await controller.addSong(
      title: 'Primera versión',
      artist: 'Artista',
      spotifyUrl: _spotifyUrl,
      coverUrl: null,
    );
    await controller.addSong(
      title: 'Versión editada',
      artist: 'Artista',
      spotifyUrl: _spotifyUrl,
      coverUrl: null,
    );

    expect(repository.songs, hasLength(1));
    expect(controller.songs.single.title, 'Versión editada');
  });

  testWidgets(
    'manual library states that Spotify API connection is unavailable',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryRepositoryProvider.overrideWithValue(
              _MemoryLibraryRepository(),
            ),
          ],
          child: const MaterialApp(home: MelodyRoomScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'La conexión directa con Spotify todavía no está disponible. '
          'Puedes guardar canciones manualmente con su enlace oficial.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

class _MemoryLibraryRepository implements LibraryRepository {
  final List<MelodySong> songs = [];
  final List<MelodyPlaylist> playlists = [];
  int _nextId = 0;

  @override
  Future<List<MelodySong>> fetchSongs() async => List.of(songs);

  @override
  Future<List<MelodyPlaylist>> fetchPlaylists() async => List.of(playlists);

  @override
  Future<MelodySong> addSong({
    required String title,
    required String artist,
    required String spotifyUrl,
    required String? coverUrl,
  }) async {
    final link = SpotifyTrackLink.parse(spotifyUrl)!;
    final existingIndex = songs.indexWhere(
      (song) => song.spotifyTrackId == link.trackId,
    );
    if (existingIndex >= 0) {
      final old = songs[existingIndex];
      final updated = _copySong(
        old,
        title: title,
        artist: artist,
        spotifyUrl: link.canonicalUrl,
        coverUrl: coverUrl,
      );
      songs[existingIndex] = updated;
      return updated;
    }

    final song = MelodySong(
      id: 'song-${_nextId++}',
      spotifyTrackId: link.trackId,
      title: title,
      artist: artist,
      spotifyUrl: link.canonicalUrl,
      coverUrl: coverUrl,
      isFavorite: false,
      reflection: '',
      createdAt: DateTime.now(),
    );
    songs.add(song);
    return song;
  }

  @override
  Future<MelodySong> updateSong({
    required MelodySong song,
    required String title,
    required String artist,
    required String spotifyUrl,
    required String? coverUrl,
  }) async {
    final link = SpotifyTrackLink.parse(spotifyUrl)!;
    final updated = _copySong(
      song,
      title: title,
      artist: artist,
      spotifyUrl: link.canonicalUrl,
      coverUrl: coverUrl,
      trackId: link.trackId,
    );
    songs[songs.indexWhere((item) => item.id == song.id)] = updated;
    return updated;
  }

  @override
  Future<void> deleteSong(String songId) async {
    songs.removeWhere((song) => song.id == songId);
    for (var index = 0; index < playlists.length; index++) {
      final playlist = playlists[index];
      playlists[index] = MelodyPlaylist(
        id: playlist.id,
        name: playlist.name,
        description: playlist.description,
        songIds: playlist.songIds.where((id) => id != songId).toList(),
        createdAt: playlist.createdAt,
      );
    }
  }

  @override
  Future<void> setFavorite(String songId, bool value) async {
    _updateSong(songId, (song) => _copySong(song, isFavorite: value));
  }

  @override
  Future<void> setReflection(String songId, String reflection) async {
    _updateSong(songId, (song) => _copySong(song, reflection: reflection));
  }

  @override
  Future<MelodyPlaylist> createPlaylist({
    required String name,
    required String description,
  }) async {
    final playlist = MelodyPlaylist(
      id: 'playlist-${_nextId++}',
      name: name,
      description: description,
      songIds: const [],
      createdAt: DateTime.now(),
    );
    playlists.add(playlist);
    return playlist;
  }

  @override
  Future<void> updatePlaylist({
    required String playlistId,
    required String name,
    required String description,
  }) async {
    final old = playlists.firstWhere((item) => item.id == playlistId);
    final index = playlists.indexOf(old);
    playlists[index] = MelodyPlaylist(
      id: old.id,
      name: name,
      description: description,
      songIds: old.songIds,
      createdAt: old.createdAt,
    );
  }

  @override
  Future<void> deletePlaylist(String playlistId) async {
    playlists.removeWhere((item) => item.id == playlistId);
  }

  @override
  Future<void> addSongToPlaylist(String playlistId, String songId) async {
    final old = playlists.firstWhere((item) => item.id == playlistId);
    if (old.songIds.contains(songId)) return;
    _replacePlaylist(old, [...old.songIds, songId]);
  }

  @override
  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final old = playlists.firstWhere((item) => item.id == playlistId);
    _replacePlaylist(old, old.songIds.where((id) => id != songId).toList());
  }

  void _updateSong(String id, MelodySong Function(MelodySong) update) {
    final index = songs.indexWhere((song) => song.id == id);
    songs[index] = update(songs[index]);
  }

  void _replacePlaylist(MelodyPlaylist old, List<String> songIds) {
    final index = playlists.indexOf(old);
    playlists[index] = MelodyPlaylist(
      id: old.id,
      name: old.name,
      description: old.description,
      songIds: songIds,
      createdAt: old.createdAt,
    );
  }

  MelodySong _copySong(
    MelodySong song, {
    String? trackId,
    String? title,
    String? artist,
    String? spotifyUrl,
    String? coverUrl,
    bool? isFavorite,
    String? reflection,
  }) => MelodySong(
    id: song.id,
    spotifyTrackId: trackId ?? song.spotifyTrackId,
    title: title ?? song.title,
    artist: artist ?? song.artist,
    spotifyUrl: spotifyUrl ?? song.spotifyUrl,
    coverUrl: coverUrl ?? song.coverUrl,
    isFavorite: isFavorite ?? song.isFavorite,
    reflection: reflection ?? song.reflection,
    createdAt: song.createdAt,
  );
}
