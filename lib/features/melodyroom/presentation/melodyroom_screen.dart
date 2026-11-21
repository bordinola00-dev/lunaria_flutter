// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/lunaria_colors.dart';
import '../../../core/services/supabase_config.dart';
import '../../../shared/widgets/lunaria_card.dart';
import '../../../shared/widgets/lunaria_scaffold.dart';
import '../domain/library_models.dart';
import 'library_controller.dart';
import 'library_providers.dart';

class MelodyRoomScreen extends ConsumerWidget {
  const MelodyRoomScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(libraryControllerProvider);
    final canEdit = supabase?.auth.currentSession != null;

    return LunariaScaffold(
      backgroundColor: const Color(0xFFFBF8FD),
      children: [
        Text(
          'Tu mundo musical',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 5),
        Text(
          'Canciones, recuerdos y listas elegidas por ti.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 18),
        const _SpotifyNotice(),
        if (!canEdit) ...[
          const SizedBox(height: 12),
          const _NoticeCard(
            icon: Icons.lock_outline,
            text:
                'Inicia sesión con una cuenta de Lunaria y configura Supabase '
                'para guardar tu biblioteca de forma privada.',
          ),
        ],
        if (controller.error != null) ...[
          const SizedBox(height: 12),
          _ErrorNotice(
            message: controller.error!,
            onRetry: controller.isLoading ? null : controller.refresh,
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Tu biblioteca',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: !canEdit || controller.isSaving
                  ? null
                  : () => _editSong(context, controller),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Añadir'),
            ),
          ],
        ),
        if (controller.isLoading)
          const Padding(
            padding: EdgeInsets.all(28),
            child: Center(
              child: CircularProgressIndicator(color: LunariaColors.plum),
            ),
          )
        else if (controller.songs.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: _EmptyCard(
              icon: Icons.music_note_rounded,
              title: 'Tu biblioteca empieza contigo',
              message:
                  'Añade una canción de Spotify con su enlace para guardarla '
                  'y escribir qué significa para ti.',
            ),
          )
        else
          ...controller.songs.map(
            (song) => Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _SongCard(
                song: song,
                enabled: canEdit && !controller.isSaving,
                onFavorite: () => _run(
                  context,
                  () => controller.toggleFavorite(song),
                  song.isFavorite
                      ? 'Canción retirada de favoritas.'
                      : 'Canción guardada en favoritas.',
                ),
                onEdit: () => _editSong(context, controller, song),
                onDelete: () => _deleteSong(context, controller, song),
                onReflection: () =>
                    _editReflection(context, controller, song),
                onOpen: () => _openSpotify(context, song.spotifyUrl),
              ),
            ),
          ),
        const SizedBox(height: 28),
        _SectionTitle(
          title: 'Mis favoritas',
          detail: '${controller.favorites.length}',
        ),
        if (controller.favorites.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: _InlineNotice(
              text: 'Tus canciones favoritas aparecerán aquí.',
            ),
          )
        else
          ...controller.favorites.map(
            (song) => Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _SongCard(
                song: song,
                enabled: canEdit && !controller.isSaving,
                compact: true,
                onFavorite: () => _run(
                  context,
                  () => controller.toggleFavorite(song),
                  'Canción retirada de favoritas.',
                ),
                onEdit: () => _editSong(context, controller, song),
                onDelete: () => _deleteSong(context, controller, song),
                onReflection: () =>
                    _editReflection(context, controller, song),
                onOpen: () => _openSpotify(context, song.spotifyUrl),
              ),
            ),
          ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: Text(
                'Mis playlists',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Crear playlist',
              onPressed: !canEdit || controller.isSaving
                  ? null
                  : () => _editPlaylist(context, controller),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        if (controller.playlists.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: _InlineNotice(
              text: 'Crea una playlist personal para ordenar tus canciones.',
            ),
          )
        else
          ...controller.playlists.map(
            (playlist) => Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _PlaylistCard(
                playlist: playlist,
                songs: controller.songs,
                enabled: canEdit && !controller.isSaving,
                onEdit: () => _editPlaylist(context, controller, playlist),
                onDelete: () =>
                    _deletePlaylist(context, controller, playlist),
                onToggleSong: (songId, selected) => _run(
                  context,
                  () => selected
                      ? controller.addSongToPlaylist(playlist.id, songId)
                      : controller.removeSongFromPlaylist(
                          playlist.id,
                          songId,
                        ),
                  selected ? 'Añadida a la playlist.' : 'Quitada de la playlist.',
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _editSong(
    BuildContext context,
    LibraryController controller, [
    MelodySong? song,
  ]) async {
    final draft = await showModalBottomSheet<_SongDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SongForm(song: song),
    );
    if (draft == null || !context.mounted) return;
    await _run(
      context,
      () => song == null
          ? controller.addSong(
              title: draft.title,
              artist: draft.artist,
              spotifyUrl: draft.spotifyUrl,
              coverUrl: draft.coverUrl,
            )
          : controller.updateSong(
              song: song,
              title: draft.title,
              artist: draft.artist,
              spotifyUrl: draft.spotifyUrl,
              coverUrl: draft.coverUrl,
            ),
      song == null ? 'Canción guardada.' : 'Canción actualizada.',
    );
  }

  Future<void> _editReflection(
    BuildContext context,
    LibraryController controller,
    MelodySong song,
  ) async {
    final reflection = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ReflectionForm(song: song),
    );
    if (reflection == null || !context.mounted) return;
    await _run(
      context,
      () => controller.saveReflection(song.id, reflection),
      'Tu recuerdo quedó guardado.',
    );
  }

  Future<void> _editPlaylist(
    BuildContext context,
    LibraryController controller, [
    MelodyPlaylist? playlist,
  ]) async {
    final draft = await showModalBottomSheet<_PlaylistDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PlaylistForm(playlist: playlist),
    );
    if (draft == null || !context.mounted) return;
    await _run(
      context,
      () => playlist == null
          ? controller.createPlaylist(
              name: draft.name,
              description: draft.description,
            )
          : controller.updatePlaylist(
              playlistId: playlist.id,
              name: draft.name,
              description: draft.description,
            ),
      playlist == null ? 'Playlist creada.' : 'Playlist actualizada.',
    );
  }

  Future<void> _deleteSong(
    BuildContext context,
    LibraryController controller,
    MelodySong song,
  ) async {
    final accepted = await _confirm(
      context,
      title: 'Eliminar canción',
      message: 'Se eliminará de la biblioteca y de las playlists.',
      confirmLabel: 'Eliminar',
    );
    if (accepted && context.mounted) {
      await _run(
        context,
        () => controller.deleteSong(song.id),
        'Canción eliminada.',
      );
    }
  }

  Future<void> _deletePlaylist(
    BuildContext context,
    LibraryController controller,
    MelodyPlaylist playlist,
  ) async {
    final accepted = await _confirm(
      context,
      title: 'Eliminar playlist',
      message: 'Las canciones permanecerán en tu biblioteca.',
      confirmLabel: 'Eliminar',
    );
    if (accepted && context.mounted) {
      await _run(
        context,
        () => controller.deletePlaylist(playlist.id),
        'Playlist eliminada.',
      );
    }
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _openSpotify(BuildContext context, String? url) async {
    final link = SpotifyTrackLink.parse(url ?? '');
    if (link == null) {
      _showMessage(context, 'Esta canción no tiene un enlace válido.');
      return;
    }
    try {
      final opened = await launchUrl(
        Uri.parse(link.canonicalUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && context.mounted) {
        _showMessage(context, 'No se pudo abrir Spotify en este dispositivo.');
      }
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
    String success,
  ) async {
    try {
      await action();
      if (context.mounted) _showMessage(context, success);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(BuildContext context, Object error) {
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

class _SpotifyNotice extends StatelessWidget {
  const _SpotifyNotice();

  @override
  Widget build(BuildContext context) => const _NoticeCard(
    icon: Icons.info_outline,
    text:
        'La conexión directa con Spotify todavía no está disponible. '
        'Puedes guardar canciones manualmente con su enlace oficial.',
  );
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => LunariaCard(
    color: const Color(0xFFF0EAF6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: LunariaColors.plum, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => LunariaCard(
    color: const Color(0xFFFFF0F2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: const TextStyle(color: LunariaColors.danger)),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      Text(detail, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
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
        Icon(icon, size: 32, color: LunariaColors.rose),
        const SizedBox(height: 10),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 5),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => LunariaCard(
    color: const Color(0xFFFFFCFE),
    child: Text(text, textAlign: TextAlign.center),
  );
}

class _SongCard extends StatelessWidget {
  const _SongCard({
    required this.song,
    required this.enabled,
    required this.onFavorite,
    required this.onEdit,
    required this.onDelete,
    required this.onReflection,
    required this.onOpen,
    this.compact = false,
  });

  final MelodySong song;
  final bool enabled;
  final bool compact;
  final VoidCallback onFavorite;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onReflection;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => LunariaCard(
    color: Colors.white,
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Cover(url: song.coverUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title?.trim().isNotEmpty == true
                        ? song.title!
                        : 'Canción guardada anteriormente',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: LunariaColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    song.artist?.trim().isNotEmpty == true
                        ? song.artist!
                        : 'Completa sus datos para mostrarla en tu biblioteca.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: song.isFavorite
                  ? 'Quitar de favoritas'
                  : 'Marcar como favorita',
              onPressed: enabled ? onFavorite : null,
              icon: Icon(
                song.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: song.isFavorite ? LunariaColors.rose : LunariaColors.plum,
              ),
            ),
          ],
        ),
        if (song.reflection.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7FB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              song.reflection,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: LunariaColors.plumDark,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
        Wrap(
          alignment: WrapAlignment.start,
          spacing: 2,
          children: [
            TextButton.icon(
              onPressed: enabled ? onReflection : null,
              icon: const Icon(Icons.edit_note_outlined),
              label: Text(song.reflection.isEmpty ? 'Añadir recuerdo' : 'Editar recuerdo'),
            ),
            IconButton(
              tooltip: 'Abrir en Spotify',
              onPressed: song.spotifyUrl == null ? null : onOpen,
              icon: const Icon(Icons.open_in_new),
            ),
            if (!compact)
              IconButton(
                tooltip: 'Editar canción',
                onPressed: enabled ? onEdit : null,
                icon: const Icon(Icons.edit_outlined),
              ),
            if (!compact)
              IconButton(
                tooltip: 'Eliminar canción',
                onPressed: enabled ? onDelete : null,
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
      ],
    ),
  );
}

class _Cover extends StatelessWidget {
  const _Cover({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(13),
    child: SizedBox(
      width: 58,
      height: 58,
      child: url == null || url!.isEmpty
          ? const ColoredBox(
              color: LunariaColors.lavender,
              child: Icon(Icons.music_note, color: LunariaColors.plum),
            )
          : Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: LunariaColors.lavender,
                child: Icon(Icons.music_note, color: LunariaColors.plum),
              ),
            ),
    ),
  );
}

class _SongDraft {
  const _SongDraft({
    required this.title,
    required this.artist,
    required this.spotifyUrl,
    required this.coverUrl,
  });

  final String title;
  final String artist;
  final String spotifyUrl;
  final String? coverUrl;
}

class _SongForm extends StatefulWidget {
  const _SongForm({this.song});

  final MelodySong? song;

  @override
  State<_SongForm> createState() => _SongFormState();
}

class _SongFormState extends State<_SongForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _artist;
  late final TextEditingController _spotifyUrl;
  late final TextEditingController _coverUrl;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.song?.title ?? '');
    _artist = TextEditingController(text: widget.song?.artist ?? '');
    _spotifyUrl = TextEditingController(text: widget.song?.spotifyUrl ?? '');
    _coverUrl = TextEditingController(text: widget.song?.coverUrl ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    _spotifyUrl.dispose();
    _coverUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      10,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.song == null ? 'Añadir canción' : 'Editar canción',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _title,
              maxLength: 150,
              decoration: const InputDecoration(labelText: 'Título'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Escribe el título de la canción.'
                  : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _artist,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Artista'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Escribe el nombre del artista.'
                  : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _spotifyUrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Enlace de Spotify',
                hintText: 'https://open.spotify.com/track/…',
              ),
              validator: (value) => SpotifyTrackLink.parse(value ?? '') == null
                  ? 'Usa el enlace de una canción de Spotify.'
                  : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _coverUrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Portada (opcional)',
                hintText: 'https://…',
              ),
              validator: (value) => isValidCoverUrl(value ?? '')
                  ? null
                  : 'Escribe un enlace web válido para la portada.',
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                Navigator.pop(
                  context,
                  _SongDraft(
                    title: _title.text.trim(),
                    artist: _artist.text.trim(),
                    spotifyUrl: _spotifyUrl.text.trim(),
                    coverUrl: _coverUrl.text.trim().isEmpty
                        ? null
                        : _coverUrl.text.trim(),
                  ),
                );
              },
              child: const Text('Guardar canción'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ReflectionForm extends StatefulWidget {
  const _ReflectionForm({required this.song});

  final MelodySong song;

  @override
  State<_ReflectionForm> createState() => _ReflectionFormState();
}

class _ReflectionFormState extends State<_ReflectionForm> {
  late final TextEditingController _reflection;

  @override
  void initState() {
    super.initState();
    _reflection = TextEditingController(text: widget.song.reflection);
  }

  @override
  void dispose() {
    _reflection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      10,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Un recuerdo para esta canción',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text('¿Qué me recuerda o qué siento al escucharla?'),
        const SizedBox(height: 14),
        TextField(
          controller: _reflection,
          maxLength: 2000,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Escribe lo que quieras conservar…',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: () => Navigator.pop(context, _reflection.text),
          child: const Text('Guardar recuerdo'),
        ),
      ],
    ),
  );
}

class _PlaylistDraft {
  const _PlaylistDraft({required this.name, required this.description});

  final String name;
  final String description;
}

class _PlaylistForm extends StatefulWidget {
  const _PlaylistForm({this.playlist});

  final MelodyPlaylist? playlist;

  @override
  State<_PlaylistForm> createState() => _PlaylistFormState();
}

class _PlaylistFormState extends State<_PlaylistForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.playlist?.name ?? '');
    _description = TextEditingController(
      text: widget.playlist?.description ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      10,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.playlist == null ? 'Crear playlist' : 'Editar playlist',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _name,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Nombre'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Escribe un nombre para tu playlist.'
                : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _description,
            maxLength: 500,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Descripción (opcional)',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              Navigator.pop(
                context,
                _PlaylistDraft(
                  name: _name.text.trim(),
                  description: _description.text.trim(),
                ),
              );
            },
            child: const Text('Guardar playlist'),
          ),
        ],
      ),
    ),
  );
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({
    required this.playlist,
    required this.songs,
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleSong,
  });

