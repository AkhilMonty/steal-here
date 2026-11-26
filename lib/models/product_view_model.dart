class ProductViewModel {
  final String id;
  final String userId;
  final String productId;
  final DateTime viewedAt;

  const ProductViewModel({
    required this.id,
    required this.userId,
    required this.productId,
    required this.viewedAt,
  });

  factory ProductViewModel.fromJson(Map<String, dynamic> json) {
    return ProductViewModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      productId: json['product_id'] as String,
      viewedAt: DateTime.parse(json['viewed_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'product_id': productId,
      'viewed_at': viewedAt.toIso8601String(),
    };
  }
}
