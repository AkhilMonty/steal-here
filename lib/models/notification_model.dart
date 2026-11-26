class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String category;
  final String? relatedProductId;
  final String? relatedOrderId;
  final bool isRead;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.category,
    this.relatedProductId,
    this.relatedOrderId,
    required this.isRead,
    this.metadata = const {},
    required this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      message: map['message'] as String,
      category: map['category'] as String? ?? 'general',
      relatedProductId: map['related_product_id'] as String?,
      relatedOrderId: map['related_order_id'] as String?,
      isRead: map['is_read'] as bool? ?? false,
      metadata: map['metadata'] == null
          ? const {}
          : Map<String, dynamic>.from(map['metadata'] as Map),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'message': message,
      'category': category,
      'related_product_id': relatedProductId,
      'related_order_id': relatedOrderId,
      'is_read': isRead,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
    };
  }

  NotificationModel copyWith({
    String? title,
    String? message,
    String? category,
    String? relatedProductId,
    String? relatedOrderId,
    bool? isRead,
    Map<String, dynamic>? metadata,
  }) {
    return NotificationModel(
      id: id,
      userId: userId,
      title: title ?? this.title,
      message: message ?? this.message,
      category: category ?? this.category,
      relatedProductId: relatedProductId ?? this.relatedProductId,
      relatedOrderId: relatedOrderId ?? this.relatedOrderId,
      isRead: isRead ?? this.isRead,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt,
    );
  }

  bool get isUnread => !isRead;

  String get formattedCategory {
    switch (category) {
      case 'price_drop':
        return 'Price Drop';
      case 'order':
        return 'Order';
      case 'delivery':
        return 'Delivery';
      case 'offer':
        return 'Offers';
      case 'cart':
        return 'Cart';
      case 'wishlist':
        return 'Wishlist';
      case 'review':
        return 'Reviews';
      case 'payment':
        return 'Payments';
      case 'security':
        return 'Security';
      case 'account':
        return 'Account';
      case 'budget':
        return 'Budget Guardian';
      case 'recommendation':
        return 'Recommendations';
      case 'announcement':
        return 'Announcements';
      default:
        return 'General';
    }
  }
}
