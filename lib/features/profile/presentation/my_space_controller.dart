import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/my_space_repository.dart';
import '../domain/my_space_models.dart';

class MySpaceController extends ChangeNotifier {
  MySpaceController(this._repository);

  final MySpaceRepository _repository;

  MySpaceSnapshot? snapshot;
  String? inviteCode;
  String? error;
  bool isLoading = true;
  bool isSaving = false;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      snapshot = await _repository.fetchSnapshot();
    } catch (exception) {
      error = 'No se pudo cargar My Space: $exception';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveProfile({required String name, required String bio}) async {
    await _mutate(() async {
      final current = snapshot;
      if (current == null) throw StateError('El perfil aún no está cargado.');
      final profile = await _repository.saveProfile(name: name, bio: bio);
      snapshot = MySpaceSnapshot(profile: profile, space: current.space);
    });
  }

  Future<void> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
  }) async {
    await _mutate(() async {
      final current = snapshot;
      if (current == null) throw StateError('El perfil aún no está cargado.');
      final profile = await _repository.uploadAvatar(
        bytes: bytes,
        fileName: fileName,
      );
      snapshot = MySpaceSnapshot(profile: profile, space: current.space);
    });
  }

  Future<void> removeAvatar() async {
    await _mutate(() async {
      final current = snapshot;
      if (current == null) throw StateError('El perfil aún no está cargado.');
      final profile = await _repository.removeAvatar();
      snapshot = MySpaceSnapshot(profile: profile, space: current.space);
    });
  }

  Future<void> createSpace() async {
    await _mutate(() async {
      inviteCode = await _repository.createSpace();
      snapshot = await _repository.fetchSnapshot();
    });
  }

  Future<void> createInvitation() async {
    await _mutate(() async {
      final space = snapshot?.space;
      if (space == null) throw StateError('Primero crea tu espacio Mi Luna.');
      inviteCode = await _repository.createInvitation(space.id);
      snapshot = await _repository.fetchSnapshot();
    });
  }

  Future<void> acceptInvitation(String code) async {
    await _mutate(() async {
      await _repository.acceptInvitation(code);
      inviteCode = null;
      snapshot = await _repository.fetchSnapshot();
    });
  }

  Future<void> revokeInvitations() async {
    await _mutate(() async {
      final space = snapshot?.space;
      if (space == null) throw StateError('No hay un espacio para actualizar.');
      await _repository.revokeInvitations(space.id);
      inviteCode = null;
    });
  }

  Future<void> deleteSpace() async {
    await _mutate(() async {
      final space = snapshot?.space;
      if (space == null) throw StateError('No hay un espacio para eliminar.');
      try {
        await _repository.deleteSpace(space.id);
        inviteCode = null;
        snapshot = await _repository.fetchSnapshot();
      } catch (error) {
        try {
          snapshot = await _repository.fetchSnapshot();
        } catch (refreshError) {
          throw StateError(
            '$error. No se pudo actualizar el estado de eliminación: '
            '$refreshError',
          );
        }
        rethrow;
      }
    });
  }

  Future<void> _mutate(Future<void> Function() action) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } catch (exception) {
      error = 'No se pudo guardar en My Space: $exception';
      rethrow;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}

class MySpaceChatController extends ChangeNotifier {
  MySpaceChatController({
    required this._repository,
    required this.spaceId,
    required this.currentUserId,
    required this.partnerId,
  });

  final MySpaceRepository _repository;
  final String spaceId;
  final String currentUserId;
  final String partnerId;

  List<LunaMessage> messages = const [];
  bool isLoading = true;
  bool isSending = false;
  bool isLoadingOlder = false;
  bool hasOlderMessages = false;
  bool isRealtimeConnected = false;
  bool isPartnerOnline = false;
  String? error;
  String? realtimeError;
  bool _isDisposed = false;
  bool _isRefreshing = false;
  bool _refreshQueued = false;

  Future<void> start() async {
    if (_isDisposed) return;
    isRealtimeConnected = false;
    isPartnerOnline = false;
    realtimeError = null;
    notifyListeners();
    try {
      await _repository.subscribeToSpace(
        spaceId: spaceId,
        partnerId: partnerId,
        onChanged: () => unawaited(refresh()),
        onConnectionChanged: (connected) {
          if (_isDisposed) return;
          isRealtimeConnected = connected;
          if (!connected) isPartnerOnline = false;
          if (connected) realtimeError = null;
          notifyListeners();
        },
        onPartnerPresenceChanged: (online) {
          if (_isDisposed) return;
          isPartnerOnline = online;
          notifyListeners();
        },
        onError: (exception) {
          if (_isDisposed) return;
          realtimeError =
              'Sincronización en tiempo real no disponible: $exception';
          notifyListeners();
        },
      );
    } catch (exception) {
      realtimeError = 'No se pudo iniciar el chat en tiempo real: $exception';
      notifyListeners();
    }
    await refresh();
  }

  Future<void> refresh() async {
    if (_isDisposed) return;
    if (_isRefreshing) {
      _refreshQueued = true;
      return;
    }
    _isRefreshing = true;
    isLoading = messages.isEmpty;
    notifyListeners();
    try {
      do {
        _refreshQueued = false;
        final page = await _repository.fetchMessages(spaceId);
        messages = _mergeMessages(messages, page.messages);
        hasOlderMessages = hasOlderMessages || page.hasMore;
        await _repository.markMessagesRead(spaceId);
      } while (_refreshQueued && !_isDisposed);
      error = null;
    } catch (exception) {
      error = 'No se pudieron sincronizar los mensajes: $exception';
    } finally {
      _isRefreshing = false;
      isLoading = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  Future<void> loadOlderMessages() async {
    if (_isDisposed ||
        isLoadingOlder ||
        !hasOlderMessages ||
        messages.isEmpty) {
      return;
    }
    isLoadingOlder = true;
    notifyListeners();
    try {
      final oldest = messages.last;
      final page = await _repository.fetchMessages(
        spaceId,
        beforeCreatedAt: oldest.createdAt,
        beforeId: oldest.id,
      );
      messages = _mergeMessages(messages, page.messages);
      hasOlderMessages = page.hasMore;
      error = null;
    } catch (exception) {
      error = 'No se pudieron cargar mensajes anteriores: $exception';
    } finally {
      isLoadingOlder = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  Future<void> sendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await _send(() => _repository.sendTextMessage(spaceId, trimmed));
  }

  Future<void> sendImage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    await _send(
      () => _repository.sendImageMessage(
        spaceId: spaceId,
        bytes: bytes,
        fileName: fileName,
      ),
    );
  }

  Future<void> _send(Future<void> Function() action) async {
    isSending = true;
    error = null;
    notifyListeners();
    try {
      await action();
      await refresh();
    } catch (exception) {
      error = 'No se pudo enviar el mensaje: $exception';
      rethrow;
    } finally {
      isSending = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  List<LunaMessage> _mergeMessages(
    List<LunaMessage> existing,
    List<LunaMessage> incoming,
  ) {
    final byId = <String, LunaMessage>{};
    for (final message in existing) {
      byId[message.id] = message;
    }
    for (final message in incoming) {
      byId[message.id] = message;
    }
    final merged = byId.values.toList()
      ..sort((a, b) {
        final byDate = b.createdAt.compareTo(a.createdAt);
        return byDate == 0 ? b.id.compareTo(a.id) : byDate;
      });
    return merged;
  }

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(_repository.stopRealtime());
    super.dispose();
  }
}
