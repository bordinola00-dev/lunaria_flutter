import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_config.dart';
import '../domain/my_space_models.dart';

abstract interface class MySpaceRepository {
  Future<MySpaceSnapshot> fetchSnapshot();
  Future<MySpaceProfile> saveProfile({
    required String name,
    required String bio,
  });
  Future<MySpaceProfile> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
  });
  Future<MySpaceProfile> removeAvatar();
  Future<String> createSpace();
  Future<String> createInvitation(String spaceId);
  Future<void> acceptInvitation(String code);
  Future<void> revokeInvitations(String spaceId);
  Future<void> deleteSpace(String spaceId);
  Future<LunaMessagePage> fetchMessages(
    String spaceId, {
    DateTime? beforeCreatedAt,
    String? beforeId,
  });
  Future<void> sendTextMessage(String spaceId, String text);
  Future<void> sendImageMessage({
    required String spaceId,
    required Uint8List bytes,
    required String fileName,
  });
  Future<void> markMessagesRead(String spaceId);
  Future<void> subscribeToSpace({
    required String spaceId,
    required String partnerId,
    required void Function() onChanged,
    required void Function(bool) onConnectionChanged,
    required void Function(bool) onPartnerPresenceChanged,
    required void Function(Object) onError,
  });
  Future<void> stopRealtime();
}

class SupabaseMySpaceRepository implements MySpaceRepository {
  SupabaseMySpaceRepository();

  static const _bucket = 'lunaria-private';
  static const _messageLimit = 100;
  final Random _random = Random.secure();
  RealtimeChannel? _channel;

