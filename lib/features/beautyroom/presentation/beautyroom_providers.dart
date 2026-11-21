import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' show Provider;
import 'package:flutter_riverpod/legacy.dart' show ChangeNotifierProvider;

import '../../../core/services/supabase_config.dart';
import '../data/beautyroom_repository.dart';
import 'beautyroom_controller.dart';

final beautyRoomRepositoryProvider = Provider<BeautyRoomRepository>(
  (ref) => SupabaseBeautyRoomRepository(),
);

final ChangeNotifierProvider<BeautyRoomController>
beautyRoomControllerProvider = ChangeNotifierProvider<BeautyRoomController>((
  ref,
) {
  final controller = BeautyRoomController(
    ref.watch(beautyRoomRepositoryProvider),
  )..load();
  final client = supabase;
  if (client != null) {
    var ownerId = client.auth.currentSession?.user.id;
    final subscription = client.auth.onAuthStateChange.listen((authState) {
      final nextOwnerId = authState.session?.user.id;
      if (nextOwnerId != ownerId) {
        ownerId = nextOwnerId;
        ref.invalidate(beautyRoomControllerProvider);
      }
    });
    ref.onDispose(() => unawaited(subscription.cancel()));
  }
  return controller;
});
