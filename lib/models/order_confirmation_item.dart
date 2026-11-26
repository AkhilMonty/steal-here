import 'cart_item_model.dart';

class OrderConfirmationItem {
  final String productName;
  final String? imageUrl;
  final double unitPrice;
  final int quantity;
  final String? variantName;
  final double totalPrice;

  const OrderConfirmationItem({
    required this.productName,
    required this.imageUrl,
    required this.unitPrice,
    required this.quantity,
    required this.variantName,
    required this.totalPrice,
  });

  factory OrderConfirmationItem.fromCartItem(CartItemModel item) {
    return OrderConfirmationItem(
      productName: item.product.name,
      imageUrl: item.displayImageUrl,
      unitPrice: item.effectivePrice,
      quantity: item.quantity,
      variantName: item.variantDisplayName,
      totalPrice: item.totalPrice,
    );
  }
}