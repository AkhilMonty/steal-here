class ProductVariantModel {
  final String id;
  final String productId;
  final String? sku;
  final Map<String, dynamic> attributes;
  final double? price;
  final int stockQuantity;
  final String? imageUrl;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProductVariantModel({
    required this.id,
    required this.productId,
    this.sku,
    this.attributes = const {},
    this.price,
    required this.stockQuantity,
    this.imageUrl,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  /// Uses the variant price when available.
  /// Otherwise, falls back to the parent product price.
  double getEffectivePrice(double productPrice) {
    return price ?? productPrice;
  }

  /// Returns a readable variant description.
  String get displayName {
    if (attributes.isEmpty) {
      return 'Default';
    }

    return attributes.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(' • ');
  }

  factory ProductVariantModel.fromMap(Map<String, dynamic> map) {
    return ProductVariantModel(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      sku: map['sku'] as String?,
      attributes: map['attributes'] == null
          ? const {}
          : Map<String, dynamic>.from(map['attributes'] as Map),
      price: map['price'] == null ? null : (map['price'] as num).toDouble(),
      stockQuantity: (map['stock_quantity'] as num).toInt(),
      imageUrl: map['image_url'] as String?,
      isActive: map['is_active'] as bool? ?? true,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] == null
          ? null
          : DateTime.parse(map['updated_at'] as String),
    );
  }
}
