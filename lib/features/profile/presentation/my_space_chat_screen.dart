// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/lunaria_colors.dart';
import '../../../shared/widgets/lunaria_card.dart';
import '../domain/my_space_models.dart';
import 'my_space_controller.dart';
import 'my_space_providers.dart';

class MySpaceChatScreen extends ConsumerStatefulWidget {
  const MySpaceChatScreen({
    super.key,
    required this.spaceId,
    required this.currentUserId,
    required this.partner,
  });

  final String spaceId;
  final String currentUserId;
  final LunaParticipant partner;

  @override
  ConsumerState<MySpaceChatScreen> createState() => _MySpaceChatScreenState();
}

class _MySpaceChatScreenState extends ConsumerState<MySpaceChatScreen> {
  final _message = TextEditingController();
  final _picker = ImagePicker();
  late final MySpaceChatController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MySpaceChatController(
      repository: ref.read(mySpaceRepositoryProvider),
      spaceId: widget.spaceId,
      currentUserId: widget.currentUserId,
      partnerId: widget.partner.userId,
    )..start();
  }

  @override
  void dispose() {
    _message.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => Scaffold(
      backgroundColor: const Color(0xFFFBF8FD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBF8FD),
        titleSpacing: 4,
        title: Row(
          children: [
            _Avatar(url: widget.partner.avatarUrl, name: widget.partner.name),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.partner.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    _presenceLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _controller.isPartnerOnline
                          ? LunariaColors.success
                          : LunariaColors.plum,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Reconectar y actualizar',
            onPressed: _controller.start,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_controller.realtimeError != null)
            _ChatNotice(
              message:
                  'El historial sigue guardado. La actualización en tiempo '
                  'real no está conectada.',
              isError: false,
            ),
          if (_controller.error != null)
            _ChatNotice(message: _controller.error!, isError: true),
          Expanded(child: _messageList),
          _composer,
        ],
      ),
    ),
  );

  String get _presenceLabel {
    if (!_controller.isRealtimeConnected) return 'Sin conexión en tiempo real';
    return _controller.isPartnerOnline ? 'Activa ahora' : 'Desconectada';
  }

  Widget get _messageList {
    if (_controller.isLoading && _controller.messages.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: LunariaColors.plum),
      );
    }
    if (_controller.messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: _EmptyConversation(),
        ),
      );
    }
    return ListView.builder(
      reverse: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      itemCount:
          _controller.messages.length + (_controller.hasOlderMessages ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _controller.messages.length) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TextButton.icon(
                onPressed: _controller.isLoadingOlder
                    ? null
                    : _controller.loadOlderMessages,
                icon: _controller.isLoadingOlder
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.history),
                label: Text(
                  _controller.isLoadingOlder
                      ? 'Cargando…'
                      : 'Cargar mensajes anteriores',
                ),
              ),
            ),
          );
        }
        final item = _controller.messages[index];
        return _MessageBubble(
          message: item,
          isMine: item.senderId == widget.currentUserId,
        );
      },
    );
  }

  Widget get _composer => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton.filledTonal(
            tooltip: 'Enviar imagen',
            onPressed: _controller.isSending ? null : _pickImage,
            icon: const Icon(Icons.image_outlined),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _message,
              minLines: 1,
              maxLines: 5,
              maxLength: 4000,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _sendText(),
              decoration: const InputDecoration(
                hintText: 'Escribe un mensaje…',
                counterText: '',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: 'Enviar mensaje',
            onPressed: _controller.isSending || _message.text.trim().isEmpty
                ? null
                : _sendText,
            icon: _controller.isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded),
          ),
        ],
      ),
    ),
  );

  Future<void> _sendText() async {
    final text = _message.text.trim();
    if (text.isEmpty || _controller.isSending) return;
    try {
      await _controller.sendText(text);
      if (mounted) {
        _message.clear();
        setState(() {});
      }
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _pickImage() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1600,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      await _controller.sendImage(bytes: bytes, fileName: file.name);
    } catch (error) {
      if (mounted) _showError(error);
    }
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

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final LunaMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final alignment = isMine ? Alignment.centerRight : Alignment.centerLeft;
    final background = isMine ? const Color(0xFFF0EAF6) : Colors.white;
    final time = message.createdAt.toLocal();
    final timestamp =
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .80,
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMine) ...[
                _Avatar(url: message.senderAvatarUrl, name: message.senderName),
                const SizedBox(width: 7),
              ],
              Flexible(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            message.senderName,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: LunariaColors.plum,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        if (message.messageType == 'image' &&
                            message.mediaUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              message.mediaUrl!,
                              width: 230,
                              height: 230,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const SizedBox(
                                  width: 230,
                                  height: 200,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: LunariaColors.plum,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (_, _, _) => const SizedBox(
                                width: 230,
                                height: 100,
                                child: Center(
                                  child: Text('No se pudo cargar la imagen.'),
                                ),
                              ),
                            ),
                          )
                        else if (message.messageType == 'audio')
                          const Text('Audio guardado; reproducción no disponible.')
                        else
                          Text(message.body),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              timestamp,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: LunariaColors.plum),
                            ),
                            if (isMine) ...[
                              const SizedBox(width: 4),
                              Icon(
                                message.isReadByPartner
                                    ? Icons.done_all
                                    : Icons.done,
                                size: 15,
                                color: message.isReadByPartner
                                    ? LunariaColors.rose
                                    : LunariaColors.plum,
                                semanticLabel: message.isReadByPartner
                                    ? 'Leído'
                                    : 'Enviado',
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (isMine) ...[
                const SizedBox(width: 7),
                _Avatar(url: message.senderAvatarUrl, name: message.senderName),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.name});

  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 19,
    backgroundColor: LunariaColors.blush,
    backgroundImage: url == null ? null : NetworkImage(url!),
    child: url == null
        ? Text(
            name.isEmpty ? '?' : name.characters.first.toUpperCase(),
            style: const TextStyle(
              color: LunariaColors.plum,
              fontWeight: FontWeight.w800,
            ),
          )
        : null,
  );
}

class _ChatNotice extends StatelessWidget {
  const _ChatNotice({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
    child: LunariaCard(
      color: isError ? const Color(0xFFFFF0F2) : const Color(0xFFF0EAF6),
      padding: const EdgeInsets.all(10),
      child: Text(
        message,
        style: TextStyle(
          color: isError ? LunariaColors.danger : LunariaColors.plumDark,
        ),
      ),
    ),
  );
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(
        Icons.forum_outlined,
        size: 34,
        color: LunariaColors.plum,
      ),
      const SizedBox(height: 10),
      Text(
        'Aquí empieza su conversación',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 4),
      const Text(
        'Este chat privado solo es visible para las dos personas de Mi Luna.',
        textAlign: TextAlign.center,
      ),
    ],
  );
}
