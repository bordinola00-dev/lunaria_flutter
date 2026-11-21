import 'dart:typed_data';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lunaria_flutter/features/beautyroom/data/beautyroom_repository.dart';
import 'package:lunaria_flutter/features/beautyroom/domain/beautyroom_models.dart';
import 'package:lunaria_flutter/features/beautyroom/presentation/beautyroom_controller.dart';
import 'package:lunaria_flutter/features/beautyroom/presentation/beautyroom_providers.dart';
import 'package:lunaria_flutter/features/beautyroom/presentation/beautyroom_screen.dart';

void main() {
  testWidgets('product form saves a product and associates it with a look', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _MemoryBeautyRoomRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [beautyRoomRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: BeautyRoomScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Añadir producto'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Rubor');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(repository.products.single.name, 'Rubor');
    expect(find.text('Tu colección empieza aquí'), findsNothing);
    expect(find.text('Rubor'), findsOneWidget);

    await tester.tap(find.text('Crear look'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Atardecer');
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Rubor'));
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(repository.looks.single.name, 'Atardecer');
    expect(repository.looks.single.productIds, [repository.products.single.id]);
    expect(tester.takeException(), isNull);
  });

  test(
    'products and looks persist across controller reloads and support CRUD',
    () async {
      final repository = _MemoryBeautyRoomRepository();
      final controller = BeautyRoomController(repository);
      await controller.load();

      await controller.createProduct(
        name: 'Rubor',
        brand: 'Luna',
        category: 'maquillaje',
        shade: 'Rosa',
        productUrl: null,
        imageUrl: null,
        imageBytes: null,
        imageFileName: null,
      );
      final product = controller.products.single;
      expect(product.name, 'Rubor');
      expect(repository.products, hasLength(1));

      await controller.createLook(
        name: 'Atardecer',
        description: 'Tonos cálidos',
        productIds: [product.id],
        imageUrl: null,
        imageBytes: null,
        imageFileName: null,
      );
      expect(controller.looks.single.productIds, [product.id]);

      final reopened = BeautyRoomController(repository);
      await reopened.load();
      expect(reopened.products.single.name, 'Rubor');
      expect(reopened.looks.single.name, 'Atardecer');

      await reopened.updateProduct(
        product: reopened.products.single,
        name: 'Rubor suave',
        brand: 'Luna',
        category: 'maquillaje',
        shade: 'Rosa claro',
        productUrl: 'https://example.com/product',
        imageUrl: null,
        imageBytes: null,
        imageFileName: null,
        removeImage: false,
      );
      expect(reopened.products.single.name, 'Rubor suave');
      expect(
        reopened.products.single.productUrl,
        'https://example.com/product',
      );

      await reopened.deleteLook(reopened.looks.single);
      await reopened.deleteProduct(reopened.products.single);
      expect(repository.looks, isEmpty);
      expect(repository.products, isEmpty);
    },
  );

  test('mutation errors are surfaced and clear the saving state', () async {
    final repository = _MemoryBeautyRoomRepository();
    final controller = BeautyRoomController(repository);
    await controller.load();
    repository.failFetch = true;

    await expectLater(
      controller.createProduct(
        name: 'Rubor',
        brand: '',
        category: 'maquillaje',
        shade: '',
        productUrl: null,
        imageUrl: null,
        imageBytes: null,
        imageFileName: null,
      ),
      throwsA(isA<StateError>()),
    );
    expect(controller.error, contains('falló la consulta'));
    expect(controller.isSaving, isFalse);
  });
}

class _MemoryBeautyRoomRepository implements BeautyRoomRepository {
  final List<BeautyProduct> products = [];
  final List<BeautyLook> looks = [];
  int _nextId = 0;
  bool failFetch = false;

  @override
  Future<List<BeautyProduct>> fetchProducts() async {
    if (failFetch) throw StateError('falló la consulta');
    return List.of(products);
  }

  @override
  Future<List<BeautyLook>> fetchLooks() async {
    if (failFetch) throw StateError('falló la consulta');
    return List.of(looks);
  }

  @override
  Future<void> createProduct({
    required String name,
    required String brand,
    required String category,
    required String shade,
    required String? productUrl,
    required String? imageUrl,
    required Uint8List? imageBytes,
    required String? imageFileName,
  }) async {
    products.add(
      BeautyProduct(
        id: 'product-${_nextId++}',
        name: name,
        brand: brand,
        category: category,
        shade: shade,
        productUrl: productUrl,
        imageUrl: imageUrl,
        imagePath: null,
        displayImageUrl: imageUrl,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> updateProduct({
    required BeautyProduct product,
    required String name,
    required String brand,
    required String category,
    required String shade,
    required String? productUrl,
    required String? imageUrl,
    required Uint8List? imageBytes,
    required String? imageFileName,
    required bool removeImage,
  }) async {
    final index = products.indexWhere((item) => item.id == product.id);
    products[index] = BeautyProduct(
      id: product.id,
      name: name,
      brand: brand,
      category: category,
      shade: shade,
      productUrl: productUrl,
      imageUrl: imageUrl,
      imagePath: removeImage ? null : product.imagePath,
      displayImageUrl:
          imageUrl ?? (removeImage ? null : product.displayImageUrl),
      createdAt: product.createdAt,
    );
  }

  @override
  Future<void> deleteProduct(BeautyProduct product) async {
    products.removeWhere((item) => item.id == product.id);
  }

  @override
  Future<void> createLook({
    required String name,
    required String description,
    required List<String> productIds,
    required String? imageUrl,
    required Uint8List? imageBytes,
    required String? imageFileName,
  }) async {
    looks.add(
      BeautyLook(
        id: 'look-${_nextId++}',
        name: name,
        description: description,
        productIds: productIds,
        imageUrl: imageUrl,
        imagePath: null,
        displayImageUrl: imageUrl,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> updateLook({
    required BeautyLook look,
    required String name,
    required String description,
    required List<String> productIds,
    required String? imageUrl,
    required Uint8List? imageBytes,
    required String? imageFileName,
    required bool removeImage,
  }) async {
    final index = looks.indexWhere((item) => item.id == look.id);
    looks[index] = BeautyLook(
      id: look.id,
      name: name,
      description: description,
      productIds: productIds,
      imageUrl: imageUrl,
      imagePath: removeImage ? null : look.imagePath,
      displayImageUrl: imageUrl ?? (removeImage ? null : look.displayImageUrl),
      createdAt: look.createdAt,
    );
  }

  @override
  Future<void> deleteLook(BeautyLook look) async {
    looks.removeWhere((item) => item.id == look.id);
  }
}
