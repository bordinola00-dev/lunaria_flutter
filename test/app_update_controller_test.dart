import 'package:flutter_test/flutter_test.dart';
import 'package:lunaria_flutter/features/profile/data/app_update_repository.dart';
import 'package:lunaria_flutter/features/profile/presentation/app_update_controller.dart';

void main() {
  test('shows available update when GitHub release is newer', () async {
    final controller = AppUpdateController(
      source: _FakeUpdateSource(release: _release('v1.0.1', '1.0.1')),
      installedVersionLoader: () async =>
          const InstalledAppVersion(version: '1.0.0', buildNumber: '1'),
    );

    await controller.loadInstalledVersion();
    await controller.checkForUpdates();

    expect(controller.status, AppUpdateStatus.updateAvailable);
    expect(controller.latestRelease?.version, '1.0.1');
    controller.dispose();
  });

  test(
    'shows current status when latest stable version is not newer',
    () async {
      final controller = AppUpdateController(
        source: _FakeUpdateSource(release: _release('v1.0.0', '1.0.0')),
        installedVersionLoader: () async =>
            const InstalledAppVersion(version: '1.0.0', buildNumber: '2'),
      );

      await controller.loadInstalledVersion();
      await controller.checkForUpdates();

      expect(controller.status, AppUpdateStatus.upToDate);
      controller.dispose();
    },
  );

  test('shows a readable error when GitHub cannot be reached', () async {
    final controller = AppUpdateController(
      source: _FakeUpdateSource(
        error: const AppUpdateException('No hay conexión a internet.'),
      ),
      installedVersionLoader: () async =>
          const InstalledAppVersion(version: '1.0.0', buildNumber: '1'),
    );

    await controller.loadInstalledVersion();
    await controller.checkForUpdates();

    expect(controller.status, AppUpdateStatus.error);
    expect(controller.errorMessage, 'No hay conexión a internet.');
    controller.dispose();
  });
}

AppUpdateRelease _release(String tag, String version) => AppUpdateRelease(
  tagName: tag,
  version: version,
  downloadUri: Uri.https(
    'github.com',
    '/bordinola00-dev/lunaria_flutter/releases/download/$tag/app-release.apk',
  ),
  releaseUri: Uri.https(
    'github.com',
    '/bordinola00-dev/lunaria_flutter/releases/tag/$tag',
  ),
);

class _FakeUpdateSource implements AppUpdateSource {
  const _FakeUpdateSource({this.release, this.error});

  final AppUpdateRelease? release;
  final AppUpdateException? error;

  @override
  Future<AppUpdateRelease> fetchLatestRelease() async {
    if (error != null) throw error!;
    return release!;
  }
}
