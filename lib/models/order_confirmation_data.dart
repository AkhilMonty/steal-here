import 'cart_item_model.dart';
import 'order_confirmation_item.dart';
import 'order_confirmation_model.dart';
import 'shipping_address_model.dart';

class OrderConfirmationData {
  final OrderConfirmationModel order;
  final List<OrderConfirmationItem> items;
  final ShippingAddressModel shippingAddress;
  final String paymentMethod;
  final String addressLabel;
  final bool addressSaved;

  OrderConfirmationData({
    required this.order,
    List<CartItemModel>? cartItems,
    List<OrderConfirmationItem>? items,
    required this.shippingAddress,
    required this.paymentMethod,
    required this.addressLabel,
    required this.addressSaved,
  }) : items =
      items ??
          cartItems
              ?.map(OrderConfirmationItem.fromCartItem)
              .toList() ??
          const [];
}