  final MelodyPlaylist playlist;
  final List<MelodySong> songs;
  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(String songId, bool selected) onToggleSong;

  @override
  Widget build(BuildContext context) => LunariaCard(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    child: ExpansionTile(
      key: PageStorageKey(playlist.id),
      leading: const Icon(Icons.queue_music, color: LunariaColors.plum),
      title: Text(
        playlist.name,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: LunariaColors.plumDark,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        '${playlist.songIds.length} canciones'
        '${playlist.description.isEmpty ? '' : ' · ${playlist.description}'}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'Opciones de playlist',
        onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Editar')),
          PopupMenuItem(value: 'delete', child: Text('Eliminar')),
        ],
      ),
      children: songs.isEmpty
          ? const [
              Padding(
                padding: EdgeInsets.all(14),
                child: Text('Añade canciones a tu biblioteca primero.'),
              ),
            ]
          : songs.map((song) {
              final selected = playlist.songIds.contains(song.id);
              return CheckboxListTile(
                value: selected,
                onChanged: enabled
                    ? (value) => onToggleSong(song.id, value ?? false)
                    : null,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  song.title?.trim().isNotEmpty == true
                      ? song.title!
                      : 'Canción guardada anteriormente',
                ),
                subtitle: Text(song.artist ?? ''),
                secondary: _Cover(url: song.coverUrl),
              );
            }).toList(),
    ),
  );
}
