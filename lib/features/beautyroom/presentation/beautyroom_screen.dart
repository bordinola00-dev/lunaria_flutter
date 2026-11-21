import 'dart:typed_data';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/lunaria_colors.dart';
import '../../../shared/widgets/lunaria_card.dart';
import '../../../shared/widgets/lunaria_scaffold.dart';
import '../domain/beautyroom_models.dart';
import 'beautyroom_controller.dart';
import 'beautyroom_providers.dart';

const _categories = [
  'maquillaje',
  'skincare',
  'cabello',
  'perfumes',
  'cuerpo',
  'uñas',
  'accesorios',
  'otros',
];

class BeautyRoomScreen extends ConsumerStatefulWidget {
  const BeautyRoomScreen({super.key});

  @override
  ConsumerState<BeautyRoomScreen> createState() => _BeautyRoomScreenState();
}

class _BeautyRoomScreenState extends ConsumerState<BeautyRoomScreen> {
  BeautyRoomController get _controller =>
      ref.read(beautyRoomControllerProvider);

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(beautyRoomControllerProvider);
    return LunariaScaffold(
      backgroundColor: const Color(0xFFFFF9FC),
      children: [
        Text(
          'Tu rincón de belleza',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Guarda tus favoritos y crea looks a tu manera.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: controller.isSaving ? null : () => _editProduct(),
              icon: const Icon(Icons.add),
              label: const Text('Añadir producto'),
              style: FilledButton.styleFrom(
                backgroundColor: LunariaColors.rose,
              ),
            ),
            OutlinedButton.icon(
              onPressed: controller.isSaving
                  ? null
                  : () => _editLook(products: controller.products),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Crear look'),
              style: OutlinedButton.styleFrom(
                foregroundColor: LunariaColors.plum,
                side: const BorderSide(color: LunariaColors.mauve),
              ),
            ),
          ],
        ),
        if (controller.isLoading) ...[
          const SizedBox(height: 32),
          const Center(
            child: CircularProgressIndicator(color: LunariaColors.rose),
          ),
        ] else if (controller.error != null) ...[
          const SizedBox(height: 18),
          LunariaCard(
            color: const Color(0xFFFFF0F2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No se pudo cargar tu BeautyRoom',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: LunariaColors.danger),
                ),
                const SizedBox(height: 6),
                SelectableText(controller.error!),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: controller.isSaving
                      ? null
                      : () => _controller.load(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Volver a intentar'),
                ),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: 28),
          _SectionHeading(
            title: 'Mi colección',
            detail: '${controller.products.length} productos',
          ),
          const SizedBox(height: 12),
          if (controller.products.isEmpty)
            const _EmptyState(
              icon: Icons.spa_outlined,
              title: 'Tu colección empieza aquí',
              message:
                  'Añade tus productos favoritos para tenerlos siempre a mano.',
            )
          else
            ...controller.products.map(
              (product) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ProductTile(
                  product: product,
                  busy: controller.isSaving,
                  onEdit: () => _editProduct(product: product),
                  onDelete: () => _deleteProduct(product),
                  onOpenLink: product.productUrl == null
                      ? null
                      : () => _openLink(product.productUrl!),
                ),
              ),
            ),
          const SizedBox(height: 20),
          _SectionHeading(
            title: 'Mis looks',
            detail: '${controller.looks.length} looks',
          ),
          const SizedBox(height: 12),
          if (controller.looks.isEmpty)
            const _EmptyState(
              icon: Icons.auto_awesome_outlined,
              title: 'Aún no has creado looks',
              message: 'Combina productos de tu colección y guarda tus ideas favoritas.',
            )
          else
            ...controller.looks.map(
              (look) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _LookTile(
                  look: look,
                  products: controller.products,
                  busy: controller.isSaving,
                  onEdit: () =>
                      _editLook(look: look, products: controller.products),
                  onDelete: () => _deleteLook(look),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _editProduct({BeautyProduct? product}) async {
    final draft = await showModalBottomSheet<_ProductDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ProductForm(product: product),
    );
    if (draft == null || !mounted) return;
    try {
      if (product == null) {
        await _controller.createProduct(
          name: draft.name,
          brand: draft.brand,
          category: draft.category,
          shade: draft.shade,
          productUrl: draft.productUrl,
          imageUrl: draft.imageUrl,
          imageBytes: draft.imageBytes,
          imageFileName: draft.imageFileName,
        );
      } else {
        await _controller.updateProduct(
          product: product,
          name: draft.name,
          brand: draft.brand,
          category: draft.category,
          shade: draft.shade,
          productUrl: draft.productUrl,
          imageUrl: draft.imageUrl,
          imageBytes: draft.imageBytes,
          imageFileName: draft.imageFileName,
          removeImage: draft.removeImage,
        );
      }
      if (mounted) {
        _showMessage(
          product == null ? 'Producto guardado.' : 'Producto actualizado.',
        );
      }
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _editLook({
    BeautyLook? look,
    required List<BeautyProduct> products,
  }) async {
    final draft = await showModalBottomSheet<_LookDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _LookForm(look: look, products: products),
    );
    if (draft == null || !mounted) return;
    try {
      if (look == null) {
        await _controller.createLook(
          name: draft.name,
          description: draft.description,
          productIds: draft.productIds,
          imageUrl: draft.imageUrl,
          imageBytes: draft.imageBytes,
          imageFileName: draft.imageFileName,
        );
      } else {
        await _controller.updateLook(
          look: look,
          name: draft.name,
          description: draft.description,
          productIds: draft.productIds,
          imageUrl: draft.imageUrl,
          imageBytes: draft.imageBytes,
          imageFileName: draft.imageFileName,
          removeImage: draft.removeImage,
        );
      }
      if (mounted) {
        _showMessage(look == null ? 'Look guardado.' : 'Look actualizado.');
      }
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _deleteProduct(BeautyProduct product) async {
    final confirmed = await _confirmDelete(
      title: '¿Eliminar producto?',
      message: '“${product.name}” se quitará de tu colección.',
    );
    if (!confirmed || !mounted) return;
    try {
      await _controller.deleteProduct(product);
      if (mounted) _showMessage('Producto eliminado.');
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _deleteLook(BeautyLook look) async {
    final confirmed = await _confirmDelete(
      title: '¿Eliminar look?',
      message: '“${look.name}” se quitará de tus looks guardados.',
    );
    if (!confirmed || !mounted) return;
    try {
      await _controller.deleteLook(look);
      if (mounted) _showMessage('Look eliminado.');
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<bool> _confirmDelete({
    required String title,
    required String message,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(
                  backgroundColor: LunariaColors.danger,
                ),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (mounted) _showMessage('No se pudo abrir el enlace.');
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          mounted) {
        _showMessage('No se pudo abrir el enlace.');
      }
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
    final detail = _controller.error ?? error.toString();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(detail),
          backgroundColor: LunariaColors.danger,
          duration: const Duration(seconds: 6),
        ),
      );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenLink,
  });

  final BeautyProduct product;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onOpenLink;

  @override
  Widget build(BuildContext context) {
    final details = [
      product.brand,
      product.category,
      product.shade,
    ].where((value) => value.trim().isNotEmpty).join(' · ');
    return LunariaCard(
      child: Row(
        children: [
          _ImagePreview(url: product.displayImageUrl, size: 66),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: LunariaColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(details, style: Theme.of(context).textTheme.bodySmall),
                ],
                if (onOpenLink != null)
                  TextButton.icon(
                    onPressed: onOpenLink,
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Ver producto'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 34),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            enabled: !busy,
            tooltip: 'Opciones del producto',
            onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Editar')),
              PopupMenuItem(value: 'delete', child: Text('Eliminar')),
            ],
          ),
        ],
      ),
    );
  }
}

class _LookTile extends StatelessWidget {
  const _LookTile({
    required this.look,
    required this.products,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
  });

  final BeautyLook look;
  final List<BeautyProduct> products;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final productNames = products
        .where((product) => look.productIds.contains(product.id))
        .map((product) => product.name)
        .toList();
    return LunariaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ImagePreview(url: look.displayImageUrl, size: 76),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      look.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: LunariaColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (look.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(look.description),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      _formatDate(look.createdAt),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: LunariaColors.plum),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                enabled: !busy,
                tooltip: 'Opciones del look',
                onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
              ),
            ],
          ),
          if (productNames.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: productNames
                  .map((name) => Chip(label: Text(name)))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final image = url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: size,
        height: size,
        child: image == null || image.isEmpty
            ? const ColoredBox(
                color: LunariaColors.softPink,
                child: Icon(Icons.image_outlined, color: LunariaColors.plum),
              )
            : Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: LunariaColors.softPink,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: LunariaColors.plum,
                  ),
                ),
              ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: LunariaColors.plumDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(detail, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return LunariaCard(
      color: const Color(0xFFFFFCFE),
      child: Row(
        children: [
          Icon(icon, size: 30, color: LunariaColors.rose),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: LunariaColors.plumDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductDraft {
  const _ProductDraft({
    required this.name,
    required this.brand,
    required this.category,
    required this.shade,
    required this.productUrl,
    required this.imageUrl,
    required this.imageBytes,
    required this.imageFileName,
    required this.removeImage,
  });

  final String name;
  final String brand;
  final String category;
  final String shade;
  final String? productUrl;
  final String? imageUrl;
  final Uint8List? imageBytes;
  final String? imageFileName;
  final bool removeImage;
}

class _ProductForm extends StatefulWidget {
  const _ProductForm({this.product});

  final BeautyProduct? product;

  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _brand;
  late final TextEditingController _shade;
  late final TextEditingController _productUrl;
  late final TextEditingController _imageUrl;
  late String _category;
  XFile? _selectedImage;
  Uint8List? _imageBytes;
  bool _removeImage = false;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _name = TextEditingController(text: product?.name ?? '');
    _brand = TextEditingController(text: product?.brand ?? '');
    _shade = TextEditingController(text: product?.shade ?? '');
    _productUrl = TextEditingController(text: product?.productUrl ?? '');
    _imageUrl = TextEditingController(text: product?.imageUrl ?? '');
    _category = _categories.contains(product?.category)
        ? product!.category
        : _categories.first;
  }

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _shade.dispose();
    _productUrl.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FormSheet(
      title: widget.product == null ? 'Añadir producto' : 'Editar producto',
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: _requiredValidator,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _brand,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Marca'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: _categories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(_categoryLabel(category)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _shade,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Tono o variante',
                hintText: 'Opcional',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _productUrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Enlace del producto',
                hintText: 'https://…',
              ),
              validator: _urlValidator,
            ),
            const SizedBox(height: 14),
            _ImagePickerField(
              selectedImage: _selectedImage,
              imageBytes: _imageBytes,
              existingImageUrl: widget.product?.displayImageUrl,
              imageUrlController: _imageUrl,
              removeImage: _removeImage,
              onPick: _pickImage,
              onImageUrlChanged: (value) => setState(
                () => _removeImage =
                    value.trim().isNotEmpty &&
                    widget.product?.imagePath != null,
              ),
              onRemoveExisting: () => setState(() {
                _removeImage = true;
                _selectedImage = null;
                _imageBytes = null;
                _imageUrl.clear();
              }),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 86,
        maxWidth: 1800,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedImage = image;
        _imageBytes = bytes;
        _imageUrl.clear();
        _removeImage = false;
      });
    } catch (error) {
      if (mounted) _showPickerError(context, error);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _ProductDraft(
        name: _name.text.trim(),
        brand: _brand.text.trim(),
        category: _category,
        shade: _shade.text.trim(),
        productUrl: _nullableText(_productUrl.text),
        imageUrl: _imageBytes == null ? _nullableText(_imageUrl.text) : null,
        imageBytes: _imageBytes,
        imageFileName: _selectedImage?.name,
        removeImage: _removeImage,
      ),
    );
  }
}

