import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' show Provider;
import 'package:flutter_riverpod/legacy.dart' show ChangeNotifierProvider;

import '../data/app_update_repository.dart';
import 'app_update_controller.dart';

final appUpdateSourceProvider = Provider<AppUpdateSource>((ref) {
  final repository = AppUpdateRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

final installedAppVersionLoaderProvider = Provider<InstalledAppVersionLoader>(
  (ref) => loadInstalledAppVersion,
);

final ChangeNotifierProvider<AppUpdateController> appUpdateControllerProvider =
    ChangeNotifierProvider<AppUpdateController>((ref) {
      final controller = AppUpdateController(
        source: ref.watch(appUpdateSourceProvider),
        installedVersionLoader: ref.watch(installedAppVersionLoaderProvider),
      );
      unawaited(controller.loadInstalledVersion());
      return controller;
    });
