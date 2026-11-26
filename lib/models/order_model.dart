import 'order_item_model.dart';

class OrderModel {
  final String id;
  final String userId;
  final String orderNumber;

  final String status;
  final String paymentMethod;
  final String paymentStatus;

  final String recipientName;
  final String phone;
  final String addressLine;
  final String city;
  final String? state;
  final String? postalCode;
  final String country;
  final String? customerNote;

  final double subtotal;
  final double shippingFee;
  final double discount;
  final double totalAmount;

  final DateTime createdAt;
  final DateTime updatedAt;

  final List<OrderItemModel> items;

  const OrderModel({
    required this.id,
    required this.userId,
    required this.orderNumber,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.recipientName,
    required this.phone,
    required this.addressLine,
    required this.city,
    this.state,
    this.postalCode,
    required this.country,
    this.customerNote,
    required this.subtotal,
    required this.shippingFee,
    required this.discount,
    required this.totalAmount,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      orderNumber: json['order_number'] as String,
      status: json['status'] as String,
      paymentMethod: json['payment_method'] as String,
      paymentStatus: json['payment_status'] as String,
      recipientName: json['recipient_name'] as String,
      phone: json['phone'] as String,
      addressLine: json['address_line'] as String,
      city: json['city'] as String,
      state: json['state'] as String?,
      postalCode: json['postal_code'] as String?,
      country: json['country'] as String,
      customerNote: json['customer_note'] as String?,
      subtotal: (json['subtotal'] as num).toDouble(),
      shippingFee: (json['shipping_fee'] as num).toDouble(),
      discount: (json['discount'] as num).toDouble(),
      totalAmount: (json['total_amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      items:
          (json['order_items'] as List<dynamic>?)?.map((item) {
            if (item is OrderItemModel) {
              return item;
            }

            return OrderItemModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            );
          }).toList() ??
          const [],
    );
  }

  int get totalItems {
    return items.fold(0, (total, item) => total + item.quantity);
  }
}
