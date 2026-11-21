import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' show Provider;
import 'package:flutter_riverpod/legacy.dart' show ChangeNotifierProvider;

import '../../../core/services/supabase_config.dart';
import '../data/melodyroom_repository.dart';
import 'melodyroom_controller.dart';

final melodyRoomRepositoryProvider = Provider<MelodyRoomRepository>(
  (ref) => SupabaseMelodyRoomRepository(),
);

final ChangeNotifierProvider<MelodyRoomController>
melodyRoomControllerProvider = ChangeNotifierProvider<MelodyRoomController>((
  ref,
) {
  final controller = MelodyRoomController(
    ref.watch(melodyRoomRepositoryProvider),
  )..load();
  final client = supabase;
  if (client != null) {
    var ownerId = client.auth.currentSession?.user.id;
    final subscription = client.auth.onAuthStateChange.listen((authState) {
      final nextOwnerId = authState.session?.user.id;
      if (nextOwnerId != ownerId) {
        ownerId = nextOwnerId;
        ref.invalidate(melodyRoomControllerProvider);
      }
    });
    ref.onDispose(() => unawaited(subscription.cancel()));
  }
  return controller;
});
