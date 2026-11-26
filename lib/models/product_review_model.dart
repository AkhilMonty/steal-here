class ProductReviewModel {
  final String id;
  final String productId;

  // Null for public review results.
  // Available when fetching the customer's own review.
  final String? userId;

  final int rating;
  final String reviewText;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isVerifiedPurchase;

  // Calculated by the database using auth.uid().
  final bool isOwner;

  const ProductReviewModel({
    required this.id,
    required this.productId,
    this.userId,
    required this.rating,
    required this.reviewText,
    required this.createdAt,
    required this.updatedAt,
    this.isVerifiedPurchase = false,
    this.isOwner = false,
  });

  factory ProductReviewModel.fromJson(Map<String, dynamic> json) {
    return ProductReviewModel(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      userId: json['user_id'] as String?,
      rating: (json['rating'] as num).toInt(),
      reviewText: json['review_text'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isVerifiedPurchase: json['is_verified_purchase'] as bool? ?? false,
      isOwner: json['is_owner'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'user_id': userId,
      'rating': rating,
      'review_text': reviewText,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_verified_purchase': isVerifiedPurchase,
      'is_owner': isOwner,
    };
  }
}
