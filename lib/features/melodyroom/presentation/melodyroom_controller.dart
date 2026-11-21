import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/melodyroom_repository.dart';
import '../domain/melodyroom_models.dart';

class MelodyRoomController extends ChangeNotifier {
  MelodyRoomController(this._repository);

  final MelodyRoomRepository _repository;

  List<MelodyFavorite> favorites = const [];
  List<SpotifyTrack> savedTracks = const [];
  List<SpotifyPlaylist> playlists = const [];
  final Map<String, List<SpotifyTrack>> playlistTracks = {};
  final Map<String, int> _playlistOffsets = {};
  final Map<String, int> _playlistTotals = {};
  final Set<String> loadingPlaylistIds = {};

  bool isLoading = true;
  bool isConnecting = false;
  bool isSaving = false;
  bool isLoadingSavedTracks = false;
  bool isLoadingPlaylists = false;
  bool isSpotifyConnected = false;
  bool isLunariaAuthenticated = false;
  bool spotifyConfigured = false;
  bool hasMoreSavedTracks = false;
  bool hasMorePlaylists = false;
  String? error;
  String? spotifyError;

  int _savedTracksOffset = 0;
  int _playlistsOffset = 0;

  List<SpotifyTrack> get allTracks {
    final tracks = <SpotifyTrack>[];
    final seen = <String>{};
    for (final track in [
      ...savedTracks,
      ...playlistTracks.values.expand((items) => items),
    ]) {
      if (seen.add(track.id)) tracks.add(track);
    }
    return tracks;
  }

  SpotifyTrack? trackForFavorite(String spotifyTrackId) {
    for (final track in allTracks) {
      if (track.id == spotifyTrackId) return track;
    }
    return null;
  }

  bool isFavorite(String spotifyTrackId) =>
      favorites.any((favorite) => favorite.spotifyTrackId == spotifyTrackId);

  bool playlistHasMore(String playlistId) =>
      (_playlistOffsets[playlistId] ?? 0) < (_playlistTotals[playlistId] ?? 0);

