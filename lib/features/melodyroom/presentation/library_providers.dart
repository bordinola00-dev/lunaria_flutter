import 'package:flutter_riverpod/flutter_riverpod.dart' show Provider;
import 'package:flutter_riverpod/legacy.dart' show ChangeNotifierProvider;

import '../../../core/services/supabase_config.dart';
import '../data/library_repository.dart';
import 'library_controller.dart';

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => SupabaseLibraryRepository(),
);

final ChangeNotifierProvider<LibraryController> libraryControllerProvider =
    ChangeNotifierProvider<LibraryController>((ref) {
      final controller = LibraryController(ref.watch(libraryRepositoryProvider))
        ..load();
      final client = supabase;
      if (client != null) {
        var ownerId = client.auth.currentUser?.id;
        final subscription = client.auth.onAuthStateChange.listen((event) {
          final nextOwnerId = event.session?.user.id;
          if (nextOwnerId != ownerId) {
            ownerId = nextOwnerId;
            ref.invalidate(libraryControllerProvider);
          }
        });
        ref.onDispose(() => subscription.cancel());
      }
      return controller;
    });
