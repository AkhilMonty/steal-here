import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/themes/app_colors.dart';
import '../../core/themes/app_spacing.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/themes/app_decorations.dart';

import '../../core/routes/app_routes.dart';
import '../../models/product_model.dart';
import '../../repositories/cart_repository.dart';
import '../../repositories/wishlist_repository.dart';
import '../../repositories/product_repository.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final WishlistRepository _wishlistRepository = WishlistRepository();
  final CartRepository _cartRepository = CartRepository();
  final ProductRepository _productRepository = ProductRepository();

  late Future<List<ProductModel>> _wishlistFuture;

  final Set<String> _removingProducts = {};
  final Set<String> _addingProducts = {};

  String _selectedSort = 'Recently Added';
  String _selectedCategory = 'All';

  final List<String> _sortOptions = [
    'Recently Added',
    'Price: Low to High',
    'Price: High to Low',
    'Highest Rated',
    'Biggest Discount',
  ];

  List<ProductModel> _sortProducts(List<ProductModel> products) {
    final sortedProducts = List<ProductModel>.from(products);

    switch (_selectedSort) {
      case 'Price: Low to High':
        sortedProducts.sort((a, b) => a.price.compareTo(b.price));
        break;

      case 'Price: High to Low':
        sortedProducts.sort((a, b) => b.price.compareTo(a.price));
        break;

      case 'Highest Rated':
        sortedProducts.sort((a, b) => b.rating.compareTo(a.rating));
        break;

      case 'Biggest Discount':
        sortedProducts.sort(
          (a, b) => _getDiscount(b).compareTo(_getDiscount(a)),
        );
        break;

      case 'Recently Added':
      default:
        // Preserve the order returned by the Wishlist repository.
        break;
    }

    return sortedProducts;
  }

  List<String> _getCategories(List<ProductModel> products) {
    final categories = products
        .map((product) => product.category.trim())
        .where((category) => category.isNotEmpty)
        .toSet()
        .toList();

    categories.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return ['All', ...categories];
  }

  static const Color _surface = AppColors.surface;
  static const Color _gold = AppColors.gold;

  @override
  void initState() {
    super.initState();
    _loadWishlist();
  }

  void _loadWishlist() {
    _wishlistFuture = _wishlistRepository.getWishlistItems();
  }

  Future<void> _refreshWishlist() async {
    setState(_loadWishlist);

    try {
      await _wishlistFuture;
    } catch (_) {
      // The FutureBuilder displays the error state.
    }
  }

  String _formatPrice(double price) {
    return 'Rp ${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => '.')}';
  }

  int _getDiscount(ProductModel product) {
    final originalPrice = product.compareAtPrice;

    if (originalPrice == null || originalPrice <= product.price) {
      return 0;
    }

    return (((originalPrice - product.price) / originalPrice) * 100).round();
  }

  double _getPriceDrop(ProductModel product) {
    final savedPrice = product.wishlistPriceAtAdd;

    if (savedPrice == null || savedPrice <= product.price) {
      return 0;
    }

    return savedPrice - product.price;
  }

  int _getPriceDropPercentage(ProductModel product) {
    final savedPrice = product.wishlistPriceAtAdd;

    if (savedPrice == null || savedPrice <= 0) {
      return 0;
    }

    final priceDrop = _getPriceDrop(product);

    if (priceDrop <= 0) {
      return 0;
    }
    return ((priceDrop / savedPrice) * 100).round();
  }

  String? _getProductImage(ProductModel product) {
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      return product.imageUrl;
    }

    if (product.images.isNotEmpty && product.images.first.isNotEmpty) {
      return product.images.first;
    }

    return null;
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.redAccent : _surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  Future<void> _removeFromWishlist(ProductModel product) async {
    setState(() {
      _removingProducts.add(product.id);
    });

    try {
      await _wishlistRepository.removeFromWishlist(product.id);

      if (!mounted) return;

      setState(() {
        _removingProducts.remove(product.id);
        _loadWishlist();
      });

      _showMessage('${product.name} removed from Wishlist.');
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _removingProducts.remove(product.id);
      });

      _showMessage(
        'Unable to remove product. Please try again.',
        isError: true,
      );
    }
  }

  Future<void> _clearAllWishlist() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Clear Entire Wishlist?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Are you sure you want to remove all products '
            'from your Wishlist? This action cannot be undone.',
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );

    if (shouldClear != true || !mounted) return;

    try {
      await _wishlistRepository.clearWishlist();

      if (!mounted) return;

      setState(() {
        _selectedCategory = 'All';
        _loadWishlist();
      });

      _showMessage('Your Wishlist has been cleared.');
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Unable to clear Wishlist. Please try again.',
        isError: true,
      );
    }
  }

  Future<void> _addToCart(ProductModel product) async {
    if (_addingProducts.contains(product.id)) return;

    setState(() {
      _addingProducts.add(product.id);
    });

    try {
      // Check whether this product has active variants.
      final variants = await _productRepository.getProductVariants(product.id);

      if (!mounted) return;

      // Variant-based products must go through Product Details
      // so customers can select their preferred options.
      if (variants.isNotEmpty) {
        setState(() {
          _addingProducts.remove(product.id);
        });

        _showMessage(
          'Please select your preferred options for ${product.name}.',
        );

        _openProduct(product);
        return;
      }

      // Standard products use product-level stock.
      if (product.stockQuantity <= 0) {
        setState(() {
          _addingProducts.remove(product.id);
        });

        _showMessage('This product is currently out of stock.', isError: true);
        return;
      }

      await _cartRepository.addToCart(product.id);

      if (!mounted) return;

      setState(() {
        _addingProducts.remove(product.id);
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${product.name} added to your cart.'),
            backgroundColor: _surface,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'GO TO CART',
              textColor: _gold,
              onPressed: () {
                context.push(AppRoutes.cart);
              },
            ),
          ),
        );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _addingProducts.remove(product.id);
      });

      _showMessage(
        error.toString().contains('login')
            ? 'Please login to use your shopping cart.'
            : 'Unable to add product to cart. Please try again.',
        isError: true,
      );
    }
  }

  void _openProduct(ProductModel product) {
    context.push('/product/${product.id}');
  }

  Widget _buildHeader(int productCount, List<String> categories) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.lg,
        AppSpacing.pageHorizontal,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: AppDecorations.premiumCard,
            child: Row(
              children: [
                Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: AppColors.primary,
                    size: 27,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('My Wishlist', style: AppTextStyles.headingMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '$productCount ${productCount == 1 ? 'product' : 'products'} saved for later.',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusCircular,
                    ),
                  ),
                  child: Text(
                    '$productCount',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.gold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              const Icon(
                Icons.category_rounded,
                color: AppColors.gold,
                size: AppSpacing.iconMedium,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('Category', style: AppTextStyles.labelLarge),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: AppDecorations.input,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: categories.contains(_selectedCategory)
                        ? _selectedCategory
                        : 'All',
                    dropdownColor: AppColors.surface,
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusMedium,
                    ),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.gold,
                    ),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white,
                    ),
                    items: categories.map((category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedCategory = value;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(
                Icons.sort_rounded,
                color: AppColors.gold,
                size: AppSpacing.iconMedium,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('Sort by', style: AppTextStyles.labelLarge),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: AppDecorations.input,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedSort,
                    dropdownColor: AppColors.surface,
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusMedium,
                    ),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.gold,
                    ),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white,
                    ),
                    items: _sortOptions.map((option) {
                      return DropdownMenuItem<String>(
                        value: option,
                        child: Text(option),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedSort = value;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          if (productCount > 0) ...[
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              height: AppSpacing.buttonHeight,
              child: OutlinedButton.icon(
                onPressed: _clearAllWishlist,
                icon: const Icon(Icons.delete_sweep_rounded, size: 19),
                label: Text(
                  'Clear All Wishlist',
                  style: AppTextStyles.buttonMedium,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: BorderSide(
                    color: Colors.redAccent.withValues(alpha: 0.45),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusMedium,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductImage(ProductModel product) {
    final imageUrl = _getProductImage(product);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
      child: Container(
        width: 116,
        height: 154,
        color: AppColors.surface,
        child: imageUrl == null
            ? const Icon(
                Icons.image_not_supported_outlined,
                color: Colors.white54,
                size: 35,
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 35,
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildProductCard(ProductModel product) {
    final discount = _getDiscount(product);
    final priceDrop = _getPriceDrop(product);
    final priceDropPercentage = _getPriceDropPercentage(product);
    final isRemoving = _removingProducts.contains(product.id);
    final isAdding = _addingProducts.contains(product.id);
    final isOutOfStock = product.stockQuantity <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppDecorations.card,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _openProduct(product),
            child: Stack(
              children: [
                _buildProductImage(product),
                if (discount > 0)
                  Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSmall,
                        ),
                      ),
                      child: Text(
                        '$discount% OFF',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (priceDrop > 0)
                  Positioned(
                    bottom: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSmall,
                        ),
                      ),
                      child: Text(
                        'PRICE DROP',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove from wishlist',
                      onPressed: isRemoving
                          ? null
                          : () => _removeFromWishlist(product),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 34,
                        minHeight: 34,
                      ),
                      icon: isRemoving
                          ? const SizedBox(
                              height: 17,
                              width: 17,
                              child: CircularProgressIndicator(
                                color: Colors.redAccent,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.favorite_rounded,
                              color: Colors.redAccent,
                              size: 21,
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  product.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  children: [
                    Text(
                      _formatPrice(product.price),
                      style: AppTextStyles.headingSmall.copyWith(
                        color: AppColors.gold,
                      ),
                    ),
                    if (discount > 0)
                      Text(
                        _formatPrice(product.compareAtPrice!),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white54,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                  ],
                ),
                if (priceDrop > 0) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      const Icon(
                        Icons.savings_rounded,
                        color: Colors.greenAccent,
                        size: 14,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'You save ${_formatPrice(priceDrop)} ($priceDropPercentage% lower)',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: Colors.greenAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: AppColors.gold,
                      size: 15,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        '${product.rating.toStringAsFixed(1)} (${product.reviewCount})',
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                    Text(
                      isOutOfStock ? 'Check options' : 'In stock',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: isOutOfStock
                            ? AppColors.gold
                            : Colors.greenAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          onPressed: isAdding
                              ? null
                              : () => _addToCart(product),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor: AppColors.primary
                                .withValues(alpha: 0.3),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusMedium,
                              ),
                            ),
                          ),
                          child: isAdding
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Add to Cart',
                                  style: AppTextStyles.buttonMedium,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    SizedBox(
                      height: 40,
                      width: 44,
                      child: OutlinedButton(
                        onPressed: () => _openProduct(product),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.gold,
                          padding: EdgeInsets.zero,
                          side: BorderSide(
                            color: AppColors.gold.withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMedium,
                            ),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 116,
              width: 116,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.13),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_border_rounded,
                color: AppColors.primary,
                size: 55,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Your Wishlist is Empty',
              textAlign: TextAlign.center,
              style: AppTextStyles.headingMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Save the products you love and find them here whenever you need them.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white70,
                height: 1.6,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              height: AppSpacing.buttonHeight,
              child: ElevatedButton.icon(
                onPressed: () => context.go(AppRoutes.home),
                icon: const Icon(Icons.shopping_bag_outlined),
                label: Text(
                  'Continue Shopping',
                  style: AppTextStyles.buttonMedium,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusMedium,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 88,
              width: 88,
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 46,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Unable to Load Wishlist',
              textAlign: TextAlign.center,
              style: AppTextStyles.headingSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Something went wrong while loading your saved products.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              onPressed: _refreshWishlist,
              icon: const Icon(Icons.refresh_rounded),
              label: Text('Try Again', style: AppTextStyles.buttonMedium),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Wishlist',
          style: AppTextStyles.headingSmall.copyWith(color: Colors.white),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Wishlist',
            onPressed: _refreshWishlist,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: _refreshWishlist,
        child: FutureBuilder<List<ProductModel>>(
          future: _wishlistFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            if (snapshot.hasError) {
              return _buildErrorState();
            }

            final products = snapshot.data ?? [];

            if (products.isEmpty) {
              return _buildEmptyState();
            }

            final filteredProducts = _selectedCategory == 'All'
                ? products
                : products
                      .where(
                        (product) =>
                            product.category.trim() == _selectedCategory,
                      )
                      .toList();

            final sortedProducts = _sortProducts(filteredProducts);

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeader(
                    filteredProducts.length,
                    _getCategories(products),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageHorizontal,
                    0,
                    AppSpacing.pageHorizontal,
                    AppSpacing.xl,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: _buildProductCard(sortedProducts[index]),
                        ),
                      );
                    }, childCount: sortedProducts.length),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