  SupabaseClient get _client {
    final client = supabase;
    if (client == null) {
      if (!isSupabaseConfigured) {
        throw const MySpaceException(
          'My Space necesita SUPABASE_URL y SUPABASE_ANON_KEY configurados.',
        );
      }
      throw const MySpaceException(
        'Supabase no está inicializado en esta sesión. Reinicia la aplicación '
        'y revisa initializeSupabase().',
      );
    }
    return client;
  }

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw const MySpaceException(
        'Inicia sesión con tu cuenta de Lunaria para cargar tu perfil.',
      );
    }
    return id;
  }

  @override
  Future<MySpaceSnapshot> fetchSnapshot() async {
    try {
      return await _fetchSnapshot();
    } on PostgrestException catch (error) {
      throw MySpaceException(_describeProfileQueryError(error));
    }
  }

  Future<MySpaceSnapshot> _fetchSnapshot() async {
    final client = _client;
    final userId = _userId;
    var profileRow = await client
        .from('profiles')
        .select('id, name, bio, avatar_path')
        .eq('id', userId)
        .maybeSingle();
    if (profileRow == null) {
      final displayName =
          client.auth.currentUser?.userMetadata?['name'] as String? ?? '';
      profileRow = await client
          .from('profiles')
          .upsert({'id': userId, 'name': displayName}, onConflict: 'id')
          .select('id, name, bio, avatar_path')
          .single();
    }
    final profile = await _profileFromRow(profileRow);

    final membership = await client
        .from('lunaria_space_members')
        .select('space_id')
        .eq('user_id', userId)
        .maybeSingle();
    if (membership == null) {
      return MySpaceSnapshot(profile: profile, space: null);
    }

    final spaceId = membership['space_id'] as String;
    final spaceRow = await client
        .from('lunaria_spaces')
        .select('id, state, created_at')
        .eq('id', spaceId)
        .single();
    final memberRows = await client
        .from('lunaria_space_members')
        .select('user_id, joined_at')
        .eq('space_id', spaceId)
        .order('joined_at');
    final memberIds = memberRows
        .map((row) => row['user_id'] as String)
        .toList(growable: false);
    final profiles = <String, Map<String, dynamic>>{};
    if (memberIds.isNotEmpty) {
      final rows = await client
          .from('profiles')
          .select('id, name, avatar_path')
          .inFilter('id', memberIds);
      for (final row in rows) {
        profiles[row['id'] as String] = Map<String, dynamic>.from(row);
      }
    }
    final participants = <LunaParticipant>[];
    for (final member in memberRows) {
      final id = member['user_id'] as String;
      final memberProfile = profiles[id];
      final avatarPath = memberProfile?['avatar_path'] as String?;
      participants.add(
        LunaParticipant(
          userId: id,
          name: (memberProfile?['name'] as String?)?.trim().isNotEmpty == true
              ? (memberProfile!['name'] as String).trim()
              : 'Participante',
          avatarUrl: avatarPath == null ? null : await _signedUrl(avatarPath),
          joinedAt: DateTime.parse(member['joined_at'] as String),
        ),
      );
    }
    return MySpaceSnapshot(
      profile: profile,
      space: LunaSpace(
        id: spaceRow['id'] as String,
        state: spaceRow['state'] as String,
        participants: participants,
        createdAt: DateTime.parse(spaceRow['created_at'] as String),
      ),
    );
  }

  String _describeProfileQueryError(PostgrestException error) {
    if (const {'PGRST204', 'PGRST205', '42703', '42P01'}.contains(error.code)) {
      return 'Falta aplicar la migración 007 de Mi Luna/My Space en Supabase '
          'o recargar el esquema de la API. Detalle (${error.code}): '
          '${error.message}';
    }
    if (error.code == '42501') {
      return 'Supabase denegó la consulta del perfil. Comprueba que la tabla '
          'profiles permita al usuario leer y editar su propia fila y que las '
          'políticas RLS de Mi Luna estén aplicadas. Detalle: ${error.message}';
    }
    return 'Falló una consulta de perfil o Mi Luna en Supabase'
        '${error.code == null ? '' : ' (${error.code})'}: ${error.message}';
  }

  @override
  Future<MySpaceProfile> saveProfile({
    required String name,
    required String bio,
  }) async {
    final cleanName = name.trim();
    final cleanBio = bio.trim();
    if (cleanName.length < 2 || cleanName.length > 80) {
      throw ArgumentError('El nombre debe tener entre 2 y 80 caracteres.');
    }
    if (cleanBio.length > 500) {
      throw ArgumentError('La biografía no puede superar 500 caracteres.');
    }
    final row = await _client
        .from('profiles')
        .update({'name': cleanName, 'bio': cleanBio})
        .eq('id', _userId)
        .select('id, name, bio, avatar_path')
        .single();
    return _profileFromRow(row);
  }

  @override
  Future<MySpaceProfile> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (bytes.isEmpty || bytes.length > 12 * 1024 * 1024) {
      throw ArgumentError('La imagen debe pesar menos de 12 MB.');
    }
    final extension = _imageExtension(fileName);
    final userId = _userId;
    final oldProfile = await _client
        .from('profiles')
        .select('avatar_path')
        .eq('id', userId)
        .single();
    final oldPath = oldProfile['avatar_path'] as String?;
    final path = '$userId/profile/${_randomFileToken()}.$extension';
    await _client.storage.from(_bucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        contentType: _contentType(extension),
        upsert: false,
      ),
    );

    late final Map<String, dynamic> row;
    try {
      row = await _client
          .from('profiles')
          .update({'avatar_path': path})
          .eq('id', userId)
          .select('id, name, bio, avatar_path')
          .single();
    } catch (error) {
      await _client.storage.from(_bucket).remove([path]);
      rethrow;
    }
    if (oldPath != null && oldPath != path) {
      try {
        await _client.storage.from(_bucket).remove([oldPath]);
      } catch (error) {
        throw StateError(
          'La nueva foto se guardó, pero no se pudo retirar la anterior: $error',
        );
      }
    }
    return _profileFromRow(row);
  }

  @override
  Future<MySpaceProfile> removeAvatar() async {
    final client = _client;
    final current = await client
        .from('profiles')
        .select('avatar_path')
        .eq('id', _userId)
        .single();
    final oldPath = current['avatar_path'] as String?;
    final row = await client
        .from('profiles')
        .update({'avatar_path': null})
        .eq('id', _userId)
        .select('id, name, bio, avatar_path')
        .single();
    if (oldPath != null) {
      await client.storage.from(_bucket).remove([oldPath]);
    }
    return _profileFromRow(row);
  }

  @override
  Future<String> createSpace() async {
    final code = _newInviteCode();
    await _client.rpc(
      'create_lunaria_space',
      params: {'p_token_hash': _hashInviteCode(code)},
    );
    return code;
  }

  @override
  Future<String> createInvitation(String spaceId) async {
    final code = _newInviteCode();
    await _client.rpc(
      'create_lunaria_space_invitation',
      params: {
        'p_space_id': spaceId,
        'p_token_hash': _hashInviteCode(code),
      },
    );
    return code;
  }

  @override
  Future<void> acceptInvitation(String code) async {
    final cleanCode = LunaInvitationCode.normalize(code);
    try {
      await _client.rpc(
        'accept_lunaria_space_invitation',
        params: {'p_token_hash': _hashInviteCode(cleanCode)},
      );
    } on PostgrestException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('invalid, expired') ||
          message.contains('already used')) {
        throw const MySpaceException(
          'El código es incorrecto, venció o ya fue utilizado. Pide una '
          'invitación nueva.',
        );
      }
      if (message.contains('already belongs')) {
        throw const MySpaceException(
          'Esta cuenta ya pertenece a un espacio Mi Luna.',
        );
      }
      if (message.contains('cannot be used')) {
        throw const MySpaceException(
          'No puedes unirte con este código. Comprueba que no sea tu propia '
          'invitación y que el espacio tenga un lugar disponible.',
        );
      }
      if (message.contains('no longer active')) {
        throw const MySpaceException(
          'Este espacio Mi Luna ya no está activo. Pide una invitación nueva.',
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> revokeInvitations(String spaceId) async {
    await _client.rpc(
      'revoke_lunaria_space_invitations',
      params: {'p_space_id': spaceId},
    );
  }

  @override
  Future<void> deleteSpace(String spaceId) async {
    final client = _client;
    final result = await client.rpc(
      'begin_lunaria_space_deletion',
      params: {'p_space_id': spaceId},
    );
    if (result is! Map || result['media_paths'] is! List) {
      throw const FormatException(
        'Supabase devolvió una respuesta de eliminación inválida.',
      );
    }
    final paths = (result['media_paths'] as List).cast<String>();
    if (paths.isNotEmpty) {
      await client.storage.from(_bucket).remove(paths);
    }
    await client.rpc(
      'finish_lunaria_space_deletion',
      params: {'p_space_id': spaceId},
    );
  }

  @override
  Future<LunaMessagePage> fetchMessages(
    String spaceId, {
    DateTime? beforeCreatedAt,
    String? beforeId,
  }) async {
    final client = _client;
    final currentUserId = _userId;
    var query = client
        .from('lunaria_space_messages')
        .select(
          'id, sender_id, message_type, body, media_path, created_at',
        )
        .eq('space_id', spaceId);
    if (beforeCreatedAt != null && beforeId != null) {
      final cursor = beforeCreatedAt.toUtc().toIso8601String();
      query = query.or(
        'created_at.lt.$cursor,and(created_at.eq.$cursor,id.lt.$beforeId)',
      );
    }
    final fetchedRows = await query
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(_messageLimit + 1);
    final hasMore = fetchedRows.length > _messageLimit;
    final messageRows = fetchedRows.take(_messageLimit).toList();
    if (messageRows.isEmpty) {
      return const LunaMessagePage(messages: [], hasMore: false);
    }

    final messageIds = messageRows.map((row) => row['id'] as String).toList();
    final senderIds = messageRows
        .map((row) => row['sender_id'] as String)
        .toSet()
        .toList();
    final profiles = <String, Map<String, dynamic>>{};
    final profileRows = await client
        .from('profiles')
        .select('id, name, avatar_path')
        .inFilter('id', senderIds);
    for (final row in profileRows) {
      profiles[row['id'] as String] = Map<String, dynamic>.from(row);
    }
    final receipts = await client
        .from('lunaria_space_message_reads')
        .select('message_id, user_id')
        .eq('space_id', spaceId)
        .inFilter('message_id', messageIds);
    final readByMessage = <String, Set<String>>{};
    for (final receipt in receipts) {
      readByMessage
          .putIfAbsent(receipt['message_id'] as String, () => <String>{})
          .add(receipt['user_id'] as String);
    }

    final avatarUrls = <String, String?>{};
    final messages = <LunaMessage>[];
    for (final row in messageRows) {
      final senderId = row['sender_id'] as String;
      final profile = profiles[senderId];
      final avatarPath = profile?['avatar_path'] as String?;
      if (!avatarUrls.containsKey(senderId)) {
        avatarUrls[senderId] = avatarPath == null
            ? null
            : await _signedUrl(avatarPath);
      }
      final mediaPath = row['media_path'] as String?;
      messages.add(
        LunaMessage(
          id: row['id'] as String,
          senderId: senderId,
          senderName:
              (profile?['name'] as String?)?.trim().isNotEmpty == true
              ? (profile!['name'] as String).trim()
              : 'Participante',
          senderAvatarUrl: avatarUrls[senderId],
          body: row['body'] as String,
          messageType: row['message_type'] as String,
          mediaUrl: mediaPath == null ? null : await _signedUrl(mediaPath),
          createdAt: DateTime.parse(row['created_at'] as String),
          isReadByPartner: senderId == currentUserId &&
              (readByMessage[row['id']] ?? const <String>{}).any(
                (readerId) => readerId != currentUserId,
              ),
        ),
      );
    }
    return LunaMessagePage(messages: messages, hasMore: hasMore);
  }

  @override
  Future<void> sendTextMessage(String spaceId, String text) async {
    final body = text.trim();
    if (body.isEmpty || body.length > 4000) {
      throw ArgumentError('El mensaje debe tener entre 1 y 4000 caracteres.');
    }
    await _client.from('lunaria_space_messages').insert({
      'space_id': spaceId,
      'sender_id': _userId,
      'message_type': 'text',
      'body': body,
    });
  }

  @override
  Future<void> sendImageMessage({
    required String spaceId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (bytes.isEmpty || bytes.length > 12 * 1024 * 1024) {
      throw ArgumentError('La imagen debe pesar menos de 12 MB.');
    }
    final extension = _imageExtension(fileName);
    final senderId = _userId;
    final path = '$spaceId/chat/$senderId/${_randomFileToken()}.$extension';
    await _client.storage.from(_bucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        contentType: _contentType(extension),
        upsert: false,
      ),
    );
    try {
      await _client.from('lunaria_space_messages').insert({
        'space_id': spaceId,
        'sender_id': senderId,
        'message_type': 'image',
        'body': '',
        'media_path': path,
      });
    } catch (error) {
      try {
        await _client.storage.from(_bucket).remove([path]);
      } catch (cleanupError) {
        throw StateError(
          'No se pudo enviar el mensaje y tampoco limpiar su archivo privado: '
          '$error; $cleanupError',
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> markMessagesRead(String spaceId) async {
    await _client.rpc(
      'mark_lunaria_space_messages_read',
      params: {'p_space_id': spaceId},
    );
  }

  @override
  Future<void> subscribeToSpace({
    required String spaceId,
    required String partnerId,
    required void Function() onChanged,
    required void Function(bool) onConnectionChanged,
    required void Function(bool) onPartnerPresenceChanged,
    required void Function(Object) onError,
  }) async {
    await stopRealtime();
    final userId = _userId;
    final channel = _client.channel(
      'my-luna:$spaceId',
      opts: RealtimeChannelConfig(
        key: userId,
        enabled: true,
        private: true,
      ),
    );
    _channel = channel;
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'lunaria_space_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'space_id',
            value: spaceId,
          ),
          callback: (_) => onChanged(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'lunaria_space_message_reads',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'space_id',
            value: spaceId,
          ),
          callback: (_) => onChanged(),
        )
        .onPresenceSync((_) {
          final online = channel.presenceState().any(
            (presence) => presence.key == partnerId,
          );
          onPartnerPresenceChanged(online);
        })
        .subscribe((status, error) {
          final connected = status == RealtimeSubscribeStatus.subscribed;
          onConnectionChanged(connected);
          if (error != null) onError(error);
          if (connected) unawaited(_trackPresence(channel, userId, onError));
        });
  }

  Future<void> _trackPresence(
    RealtimeChannel channel,
    String userId,
    void Function(Object) onError,
  ) async {
    try {
      await channel.track({'user_id': userId});
    } catch (error) {
      onError(error);
    }
  }

  @override
  Future<void> stopRealtime() async {
    final channel = _channel;
    _channel = null;
    if (channel != null) await _client.removeChannel(channel);
  }

  Future<MySpaceProfile> _profileFromRow(Map<String, dynamic> row) async {
    final path = row['avatar_path'] as String?;
    return MySpaceProfile(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      bio: row['bio'] as String? ?? '',
      avatarPath: path,
      avatarUrl: path == null ? null : await _signedUrl(path),
    );
  }

  Future<String> _signedUrl(String path) =>
      _client.storage.from(_bucket).createSignedUrl(path, 3600);

  String _newInviteCode() {
    final bytes = List<int>.generate(24, (_) => _random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  String _hashInviteCode(String code) =>
      sha256.convert(utf8.encode(code)).toString();

  String _randomFileToken() {
    final bytes = List<int>.generate(18, (_) => _random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  String _imageExtension(String fileName) {
    final extension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    const supported = {'jpg', 'jpeg', 'png', 'webp', 'heic'};
    if (!supported.contains(extension)) {
      throw ArgumentError('Formato de imagen no compatible: .$extension');
    }
    return extension;
  }

  String _contentType(String extension) => switch (extension) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    _ => 'image/jpeg',
  };
}
