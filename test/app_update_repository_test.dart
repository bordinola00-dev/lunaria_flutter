import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lunaria_flutter/features/profile/data/app_update_repository.dart';

void main() {
  test(
    'fetches the latest stable APK from the Lunaria GitHub repository',
    () async {
      late Uri requestedUri;
      final client = MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode({
            'tag_name': 'v1.2.0',
            'draft': false,
            'prerelease': false,
            'html_url': 'https://github.com/bordinola00-dev/lunaria_flutter/releases/tag/v1.2.0',
            'assets': [
              {
                'name': 'app-release.apk',
                'browser_download_url': 'https://github.com/bordinola00-dev/lunaria_flutter/releases/download/v1.2.0/app-release.apk',
              },
            ],
          }),
          200,
        );
      });
      final repository = AppUpdateRepository(client: client);

      final release = await repository.fetchLatestRelease();

      expect(
        requestedUri,
        Uri.https(
          'api.github.com',
          '/repos/bordinola00-dev/lunaria_flutter/releases/latest',
        ),
      );
      expect(release.tagName, 'v1.2.0');
      expect(release.version, '1.2.0');
      expect(release.downloadUri.path, endsWith('/app-release.apk'));
      expect(release.releaseUri.host, 'github.com');
      client.close();
    },
  );

  test('fetches the latest stable IPA for iOS', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'tag_name': 'v1.2.0',
          'draft': false,
          'prerelease': false,
          'html_url':
              'https://github.com/bordinola00-dev/lunaria_flutter/releases/tag/v1.2.0',
          'assets': [
            {
              'name': 'app-release.apk',
              'browser_download_url':
                  'https://github.com/bordinola00-dev/lunaria_flutter/releases/download/v1.2.0/app-release.apk',
            },
            {
              'name': 'app-release.ipa',
              'browser_download_url':
                  'https://github.com/bordinola00-dev/lunaria_flutter/releases/download/v1.2.0/app-release.ipa',
            },
          ],
        }),
        200,
      ),
    );
    final repository = AppUpdateRepository(client: client, isIOS: true);

    final release = await repository.fetchLatestRelease();

    expect(release.downloadUri.path, endsWith('/app-release.ipa'));
    client.close();
  });

  test('rejects APK download URLs outside the official repository', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'tag_name': 'v1.2.0',
          'draft': false,
          'prerelease': false,
          'html_url': 'https://github.com/bordinola00-dev/lunaria_flutter/releases/tag/v1.2.0',
          'assets': [
            {
              'name': 'app-release.apk',
              'browser_download_url': 'https://example.com/app-release.apk',
            },
          ],
        }),
        200,
      ),
    );
    final repository = AppUpdateRepository(client: client);

    await expectLater(
      repository.fetchLatestRelease(),
      throwsA(
        isA<AppUpdateException>().having(
          (error) => error.message,
          'message',
          contains('no incluye un APK oficial'),
        ),
      ),
    );
    client.close();
  });

  test('reports GitHub not found as no stable release', () async {
    final client = MockClient((_) async => http.Response('{}', 404));
    final repository = AppUpdateRepository(client: client);

    await expectLater(
      repository.fetchLatestRelease(),
      throwsA(
        isA<AppUpdateException>().having(
          (error) => error.message,
          'message',
          contains('no hay una versión estable'),
        ),
      ),
    );
    client.close();
  });

  test('rejects prereleases from the latest-release response', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'tag_name': 'v1.2.0-rc.1',
          'draft': false,
          'prerelease': true,
          'html_url':
              'https://github.com/bordinola00-dev/lunaria_flutter/releases/tag/v1.2.0-rc.1',
          'assets': [],
        }),
        200,
      ),
    );
    final repository = AppUpdateRepository(client: client);

    await expectLater(
      repository.fetchLatestRelease(),
      throwsA(isA<AppUpdateException>()),
    );
    client.close();
  });

  test('compares stable app versions by major, minor, and patch', () {
    expect(isNewerAppVersion('v1.0.1', '1.0.0'), isTrue);
    expect(isNewerAppVersion('1.1.0', '1.0.9'), isTrue);
    expect(isNewerAppVersion('1.0.0', '1.0.0'), isFalse);
    expect(isNewerAppVersion('1.0.0', '1.0.1'), isFalse);
  });
}
