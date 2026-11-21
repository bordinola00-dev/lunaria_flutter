import 'package:flutter/foundation.dart';

import '../data/library_repository.dart';
import '../domain/library_models.dart';

class LibraryController extends ChangeNotifier {
  LibraryController(this._repository);

  final LibraryRepository _repository;

  List<MelodySong> songs = const [];
  List<MelodyPlaylist> playlists = const [];
  bool isLoading = true;
  bool isSaving = false;
  String? error;

  List<MelodySong> get favorites =>
      songs.where((song) => song.isFavorite).toList(growable: false);

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _reload();
    } catch (exception) {
      error = 'No se pudo cargar MelodyRoom: $exception';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await load();
  }

  Future<void> addSong({
    required String title,
    required String artist,
    required String spotifyUrl,
    required String? coverUrl,
  }) async {
    await _mutate(() async {
      await _repository.addSong(
        title: title,
        artist: artist,
        spotifyUrl: spotifyUrl,
        coverUrl: coverUrl,
      );
      await _reload();
    });
  }

  Future<void> updateSong({
    required MelodySong song,
    required String title,
    required String artist,
    required String spotifyUrl,
    required String? coverUrl,
  }) async {
    await _mutate(() async {
      await _repository.updateSong(
        song: song,
        title: title,
        artist: artist,
        spotifyUrl: spotifyUrl,
        coverUrl: coverUrl,
      );
      await _reload();
    });
  }

  Future<void> deleteSong(String songId) async {
    await _mutate(() async {
      await _repository.deleteSong(songId);
      await _reload();
    });
  }

  Future<void> toggleFavorite(MelodySong song) async {
    await _mutate(() async {
      await _repository.setFavorite(song.id, !song.isFavorite);
      await _reload();
    });
  }

  Future<void> saveReflection(String songId, String reflection) async {
    await _mutate(() async {
      await _repository.setReflection(songId, reflection);
      await _reload();
    });
  }

  Future<void> createPlaylist({
    required String name,
    required String description,
  }) async {
    await _mutate(() async {
      await _repository.createPlaylist(name: name, description: description);
      await _reload();
    });
  }

  Future<void> updatePlaylist({
    required String playlistId,
    required String name,
    required String description,
  }) async {
    await _mutate(() async {
      await _repository.updatePlaylist(
        playlistId: playlistId,
        name: name,
        description: description,
      );
      await _reload();
    });
  }

  Future<void> deletePlaylist(String playlistId) async {
    await _mutate(() async {
      await _repository.deletePlaylist(playlistId);
      await _reload();
    });
  }

  Future<void> addSongToPlaylist(String playlistId, String songId) async {
    await _mutate(() async {
      await _repository.addSongToPlaylist(playlistId, songId);
      await _reload();
    });
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    await _mutate(() async {
      await _repository.removeSongFromPlaylist(playlistId, songId);
      await _reload();
    });
  }

  Future<void> _mutate(Future<void> Function() action) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } catch (exception) {
      error = 'No se pudo guardar en MelodyRoom: $exception';
      rethrow;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> _reload() async {
    final result = await Future.wait([
      _repository.fetchSongs(),
      _repository.fetchPlaylists(),
    ]);
    songs = result[0] as List<MelodySong>;
    playlists = result[1] as List<MelodyPlaylist>;
  }
}
