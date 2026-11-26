import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product_model.dart';
import 'product_repository.dart';

class TrendingRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ProductRepository _productRepository = ProductRepository();

  /// Fetches trending products based on aggregated product views.
  ///
  /// Products are ranked by views recorded during the selected period.
  /// Only active and in-stock products are returned.
  Future<List<ProductModel>> getTrendingProducts({
    int daysBack = 7,
    int limit = 10,
  }) async {
    if (daysBack <= 0 || limit <= 0) {
      return [];
    }

    try {
      // Fetch aggregated trending product IDs from Supabase.
      final response = await _supabase.rpc(
        'get_trending_products',
        params: {'days_back': daysBack, 'result_limit': limit},
      );

      final rows = response as List;

      if (rows.isEmpty) {
        return [];
      }

      // Preserve the popularity ranking returned by the database.
      final productIds = rows
          .map((row) => row['product_id'].toString())
          .toList();

      // Fetch product details.
      final results = await Future.wait(
        productIds.map(_productRepository.getProductById),
      );

      // Remove unavailable and out-of-stock products.
      return results
          .whereType<ProductModel>()
          .where((product) => product.stockQuantity > 0)
          .toList();
    } catch (error) {
      throw Exception('Unable to load trending products: $error');
    }
  }
}
