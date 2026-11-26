class PreviousPurchaseModel {
  final String orderId;
  final String orderNumber;
  final String orderStatus;
  final String paymentStatus;
  final DateTime purchasedAt;

  final String productId;
  final String productName;
  final String? productImage;
  final String? productSku;

  final String? variantId;
  final String? variantSku;
  final Map<String, dynamic> variantAttributes;

  final double unitPrice;
  final int quantity;

  const PreviousPurchaseModel({
    required this.orderId,
    required this.orderNumber,
    required this.orderStatus,
    required this.paymentStatus,
    required this.purchasedAt,
    required this.productId,
    required this.productName,
    this.productImage,
    this.productSku,
    this.variantId,
    this.variantSku,
    this.variantAttributes = const {},
    required this.unitPrice,
    required this.quantity,
  });

  String get variantDisplayName {
    if (variantAttributes.isEmpty) {
      return 'Default';
    }

    return variantAttributes.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(' • ');
  }

  double get totalPrice => unitPrice * quantity;

  factory PreviousPurchaseModel.fromMap(Map<String, dynamic> map) {
    final orderData = Map<String, dynamic>.from(map['orders'] as Map);

    final attributes = map['variant_attributes'];

    return PreviousPurchaseModel(
      orderId: orderData['id'] as String,
      orderNumber: orderData['order_number'] as String,
      orderStatus: orderData['status'] as String,
      paymentStatus: orderData['payment_status'] as String,
      purchasedAt: DateTime.parse(orderData['created_at'] as String),
      productId: map['product_id'] as String,
      productName: map['product_name'] as String,
      productImage: map['product_image'] as String?,
      productSku: map['product_sku'] as String?,
      variantId: map['variant_id'] as String?,
      variantSku: map['variant_sku'] as String?,
      variantAttributes: attributes == null
          ? const {}
          : Map<String, dynamic>.from(attributes as Map),
      unitPrice: (map['unit_price'] as num).toDouble(),
      quantity: (map['quantity'] as num).toInt(),
    );
  }
}
