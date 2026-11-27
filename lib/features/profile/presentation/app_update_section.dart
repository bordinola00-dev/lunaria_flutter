import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/lunaria_colors.dart';
import '../../../shared/widgets/lunaria_card.dart';
import 'app_update_controller.dart';
import 'app_update_providers.dart';

class AppUpdateSection extends ConsumerStatefulWidget {
  const AppUpdateSection({super.key});

  @override
  ConsumerState<AppUpdateSection> createState() => _AppUpdateSectionState();
}

class _AppUpdateSectionState extends ConsumerState<AppUpdateSection> {
  String? _downloadMessage;
  bool _openingDownload = false;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const _WebAppUpdateSection();

    final controller = ref.watch(appUpdateControllerProvider);
    final installed = controller.installedVersion;
    final release = controller.latestRelease;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    return LunariaCard(
      color: const Color(0xFFFFFCFE),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Actualización de Lunaria',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text('Lunaria', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            installed == null
                ? 'Consultando versión instalada…'
                : 'Versión ${installed.version} · Compilación ${installed.buildNumber}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          _UpdateStatus(controller: controller),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed:
                controller.status == AppUpdateStatus.checking ||
                    controller.status == AppUpdateStatus.loadingVersion
                ? null
                : controller.checkForUpdates,
            icon: controller.status == AppUpdateStatus.checking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(
              controller.status == AppUpdateStatus.checking
                  ? 'Buscando actualizaciones…'
                  : 'Buscar actualizaciones',
            ),
          ),
          if (controller.status == AppUpdateStatus.updateAvailable &&
              release != null) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _openingDownload
                  ? null
                  : () => _openDownload(release.downloadUri),
              icon: _openingDownload
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download_outlined),
              label: Text(
                _openingDownload
                    ? 'Abriendo navegador…'
                    : 'Descargar actualización',
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isIOS
                  ? 'Descarga el IPA y ábrelo desde AltStore o SideStore para '
                        'firmarlo e instalarlo. Con una cuenta gratuita, '
                        'renueva la firma cada 7 días.'
                  : 'Se abrirá el navegador; confirma la descarga e instalación. '
                        'Si Android lo solicita, permite instalar apps desde ese '
                        'navegador en Ajustes > Apps > Acceso especial > Instalar apps '
                        'desconocidas.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (_downloadMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _downloadMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _downloadMessage!.startsWith('No se pudo')
                    ? LunariaColors.danger
                    : LunariaColors.success,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openDownload(Uri uri) async {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    setState(() {
      _openingDownload = true;
      _downloadMessage = null;
    });
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      setState(() {
        _downloadMessage = opened
            ? isIOS
                  ? 'Se abrió el navegador. Guarda el IPA y ábrelo desde '
                        'AltStore o SideStore para firmarlo e instalarlo.'
                  : 'Se abrió el navegador. Confirma la descarga para continuar.'
            : 'No se pudo abrir el enlace. Inténtalo de nuevo más tarde.';
      });
    } on PlatformException {
      if (!mounted) return;
      setState(() {
        _downloadMessage = 'No se pudo abrir el navegador. Comprueba que tengas uno instalado.';
      });
    } finally {
      if (mounted) setState(() => _openingDownload = false);
    }
  }
}

class _WebAppUpdateSection extends StatelessWidget {
  const _WebAppUpdateSection();

  @override
  Widget build(BuildContext context) => LunariaCard(
    color: const Color(0xFFFFFCFE),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actualización de Lunaria',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text('Lunaria', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Las actualizaciones se publican en la web. Cierra y vuelve a abrir '
          'Lunaria con conexión para cargar la versión más reciente.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    ),
  );
}

class _UpdateStatus extends StatelessWidget {
  const _UpdateStatus({required this.controller});

  final AppUpdateController controller;

  @override
  Widget build(BuildContext context) {
    final release = controller.latestRelease;
    final (label, icon, color) = switch (controller.status) {
      AppUpdateStatus.loadingVersion => (
        'Preparando información de la versión…',
        Icons.hourglass_empty,
        LunariaColors.plum,
      ),
      AppUpdateStatus.ready => (
        'Busca una versión estable en GitHub.',
        Icons.info_outline,
        LunariaColors.plum,
      ),
      AppUpdateStatus.checking => (
        'Consultando GitHub…',
        Icons.sync,
        LunariaColors.plum,
      ),
      AppUpdateStatus.updateAvailable => (
        'Nueva versión disponible${release == null ? '' : ': ${release.version}'}',
        Icons.system_update_alt,
        LunariaColors.rose,
      ),
      AppUpdateStatus.upToDate => (
        'Tu aplicación está actualizada.',
        Icons.check_circle_outline,
        LunariaColors.success,
      ),
      AppUpdateStatus.error => (
        controller.errorMessage ?? 'No se pudo comprobar la actualización.',
        Icons.error_outline,
        LunariaColors.danger,
      ),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (controller.status == AppUpdateStatus.checking ||
            controller.status == AppUpdateStatus.loadingVersion)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
