import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product_model.dart';
import '../models/product_recommendation_model.dart';

class RecommendationRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get _userId => _supabase.auth.currentUser?.id;

  /// Fetch personalized product recommendations with explanations.
  Future<List<ProductRecommendationModel>> getRecommendations({
    int limit = 10,
  }) async {
    if (limit <= 0) return [];

    try {
      // Fetch active products that are currently in stock.
      final productsResponse = await _supabase
          .from('products')
          .select()
          .eq('is_active', true)
          .gt('stock_quantity', 0)
          .order('rating', ascending: false)
          .limit(100);

      final products = (productsResponse as List)
          .map((item) => ProductModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();

      if (products.isEmpty) return [];

      final userId = _userId;

      // Guest users receive popular product recommendations.
      if (userId == null) {
        return _getTrendingRecommendations(products, limit);
      }

      // Fetch wishlist product information.
      final wishlistResponse = await _supabase
          .from('wishlist')
          .select('product_id')
          .eq('user_id', userId);

      final wishlistIds = wishlistResponse
          .map((item) => item['product_id'] as String)
          .toSet();

      final preferredCategories = <String, int>{};
      final preferredProductTypes = <String, int>{};
      final preferredBrands = <String, int>{};

      final viewedCategoryCounts = <String, int>{};
      final purchasedCategories = <String>{};
      final wishlistCategories = <String>{};

      final purchasedIds = <String>{};

      // -------------------------------------------------
      // BROWSING HISTORY
      // -------------------------------------------------

      final viewsResponse = await _supabase
          .from('product_views')
          .select('product_id')
          .eq('user_id', userId)
          .order('viewed_at', ascending: false)
          .limit(50);

      if (viewsResponse.isNotEmpty) {
        final viewedProductIds = viewsResponse
            .map((view) => view['product_id'] as String)
            .toSet()
            .toList();

        final viewedProductsResponse = await _supabase
            .from('products')
            .select('id, category, product_type, brand')
            .inFilter('id', viewedProductIds);

        final viewedProducts = {
          for (final item in viewedProductsResponse) item['id'] as String: item,
        };

        for (final view in viewsResponse) {
          final productId = view['product_id'] as String?;
          final viewedProduct = viewedProducts[productId];

          if (viewedProduct == null) continue;

          final category = _normalize(viewedProduct['category']);
          final productType = _normalize(viewedProduct['product_type']);
          final brand = _normalize(viewedProduct['brand']);

          _addPreference(
            viewedCategoryCounts,
            category,
            preferredCategories,
            1,
          );

          if (productType != null) {
            preferredProductTypes[productType] =
                (preferredProductTypes[productType] ?? 0) + 1;
          }

          if (brand != null) {
            preferredBrands[brand] = (preferredBrands[brand] ?? 0) + 1;
          }
        }
      }

      // -------------------------------------------------
      // PURCHASE HISTORY
      // -------------------------------------------------

      final ordersResponse = await _supabase
          .from('orders')
          .select('id, status, payment_status')
          .eq('user_id', userId);

      final orders = List<Map<String, dynamic>>.from(ordersResponse);

      // Only paid, non-cancelled and non-failed orders
      // contribute to purchase preferences.
      final eligibleOrderIds = orders
          .where((order) {
            final status = order['status'].toString().toLowerCase();
            final paymentStatus = order['payment_status']
                .toString()
                .toLowerCase();

            return paymentStatus == 'paid' &&
                status != 'cancelled' &&
                status != 'failed';
          })
          .map((order) => order['id'] as String)
          .toList();

      // Exclude orders whose returns have been completed.
      final completedReturnedOrderIds = <String>{};

      if (eligibleOrderIds.isNotEmpty) {
        final returnedOrdersResponse = await _supabase
            .from('order_return_requests')
            .select('order_id')
            .eq('user_id', userId)
            .inFilter('order_id', eligibleOrderIds)
            .eq('status', 'completed');

        completedReturnedOrderIds.addAll(
          returnedOrdersResponse.map((item) => item['order_id'] as String),
        );
      }

      final validOrderIds = eligibleOrderIds
          .where((orderId) => !completedReturnedOrderIds.contains(orderId))
          .toList();

      if (validOrderIds.isNotEmpty) {
        final itemsResponse = await _supabase
            .from('order_items')
            .select('product_id, product_category')
            .inFilter('order_id', validOrderIds);

        for (final item in itemsResponse) {
          final productId = item['product_id'] as String?;
          final category = _normalize(item['product_category']);

          if (productId != null) {
            purchasedIds.add(productId);
          }

          if (category != null) {
            purchasedCategories.add(category);

            preferredCategories[category] =
                (preferredCategories[category] ?? 0) + 2;
          }
        }
      }

      // -------------------------------------------------
      // WISHLIST PREFERENCES
      // -------------------------------------------------

      if (wishlistIds.isNotEmpty) {
        final wishlistProductsResponse = await _supabase
            .from('products')
            .select('id, category, product_type, brand')
            .inFilter('id', wishlistIds.toList());

        for (final product in wishlistProductsResponse) {
          final category = _normalize(product['category']);
          final productType = _normalize(product['product_type']);
          final brand = _normalize(product['brand']);

          if (category != null) {
            wishlistCategories.add(category);

            preferredCategories[category] =
                (preferredCategories[category] ?? 0) + 3;
          }

          if (productType != null) {
            preferredProductTypes[productType] =
                (preferredProductTypes[productType] ?? 0) + 2;
          }

          if (brand != null) {
            preferredBrands[brand] = (preferredBrands[brand] ?? 0) + 2;
          }
        }
      }

      // -------------------------------------------------
      // CHECK CUSTOMER PERSONALIZATION ACTIVITY
      // -------------------------------------------------

      final hasPersonalActivity =
          viewedCategoryCounts.isNotEmpty ||
          wishlistIds.isNotEmpty ||
          purchasedIds.isNotEmpty;

      // A customer without browsing, wishlist, or purchase
      // activity should receive popular recommendations.
      if (!hasPersonalActivity) {
        return _getTrendingRecommendations(products, limit);
      }

      // -------------------------------------------------
      // FILTER RECOMMENDATION CANDIDATES
      // -------------------------------------------------

      final candidates = products.where((product) {
        return !purchasedIds.contains(product.id) &&
            !wishlistIds.contains(product.id);
      }).toList();

      if (candidates.isEmpty) {
        return _getTrendingRecommendations(products, limit);
      }

      // -------------------------------------------------
      // SCORE AND EXPLAIN RECOMMENDATIONS
      // -------------------------------------------------

      final scoredProducts = candidates.map((product) {
        final category = _normalize(product.category);
        final productType = _normalize(product.productType);
        final brand = _normalize(product.brand);

        double score = 0;

        // Category preference.
        if (category != null) {
          score += (preferredCategories[category] ?? 0) * 10;
        }

        // Product type preference.
        if (productType != null) {
          score += (preferredProductTypes[productType] ?? 0) * 5;
        }

        // Brand preference.
        if (brand != null) {
          score += (preferredBrands[brand] ?? 0) * 4;
        }

        // Product quality.
        score += product.rating.clamp(0, 5) * 5;

        // Review popularity.
        score += product.reviewCount.clamp(0, 100) * 0.1;

        // Featured product boost.
        if (product.isFeatured) {
          score += 5;
        }

        // Recently added product boost.
        if (product.createdAt != null) {
          final age = DateTime.now().difference(product.createdAt!).inDays;

          if (age >= 0 && age <= 30) {
            score += 2;
          }
        }

        // Generate recommendation explanations.
        late String reason;
        late String reasonLabel;

        if (category != null && wishlistCategories.contains(category)) {
          reason = 'Based on categories in your wishlist.';
          reasonLabel = 'Wishlist Interest';
        } else if (category != null && purchasedCategories.contains(category)) {
          reason = 'Based on categories you have purchased before.';
          reasonLabel = 'Based on Purchases';
        } else if (category != null &&
            viewedCategoryCounts.containsKey(category)) {
          reason = 'Similar to categories you have recently explored.';
          reasonLabel = 'Recently Viewed';
        } else if (productType != null &&
            preferredProductTypes.containsKey(productType)) {
          reason = 'Based on product types you are interested in.';
          reasonLabel = 'Your Interests';
        } else if (brand != null && preferredBrands.containsKey(brand)) {
          reason = 'Based on brands you have shown interest in.';
          reasonLabel = 'Preferred Brand';
        } else if (product.rating >= 4.5) {
          reason = 'Customers love this highly rated product.';
          reasonLabel = 'Highly Rated';
        } else if (product.isFeatured) {
          reason = 'Handpicked from our featured collection.';
          reasonLabel = 'Featured Pick';
        } else {
          reason = 'Discover another product from our collection.';
          reasonLabel = 'Recommended For You';
        }

        return MapEntry(
          ProductRecommendationModel(
            product: product,
            reason: reason,
            reasonLabel: reasonLabel,
            type: RecommendationType.personalized,
          ),
          score,
        );
      }).toList();

      scoredProducts.sort((a, b) => b.value.compareTo(a.value));

      return scoredProducts.take(limit).map((entry) => entry.key).toList();
    } catch (error, stackTrace) {
      debugPrint('RECOMMENDATION ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  // -------------------------------------------------
  // HELPER METHODS
  // -------------------------------------------------

  String? _normalize(dynamic value) {
    if (value == null) return null;

    final normalized = value.toString().trim().toLowerCase();

    return normalized.isEmpty ? null : normalized;
  }

  void _addPreference(
    Map<String, int> target,
    String? value,
    Map<String, int> combined,
    int weight,
  ) {
    if (value == null) return;

    target[value] = (target[value] ?? 0) + 1;

    combined[value] = (combined[value] ?? 0) + weight;
  }

  List<ProductRecommendationModel> _getTrendingRecommendations(
    List<ProductModel> products,
    int limit,
  ) {
    final sortedProducts = [...products];

    sortedProducts.sort((a, b) {
      final scoreComparison = _trendingScore(b).compareTo(_trendingScore(a));

      if (scoreComparison != 0) return scoreComparison;

      return b.reviewCount.compareTo(a.reviewCount);
    });

    return sortedProducts.take(limit).map((product) {
      final highlyRated = product.rating >= 4.0;

      return ProductRecommendationModel(
        product: product,
        reason: highlyRated
            ? 'Customers rate this product highly.'
            : 'Discover a popular product from our collection.',
        reasonLabel: highlyRated ? 'Highly Rated' : 'Popular Pick',
        type: RecommendationType.popular,
      );
    }).toList();
  }

  double _trendingScore(ProductModel product) {
    return product.rating.clamp(0, 5) * 3 +
        product.reviewCount.clamp(0, 100) * 0.1 +
        (product.isFeatured ? 2 : 0);
  }
}
