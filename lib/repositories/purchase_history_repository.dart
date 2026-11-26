import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cart_item_model.dart';
import '../models/direct_purchase_data.dart';
import '../models/previous_purchase_model.dart';

class PurchaseHistoryRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  String get _userId {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw StateError('Please login to check your purchase history.');
    }

    return user.id;
  }

  /// Retrieves the latest eligible previous purchase for each
  /// selected cart item.
  ///
  /// The returned map uses cart item IDs as keys.
  Future<Map<String, PreviousPurchaseModel>> getPreviousPurchases(
    List<CartItemModel> cartItems,
  ) async {
    if (cartItems.isEmpty) {
      return {};
    }

    final productIds = cartItems.map((item) => item.productId).toSet().toList();

    final purchaseHistory = await _getPurchaseHistory(productIds);

    final result = <String, PreviousPurchaseModel>{};

    for (final cartItem in cartItems) {
      for (final purchase in purchaseHistory) {
        if (purchase.productName.isEmpty) {
          continue;
        }

        if (_matchesPurchase(cartItem, purchase)) {
          result[cartItem.id] = purchase;
          break;
        }
      }
    }

    return result;
  }

  /// Retrieves the latest eligible previous purchase for a Buy Now
  /// direct purchase.
  ///
  /// Returns null when the customer has never purchased the same
  /// product and variant.
  Future<PreviousPurchaseModel?> getPreviousPurchaseForDirectPurchase(
    DirectPurchaseData directPurchase,
  ) async {
    final purchaseHistory = await _getPurchaseHistory([
      directPurchase.product.id,
    ]);

    for (final purchase in purchaseHistory) {
      if (purchase.productName.isEmpty) {
        continue;
      }

      if (_matchesDirectPurchase(directPurchase, purchase)) {
        return purchase;
      }
    }

    return null;
  }

  /// Shared purchase-history query for Cart Checkout and Buy Now.
  Future<List<PreviousPurchaseModel>> _getPurchaseHistory(
    List<String> productIds,
  ) async {
    if (productIds.isEmpty) {
      return [];
    }

    final userId = _userId;

    final response = await _supabase
        .from('order_items')
        .select('''
          id,
          product_id,
          product_name,
          product_sku,
          product_image,
          variant_id,
          variant_sku,
          variant_attributes,
          unit_price,
          quantity,
          orders!inner(
            id,
            user_id,
            order_number,
            status,
            payment_status,
            created_at
          )
        ''')
        .inFilter('product_id', productIds)
        .eq('orders.user_id', userId);

    final purchaseHistory = <PreviousPurchaseModel>[];

    for (final row in response) {
      final orderData = Map<String, dynamic>.from(row['orders'] as Map);

      final orderStatus = (orderData['status'] as String).toLowerCase();

      final paymentStatus = (orderData['payment_status'] as String)
          .toLowerCase();

      // Exclude cancelled orders and unsuccessful payments.
      if (orderStatus == 'cancelled' ||
          paymentStatus == 'failed' ||
          paymentStatus == 'refunded') {
        continue;
      }

      purchaseHistory.add(
        PreviousPurchaseModel.fromMap(Map<String, dynamic>.from(row)),
      );
    }

    // Newest purchases first.
    purchaseHistory.sort((a, b) => b.purchasedAt.compareTo(a.purchasedAt));

    return purchaseHistory;
  }

  /// Checks whether a cart item matches the exact product and variant.
  bool _matchesPurchase(
    CartItemModel cartItem,
    PreviousPurchaseModel purchase,
  ) {
    if (cartItem.productId != purchase.productId) {
      return false;
    }

    return _matchesVariant(
      currentVariantId: cartItem.variantId,
      currentAttributes: cartItem.variant?.attributes ?? {},
      previousVariantId: purchase.variantId,
      previousAttributes: purchase.variantAttributes,
    );
  }

  /// Checks whether a direct purchase matches the exact product and variant.
  bool _matchesDirectPurchase(
    DirectPurchaseData directPurchase,
    PreviousPurchaseModel purchase,
  ) {
    if (directPurchase.product.id != purchase.productId) {
      return false;
    }

    return _matchesVariant(
      currentVariantId: directPurchase.variant?.id,
      currentAttributes: directPurchase.variant?.attributes ?? {},
      previousVariantId: purchase.variantId,
      previousAttributes: purchase.variantAttributes,
    );
  }

  /// Shared variant matching logic for both checkout paths.
  bool _matchesVariant({
    required String? currentVariantId,
    required Map<String, dynamic> currentAttributes,
    required String? previousVariantId,
    required Map<String, dynamic> previousAttributes,
  }) {
    // Both purchases have no variant.
    if (currentVariantId == null && previousVariantId == null) {
      return true;
    }

    // Exact same variant.
    if (currentVariantId != null &&
        previousVariantId != null &&
        currentVariantId == previousVariantId) {
      return true;
    }

    // If variant IDs differ, compare their attributes.
    if (currentAttributes.isEmpty || previousAttributes.isEmpty) {
      return false;
    }

    return _normalizeAttributes(currentAttributes) ==
        _normalizeAttributes(previousAttributes);
  }

  /// Normalizes attribute keys and values to make comparisons
  /// independent of capitalization and surrounding whitespace.
  Map<String, String> _normalizeAttributes(Map<String, dynamic> attributes) {
    final normalized = <String, String>{};

    for (final entry in attributes.entries) {
      normalized[entry.key.trim().toLowerCase()] = entry.value
          .toString()
          .trim()
          .toLowerCase();
    }

    return normalized;
  }
}
