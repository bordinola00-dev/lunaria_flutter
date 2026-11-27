import 'package:flutter/foundation.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lunaria_flutter/features/profile/data/app_update_repository.dart';
import 'package:lunaria_flutter/features/profile/presentation/app_update_controller.dart';
import 'package:lunaria_flutter/features/profile/presentation/app_update_providers.dart';
import 'package:lunaria_flutter/features/profile/presentation/app_update_section.dart';

void main() {
  testWidgets('shows update state and download action after checking', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appUpdateSourceProvider.overrideWithValue(
            _FakeUpdateSource(
              AppUpdateRelease(
                tagName: 'v1.0.1',
                version: '1.0.1',
                downloadUri: Uri.https(
                  'github.com',
                  '/bordinola00-dev/lunaria_flutter/releases/download/v1.0.1/app-release.apk',
                ),
                releaseUri: Uri.https(
                  'github.com',
                  '/bordinola00-dev/lunaria_flutter/releases/tag/v1.0.1',
                ),
              ),
            ),
          ),
          installedAppVersionLoaderProvider.overrideWithValue(
            () async =>
                const InstalledAppVersion(version: '1.0.0', buildNumber: '1'),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: AppUpdateSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lunaria'), findsOneWidget);
    expect(find.text('Versión 1.0.0 · Compilación 1'), findsOneWidget);
    await tester.tap(find.text('Buscar actualizaciones'));
    await tester.pumpAndSettle();

    expect(find.text('Nueva versión disponible: 1.0.1'), findsOneWidget);
    expect(find.text('Descargar actualización'), findsOneWidget);
    expect(find.textContaining('permite instalar apps'), findsOneWidget);
  });

  testWidgets('explains private IPA installation on iOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appUpdateSourceProvider.overrideWithValue(
            _FakeUpdateSource(
              AppUpdateRelease(
                tagName: 'v1.0.1',
                version: '1.0.1',
                downloadUri: Uri.https(
                  'github.com',
                  '/bordinola00-dev/lunaria_flutter/releases/download/v1.0.1/app-release.ipa',
                ),
                releaseUri: Uri.https(
                  'github.com',
                  '/bordinola00-dev/lunaria_flutter/releases/tag/v1.0.1',
                ),
              ),
            ),
          ),
          installedAppVersionLoaderProvider.overrideWithValue(
            () async =>
                const InstalledAppVersion(version: '1.0.0', buildNumber: '1'),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: AppUpdateSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buscar actualizaciones'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('ábrelo desde AltStore o SideStore'),
      findsOneWidget,
    );
    expect(find.textContaining('renueva la firma cada 7 días'), findsOneWidget);
    expect(find.textContaining('permite instalar apps'), findsNothing);
  });
}

class _FakeUpdateSource implements AppUpdateSource {
  const _FakeUpdateSource(this.release);

  final AppUpdateRelease release;

  @override
  Future<AppUpdateRelease> fetchLatestRelease() async => release;
}
