import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' show Provider;
import 'package:flutter_riverpod/legacy.dart' show ChangeNotifierProvider;

import '../../../core/services/supabase_config.dart';
import '../data/mindspace_repository.dart';
import 'mindspace_controller.dart';

final mindSpaceRepositoryProvider = Provider<MindSpaceRepository>(
  (ref) => SupabaseMindSpaceRepository(),
);

final ChangeNotifierProvider<MindSpaceController> mindSpaceControllerProvider =
    ChangeNotifierProvider<MindSpaceController>((ref) {
      final controller = MindSpaceController(
        ref.watch(mindSpaceRepositoryProvider),
      )..load();
      final client = supabase;
      if (client != null) {
        var ownerId = client.auth.currentSession?.user.id;
        final subscription = client.auth.onAuthStateChange.listen((authState) {
          final nextOwnerId = authState.session?.user.id;
          if (nextOwnerId != ownerId) {
            ownerId = nextOwnerId;
            ref.invalidate(mindSpaceControllerProvider);
          }
        });
        ref.onDispose(() => unawaited(subscription.cancel()));
      }
      return controller;
    });
