import 'package:flutter_test/flutter_test.dart';
import 'package:lunaria_flutter/features/profile/data/my_space_repository.dart';
import 'package:lunaria_flutter/features/profile/domain/my_space_models.dart';
import 'package:lunaria_flutter/features/profile/presentation/my_space_controller.dart';

void main() {
  test(
    'invitation codes normalize pasted whitespace without changing case',
    () {
      const code = 'AbcdEFGH_01234567-abcdefgh_01234';

      expect(code, hasLength(32));
      expect(
        LunaInvitationCode.normalize('  AbcdEFGH_0123\n4567-abcdefgh_01234 '),
        code,
      );
    },
  );

  test('invitation codes reject malformed input with a useful message', () {
    expect(
      () => LunaInvitationCode.normalize('short-code'),
      throwsA(
        isA<InvitationCodeFormatException>().having(
          (error) => error.toString(),
          'message',
          contains('32 caracteres válidos'),
        ),
      ),
    );
  });

  test('realtime disconnect clears stale partner presence', () async {
    final repository = _ChatStateRepository();
    final controller = MySpaceChatController(
      repository: repository,
      spaceId: 'space-id',
      currentUserId: 'user-id',
      partnerId: 'partner-id',
    );
    addTearDown(controller.dispose);

    await controller.start();
    repository.onConnectionChanged!(true);
    repository.onPartnerPresenceChanged!(true);

    expect(controller.isRealtimeConnected, isTrue);
    expect(controller.isPartnerOnline, isTrue);

    repository.onConnectionChanged!(false);

    expect(controller.isRealtimeConnected, isFalse);
    expect(controller.isPartnerOnline, isFalse);
  });

  test(
    'failed shared-media cleanup refreshes the pending deletion state',
    () async {
      final repository = _RetryableDeleteRepository();
      final controller = MySpaceController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      expect(controller.snapshot?.space?.state, 'active');

      await expectLater(controller.deleteSpace(), throwsA(isA<StateError>()));

      expect(controller.snapshot?.space?.state, 'deleting');
      expect(controller.error, contains('Storage no disponible'));
    },
  );
}

class _RetryableDeleteRepository implements MySpaceRepository {
  MySpaceSnapshot snapshot = _buildSnapshot('active');

  @override
  Future<MySpaceSnapshot> fetchSnapshot() async => snapshot;

  @override
  Future<void> deleteSpace(String spaceId) async {
    snapshot = _buildSnapshot('deleting');
    throw StateError('Storage no disponible');
  }

  @override
  Future<void> stopRealtime() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ChatStateRepository implements MySpaceRepository {
  void Function(bool)? onConnectionChanged;
  void Function(bool)? onPartnerPresenceChanged;

  @override
  Future<LunaMessagePage> fetchMessages(
    String spaceId, {
    DateTime? beforeCreatedAt,
    String? beforeId,
  }) async => const LunaMessagePage(messages: [], hasMore: false);

  @override
  Future<void> markMessagesRead(String spaceId) async {}

  @override
  Future<void> subscribeToSpace({
    required String spaceId,
    required String partnerId,
    required void Function() onChanged,
    required void Function(bool) onConnectionChanged,
    required void Function(bool) onPartnerPresenceChanged,
    required void Function(Object) onError,
  }) async {
    this.onConnectionChanged = onConnectionChanged;
    this.onPartnerPresenceChanged = onPartnerPresenceChanged;
  }

  @override
  Future<void> stopRealtime() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MySpaceSnapshot _buildSnapshot(String state) => MySpaceSnapshot(
  profile: const MySpaceProfile(
    id: 'user-id',
    name: 'Luna',
    bio: '',
    avatarPath: null,
    avatarUrl: null,
  ),
  space: LunaSpace(
    id: 'space-id',
    state: state,
    participants: [
      LunaParticipant(
        userId: 'user-id',
        name: 'Luna',
        avatarUrl: null,
        joinedAt: DateTime.utc(2025),
      ),
    ],
    createdAt: DateTime.utc(2025),
  ),
);
