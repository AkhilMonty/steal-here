import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product_model.dart';
import 'notification_repository.dart';

class WishlistRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  final NotificationRepository _notificationRepository =
      NotificationRepository();

  // Get the currently authenticated user's ID.
  String get _userId {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw StateError('Please login before using your wishlist.');
    }

    return user.id;
  }

  // Add a product to the wishlist.
  Future<void> addToWishlist(String productId) async {
    final userId = _userId;

    // Check whether the product exists and is active.
    final product = await _supabase
        .from('products')
        .select('id, name, price, is_active')
        .eq('id', productId)
        .maybeSingle();

    if (product == null || product['is_active'] != true) {
      throw StateError('This product is currently unavailable.');
    }

    // Save the current product price when adding it.
    // Existing wishlist entries will not have their saved price overwritten.
    final insertedRows = await _supabase
        .from('wishlist')
        .upsert(
          {
            'user_id': userId,
            'product_id': productId,
            'price_at_add': product['price'],
          },
          onConflict: 'user_id,product_id',
          ignoreDuplicates: true,
        )
        .select('product_id');

    // Create a notification only when a new wishlist entry was inserted.
    if (insertedRows.isNotEmpty) {
      try {
        await _notificationRepository.createNotification(
          title: 'Added to Wishlist',
          message: '${product['name']} was added to your wishlist.',
          category: 'wishlist',
          relatedProductId: productId,
          metadata: {
            'event': 'wishlist_added',
            'product_name': product['name'],
          },
        );
      } catch (error) {
        // Notification failure should not interrupt wishlist functionality.
        debugPrint('WISHLIST NOTIFICATION ERROR: $error');
      }
    }
  }

  // Check whether a product is already in the wishlist.
  Future<bool> isInWishlist(String productId) async {
    final userId = _userId;

    final result = await _supabase
        .from('wishlist')
        .select('id')
        .eq('user_id', userId)
        .eq('product_id', productId)
        .maybeSingle();

    return result != null;
  }

  // Fetch all products in the current user's wishlist.
  Future<List<ProductModel>> getWishlistItems() async {
    final userId = _userId;

    final response = await _supabase
        .from('wishlist')
        .select('created_at, price_at_add, products!inner(*)')
        .eq('user_id', userId)
        .eq('products.is_active', true)
        .order('created_at', ascending: false);

    return (response as List).map((item) {
      final product = item['products'] as Map<String, dynamic>;

      return ProductModel.fromMap({
        ...product,
        'wishlist_price_at_add': item['price_at_add'],
      });
    }).toList();
  }

  // Remove a product from the wishlist.
  Future<void> removeFromWishlist(String productId) async {
    final userId = _userId;

    await _supabase
        .from('wishlist')
        .delete()
        .eq('user_id', userId)
        .eq('product_id', productId);
  }

  // Clear the current user's entire wishlist.
  Future<void> clearWishlist() async {
    final userId = _userId;

    await _supabase.from('wishlist').delete().eq('user_id', userId);
  }
}
