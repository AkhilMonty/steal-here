import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cart_item_model.dart';
import 'notification_repository.dart';

class CartRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  final NotificationRepository _notificationRepository =
      NotificationRepository();

  // Get the currently authenticated user's ID.
  String get _userId {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw StateError('Please login before using the shopping cart.');
    }

    return user.id;
  }

  // Get an existing cart or create a new one.
  Future<String> _getOrCreateCart() async {
    final userId = _userId;

    final existingCart = await _supabase
        .from('carts')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();

    if (existingCart != null) {
      return existingCart['id'] as String;
    }

    final newCart = await _supabase
        .from('carts')
        .insert({'user_id': userId})
        .select('id')
        .single();

    return newCart['id'] as String;
  }

  // Find an existing cart item for the exact product and variant.
  Future<Map<String, dynamic>?> _findExistingCartItem({
    required String cartId,
    required String productId,
    required String? variantId,
  }) async {
    var query = _supabase
        .from('cart_items')
        .select('id, quantity')
        .eq('cart_id', cartId)
        .eq('product_id', productId);

    if (variantId == null) {
      return await query.isFilter('variant_id', null).maybeSingle();
    }

    return await query.eq('variant_id', variantId).maybeSingle();
  }

  // Add a product or a specific variant to the cart.
  Future<void> addToCart(
    String productId, {
    int quantity = 1,
    String? variantId,
  }) async {
    if (quantity < 1) {
      throw ArgumentError('Quantity must be at least 1.');
    }

    final product = await _supabase
        .from('products')
        .select('id, name, stock_quantity, is_active')
        .eq('id', productId)
        .maybeSingle();

    if (product == null || product['is_active'] != true) {
      throw StateError('This product is currently unavailable.');
    }

    final productName = product['name'] as String;

    int stockQuantity;
    String variantName = '';

    if (variantId != null) {
      final variant = await _supabase
          .from('product_variants')
          .select('id, product_id, sku, attributes, stock_quantity, is_active')
          .eq('id', variantId)
          .maybeSingle();

      if (variant == null ||
          variant['is_active'] != true ||
          variant['product_id'] != productId) {
        throw StateError('This product variant is unavailable.');
      }

      stockQuantity = (variant['stock_quantity'] as num).toInt();

      final attributes = variant['attributes'];

      if (attributes is Map && attributes.isNotEmpty) {
        variantName = attributes.entries
            .map((entry) => '${entry.key}: ${entry.value}')
            .join(', ');
      }
    } else {
      stockQuantity = (product['stock_quantity'] as num).toInt();
    }

    if (stockQuantity < quantity) {
      throw StateError('Not enough stock available.');
    }

    final cartId = await _getOrCreateCart();

    final existingItem = await _findExistingCartItem(
      cartId: cartId,
      productId: productId,
      variantId: variantId,
    );

    final existingQuantity = (existingItem?['quantity'] as num?)?.toInt() ?? 0;

    final newQuantity = existingQuantity + quantity;

    if (newQuantity > stockQuantity) {
      throw StateError('Only $stockQuantity units are currently available.');
    }

    final now = DateTime.now().toIso8601String();

    if (existingItem != null) {
      await _supabase
          .from('cart_items')
          .update({'quantity': newQuantity, 'updated_at': now})
          .eq('id', existingItem['id']);
    } else {
      await _supabase.from('cart_items').insert({
        'cart_id': cartId,
        'product_id': productId,
        'variant_id': variantId,
        'quantity': quantity,
        'created_at': now,
        'updated_at': now,
      });
    }

    // Create an in-app notification after the cart update succeeds.
    try {
      final displayName = variantName.isEmpty
          ? productName
          : '$productName ($variantName)';

      await _notificationRepository.createNotification(
        title: existingItem == null ? 'Added to Cart' : 'Cart Updated',
        message: existingItem == null
            ? '$displayName was added to your cart.'
            : 'Your cart quantity for $displayName is now $newQuantity.',
        category: 'cart',
        relatedProductId: productId,
        metadata: {
          'event': existingItem == null
              ? 'cart_added'
              : 'cart_quantity_increased',
          'product_name': productName,
          'variant_id': variantId,
          'variant_name': variantName,
          'quantity_added': quantity,
          'total_quantity': newQuantity,
        },
      );
    } catch (error) {
      // Notification failure must not interrupt cart functionality.
      debugPrint('CART NOTIFICATION ERROR: $error');
    }
  }

  // Fetch all products and their selected variants in the current cart.
  Future<List<CartItemModel>> getCartItems() async {
    final cartId = await _getOrCreateCart();

    final response = await _supabase
        .from('cart_items')
        .select('*, products!inner(*), product_variants(*)')
        .eq('cart_id', cartId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((item) => CartItemModel.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  // Update the quantity of a cart item using its correct stock source.
  Future<void> updateQuantity(String cartItemId, int quantity) async {
    if (quantity < 1) {
      throw ArgumentError('Quantity must be at least 1.');
    }

    final cartId = await _getOrCreateCart();

    final item = await _supabase
        .from('cart_items')
        .select('product_id, variant_id')
        .eq('id', cartItemId)
        .eq('cart_id', cartId)
        .maybeSingle();

    if (item == null) {
      throw StateError('Cart item not found.');
    }

    final product = await _supabase
        .from('products')
        .select('stock_quantity, is_active')
        .eq('id', item['product_id'])
        .maybeSingle();

    if (product == null || product['is_active'] != true) {
      throw StateError('Product is no longer available.');
    }

    final variantId = item['variant_id'] as String?;

    int stockQuantity;

    if (variantId != null) {
      final variant = await _supabase
          .from('product_variants')
          .select('product_id, stock_quantity, is_active')
          .eq('id', variantId)
          .maybeSingle();

      if (variant == null ||
          variant['is_active'] != true ||
          variant['product_id'] != item['product_id']) {
        throw StateError('This product variant is no longer available.');
      }

      stockQuantity = (variant['stock_quantity'] as num).toInt();
    } else {
      stockQuantity = (product['stock_quantity'] as num).toInt();
    }

    if (quantity > stockQuantity) {
      throw StateError('Only $stockQuantity units are currently available.');
    }

    await _supabase
        .from('cart_items')
        .update({
          'quantity': quantity,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', cartItemId)
        .eq('cart_id', cartId);
  }

  // Change the selected variant of an existing cart item.
  // Change the selected variant and quantity of an existing cart item.
  Future<void> updateCartItemVariant({
    required String cartItemId,
    required String? variantId,
    required int quantity,
  }) async {
    if (quantity < 1) {
      throw ArgumentError('Quantity must be at least 1.');
    }

    final cartId = await _getOrCreateCart();

    final item = await _supabase
        .from('cart_items')
        .select('id, product_id, variant_id')
        .eq('id', cartItemId)
        .eq('cart_id', cartId)
        .maybeSingle();

    if (item == null) {
      throw StateError('Cart item not found.');
    }

    final productId = item['product_id'] as String;
    final currentVariantId = item['variant_id'] as String?;

    if (currentVariantId == variantId) {
      // The variant is unchanged, but quantity may have changed.
    }

    final product = await _supabase
        .from('products')
        .select('id, name, stock_quantity, is_active')
        .eq('id', productId)
        .maybeSingle();

    if (product == null || product['is_active'] != true) {
      throw StateError('This product is no longer available.');
    }

    final productName = product['name'] as String;

    int availableStock;
    String variantName = '';

    if (variantId != null) {
      final variant = await _supabase
          .from('product_variants')
          .select('id, product_id, attributes, stock_quantity, is_active')
          .eq('id', variantId)
          .maybeSingle();

      if (variant == null ||
          variant['is_active'] != true ||
          variant['product_id'] != productId) {
        throw StateError('The selected variant is unavailable.');
      }

      availableStock = (variant['stock_quantity'] as num).toInt();

      final attributes = variant['attributes'];

      if (attributes is Map && attributes.isNotEmpty) {
        variantName = attributes.entries
            .map((entry) => '${entry.key}: ${entry.value}')
            .join(', ');
      }
    } else {
      availableStock = (product['stock_quantity'] as num).toInt();
    }

    if (quantity > availableStock) {
      throw StateError(
        'Only $availableStock units are available for this variant.',
      );
    }

    // Prevent duplicate product-variant entries.
    var duplicateQuery = _supabase
        .from('cart_items')
        .select('id')
        .eq('cart_id', cartId)
        .eq('product_id', productId)
        .neq('id', cartItemId);

    final duplicateItem = variantId == null
        ? await duplicateQuery.isFilter('variant_id', null).maybeSingle()
        : await duplicateQuery.eq('variant_id', variantId).maybeSingle();

    if (duplicateItem != null) {
      throw StateError(
        'This variant is already in your cart. '
        'Please update or remove the other cart item first.',
      );
    }

    // Save variant and quantity together.
    await _supabase
        .from('cart_items')
        .update({
          'variant_id': variantId,
          'quantity': quantity,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', cartItemId)
        .eq('cart_id', cartId);

    try {
      await _notificationRepository.createNotification(
        title: 'Cart Item Updated',
        message: variantName.isEmpty
            ? '$productName was updated successfully.'
            : '$productName updated to $variantName.',
        category: 'cart',
        relatedProductId: productId,
        metadata: {
          'event': 'cart_variant_updated',
          'product_name': productName,
          'previous_variant_id': currentVariantId,
          'variant_id': variantId,
          'variant_name': variantName,
          'quantity': quantity,
        },
      );
    } catch (error) {
      debugPrint('CART VARIANT NOTIFICATION ERROR: $error');
    }
  }

  // Remove a product or variant from the cart.
  Future<void> removeFromCart(String cartItemId) async {
    final cartId = await _getOrCreateCart();

    await _supabase
        .from('cart_items')
        .delete()
        .eq('id', cartItemId)
        .eq('cart_id', cartId);
  }

  // Clear all products and variants from the current user's cart.
  Future<void> clearCart() async {
    final cartId = await _getOrCreateCart();

    await _supabase.from('cart_items').delete().eq('cart_id', cartId);
  }
}
