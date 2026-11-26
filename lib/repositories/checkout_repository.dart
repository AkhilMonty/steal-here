import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order_confirmation_model.dart';
import '../models/shipping_address_model.dart';

class CheckoutRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? _checkoutToken;
  String? _directCheckoutToken;

  String _normalizePaymentMethod(String paymentMethod) {
    final normalized = paymentMethod.trim().toLowerCase();

    if (normalized == 'cod' ||
        normalized == 'cash on delivery' ||
        normalized == 'cash_on_delivery') {
      return 'cash_on_delivery';
    }

    throw ArgumentError('Unsupported payment method: $paymentMethod');
  }

  String get _userId {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw StateError('Please login before placing an order.');
    }

    return user.id;
  }

  String _generateCheckoutToken() {
    final random = Random.secure();

    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    // UUID version 4.
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;

    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();

    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  Future<Map<String, dynamic>> getAvailableCoupons({
    required List<String> selectedCartItemIds,
  }) async {
    _userId;

    if (selectedCartItemIds.isEmpty) {
      throw StateError(
        'Please select at least one product to view available coupons.',
      );
    }

    final response = await _supabase.rpc(
      'get_available_coupons',
      params: {'p_selected_cart_item_ids': selectedCartItemIds},
    );

    if (response is! Map) {
      throw const FormatException('Invalid available coupons response.');
    }

    return Map<String, dynamic>.from(response);
  }

  Future<Map<String, dynamic>> validateCoupon(
    String couponCode, {
    required List<String> selectedCartItemIds,
  }) async {
    _userId;

    if (selectedCartItemIds.isEmpty) {
      throw StateError(
        'Please select at least one product before applying a coupon.',
      );
    }

    final response = await _supabase.rpc(
      'validate_coupon',
      params: {
        'p_coupon_code': couponCode.trim(),
        'p_selected_cart_item_ids': selectedCartItemIds,
      },
    );

    if (response is! Map) {
      throw const FormatException('Invalid coupon validation response.');
    }

    return Map<String, dynamic>.from(response);
  }

  Future<OrderConfirmationModel> placeOrder({
    required ShippingAddressModel address,
    required String paymentMethod,
    required List<String> selectedCartItemIds,
    String? couponCode,
  }) async {
    _userId;

    if (selectedCartItemIds.isEmpty) {
      throw StateError('Please select at least one item to place your order.');
    }

    _checkoutToken ??= _generateCheckoutToken();

    try {
      final response = await _supabase.rpc(
        'place_order',
        params: {
          'p_checkout_token': _checkoutToken,
          'p_payment_method': _normalizePaymentMethod(paymentMethod),
          'p_recipient_name': address.recipientName,
          'p_phone': address.phone,
          'p_address_line': address.addressLine,
          'p_city': address.city,
          'p_selected_cart_item_ids': selectedCartItemIds,
          'p_coupon_code': couponCode,
          'p_state': address.state,
          'p_postal_code': address.postalCode,
          'p_country': address.country,
          'p_customer_note': address.customerNote,
        },
      );

      if (response is! Map) {
        throw const FormatException('Invalid order confirmation received.');
      }

      final result = OrderConfirmationModel.fromMap(
        Map<String, dynamic>.from(response),
      );

      _checkoutToken = null;

      return result;
    } catch (_) {
      // Preserve the checkout token when an operation fails.
      // This prevents duplicate orders when retrying.
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getAvailableDirectCoupons({
    required String productId,
    String? variantId,
    required int quantity,
  }) async {
    _userId;

    if (quantity < 1) {
      throw ArgumentError('Quantity must be at least 1.');
    }

    final response = await _supabase.rpc(
      'get_available_direct_coupons',
      params: {
        'p_product_id': productId,
        'p_variant_id': variantId,
        'p_quantity': quantity,
      },
    );

    if (response is! Map) {
      throw FormatException('Invalid direct coupon response.');
    }

    return Map<String, dynamic>.from(response);
  }

  Future<Map<String, dynamic>> validateDirectCoupon(
    String couponCode, {
    required String productId,
    String? variantId,
    required int quantity,
  }) async {
    _userId;

    if (quantity < 1) {
      throw ArgumentError('Quantity must be at least 1.');
    }

    final response = await _supabase.rpc(
      'validate_direct_coupon',
      params: {
        'p_coupon_code': couponCode.trim(),
        'p_product_id': productId,
        'p_variant_id': variantId,
        'p_quantity': quantity,
      },
    );

    if (response is! Map) {
      throw FormatException('Invalid direct coupon validation response.');
    }

    return Map<String, dynamic>.from(response);
  }

  Future<OrderConfirmationModel> placeDirectOrder({
    required ShippingAddressModel address,
    required String paymentMethod,
    required String productId,
    String? variantId,
    required int quantity,
    String? couponCode,
  }) async {
    _userId;

    if (quantity < 1) {
      throw ArgumentError('Quantity must be at least 1.');
    }

    _directCheckoutToken ??= _generateCheckoutToken();

    try {
      final response = await _supabase.rpc(
        'place_order_direct',
        params: {
          'p_checkout_token': _directCheckoutToken,
          'p_payment_method': _normalizePaymentMethod(paymentMethod),
          'p_recipient_name': address.recipientName,
          'p_phone': address.phone,
          'p_address_line': address.addressLine,
          'p_city': address.city,
          'p_product_id': productId,
          'p_variant_id': variantId,
          'p_quantity': quantity,
          'p_coupon_code': couponCode,
          'p_state': address.state,
          'p_postal_code': address.postalCode,
          'p_country': address.country,
          'p_customer_note': address.customerNote,
        },
      );

      if (response is! Map) {
        throw FormatException('Invalid direct order response.');
      }

      final result = OrderConfirmationModel.fromMap(
        Map<String, dynamic>.from(response),
      );

      _directCheckoutToken = null;

      return result;
    } catch (_) {
      // Preserve the token if the request fails, preventing duplicate orders.
      rethrow;
    }
  }
}
