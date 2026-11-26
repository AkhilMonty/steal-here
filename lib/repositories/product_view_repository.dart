import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product_view_model.dart';
import '../models/product_model.dart';

class ProductViewRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get _userId => _supabase.auth.currentUser?.id;

  /// Record a product view for the logged-in customer.
  Future<void> recordProductView(String productId) async {
    final userId = _userId;

    // Do not track anonymous browsing.
    if (userId == null) {
      return;
    }

    await _supabase.from('product_views').insert({
      'user_id': userId,
      'product_id': productId,
    });
  }

  /// Fetch recent browsing history.
  Future<List<ProductViewModel>> getRecentViews({int limit = 50}) async {
    final userId = _userId;

    if (userId == null) {
      return [];
    }

    final response = await _supabase
        .from('product_views')
        .select()
        .eq('user_id', userId)
        .order('viewed_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map(
          (item) => ProductViewModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  /// Fetch unique, recently viewed products for the logged-in customer.
  Future<List<ProductModel>> getRecentlyViewedProducts({int limit = 10}) async {
    if (limit <= 0) return [];

    final views = await getRecentViews(limit: 100);

    if (views.isEmpty) return [];

    // Remove duplicate product IDs while preserving recent-view order.
    final productIds = <String>[];

    for (final view in views) {
      if (!productIds.contains(view.productId)) {
        productIds.add(view.productId);
      }

      if (productIds.length >= limit) break;
    }

    if (productIds.isEmpty) return [];

    final response = await _supabase
        .from('products')
        .select()
        .inFilter('id', productIds)
        .eq('is_active', true)
        .gt('stock_quantity', 0);

    final products = (response as List)
        .map((item) => ProductModel.fromMap(Map<String, dynamic>.from(item)))
        .toList();

    // Preserve the order in which products were most recently viewed.
    final productsById = {for (final product in products) product.id: product};

    return productIds
        .where((id) => productsById.containsKey(id))
        .map((id) => productsById[id]!)
        .toList();
  }

  /// Clear the customer's browsing history.
  Future<void> clearBrowsingHistory() async {
    final userId = _userId;

    if (userId == null) {
      return;
    }

    await _supabase.from('product_views').delete().eq('user_id', userId);
  }
}
