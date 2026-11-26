class ProductModel {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? sku;
  final String category;
  final String? productType;
  final String? brand;
  final double price;
  final double? compareAtPrice;
  final double? wishlistPriceAtAdd;
  final String? imageUrl;
  final List<String> images;
  final int stockQuantity;
  final double rating;
  final int reviewCount;
  final bool isFeatured;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> specifications;

  const ProductModel({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.sku,
    required this.category,
    this.productType,
    this.brand,
    required this.price,
    this.compareAtPrice,
    this.wishlistPriceAtAdd,
    this.imageUrl,
    this.images = const [],
    required this.stockQuantity,
    required this.rating,
    required this.reviewCount,
    required this.isFeatured,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    this.specifications = const {},
  });

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] as String,
      name: map['name'] as String,
      slug: map['slug'] as String,
      description: map['description'] as String?,
      sku: map['sku'] as String?,
      category: map['category'] as String,
      productType: map['product_type'] as String?,
      brand: map['brand'] as String?,
      price: (map['price'] as num).toDouble(),
      wishlistPriceAtAdd: map['wishlist_price_at_add'] == null
          ? null
          : (map['wishlist_price_at_add'] as num).toDouble(),
      compareAtPrice: map['compare_at_price'] == null
          ? null
          : (map['compare_at_price'] as num).toDouble(),
      imageUrl: map['image_url'] as String?,
      images: List<String>.from(map['images'] ?? []),
      stockQuantity: (map['stock_quantity'] as num).toInt(),
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (map['review_count'] as num?)?.toInt() ?? 0,
      isFeatured: map['is_featured'] as bool? ?? false,
      isActive: map['is_active'] as bool? ?? true,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] == null
          ? null
          : DateTime.parse(map['updated_at'] as String),
      specifications: map['specifications'] == null
          ? const {}
          : Map<String, dynamic>.from(map['specifications'] as Map),
    );
  }
}
