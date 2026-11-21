class MySpaceProfile {
  const MySpaceProfile({
    required this.id,
    required this.name,
    required this.bio,
    required this.avatarPath,
    required this.avatarUrl,
  });

  final String id;
  final String name;
  final String bio;
  final String? avatarPath;
  final String? avatarUrl;
}

class LunaParticipant {
  const LunaParticipant({
    required this.userId,
    required this.name,
    required this.avatarUrl,
    required this.joinedAt,
  });

  final String userId;
  final String name;
  final String? avatarUrl;
  final DateTime joinedAt;
}

class LunaSpace {
  const LunaSpace({
    required this.id,
    required this.state,
    required this.participants,
    required this.createdAt,
  });

  final String id;
  final String state;
  final List<LunaParticipant> participants;
  final DateTime createdAt;

  bool get isDeleting => state == 'deleting';
  bool get isPaired => participants.length == 2;
  LunaParticipant? partnerFor(String userId) {
    for (final participant in participants) {
      if (participant.userId != userId) return participant;
    }
    return null;
  }
}

class MySpaceSnapshot {
  const MySpaceSnapshot({required this.profile, required this.space});

  final MySpaceProfile profile;
  final LunaSpace? space;
}

class LunaMessage {
  const LunaMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderAvatarUrl,
    required this.body,
    required this.messageType,
    required this.mediaUrl,
    required this.createdAt,
    required this.isReadByPartner,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final String body;
  final String messageType;
  final String? mediaUrl;
  final DateTime createdAt;
  final bool isReadByPartner;
}

class LunaMessagePage {
  const LunaMessagePage({
    required this.messages,
    required this.hasMore,
  });

  final List<LunaMessage> messages;
  final bool hasMore;
}

class MySpaceException implements Exception {
  const MySpaceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class InvitationCodeFormatException extends MySpaceException {
  const InvitationCodeFormatException(super.message);
}

abstract final class LunaInvitationCode {
  static final _pattern = RegExp(r'^[A-Za-z0-9_-]{32}$');

  static String normalize(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), '');
    if (!_pattern.hasMatch(normalized)) {
      throw const InvitationCodeFormatException(
        'El código debe tener 32 caracteres válidos. Vuelve a copiarlo '
        'completo e inténtalo de nuevo.',
      );
    }
    return normalized;
  }
}