class _LookDraft {
  const _LookDraft({
    required this.name,
    required this.description,
    required this.productIds,
    required this.imageUrl,
    required this.imageBytes,
    required this.imageFileName,
    required this.removeImage,
  });

  final String name;
  final String description;
  final List<String> productIds;
  final String? imageUrl;
  final Uint8List? imageBytes;
  final String? imageFileName;
  final bool removeImage;
}

class _LookForm extends StatefulWidget {
  const _LookForm({this.look, required this.products});

  final BeautyLook? look;
  final List<BeautyProduct> products;

  @override
  State<_LookForm> createState() => _LookFormState();
}

class _LookFormState extends State<_LookForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _imageUrl;
  late Set<String> _productIds;
  XFile? _selectedImage;
  Uint8List? _imageBytes;
  bool _removeImage = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.look?.name ?? '');
    _description = TextEditingController(text: widget.look?.description ?? '');
    _imageUrl = TextEditingController(text: widget.look?.imageUrl ?? '');
    _productIds = widget.look?.productIds.toSet() ?? {};
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FormSheet(
      title: widget.look == null ? 'Crear look' : 'Editar look',
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nombre del look'),
              validator: _requiredValidator,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                hintText: 'Opcional',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Productos de tu colección',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: LunariaColors.plumDark,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (widget.products.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Añade productos para poder asociarlos a un look.'),
              )
            else
              ...widget.products.map(
                (product) => CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _productIds.contains(product.id),
                  title: Text(product.name),
                  subtitle: product.brand.isEmpty ? null : Text(product.brand),
                  activeColor: LunariaColors.rose,
                  onChanged: (selected) => setState(() {
                    if (selected == true) {
                      _productIds.add(product.id);
                    } else {
                      _productIds.remove(product.id);
                    }
                  }),
                ),
              ),
            const SizedBox(height: 10),
            _ImagePickerField(
              selectedImage: _selectedImage,
              imageBytes: _imageBytes,
              existingImageUrl: widget.look?.displayImageUrl,
              imageUrlController: _imageUrl,
              removeImage: _removeImage,
              onPick: _pickImage,
              onImageUrlChanged: (value) => setState(
                () => _removeImage =
                    value.trim().isNotEmpty && widget.look?.imagePath != null,
              ),
              onRemoveExisting: () => setState(() {
                _removeImage = true;
                _selectedImage = null;
                _imageBytes = null;
                _imageUrl.clear();
              }),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 86,
        maxWidth: 1800,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedImage = image;
        _imageBytes = bytes;
        _imageUrl.clear();
        _removeImage = false;
      });
    } catch (error) {
      if (mounted) _showPickerError(context, error);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _LookDraft(
        name: _name.text.trim(),
        description: _description.text.trim(),
        productIds: _productIds.toList(),
        imageUrl: _imageBytes == null ? _nullableText(_imageUrl.text) : null,
        imageBytes: _imageBytes,
        imageFileName: _selectedImage?.name,
        removeImage: _removeImage,
      ),
    );
  }
}

