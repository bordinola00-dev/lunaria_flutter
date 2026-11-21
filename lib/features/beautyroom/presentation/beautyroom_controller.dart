import 'package:flutter/foundation.dart';

import '../data/beautyroom_repository.dart';
import '../domain/beautyroom_models.dart';

class BeautyRoomController extends ChangeNotifier {
  BeautyRoomController(this._repository);

  final BeautyRoomRepository _repository;

  List<BeautyProduct> products = const [];
  List<BeautyLook> looks = const [];
  bool isLoading = true;
  bool isSaving = false;
  String? error;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _refresh();
    } catch (exception) {
      error = _messageFor(exception);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

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
    await _mutate(
      () => _repository.createProduct(
        name: name,
        brand: brand,
        category: category,
        shade: shade,
        productUrl: productUrl,
        imageUrl: imageUrl,
        imageBytes: imageBytes,
        imageFileName: imageFileName,
      ),
    );
  }

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
    await _mutate(
      () => _repository.updateProduct(
        product: product,
        name: name,
        brand: brand,
        category: category,
        shade: shade,
        productUrl: productUrl,
        imageUrl: imageUrl,
        imageBytes: imageBytes,
        imageFileName: imageFileName,
        removeImage: removeImage,
      ),
    );
  }

  Future<void> deleteProduct(BeautyProduct product) async {
    await _mutate(() => _repository.deleteProduct(product));
  }

  Future<void> createLook({
    required String name,
    required String description,
    required List<String> productIds,
    required String? imageUrl,
    required Uint8List? imageBytes,
    required String? imageFileName,
  }) async {
    await _mutate(
      () => _repository.createLook(
        name: name,
        description: description,
        productIds: productIds,
        imageUrl: imageUrl,
        imageBytes: imageBytes,
        imageFileName: imageFileName,
      ),
    );
  }

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
    await _mutate(
      () => _repository.updateLook(
        look: look,
        name: name,
        description: description,
        productIds: productIds,
        imageUrl: imageUrl,
        imageBytes: imageBytes,
        imageFileName: imageFileName,
        removeImage: removeImage,
      ),
    );
  }

  Future<void> deleteLook(BeautyLook look) async {
    await _mutate(() => _repository.deleteLook(look));
  }

  Future<void> _mutate(Future<void> Function() action) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      await action();
      await _refresh();
    } catch (exception) {
      error = _messageFor(exception);
      rethrow;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> _refresh() async {
    final nextProducts = await _repository.fetchProducts();
    final nextLooks = await _repository.fetchLooks();
    products = nextProducts;
    looks = nextLooks;
  }

  String _messageFor(Object exception) {
    final message = exception.toString().replaceFirst('Exception: ', '');
    return 'No se pudo sincronizar BeautyRoom: $message';
  }
}
