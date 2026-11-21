import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_config.dart';
import '../domain/beautyroom_models.dart';

abstract interface class BeautyRoomRepository {
  Future<List<BeautyProduct>> fetchProducts();
  Future<List<BeautyLook>> fetchLooks();

  Future<void> createProduct({
    required String name,
    required String brand,
    required String category,
    required String shade,
    required String? productUrl,
    required String? imageUrl,
    required Uint8List? imageBytes,
    required String? imageFileName,
  });

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
  });

  Future<void> deleteProduct(BeautyProduct product);

  Future<void> createLook({
    required String name,
    required String description,
    required List<String> productIds,
    required String? imageUrl,
    required Uint8List? imageBytes,
    required String? imageFileName,
  });

  Future<void> updateLook({
    required BeautyLook look,
    required String name,
    required String description,
    required List<String> productIds,
    required String? imageUrl,
    required Uint8List? imageBytes,
    required String? imageFileName,
    required bool removeImage,
  });

  Future<void> deleteLook(BeautyLook look);
}

class SupabaseBeautyRoomRepository implements BeautyRoomRepository {
  SupabaseBeautyRoomRepository();

  static const _bucket = 'beautyroom-images';

  SupabaseClient get _client {
    final client = supabase;
    if (client == null) {
      throw StateError(
        'Supabase no está configurado o no se pudo inicializar. '
        'Comprueba SUPABASE_URL y SUPABASE_ANON_KEY.',
      );
    }
    return client;
  }

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError(
        'Inicia sesión para consultar y guardar tu colección de BeautyRoom.',
      );
    }
    return userId;
  }

  @override
  Future<List<BeautyProduct>> fetchProducts() async {
    final userId = _userId;
    final rows = await _client
        .from('beauty_products')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return Future.wait(
      rows.map((row) => _productFromRow(Map<String, dynamic>.from(row))),
    );
  }

  @override
  Future<List<BeautyLook>> fetchLooks() async {
    final userId = _userId;
    final rows = await _client
        .from('beauty_looks')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return Future.wait(
      rows.map((row) => _lookFromRow(Map<String, dynamic>.from(row))),
    );
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
    final userId = _userId;
    final path = imageBytes == null
        ? null
        : await _uploadImage(userId, 'products', imageFileName, imageBytes);
    try {
      await _client.from('beauty_products').insert({
        'user_id': userId,
        'name': name,
        'brand': brand,
        'category': category,
        'shade': shade,
        'product_url': productUrl,
        'image_url': imageBytes == null ? imageUrl : null,
        'image_path': path,
      });
    } catch (error) {
      if (path != null) {
        try {
          await _client.storage.from(_bucket).remove([path]);
        } catch (cleanupError) {
          throw StateError(
            'No se pudo guardar el producto ($error) ni limpiar su imagen '
            '($cleanupError).',
          );
        }
      }
      rethrow;
    }
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
    final userId = _userId;
    final newPath = imageBytes == null
        ? null
        : await _uploadImage(userId, 'products', imageFileName, imageBytes);
    final imagePath = newPath ?? (removeImage ? null : product.imagePath);
    final nextImageUrl = imageBytes != null ? null : imageUrl;
    try {
      await _client
          .from('beauty_products')
          .update({
            'name': name,
            'brand': brand,
            'category': category,
            'shade': shade,
            'product_url': productUrl,
            'image_url': nextImageUrl,
            'image_path': imagePath,
          })
          .eq('id', product.id)
          .eq('user_id', userId)
          .select()
          .single();
    } catch (error) {
      if (newPath != null) {
        try {
          await _client.storage.from(_bucket).remove([newPath]);
        } catch (cleanupError) {
          throw StateError(
            'No se pudo actualizar el producto ($error) ni limpiar la nueva '
            'imagen ($cleanupError).',
          );
        }
      }
      rethrow;
    }
    if (product.imagePath != null && product.imagePath != imagePath) {
      await _client.storage.from(_bucket).remove([product.imagePath!]);
    }
  }

  @override
  Future<void> deleteProduct(BeautyProduct product) async {
    final userId = _userId;
    await _client
        .from('beauty_products')
        .delete()
        .eq('id', product.id)
        .eq('user_id', userId)
        .select('id')
        .single();
    if (product.imagePath != null) {
      await _client.storage.from(_bucket).remove([product.imagePath!]);
    }
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
    final userId = _userId;
    final path = imageBytes == null
        ? null
        : await _uploadImage(userId, 'looks', imageFileName, imageBytes);
    try {
      await _client.from('beauty_looks').insert({
        'user_id': userId,
        'name': name,
        'description': description,
        'products': productIds,
        'image_url': imageBytes == null ? imageUrl : null,
        'image_path': path,
      });
    } catch (error) {
      if (path != null) {
        try {
          await _client.storage.from(_bucket).remove([path]);
        } catch (cleanupError) {
          throw StateError(
            'No se pudo guardar el look ($error) ni limpiar su imagen '
            '($cleanupError).',
          );
        }
      }
      rethrow;
    }
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
    final userId = _userId;
    final newPath = imageBytes == null
        ? null
        : await _uploadImage(userId, 'looks', imageFileName, imageBytes);
    final imagePath = newPath ?? (removeImage ? null : look.imagePath);
    final nextImageUrl = imageBytes != null ? null : imageUrl;
    try {
      await _client
          .from('beauty_looks')
          .update({
            'name': name,
            'description': description,
            'products': productIds,
            'image_url': nextImageUrl,
            'image_path': imagePath,
          })
          .eq('id', look.id)
          .eq('user_id', userId)
          .select()
          .single();
    } catch (error) {
      if (newPath != null) {
        try {
          await _client.storage.from(_bucket).remove([newPath]);
        } catch (cleanupError) {
          throw StateError(
            'No se pudo actualizar el look ($error) ni limpiar la nueva '
            'imagen ($cleanupError).',
          );
        }
      }
      rethrow;
    }
    if (look.imagePath != null && look.imagePath != imagePath) {
      await _client.storage.from(_bucket).remove([look.imagePath!]);
    }
  }

  @override
  Future<void> deleteLook(BeautyLook look) async {
    final userId = _userId;
    await _client
        .from('beauty_looks')
        .delete()
        .eq('id', look.id)
        .eq('user_id', userId)
        .select('id')
        .single();
    if (look.imagePath != null) {
      await _client.storage.from(_bucket).remove([look.imagePath!]);
    }
  }

  Future<BeautyProduct> _productFromRow(Map<String, dynamic> row) async {
    final imagePath = row['image_path'] as String?;
    return BeautyProduct(
      id: row['id'] as String,
      name: row['name'] as String,
      brand: row['brand'] as String? ?? '',
      category: row['category'] as String? ?? '',
      shade: row['shade'] as String? ?? '',
      productUrl: row['product_url'] as String?,
      imageUrl: row['image_url'] as String?,
      imagePath: imagePath,
      displayImageUrl: await _displayImage(
        imagePath,
        row['image_url'] as String?,
      ),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  Future<BeautyLook> _lookFromRow(Map<String, dynamic> row) async {
    final imagePath = row['image_path'] as String?;
    return BeautyLook(
      id: row['id'] as String,
      name: row['name'] as String,
      description: row['description'] as String? ?? '',
      productIds: (row['products'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      imageUrl: row['image_url'] as String?,
      imagePath: imagePath,
      displayImageUrl: await _displayImage(
        imagePath,
        row['image_url'] as String?,
      ),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  Future<String?> _displayImage(String? path, String? imageUrl) {
    if (path == null) return Future.value(imageUrl);
    return _client.storage.from(_bucket).createSignedUrl(path, 3600);
  }

  Future<String> _uploadImage(
    String userId,
    String collection,
    String? fileName,
    Uint8List bytes,
  ) async {
    if (fileName == null || fileName.trim().isEmpty) {
      throw ArgumentError('Falta el nombre del archivo de imagen.');
    }
    final extension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'jpg';
    const supportedExtensions = {'jpg', 'jpeg', 'png', 'webp', 'heic'};
    if (!supportedExtensions.contains(extension)) {
      throw ArgumentError('Formato de imagen no compatible: .$extension');
    }
    final contentType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      _ => 'image/jpeg',
    };
    final suffix =
        '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}';
    final path = '$userId/$collection/$suffix.$extension';
    await _client.storage
        .from(_bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    return path;
  }
}
