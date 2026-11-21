import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/app_update_repository.dart';

enum AppUpdateStatus {
  loadingVersion,
  ready,
  checking,
  updateAvailable,
  upToDate,
  error,
}

class InstalledAppVersion {
  const InstalledAppVersion({required this.version, required this.buildNumber});

  final String version;
  final String buildNumber;
}

typedef InstalledAppVersionLoader = Future<InstalledAppVersion> Function();

Future<InstalledAppVersion> loadInstalledAppVersion() async {
  final packageInfo = await PackageInfo.fromPlatform();
  return InstalledAppVersion(
    version: packageInfo.version,
    buildNumber: packageInfo.buildNumber,
  );
}

class AppUpdateController extends ChangeNotifier {
  AppUpdateController({
    required this.source,
    required this.installedVersionLoader,
  });

  final AppUpdateSource source;
  final InstalledAppVersionLoader installedVersionLoader;

  AppUpdateStatus status = AppUpdateStatus.loadingVersion;
  InstalledAppVersion? installedVersion;
  AppUpdateRelease? latestRelease;
  String? errorMessage;
  bool _disposed = false;

  Future<void> loadInstalledVersion() async {
    if (status == AppUpdateStatus.loadingVersion && installedVersion != null) {
      return;
    }
    status = AppUpdateStatus.loadingVersion;
    errorMessage = null;
    _notify();
    try {
      final version = await installedVersionLoader();
      AppReleaseVersion.parse(version.version);
      if (_disposed) return;
      installedVersion = version;
      status = AppUpdateStatus.ready;
      _notify();
    } on FormatException {
      _setError('No se pudo interpretar la versión instalada de Lunaria.');
    } on PlatformException {
      _setError('No se pudo consultar la versión instalada de Lunaria.');
    } on MissingPluginException {
      _setError('No se pudo consultar la versión instalada de Lunaria.');
    }
  }

  Future<void> checkForUpdates() async {
    if (status == AppUpdateStatus.checking) return;
    if (installedVersion == null) {
      await loadInstalledVersion();
      if (installedVersion == null) return;
    }

    status = AppUpdateStatus.checking;
    errorMessage = null;
    latestRelease = null;
    _notify();
    try {
      final release = await source.fetchLatestRelease();
      if (_disposed) return;
      latestRelease = release;
      status = isNewerAppVersion(release.version, installedVersion!.version)
          ? AppUpdateStatus.updateAvailable
          : AppUpdateStatus.upToDate;
      _notify();
    } on AppUpdateException catch (error) {
      _setError(error.message);
    } on FormatException {
      _setError('No se pudo interpretar la versión publicada en GitHub.');
    }
  }

  void _setError(String message) {
    if (_disposed) return;
    errorMessage = message;
    status = AppUpdateStatus.error;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