class _ImagePickerField extends StatelessWidget {
  const _ImagePickerField({
    required this.selectedImage,
    required this.imageBytes,
    required this.existingImageUrl,
    required this.imageUrlController,
    required this.removeImage,
    required this.onPick,
    required this.onImageUrlChanged,
    required this.onRemoveExisting,
  });

  final XFile? selectedImage;
  final Uint8List? imageBytes;
  final String? existingImageUrl;
  final TextEditingController imageUrlController;
  final bool removeImage;
  final VoidCallback onPick;
  final ValueChanged<String> onImageUrlChanged;
  final VoidCallback onRemoveExisting;

  @override
  Widget build(BuildContext context) {
    final hasCurrentImage =
        selectedImage != null || (existingImageUrl != null && !removeImage);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Imagen de referencia',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: LunariaColors.plumDark,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (hasCurrentImage) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 58,
                  height: 58,
                  child: imageBytes != null
                      ? Image.memory(imageBytes!, fit: BoxFit.cover)
                      : Image.network(
                          existingImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: LunariaColors.softPink,
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selectedImage?.name ?? 'Imagen guardada',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Quitar imagen',
                onPressed: onRemoveExisting,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ],
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Elegir de la galería'),
        ),
        TextFormField(
          controller: imageUrlController,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'O pega una URL de imagen',
            hintText: 'https://…',
          ),
          onChanged: onImageUrlChanged,
          validator: _urlValidator,
        ),
      ],
    );
  }
}

class _FormSheet extends StatelessWidget {
  const _FormSheet({
    required this.title,
    required this.child,
    required this.onSave,
  });

  final String title;
  final Widget child;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: LunariaColors.plumDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: child,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onSave,
                  style: FilledButton.styleFrom(
                    backgroundColor: LunariaColors.rose,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Guardar'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _requiredValidator(String? value) =>
    value == null || value.trim().isEmpty ? 'Este campo es obligatorio.' : null;

String? _urlValidator(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      !uri.hasAuthority ||
      (uri.scheme != 'https' && uri.scheme != 'http')) {
    return 'Introduce un enlace válido que comience por https:// o http://.';
  }
  return null;
}

String? _nullableText(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _categoryLabel(String category) => switch (category) {
  'skincare' => 'Skincare',
  'uñas' => 'Uñas',
  _ => '${category[0].toUpperCase()}${category.substring(1)}',
};

String _formatDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/${local.year}';
}

void _showPickerError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('No se pudo cargar la imagen desde la galería: $error'),
      backgroundColor: LunariaColors.danger,
    ),
  );
}
