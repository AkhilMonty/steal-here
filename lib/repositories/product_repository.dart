import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product_model.dart';
import '../models/product_variant_model.dart';

class ProductRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch all active products.
  Future<List<ProductModel>> getProducts() async {
    final response = await _supabase
        .from('products')
        .select()
        .eq('is_active', true)
        .order('created_at', ascending: false);

    return (response as List)
        .map((product) => ProductModel.fromMap(product as Map<String, dynamic>))
        .toList();
  }

  /// Fetch featured active products.
  Future<List<ProductModel>> getFeaturedProducts() async {
    final response = await _supabase
        .from('products')
        .select()
        .eq('is_active', true)
        .eq('is_featured', true)
        .order('created_at', ascending: false);

    return (response as List)
        .map((product) => ProductModel.fromMap(product as Map<String, dynamic>))
        .toList();
  }

  /// Fetch products belonging to a category.
  Future<List<ProductModel>> getProductsByCategory(String category) async {
    final response = await _supabase
        .from('products')
        .select()
        .eq('is_active', true)
        .eq('category', category)
        .order('created_at', ascending: false);

    return (response as List)
        .map((product) => ProductModel.fromMap(product as Map<String, dynamic>))
        .toList();
  }

  /// Fetch products belonging to a specific product type.
  ///
  /// Example: Electronics + Headphones.
  Future<List<ProductModel>> getProductsByType({
    required String category,
    required String productType,
  }) async {
    final response = await _supabase
        .from('products')
        .select()
        .eq('is_active', true)
        .eq('category', category)
        .eq('product_type', productType)
        .order('created_at', ascending: false);

    return (response as List)
        .map((product) => ProductModel.fromMap(product as Map<String, dynamic>))
        .toList();
  }

  /// Fetch a single active product by ID.
  Future<ProductModel?> getProductById(String productId) async {
    final response = await _supabase
        .from('products')
        .select()
        .eq('id', productId)
        .eq('is_active', true)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return ProductModel.fromMap(response);
  }

  /// Fetch all active variants belonging to a product.
  Future<List<ProductVariantModel>> getProductVariants(String productId) async {
    final response = await _supabase
        .from('product_variants')
        .select()
        .eq('product_id', productId)
        .eq('is_active', true)
        .order('created_at', ascending: true);

    return (response as List)
        .map(
          (variant) =>
              ProductVariantModel.fromMap(variant as Map<String, dynamic>),
        )
        .toList();
  }

  /// Fetch one active variant by its ID.
  Future<ProductVariantModel?> getProductVariantById(String variantId) async {
    final response = await _supabase
        .from('product_variants')
        .select()
        .eq('id', variantId)
        .eq('is_active', true)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return ProductVariantModel.fromMap(response);
  }

  /// Fetch personalized recommendations based on the current customer's
  /// browsing history, wishlist, and previous orders.
  ///
  /// New customers receive featured products and popular alternatives.
  Future<List<ProductModel>> getPersonalizedProducts({
    required List<ProductModel> catalog,
    int limit = 8,
  }) async {
    final user = _supabase.auth.currentUser;

    // Only recommend active products that are currently in stock.
    final availableProducts = catalog
        .where((product) => product.isActive && product.stockQuantity > 0)
        .toList();

    if (availableProducts.isEmpty) {
      return [];
    }

    // Fallback for guests or new customers.
    List<ProductModel> getFallbackProducts() {
      final fallback = [...availableProducts];

      fallback.sort((a, b) {
        final featuredComparison = (b.isFeatured ? 1 : 0).compareTo(
          a.isFeatured ? 1 : 0,
        );

        if (featuredComparison != 0) {
          return featuredComparison;
        }

        final ratingComparison = b.rating.compareTo(a.rating);

        if (ratingComparison != 0) {
          return ratingComparison;
        }

        return b.reviewCount.compareTo(a.reviewCount);
      });

      return fallback.take(limit).toList();
    }

    if (user == null) {
      return getFallbackProducts();
    }

    try {
      final userId = user.id;

      // 1. Fetch recently viewed products.
      final viewsResponse = await _supabase
          .from('product_views')
          .select('product_id')
          .eq('user_id', userId)
          .order('viewed_at', ascending: false)
          .limit(30);

      // 2. Fetch wishlist products.
      final wishlistResponse = await _supabase
          .from('wishlist')
          .select('product_id')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(30);

      // 3. Fetch the customer's recent orders.
      final ordersResponse = await _supabase
          .from('orders')
          .select('id')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(20);

      final orderIds = (ordersResponse as List)
          .map((order) => order['id'] as String)
          .toList();

      // 4. Fetch products from those orders.
      List<dynamic> purchasedProductRows = [];

      if (orderIds.isNotEmpty) {
        purchasedProductRows = await _supabase
            .from('order_items')
            .select('product_id')
            .inFilter('order_id', orderIds);
      }

      // 5. Calculate interaction weights.
      //
      // Browsing = 1 point
      // Wishlist = 3 points
      // Purchase = 4 points

      final Map<String, int> productScores = {};

      void addInteractions(List<dynamic> rows, int weight) {
        for (final row in rows) {
          final productId = row['product_id'] as String?;

          if (productId == null) continue;

          productScores.update(
            productId,
            (score) => score + weight,
            ifAbsent: () => weight,
          );
        }
      }

      addInteractions(viewsResponse as List, 1);
      addInteractions(wishlistResponse as List, 3);
      addInteractions(purchasedProductRows, 4);

      // No activity means this is probably a new customer.
      if (productScores.isEmpty) {
        return getFallbackProducts();
      }

      // 6. Match customer activity with products in our catalog.
      final productsById = {
        for (final product in availableProducts) product.id: product,
      };

      final Map<String, int> categoryScores = {};
      final Map<String, int> brandScores = {};

      for (final entry in productScores.entries) {
        final product = productsById[entry.key];

        if (product == null) continue;

        final weight = entry.value;

        categoryScores.update(
          product.category,
          (score) => score + weight,
          ifAbsent: () => weight,
        );

        final brand = product.brand?.trim();

        if (brand != null && brand.isNotEmpty) {
          brandScores.update(
            brand.toLowerCase(),
            (score) => score + weight,
            ifAbsent: () => weight,
          );
        }
      }

      // 7. Rank other products using category and brand relevance.
      final recommendations = availableProducts
          .where((product) => !productScores.containsKey(product.id))
          .toList();

      int getRecommendationScore(ProductModel product) {
        final categoryScore = categoryScores[product.category] ?? 0;

        final brandScore = product.brand == null
            ? 0
            : brandScores[product.brand!.toLowerCase()] ?? 0;

        return (categoryScore * 2) + brandScore;
      }

      recommendations.sort((a, b) {
        final scoreComparison = getRecommendationScore(b)
            .compareTo(getRecommendationScore(a));

        if (scoreComparison != 0) {
          return scoreComparison;
        }

        final ratingComparison = b.rating.compareTo(a.rating);

        if (ratingComparison != 0) {
          return ratingComparison;
        }

        return b.reviewCount.compareTo(a.reviewCount);
      });

      // 8. Use fallback products if no relevant recommendations exist.
      if (recommendations.isEmpty ||
          getRecommendationScore(recommendations.first) == 0) {
        return getFallbackProducts();
      }

      return recommendations.take(limit).toList();
    } catch (error) {
      // Recommendation failures should not break the shopping experience.
      return getFallbackProducts();
    }
  }
}
