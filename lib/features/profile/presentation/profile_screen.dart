// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/lunaria_colors.dart';
import '../../../core/providers.dart';
import '../../../core/services/supabase_config.dart';
import '../../../shared/widgets/lunaria_card.dart';
import '../../../shared/widgets/lunaria_scaffold.dart';
import '../domain/my_space_models.dart';
import 'app_update_section.dart';
import 'my_space_chat_screen.dart';
import 'my_space_controller.dart';
import 'my_space_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _inviteCode = TextEditingController();
  final _imagePicker = ImagePicker();
  String? _loadedProfileId;
  bool _giftVisible = false;

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _inviteCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(mySpaceControllerProvider);
    final snapshot = controller.snapshot;
    final authenticated = supabase?.auth.currentSession != null;
    if (snapshot != null && snapshot.profile.id != _loadedProfileId) {
      _loadedProfileId = snapshot.profile.id;
      _name.text = snapshot.profile.name;
      _bio.text = snapshot.profile.bio;
    }

    return LunariaScaffold(
      backgroundColor: const Color(0xFFFBF8FD),
      children: [
        Text('My Space', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(
          'Tu espacio personal y privado.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        if (controller.error != null && snapshot != null) ...[
          const SizedBox(height: 12),
          _ErrorCard(
            message: controller.error!,
            onRetry: controller.isLoading ? null : controller.load,
          ),
        ],
        const SizedBox(height: 22),
        if (snapshot == null)
          _ProfileLoadingCard(
            isLoading: controller.isLoading,
            error: controller.error,
            onRetry: controller.isLoading ? null : controller.load,
          )
        else
          _profileCard(context, controller, snapshot.profile),
        const SizedBox(height: 14),
        if (snapshot != null) _interestsCard(),
        const SizedBox(height: 24),
        _myLunaSection(
          context,
          controller,
          snapshot?.space,
          authenticated,
          snapshot?.profile,
        ),
        const SizedBox(height: 20),
        TextButton.icon(
          onPressed: () => setState(() => _giftVisible = !_giftVisible),
          icon: const Icon(Icons.auto_awesome_outlined),
          label: const Text('Pequeño secreto'),
        ),
        if (_giftVisible)
          LunariaCard(
            child: Text(
              'Alguien creó este pequeño universo pensando en ti.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        const SizedBox(height: 18),
        const AppUpdateSection(),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar sesión'),
          style: OutlinedButton.styleFrom(
            foregroundColor: LunariaColors.plumDark,
            side: const BorderSide(color: LunariaColors.mauve),
          ),
        ),
      ],
    );
  }

  Widget _profileCard(
    BuildContext context,
    MySpaceController controller,
    MySpaceProfile profile,
  ) {
    final dirty =
        _name.text.trim() != profile.name || _bio.text.trim() != profile.bio;
    return LunariaCard(
      color: const Color(0xFFFFFCFE),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                _ProfileAvatar(
                  url: profile.avatarUrl,
                  name: profile.name,
                  radius: 46,
                ),
                const SizedBox(height: 8),
                Text(
                  profile.name.isEmpty ? 'Tu perfil' : profile.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: controller.isSaving ? null : _pickAvatar,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(
                    profile.avatarPath == null ? 'Añadir foto' : 'Cambiar foto',
                  ),
                ),
                if (profile.avatarPath != null)
                  TextButton(
                    onPressed: controller.isSaving
                        ? null
                        : () => _mutate(
                            controller.removeAvatar,
                            'Foto eliminada.',
                          ),
                    child: const Text('Quitar foto'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _name,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nombre'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _bio,
            maxLength: 500,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Biografía',
              hintText: 'Unas palabras sobre ti…',
              alignLabelWithHint: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: !dirty || controller.isSaving
                ? null
                : () => _mutate(
                    () => controller.saveProfile(
                      name: _name.text,
                      bio: _bio.text,
                    ),
                    'Tu perfil quedó guardado.',
                  ),
            child: Text(controller.isSaving ? 'Guardando…' : 'Guardar perfil'),
          ),
        ],
      ),
    );
  }

  Widget _interestsCard() {
    final interests = ref.watch(lunariaStoreProvider).interests;
    if (interests.isEmpty) return const SizedBox.shrink();
    return LunariaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mis intereses', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: interests
                .map(
                  (interest) => Chip(
                    label: Text(interest),
                    backgroundColor: LunariaColors.softPink,
                    side: BorderSide.none,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _myLunaSection(
    BuildContext context,
    MySpaceController controller,
    LunaSpace? space,
    bool authenticated,
    MySpaceProfile? profile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mi Luna', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (!authenticated)
          const _EmptySpaceCard(
            icon: Icons.lock_outline,
            title: 'Mi Luna',
            message:
                'Inicia sesión y conecta Supabase para crear o usar una '
                'invitación.',
          )
        else if (controller.isLoading && space == null)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(22),
              child: CircularProgressIndicator(color: LunariaColors.plum),
            ),
          )
        else if (space == null)
          _buildJoinCreateCard(controller)
        else if (space.isDeleting)
          _buildDeletionCard(controller, space)
        else
          _buildActiveSpaceCard(context, controller, space, profile),
      ],
    );
  }

  Widget _buildJoinCreateCard(MySpaceController controller) => LunariaCard(
    color: const Color(0xFFF0EAF6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _inviteCode,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.none,
          maxLength: 64,
          decoration: const InputDecoration(
            labelText: 'Ingresa código promocional',
            hintText: 'Pega tu código de invitación',
            counterText: '',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: controller.isSaving
              ? null
              : () => _mutate(controller.createSpace, 'Mi Luna está listo.'),
          icon: const Icon(Icons.nightlight_round),
          label: const Text('Crear Mi Luna'),
        ),
        const SizedBox(height: 18),
        FilledButton.tonalIcon(
          onPressed:
              controller.isSaving ||
                  _inviteCode.text.replaceAll(RegExp(r'\s+'), '').isEmpty
              ? null
              : () => _mutate(() async {
                  await controller.acceptInvitation(_inviteCode.text);
                  _inviteCode.clear();
                  setState(() {});
                }, 'Te uniste al espacio.'),
          icon: const Icon(Icons.link),
          label: const Text('Unirme con un código'),
        ),
      ],
    ),
  );

  Widget _buildDeletionCard(
    MySpaceController controller,
    LunaSpace space,
  ) => LunariaCard(
    color: const Color(0xFFFFF0F2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Eliminación pendiente',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: LunariaColors.danger),
        ),
        const SizedBox(height: 6),
        const Text(
          'El acceso está bloqueado. Falta completar la limpieza de archivos '
          'privados; puedes reintentar sin exponer el chat.',
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: controller.isSaving
              ? null
              : () => _mutate(controller.deleteSpace, 'Mi Luna se eliminó.'),
          child: const Text('Reintentar eliminación'),
        ),
      ],
    ),
  );

  Widget _buildActiveSpaceCard(
    BuildContext context,
    MySpaceController controller,
    LunaSpace space,
    MySpaceProfile? profile,
  ) {
    final currentUserId = supabase?.auth.currentUser?.id ?? '';
    final partner = space.partnerFor(currentUserId);
    return LunariaCard(
      color: const Color(0xFFFFFCFE),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.nightlight_round,
                color: LunariaColors.plum,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Mi Luna',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                space.isPaired ? 'Conectadas' : 'Esperando a alguien',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _Participant(
                name: profile?.name.isNotEmpty == true ? profile!.name : 'Tú',
                avatarUrl: profile?.avatarUrl,
                isCurrent: true,
              ),
              if (partner != null)
                _Participant(
                  name: partner.name,
                  avatarUrl: partner.avatarUrl,
                  isCurrent: false,
                )
              else
                const _WaitingParticipant(),
            ],
          ),
          if (controller.inviteCode != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: LunariaColors.softPink,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Código de un solo uso',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    controller.inviteCode!,
                    style: const TextStyle(
                      color: LunariaColors.plumDark,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _copyInvite(controller.inviteCode!),
                    icon: const Icon(Icons.copy),
                    label: const Text('Copiar código'),
                  ),
                ],
              ),
            ),
          ] else if (!space.isPaired) ...[
            const SizedBox(height: 12),
            const Text(
              'Los códigos caducan en siete días y solo se muestran una vez. '
              'Genera uno nuevo si no lo guardaste.',
            ),
          ],
          if (space.isPaired) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () {
                final other = partner;
                if (other == null || profile == null) return;
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MySpaceChatScreen(
                      spaceId: space.id,
                      currentUserId: currentUserId,
                      partner: other,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.forum_outlined),
              label: const Text('Abrir chat privado'),
            ),
          ] else ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: controller.isSaving
                  ? null
                  : () => _mutate(
                      controller.createInvitation,
                      'Código nuevo. El anterior dejó de funcionar.',
                    ),
              icon: const Icon(Icons.refresh),
              label: const Text('Crear o renovar invitación'),
            ),
            TextButton(
              onPressed: controller.isSaving
                  ? null
                  : () => _mutate(
                      controller.revokeInvitations,
                      'Invitaciones revocadas.',
                    ),
              child: const Text('Revocar invitaciones'),
            ),
          ],
          const Divider(height: 24),
          TextButton.icon(
            onPressed: controller.isSaving
                ? null
                : () => _confirmDeleteSpace(controller),
            icon: const Icon(Icons.link_off, color: LunariaColors.danger),
            label: const Text(
              'Desvincular y eliminar el espacio',
              style: TextStyle(color: LunariaColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAvatar() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 86,
        maxWidth: 1400,
      );
      if (image == null || !mounted) return;
      final bytes = await image.readAsBytes();
      await _mutate(
        () => ref
            .read(mySpaceControllerProvider)
            .uploadAvatar(bytes: bytes, fileName: image.name),
        'Tu foto de perfil quedó guardada.',
      );
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _confirmDeleteSpace(MySpaceController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Mi Luna'),
        content: const Text(
          'Se eliminará inmediatamente para ambas personas el espacio, las '
          'invitaciones, el historial del chat y sus archivos. No se puede '
          'deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Conservar Mi Luna'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: LunariaColors.danger,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar para ambas'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _mutate(controller.deleteSpace, 'Mi Luna se eliminó para ambas.');
    }
  }

  Future<void> _copyInvite(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) _showMessage('Código copiado.');
  }

  Future<void> _logout() async {
    try {
      if (supabase != null) await supabase!.auth.signOut();
      await ref.read(lunariaStoreProvider).logout();
      if (mounted) context.go('/login');
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _mutate(Future<void> Function() action, String success) async {
    try {
      await action();
      if (mounted) _showMessage(success);
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: LunariaColors.danger,
          duration: const Duration(seconds: 6),
        ),
      );
  }
}

class _ProfileLoadingCard extends StatelessWidget {
  const _ProfileLoadingCard({
    required this.isLoading,
    required this.error,
    required this.onRetry,
  });

  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => LunariaCard(
    child: Column(
      children: [
        if (isLoading)
          const CircularProgressIndicator(color: LunariaColors.plum)
        else
          SelectableText(
            error ?? 'No se pudo cargar el perfil. Intenta de nuevo.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: LunariaColors.danger),
          ),
        if (onRetry != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Volver a intentar'),
          ),
        ],
      ],
    ),
  );
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.url,
    required this.name,
    required this.radius,
  });

  final String? url;
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: LunariaColors.blush,
    child: ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: url == null
            ? Center(
                child: Text(
                  name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                  style: const TextStyle(
                    color: LunariaColors.plum,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Center(
                  child: Text(
                    name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                    style: const TextStyle(
                      color: LunariaColors.plum,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
      ),
    ),
  );
}

class _Participant extends StatelessWidget {
  const _Participant({
    required this.name,
    required this.avatarUrl,
    required this.isCurrent,
  });

  final String name;
  final String? avatarUrl;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _ProfileAvatar(url: avatarUrl, name: name, radius: 21),
      const SizedBox(width: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: Theme.of(context).textTheme.titleSmall),
          Text(
            isCurrent ? 'Tú' : 'Tu persona',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ],
  );
}

class _WaitingParticipant extends StatelessWidget {
  const _WaitingParticipant();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const CircleAvatar(
        radius: 21,
        backgroundColor: LunariaColors.lavender,
        child: Icon(Icons.person_outline, color: LunariaColors.plum),
      ),
      const SizedBox(width: 8),
      Text('Espacio disponible', style: Theme.of(context).textTheme.bodyMedium),
    ],
  );
}

class _EmptySpaceCard extends StatelessWidget {
  const _EmptySpaceCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => LunariaCard(
    color: const Color(0xFFFFFCFE),
    child: Column(
      children: [
        Icon(icon, size: 28, color: LunariaColors.plum),
        const SizedBox(height: 8),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => LunariaCard(
    color: const Color(0xFFFFF0F2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          message,
          style: const TextStyle(color: LunariaColors.danger),
        ),
        if (onRetry != null)
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Volver a intentar'),
          ),
      ],
    ),
  );
}
