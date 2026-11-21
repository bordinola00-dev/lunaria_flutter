class BeautyProduct {
  const BeautyProduct({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.shade,
    required this.productUrl,
    required this.imageUrl,
    required this.imagePath,
    required this.displayImageUrl,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String brand;
  final String category;
  final String shade;
  final String? productUrl;
  final String? imageUrl;
  final String? imagePath;
  final String? displayImageUrl;
  final DateTime createdAt;
}

class BeautyLook {
  const BeautyLook({
    required this.id,
    required this.name,
    required this.description,
    required this.productIds,
    required this.imageUrl,
    required this.imagePath,
    required this.displayImageUrl,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String description;
  final List<String> productIds;
  final String? imageUrl;
  final String? imagePath;
  final String? displayImageUrl;
  final DateTime createdAt;
}
