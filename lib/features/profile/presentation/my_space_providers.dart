import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' show Provider;
import 'package:flutter_riverpod/legacy.dart' show ChangeNotifierProvider;

import '../../../core/services/supabase_config.dart';
import '../data/my_space_repository.dart';
import 'my_space_controller.dart';

final mySpaceRepositoryProvider = Provider<MySpaceRepository>(
  (ref) => SupabaseMySpaceRepository(),
);

final ChangeNotifierProvider<MySpaceController> mySpaceControllerProvider =
    ChangeNotifierProvider<MySpaceController>((ref) {
      final controller = MySpaceController(ref.watch(mySpaceRepositoryProvider))
        ..load();
      final client = supabase;
      if (client != null) {
        var ownerId = client.auth.currentUser?.id;
        final subscription = client.auth.onAuthStateChange.listen((event) {
          final nextOwnerId = event.session?.user.id;
          if (nextOwnerId != ownerId) {
            ownerId = nextOwnerId;
            ref.invalidate(mySpaceControllerProvider);
          }
        });
        ref.onDispose(() => unawaited(subscription.cancel()));
      }
      return controller;
    });
