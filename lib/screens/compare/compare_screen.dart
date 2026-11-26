import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routes/app_routes.dart';
import '../../models/product_model.dart';
import '../../repositories/cart_repository.dart';
import '../../repositories/compare_repository.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_spacing.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/themes/app_decorations.dart';

class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  final CompareRepository _compareRepository = CompareRepository();
  final CartRepository _cartRepository = CartRepository();

  final Set<String> _addingToCartIds = {};

  List<ProductModel> _products = [];

  bool _isLoading = true;
  String? _error;

  static const Color _background = AppColors.background;
  static const Color _surface = AppColors.surface;
  static const Color _primary = AppColors.primary;
  static const Color _gold = AppColors.gold;
  static const Color _muted = AppColors.textMuted;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final products = await _compareRepository.getComparedProducts();

      if (!mounted) return;

      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Unable to load comparison products.';
        _isLoading = false;
      });
    }
  }

  Future<void> _removeProduct(ProductModel product) async {
    try {
      await _compareRepository.removeProduct(product.id);

      if (!mounted) return;

      setState(() {
        _products.removeWhere((item) => item.id == product.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} removed from comparison.'),
          backgroundColor: _surface,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to remove product.')),
      );
    }
  }

  Future<void> _clearComparison() async {
    if (_products.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surface,
        title: const Text(
          'Clear comparison?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'All products will be removed from your comparison list.',
          style: TextStyle(color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Clear All',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _compareRepository.clearComparison();

      if (!mounted) return;

      setState(() {
        _products.clear();
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to clear comparison.')),
      );
    }
  }

  void _viewProductDetails(ProductModel product) {
    context.push('/product/${product.id}');
  }

  Future<void> _addToCart(ProductModel product) async {
    if (_addingToCartIds.contains(product.id)) return;

    if (product.stockQuantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This product is currently out of stock.'),
        ),
      );
      return;
    }

    setState(() {
      _addingToCartIds.add(product.id);
    });

    try {
      await _cartRepository.addToCart(product.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} added to your cart!'),
          backgroundColor: _surface,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'VIEW CART',
            textColor: _gold,
            onPressed: () {
              context.push(AppRoutes.cart);
            },
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: _surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _addingToCartIds.remove(product.id);
        });
      }
    }
  }

  String _formatPrice(double price) {
    final value = price.toStringAsFixed(0);
    final reversed = value.split('').reversed.toList();

    final formatted = <String>[];

    for (int i = 0; i < reversed.length; i++) {
      if (i > 0 && i % 3 == 0) {
        formatted.add('.');
      }

      formatted.add(reversed[i]);
    }

    return 'Rp ${formatted.reversed.join()}';
  }

  // Products that are currently available for purchase.
  List<ProductModel> get _availableProducts {
    return _products.where((product) => product.stockQuantity > 0).toList();
  }

  // Find the product with the lowest price.
  ProductModel? get _lowestPriceProduct {
    if (_availableProducts.isEmpty) return null;

    return _availableProducts.reduce((a, b) => a.price <= b.price ? a : b);
  }

  // Find the product with the highest customer rating.
  ProductModel? get _highestRatedProduct {
    final ratedProducts = _availableProducts
        .where((product) => product.reviewCount > 0 && product.rating > 0)
        .toList();

    if (ratedProducts.isEmpty) return null;

    return ratedProducts.reduce((a, b) => a.rating >= b.rating ? a : b);
  }

  // Calculate a transparent value score for each product.
  double _calculateValueScore(ProductModel product) {
    if (_availableProducts.isEmpty) return 0;

    final lowestPrice = _lowestPriceProduct!.price;

    final affordabilityScore = product.price > 0 && lowestPrice > 0
        ? ((lowestPrice / product.price) * 100).clamp(0.0, 100.0)
        : 0.0;

    final hasAnyRatedProducts = _availableProducts.any(
      (item) => item.reviewCount > 0 && item.rating > 0,
    );

    // When nobody has reviews, compare affordability alone.
    if (!hasAnyRatedProducts) {
      return affordabilityScore;
    }

    final hasReviews = product.reviewCount > 0 && product.rating > 0;

    final ratingScore = hasReviews
        ? ((product.rating / 5) * 100).clamp(0.0, 100.0)
        : 0.0;

    return (ratingScore * 0.55) + (affordabilityScore * 0.45);
  }

  // Identify the best overall value.
  ProductModel? get _bestValueProduct {
    if (_availableProducts.isEmpty) return null;

    return _availableProducts.reduce(
      (a, b) => _calculateValueScore(a) >= _calculateValueScore(b) ? a : b,
    );
  }

  Widget _buildProductImage(ProductModel product) {
    final imageUrl = product.imageUrl?.trim();

    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        color: _surface,
        child: const Icon(
          Icons.image_not_supported_outlined,
          color: _muted,
          size: 35,
        ),
      );
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: _surface,
          child: const Icon(
            Icons.broken_image_outlined,
            color: _muted,
            size: 35,
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.lg,
        AppSpacing.pageHorizontal,
        AppSpacing.md,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: AppDecorations.premiumCard,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              ),
              child: const Icon(
                Icons.compare_arrows_rounded,
                color: AppColors.gold,
                size: 25,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Compare Products',
                    style: AppTextStyles.headingSmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${_products.length} of ${CompareRepository.maxProducts} products selected',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (_products.isNotEmpty)
              IconButton(
                tooltip: 'Clear comparison',
                onPressed: _clearComparison,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.10),
                  foregroundColor: Colors.redAccent,
                ),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartPickScore({
    required String title,
    required double score,
    required Color color,
  }) {
    final normalizedScore = (score / 100).clamp(0.0, 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${score.toStringAsFixed(0)}%',
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: normalizedScore,
            minHeight: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildSmartPick() {
    final bestValue = _bestValueProduct;
    final lowestPrice = _lowestPriceProduct;
    final highestRated = _highestRatedProduct;

    if (bestValue == null) {
      return Container(
        margin: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _primary.withValues(alpha: 0.25)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: _gold, size: 25),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your selected products are currently out of stock. '
                'Choose an available product to receive a recommendation.',
                style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
              ),
            ),
          ],
        ),
      );
    }

    final score = _calculateValueScore(bestValue);

    // Calculate potential savings.
    final originalPrice = bestValue.compareAtPrice ?? 0;

    final hasDiscount = originalPrice > bestValue.price && bestValue.price > 0;

    final savings = hasDiscount ? originalPrice - bestValue.price : 0.0;

    final discountPercentage = hasDiscount
        ? (savings / originalPrice) * 100
        : 0.0;

    // Calculate individual value components.
    final hasReviews = bestValue.reviewCount > 0 && bestValue.rating > 0;

    final hasAnyRatedProducts = _availableProducts.any(
      (product) => product.reviewCount > 0 && product.rating > 0,
    );

    final ratingScore = hasReviews
        ? (bestValue.rating / 5 * 100).clamp(0.0, 100.0)
        : 0.0;

    final affordabilityScore =
        bestValue.price > 0 && lowestPrice != null && lowestPrice.price > 0
        ? (lowestPrice.price / bestValue.price * 100).clamp(0.0, 100.0)
        : 0.0;

    // Generate a recommendation based on actual product information.
    final recommendation = !hasAnyRatedProducts
        ? 'Customer ratings are not available for these products yet. This recommendation is based on affordability.'
        : !hasReviews
        ? 'This product has no customer reviews yet. Consider checking customer feedback before purchasing.'
        : bestValue.rating >= 4.5
        ? 'Excellent customer feedback combined with competitive pricing makes this a strong choice.'
        : bestValue.rating >= 4.0
        ? 'Good customer feedback and competitive pricing make this a worthwhile option.'
        : bestValue.rating >= 3.0
        ? 'Customer feedback is mixed. Compare other options before making your decision.'
        : 'Customer ratings are relatively low. Consider other products before purchasing.';

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF30204F), Color(0xFF191927)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _gold.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section heading.
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: _gold,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SMART PICK',
                      style: TextStyle(
                        color: _gold,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Your intelligent shopping assistant',
                      style: TextStyle(color: _muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.workspace_premium_rounded,
                color: _gold,
                size: 27,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Best value product.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _gold.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.emoji_events_rounded,
                      color: _gold,
                      size: 19,
                    ),
                    const SizedBox(width: 7),
                    const Expanded(
                      child: Text(
                        'BEST VALUE',
                        style: TextStyle(
                          color: _gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${score.toStringAsFixed(0)}/100',
                        style: const TextStyle(
                          color: _gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Text(
                  bestValue.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 8),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        _formatPrice(bestValue.price),
                        style: const TextStyle(
                          color: _gold,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (hasDiscount) ...[
                      const SizedBox(width: 9),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${discountPercentage.toStringAsFixed(0)}% OFF',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                if (hasDiscount) ...[
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Text(
                        _formatPrice(originalPrice),
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 11,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'You save ${_formatPrice(savings)}',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 10),

                Text(
                  recommendation,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 11,
                    height: 1.6,
                  ),
                ),

                // INSERT NEW CODE BELOW THIS LINE
                const SizedBox(height: 16),

                // Value score breakdown.
                if (hasAnyRatedProducts)
                  _buildSmartPickScore(
                    title: 'Customer Rating',
                    score: ratingScore.toDouble(),
                    color: _gold,
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: _muted,
                          size: 15,
                        ),
                        SizedBox(width: 7),
                        Text(
                          'Customer Rating: Not available yet',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),

                _buildSmartPickScore(
                  title: 'Affordability',
                  score: affordabilityScore.toDouble(),
                  color: Colors.greenAccent,
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      color: Colors.greenAccent,
                      size: 15,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        '${bestValue.stockQuantity} units currently available',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 13),

                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: _gold, size: 17),
                    const SizedBox(width: 5),
                    Text(
                      hasReviews
                          ? '${bestValue.rating.toStringAsFixed(1)} / 5 customer rating (${bestValue.reviewCount} reviews)'
                          : 'No customer reviews yet',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _viewProductDetails(bestValue),
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: const Text(
                          'View Details',
                          style: TextStyle(fontSize: 11),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: _gold.withValues(alpha: 0.6)),
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            bestValue.stockQuantity > 0 &&
                                !_addingToCartIds.contains(bestValue.id)
                            ? () => _addToCart(bestValue)
                            : null,
                        icon: _addingToCartIds.contains(bestValue.id)
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.shopping_cart_outlined,
                                size: 16,
                              ),
                        label: Text(
                          _addingToCartIds.contains(bestValue.id)
                              ? 'Adding...'
                              : bestValue.stockQuantity > 0
                              ? 'Add to Cart'
                              : 'Out of Stock',
                          style: const TextStyle(fontSize: 11),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: Colors.grey.shade800,
                          disabledForegroundColor: Colors.white54,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 5,
                          ),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          const Text(
            'OTHER TOP PICKS',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),

          const SizedBox(height: 11),

          // Lowest price alternative — only if different from Best Value.
          if (lowestPrice != null && lowestPrice.id != bestValue.id)
            _buildSmartPickTile(
              icon: Icons.savings_rounded,
              title: 'Lowest Price',
              productName: lowestPrice.name,
              value: _formatPrice(lowestPrice.price),
              color: Colors.greenAccent,
            ),

          if (lowestPrice != null && lowestPrice.id != bestValue.id)
            const SizedBox(height: 9),

          // Highest rated alternative — avoid duplicate recommendations.
          if (highestRated != null &&
              highestRated.id != bestValue.id &&
              highestRated.id != lowestPrice?.id)
            _buildSmartPickTile(
              icon: Icons.star_rounded,
              title: 'Highest Rated',
              productName: highestRated.name,
              value: '${highestRated.rating.toStringAsFixed(1)} / 5',
              color: _gold,
            ),
          const SizedBox(height: 16),

          // Purchase recommendation.
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  color: Color(0xFFA78BFA),
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Smart advice: Compare the price and customer '
                    'rating before purchasing. The best value is '
                    'not always the cheapest product.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartPickTile({
    required IconData icon,
    required String title,
    required String productName,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductBadge({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.65)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCards() {
    final bestValue = _bestValueProduct;
    final lowestPrice = _lowestPriceProduct;
    final highestRated = _highestRatedProduct;

    return SizedBox(
      height: 375,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _products.length,
        separatorBuilder: (_, index) => const SizedBox(width: 13),
        itemBuilder: (context, index) {
          final product = _products[index];

          final isBestValue = bestValue?.id == product.id;
          final isLowestPrice = lowestPrice?.id == product.id;
          final isHighestRated =
              highestRated?.id == product.id && product.rating > 0;

          final isOutOfStock = product.stockQuantity <= 0;
          final isAdding = _addingToCartIds.contains(product.id);

          return Container(
            width: 190,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_surface, _background],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
              border: Border.all(
                color: isBestValue
                    ? _gold.withValues(alpha: 0.65)
                    : _primary.withValues(alpha: 0.25),
                width: isBestValue ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(18),
                      ),
                      child: SizedBox(
                        height: 125,
                        width: double.infinity,
                        child: _buildProductImage(product),
                      ),
                    ),

                    // Product winner badges.
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isBestValue)
                            _buildProductBadge(
                              label: 'BEST VALUE',
                              icon: Icons.emoji_events_rounded,
                              color: _gold,
                            ),
                          if (isBestValue && isLowestPrice)
                            const SizedBox(height: 5),
                          if (isLowestPrice)
                            _buildProductBadge(
                              label: 'LOWEST PRICE',
                              icon: Icons.trending_down_rounded,
                              color: Colors.greenAccent,
                            ),
                          if (isHighestRated)
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: _buildProductBadge(
                                label: 'TOP RATED',
                                icon: Icons.star_rounded,
                                color: Colors.orangeAccent,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Remove product button.
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.7),
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Remove product',
                          onPressed: () => _removeProduct(product),
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 17,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          _formatPrice(product.price),
                          style: const TextStyle(
                            color: _gold,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Row(
                          children: [
                            Icon(
                              isOutOfStock
                                  ? Icons.cancel_rounded
                                  : Icons.check_circle_rounded,
                              size: 12,
                              color: isOutOfStock
                                  ? Colors.redAccent
                                  : Colors.greenAccent,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                isOutOfStock
                                    ? 'Out of Stock'
                                    : '${product.stockQuantity} units available',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isOutOfStock
                                      ? Colors.redAccent
                                      : Colors.greenAccent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const Spacer(),

                        // View product details.
                        SizedBox(
                          width: double.infinity,
                          height: 32,
                          child: OutlinedButton(
                            onPressed: () => _viewProductDetails(product),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _primary,
                              side: BorderSide(
                                color: _primary.withValues(alpha: 0.6),
                              ),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'VIEW DETAILS',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),

                        // Add product to cart.
                        SizedBox(
                          width: double.infinity,
                          height: 32,
                          child: ElevatedButton(
                            onPressed: isOutOfStock || isAdding
                                ? null
                                : () => _addToCart(product),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              disabledBackgroundColor: Colors.grey.shade800,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: isAdding
                                ? const SizedBox(
                                    height: 15,
                                    width: 15,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    isOutOfStock
                                        ? 'OUT OF STOCK'
                                        : 'ADD TO CART',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatSpecificationValue(dynamic value) {
    if (value == null) {
      return 'Not specified';
    }

    if (value is List) {
      if (value.isEmpty) return 'Not specified';

      return value.join(', ');
    }

    if (value is Map) {
      if (value.isEmpty) return 'Not specified';

      return value.entries
          .map((entry) => '${entry.key}: ${entry.value}')
          .join('\n');
    }

    final formatted = value.toString().trim();

    return formatted.isEmpty ? 'Not specified' : formatted;
  }

  ProductModel? _getBestProduct(
    double Function(ProductModel product) value, {
    bool lowestIsBest = false,
  }) {
    if (_products.isEmpty) return null;

    final comparableProducts = _products.where(
      (product) => product.stockQuantity > 0,
    );

    final products = comparableProducts.isNotEmpty
        ? comparableProducts.toList()
        : _products;

    return products.reduce((a, b) {
      final first = value(a);
      final second = value(b);

      if (lowestIsBest) {
        return first <= second ? a : b;
      }

      return first >= second ? a : b;
    });
  }

  bool _isWinner(ProductModel product, ProductModel? winner) {
    return winner != null && product.id == winner.id;
  }

  Widget _buildLegendItem({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: _muted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonTable() {
    // Identify winners for comparable product attributes.
    final availableForPriceComparison = _products
        .where((product) => product.stockQuantity > 0)
        .toList();

    final lowestPrice = availableForPriceComparison.isEmpty
        ? null
        : availableForPriceComparison.reduce(
            (a, b) => a.price <= b.price ? a : b,
          );

    final ratedProducts = _products
        .where(
          (product) =>
              product.stockQuantity > 0 &&
              product.reviewCount > 0 &&
              product.rating > 0,
        )
        .toList();

    final highestRated = ratedProducts.isEmpty
        ? null
        : ratedProducts.reduce((a, b) => a.rating >= b.rating ? a : b);

    final reviewedProducts = _products
        .where((product) => product.reviewCount > 0)
        .toList();

    final mostReviewed = reviewedProducts.isEmpty
        ? null
        : reviewedProducts.reduce(
            (a, b) => a.reviewCount >= b.reviewCount ? a : b,
          );

    final highestStock = _getBestProduct(
      (product) => product.stockQuantity.toDouble(),
    );

    // Avoid awarding a winner when nobody has ratings or reviews.
    final ratingWinner = highestRated != null && highestRated.rating > 0
        ? highestRated
        : null;

    final reviewWinner = mostReviewed != null && mostReviewed.reviewCount > 0
        ? mostReviewed
        : null;

    final stockWinner = highestStock != null && highestStock.stockQuantity > 0
        ? highestStock
        : null;

    // Standard product information.
    final specifications = <_ComparisonRow>[
      _ComparisonRow(
        label: 'Brand',
        value: (product) {
          final brand = product.brand?.trim();
          return brand == null || brand.isEmpty ? 'Not available' : brand;
        },
      ),
      _ComparisonRow(
        label: 'Product Type',
        value: (product) => product.productType?.trim().isNotEmpty == true
            ? product.productType!.trim()
            : 'Not available',
      ),
      _ComparisonRow(
        label: 'Price',
        value: (product) => _formatPrice(product.price),
      ),
      _ComparisonRow(
        label: 'Original Price',
        value: (product) =>
            product.compareAtPrice != null &&
                product.compareAtPrice! > product.price
            ? _formatPrice(product.compareAtPrice!)
            : 'No discount',
      ),
      _ComparisonRow(
        label: 'Category',
        value: (product) {
          final category = product.category.trim();
          return category.isEmpty ? 'Not available' : category;
        },
      ),
      _ComparisonRow(
        label: 'Rating',
        value: (product) => product.reviewCount > 0 && product.rating > 0
            ? '${product.rating.toStringAsFixed(1)} / 5'
            : 'No reviews yet',
      ),
      _ComparisonRow(
        label: 'Reviews',
        value: (product) => product.reviewCount > 0
            ? '${product.reviewCount} reviews'
            : 'No reviews yet',
      ),
      _ComparisonRow(
        label: 'Stock',
        value: (product) => '${product.stockQuantity} units',
      ),
      _ComparisonRow(
        label: 'Availability',
        value: (product) =>
            product.stockQuantity > 0 ? 'In Stock' : 'Out of Stock',
      ),
      _ComparisonRow(
        label: 'SKU',
        value: (product) => product.sku?.trim().isNotEmpty == true
            ? product.sku!.trim()
            : 'Not available',
      ),
      _ComparisonRow(
        label: 'Description',
        value: (product) {
          final description = product.description?.trim();
          return description == null || description.isEmpty
              ? 'No description available'
              : description;
        },
      ),
    ];

    // Collect all unique specification keys from selected products.
    final specificationKeys = <String>{};

    for (final product in _products) {
      for (final entry in product.specifications.entries) {
        final value = entry.value;

        final hasValue =
            value != null &&
            (value is List
                ? value.isNotEmpty
                : value is Map
                ? value.isNotEmpty
                : value.toString().trim().isNotEmpty);

        if (hasValue) {
          specificationKeys.add(entry.key);
        }
      }
    }

    final sortedKeys = specificationKeys.toList()..sort();

    // Add dynamic specifications from Supabase JSONB.
    for (final key in sortedKeys) {
      specifications.add(
        _ComparisonRow(
          label: key
              .replaceAll('_', ' ')
              .split(' ')
              .map(
                (word) => word.isEmpty
                    ? word
                    : '${word[0].toUpperCase()}${word.substring(1)}',
              )
              .join(' '),
          value: (product) =>
              _formatSpecificationValue(product.specifications[key]),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.xl,
        AppSpacing.pageHorizontal,
        AppSpacing.lg,
      ),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Product Specifications',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Compare product details side by side.',
                  style: TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF30303D), height: 1),

          // Comparison winner legend.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Wrap(
              spacing: 14,
              runSpacing: 10,
              children: [
                _buildLegendItem(
                  color: Colors.greenAccent,
                  label: 'Lowest Price',
                ),
                _buildLegendItem(color: _gold, label: 'Top Rated / Reviews'),
                _buildLegendItem(color: _primary, label: 'Highest Stock'),
              ],
            ),
          ),

          const Divider(color: Color(0xFF30303D), height: 1),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              horizontalMargin: 14,
              columnSpacing: 22,
              headingRowHeight: 48,
              dataRowMinHeight: 54,
              dataRowMaxHeight: 160,
              columns: [
                const DataColumn(
                  label: Text(
                    'FEATURE',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ..._products.map(
                  (product) => DataColumn(
                    label: SizedBox(
                      width: 125,
                      child: Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              rows: specifications.map((specification) {
                return DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 90,
                        child: Text(
                          specification.label,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    ..._products.map((product) {
                      // Determine the winner for this comparison row.
                      final winner = switch (specification.label) {
                        'Price' => lowestPrice,
                        'Rating' => ratingWinner,
                        'Reviews' => reviewWinner,
                        'Stock' => stockWinner,
                        _ => null,
                      };

                      final isWinner = _isWinner(product, winner);

                      // Availability gets its own color treatment.
                      final isAvailability =
                          specification.label == 'Availability';

                      final availabilityColor = product.stockQuantity > 0
                          ? Colors.greenAccent
                          : Colors.redAccent;

                      final textColor = isAvailability
                          ? availabilityColor
                          : isWinner
                          ? _gold
                          : Colors.white;

                      final winnerColor = switch (specification.label) {
                        'Price' => Colors.greenAccent,
                        'Rating' => _gold,
                        'Reviews' => _gold,
                        'Stock' => _primary,
                        _ => _gold,
                      };

                      return DataCell(
                        SizedBox(
                          width: 125,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isWinner
                                  ? winnerColor.withValues(alpha: 0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    specification.value(product),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 11,
                                      height: 1.5,
                                      fontWeight: isWinner
                                          ? FontWeight.w800
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (isWinner) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.emoji_events_rounded,
                                    size: 15,
                                    color: winnerColor,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: AppDecorations.premiumCard,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 100,
                width: 100,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXXLarge),
                ),
                child: const Icon(
                  Icons.compare_arrows_rounded,
                  color: AppColors.primary,
                  size: 48,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Nothing to Compare Yet',
                textAlign: TextAlign.center,
                style: AppTextStyles.headingMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Add products to your comparison list to evaluate their prices, ratings and specifications side by side.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textMuted,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('Continue Shopping'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.6),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusMedium,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: AppDecorations.card,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: Colors.redAccent,
                size: 48,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Unable to Load Comparison',
                style: AppTextStyles.headingSmall.copyWith(
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error ?? 'Something went wrong.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: _loadProducts,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Text(
          'Smart Comparison',
          style: AppTextStyles.headingSmall.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Loading comparison...',
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
            )
          : _error != null
          ? _buildErrorState()
          : _products.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              color: _primary,
              onRefresh: _loadProducts,
              child: ListView(
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                children: [
                  _buildHeader(),
                  _buildSmartPick(),
                  _buildProductCards(),
                  _buildComparisonTable(),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
    );
  }
}

class _ComparisonRow {
  final String label;
  final String Function(ProductModel product) value;

  const _ComparisonRow({required this.label, required this.value});
}
