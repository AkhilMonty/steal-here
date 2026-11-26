class OrderConfirmationModel {
  final String orderId;
  final String orderNumber;
  final double subtotal;
  final double shippingFee;
  final double discount;
  final double totalAmount;
  final String status;
  final bool isDuplicate;

  const OrderConfirmationModel({
    required this.orderId,
    required this.orderNumber,
    required this.subtotal,
    required this.shippingFee,
    required this.discount,
    required this.totalAmount,
    required this.status,
    this.isDuplicate = false,
  });

  factory OrderConfirmationModel.fromMap(Map<String, dynamic> map) {
    return OrderConfirmationModel(
      orderId: map['order_id'] as String,
      orderNumber: map['order_number'] as String,
      subtotal: (map['subtotal'] as num).toDouble(),
      shippingFee: (map['shipping_fee'] as num).toDouble(),
      discount: ((map['discount'] ?? 0) as num).toDouble(),
      totalAmount: (map['total_amount'] as num).toDouble(),
      status: map['status'] as String,
      isDuplicate: map['duplicate'] == true,
    );
  }
}