  Future<void> load() async {
    isLoading = true;
    error = null;
    spotifyError = null;
    spotifyConfigured = _repository.spotifyConfigured;
    isLunariaAuthenticated = _repository.isLunariaAuthenticated;
    notifyListeners();
    try {
      favorites = await _repository.fetchFavorites();
      isSpotifyConnected = spotifyConfigured
          ? await _repository.isSpotifyConnected()
          : false;
      if (isSpotifyConnected) await _loadSpotifyCatalog();
    } catch (exception) {
      error = _messageFor(exception);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> connectSpotify() async {
    isConnecting = true;
    error = null;
    spotifyError = null;
    notifyListeners();
    try {
      await _repository.connectSpotify();
      isSpotifyConnected = true;
      await _loadSpotifyCatalog();
    } catch (exception) {
      error = _messageFor(exception);
      rethrow;
    } finally {
      isConnecting = false;
      notifyListeners();
    }
  }

  Future<void> disconnectSpotify() async {
    await _runMutation(_repository.disconnectSpotify);
    isSpotifyConnected = false;
    favorites = const [];
    savedTracks = const [];
    playlists = const [];
    playlistTracks.clear();
    _resetPagination();
    spotifyError = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    isLoading = true;
    error = null;
    spotifyError = null;
    spotifyConfigured = _repository.spotifyConfigured;
    isLunariaAuthenticated = _repository.isLunariaAuthenticated;
    notifyListeners();
    try {
      favorites = await _repository.fetchFavorites();
      isSpotifyConnected = spotifyConfigured
          ? await _repository.isSpotifyConnected()
          : false;
      savedTracks = const [];
      playlists = const [];
      playlistTracks.clear();
      _resetPagination();
      if (isSpotifyConnected) await _loadSpotifyCatalog();
    } catch (exception) {
      error = _messageFor(exception);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreSavedTracks() async {
    if (!isSpotifyConnected || isLoadingSavedTracks || !hasMoreSavedTracks) {
      return;
    }
    isLoadingSavedTracks = true;
    spotifyError = null;
    notifyListeners();
    try {
      final page = await _repository.fetchSavedTracks(
        offset: _savedTracksOffset,
      );
      savedTracks = _appendUniqueTracks(savedTracks, page.items);
      _savedTracksOffset = page.nextOffset;
      hasMoreSavedTracks = page.hasMore;
    } catch (exception) {
      spotifyError = _messageFor(exception);
      rethrow;
    } finally {
      isLoadingSavedTracks = false;
      notifyListeners();
    }
  }

  Future<void> loadMorePlaylists() async {
    if (!isSpotifyConnected || isLoadingPlaylists || !hasMorePlaylists) return;
    isLoadingPlaylists = true;
    spotifyError = null;
    notifyListeners();
    try {
      final page = await _repository.fetchPlaylists(offset: _playlistsOffset);
      playlists = [...playlists, ...page.items];
      _playlistsOffset = page.nextOffset;
      hasMorePlaylists = page.hasMore;
    } catch (exception) {
      spotifyError = _messageFor(exception);
      rethrow;
    } finally {
      isLoadingPlaylists = false;
      notifyListeners();
    }
  }

  Future<void> loadPlaylistTracks(String playlistId) async {
    if (playlistTracks.containsKey(playlistId) ||
        loadingPlaylistIds.contains(playlistId)) {
      return;
    }
    loadingPlaylistIds.add(playlistId);
    spotifyError = null;
    notifyListeners();
    try {
      final page = await _repository.fetchPlaylistTracks(
        playlistId: playlistId,
        offset: 0,
      );
      playlistTracks[playlistId] = page.items;
      _playlistOffsets[playlistId] = page.nextOffset;
      _playlistTotals[playlistId] = page.total;
    } catch (exception) {
      spotifyError = _messageFor(exception);
      rethrow;
    } finally {
      loadingPlaylistIds.remove(playlistId);
      notifyListeners();
    }
  }

  Future<void> loadMorePlaylistTracks(String playlistId) async {
    if (loadingPlaylistIds.contains(playlistId) ||
        !playlistHasMore(playlistId)) {
      return;
    }
    loadingPlaylistIds.add(playlistId);
    spotifyError = null;
    notifyListeners();
    try {
      final page = await _repository.fetchPlaylistTracks(
        playlistId: playlistId,
        offset: _playlistOffsets[playlistId] ?? 0,
      );
      playlistTracks[playlistId] = _appendUniqueTracks(
        playlistTracks[playlistId] ?? const [],
        page.items,
      );
      _playlistOffsets[playlistId] = page.nextOffset;
      _playlistTotals[playlistId] = page.total;
    } catch (exception) {
      spotifyError = _messageFor(exception);
      rethrow;
    } finally {
      loadingPlaylistIds.remove(playlistId);
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(SpotifyTrack track) async {
    if (isFavorite(track.id)) {
      await removeFavorite(track.id);
      return;
    }
    await _runMutation(() async {
      await _repository.addFavorite(track.id);
      favorites = await _repository.fetchFavorites();
    });
  }

  Future<void> removeFavorite(String spotifyTrackId) async {
    await _runMutation(() => _repository.removeFavorite(spotifyTrackId));
    favorites = favorites
        .where((favorite) => favorite.spotifyTrackId != spotifyTrackId)
        .toList();
    notifyListeners();
  }

  Future<void> updateReflection({
    required String spotifyTrackId,
    required String reflection,
  }) async {
    await _runMutation(
      () => _repository.updateReflection(
        spotifyTrackId: spotifyTrackId,
        reflection: reflection,
      ),
    );
    favorites = favorites
        .map(
          (favorite) => favorite.spotifyTrackId == spotifyTrackId
              ? MelodyFavorite(
                  id: favorite.id,
                  spotifyTrackId: favorite.spotifyTrackId,
                  reflection: reflection,
                  createdAt: favorite.createdAt,
                )
              : favorite,
        )
        .toList();
    notifyListeners();
  }

  Future<void> _runMutation(Future<void> Function() action) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } catch (exception) {
      error = _messageFor(exception);
      rethrow;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> _loadSpotifyCatalog() async {
    final errors = <String>[];
    try {
      final page = await _repository.fetchSavedTracks(offset: 0);
      savedTracks = page.items;
      _savedTracksOffset = page.nextOffset;
      hasMoreSavedTracks = page.hasMore;
    } catch (exception) {
      errors.add(_messageFor(exception));
      if (exception is SpotifyReauthorizationRequired) {
        isSpotifyConnected = false;
      }
    }
    if (isSpotifyConnected) {
      try {
        final page = await _repository.fetchPlaylists(offset: 0);
        playlists = page.items;
        _playlistsOffset = page.nextOffset;
        hasMorePlaylists = page.hasMore;
      } catch (exception) {
        errors.add(_messageFor(exception));
        if (exception is SpotifyReauthorizationRequired) {
          isSpotifyConnected = false;
        }
      }
    }
    spotifyError = errors.isEmpty ? null : errors.join('\n');
  }

  List<SpotifyTrack> _appendUniqueTracks(
    List<SpotifyTrack> current,
    List<SpotifyTrack> next,
  ) {
    final existingIds = current.map((track) => track.id).toSet();
    return [...current, ...next.where((track) => existingIds.add(track.id))];
  }

  void _resetPagination() {
    _savedTracksOffset = 0;
    _playlistsOffset = 0;
    hasMoreSavedTracks = false;
    hasMorePlaylists = false;
    _playlistOffsets.clear();
    _playlistTotals.clear();
  }

  String _messageFor(Object exception) =>
      'No se pudo sincronizar MelodyRoom: $exception';
}
