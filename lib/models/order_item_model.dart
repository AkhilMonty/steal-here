class OrderItemModel {
  final String id;
  final String orderId;
  final String? productId;

  final String productName;
  final String? productSku;
  final String? productImage;
  final String? productCategory;

  // Purchased variant information.
  final String? variantId;
  final String? variantSku;
  final Map<String, dynamic> variantAttributes;

  final double unitPrice;
  final int quantity;
  final double lineTotal;

  final DateTime createdAt;

  const OrderItemModel({
    required this.id,
    required this.orderId,
    this.productId,
    required this.productName,
    this.productSku,
    this.productImage,
    this.productCategory,
    this.variantId,
    this.variantSku,
    this.variantAttributes = const {},
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
    required this.createdAt,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      productId: json['product_id'] as String?,
      productName: json['product_name'] as String,
      productSku: json['product_sku'] as String?,
      productImage: json['product_image'] as String?,
      productCategory: json['product_category'] as String?,

      variantId: json['variant_id'] as String?,
      variantSku: json['variant_sku'] as String?,
      variantAttributes: Map<String, dynamic>.from(
        json['variant_attributes'] as Map? ?? {},
      ),

      unitPrice: (json['unit_price'] as num).toDouble(),
      quantity: (json['quantity'] as num).toInt(),
      lineTotal: (json['line_total'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
