import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

final _latestReleaseUri = Uri.https(
  'api.github.com',
  '/repos/bordinola00-dev/lunaria_flutter/releases/latest',
);

abstract interface class AppUpdateSource {
  Future<AppUpdateRelease> fetchLatestRelease();
}

class AppUpdateRepository implements AppUpdateSource {
  AppUpdateRepository({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  static const _requestTimeout = Duration(seconds: 15);
  static const _downloadPathPrefix =
      '/bordinola00-dev/lunaria_flutter/releases/download/';
  final http.Client _client;
  final bool _ownsClient;

  @override
  Future<AppUpdateRelease> fetchLatestRelease() async {
    late final http.Response response;
    try {
      response = await _client
          .get(
            _latestReleaseUri,
            headers: const {
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
              'User-Agent': 'Lunaria-Android-Updater',
            },
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw const AppUpdateException(
        'GitHub tardó demasiado en responder. Inténtalo de nuevo.',
      );
    } on SocketException {
      throw const AppUpdateException(
        'No hay conexión a internet. Revisa tu conexión e inténtalo de nuevo.',
      );
    } on http.ClientException {
      throw const AppUpdateException(
        'No se pudo conectar con GitHub. Revisa tu conexión e inténtalo de nuevo.',
      );
    }

    if (response.statusCode == 404) {
      throw const AppUpdateException(
        'Todavía no hay una versión estable publicada para Lunaria.',
      );
    }
    if (response.statusCode == 403) {
      throw const AppUpdateException(
        'GitHub limitó temporalmente las consultas. Inténtalo más tarde.',
      );
    }
    if (response.statusCode != 200) {
      throw AppUpdateException(
        'GitHub respondió con un error (${response.statusCode}). Inténtalo más tarde.',
      );
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const AppUpdateException(
        'GitHub devolvió una respuesta que Lunaria no pudo interpretar.',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const AppUpdateException(
        'GitHub devolvió una respuesta que Lunaria no pudo interpretar.',
      );
    }

    final tagName = decoded['tag_name'];
    if (tagName is! String ||
        decoded['draft'] == true ||
        decoded['prerelease'] == true) {
      throw const AppUpdateException(
        'GitHub no devolvió una versión estable válida.',
      );
    }

    late final AppReleaseVersion releaseVersion;
    try {
      releaseVersion = AppReleaseVersion.parse(tagName);
    } on FormatException {
      throw const AppUpdateException(
        'La versión publicada en GitHub tiene un formato no compatible.',
      );
    }

    final assets = decoded['assets'];
    if (assets is! List) {
      throw const AppUpdateException(
        'La versión de GitHub no incluye un APK descargable.',
      );
    }

    Uri? downloadUri;
    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) continue;
      final name = asset['name'];
      final url = asset['browser_download_url'];
      if (name is! String || !name.toLowerCase().endsWith('.apk')) continue;
      if (url is! String) continue;

      final candidate = Uri.tryParse(url);
      if (_isOfficialReleaseAsset(candidate)) {
        downloadUri = candidate;
        if (name.toLowerCase() == 'app-release.apk') break;
      }
    }
    if (downloadUri == null) {
      throw const AppUpdateException(
        'La versión más reciente no incluye un APK oficial descargable.',
      );
    }

    final releaseUrlValue = decoded['html_url'];
    final releaseUri = releaseUrlValue is String
        ? Uri.tryParse(releaseUrlValue)
        : null;
    if (releaseUri == null || !_isOfficialReleasePage(releaseUri)) {
      throw const AppUpdateException(
        'GitHub devolvió un enlace de publicación no válido.',
      );
    }

    return AppUpdateRelease(
      tagName: tagName,
      version: releaseVersion.toString(),
      downloadUri: downloadUri,
      releaseUri: releaseUri,
    );
  }

  bool _isOfficialReleaseAsset(Uri? uri) =>
      uri != null &&
      uri.scheme == 'https' &&
      uri.host == 'github.com' &&
      uri.port == 443 &&
      uri.path.startsWith(_downloadPathPrefix);

  bool _isOfficialReleasePage(Uri? uri) =>
      uri != null &&
      uri.scheme == 'https' &&
      uri.host == 'github.com' &&
      uri.port == 443 &&
      uri.path.startsWith('/bordinola00-dev/lunaria_flutter/releases/tag/');

  void dispose() {
    if (_ownsClient) _client.close();
  }
}

class AppUpdateRelease {
  const AppUpdateRelease({
    required this.tagName,
    required this.version,
    required this.downloadUri,
    required this.releaseUri,
  });

  final String tagName;
  final String version;
  final Uri downloadUri;
  final Uri releaseUri;
}

class AppUpdateException implements Exception {
  const AppUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AppReleaseVersion implements Comparable<AppReleaseVersion> {
  const AppReleaseVersion(this.major, this.minor, this.patch);

  static final _pattern = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)$');

  final int major;
  final int minor;
  final int patch;

  factory AppReleaseVersion.parse(String value) {
    final match = _pattern.firstMatch(value.trim());
    if (match == null) throw FormatException('Unsupported app version: $value');
    return AppReleaseVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  @override
  int compareTo(AppReleaseVersion other) {
    final majorComparison = major.compareTo(other.major);
    if (majorComparison != 0) return majorComparison;
    final minorComparison = minor.compareTo(other.minor);
    if (minorComparison != 0) return minorComparison;
    return patch.compareTo(other.patch);
  }

  @override
  String toString() => '$major.$minor.$patch';
}

bool isNewerAppVersion(String latestVersion, String installedVersion) =>
    AppReleaseVersion.parse(latestVersion)
        .compareTo(AppReleaseVersion.parse(installedVersion)) >
    0;
