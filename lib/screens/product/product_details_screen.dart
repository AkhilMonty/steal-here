import 'package:flutter/material.dart';

import '../../models/product_model.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/cart_repository.dart';

import 'package:go_router/go_router.dart';

import '../../core/routes/app_routes.dart';
import '../../repositories/wishlist_repository.dart';
import '../../repositories/compare_repository.dart';
import '../../widgets/product_reviews_section.dart';
import '../../repositories/product_view_repository.dart';
import '../../widgets/product_questions_section.dart';
import '../../models/product_variant_model.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_spacing.dart';
import '../../core/themes/app_text_styles.dart';
import '../../models/direct_purchase_data.dart';

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({
    super.key,
    required this.productId,
    this.openReviewForm = false,
    this.cartItemId,
    this.initialVariantId,
    this.initialQuantity,
  });

  final String productId;
  final bool openReviewForm;

  // Cart editing information.
  final String? cartItemId;
  final String? initialVariantId;
  final int? initialQuantity;

  bool get isCartEditMode => cartItemId != null;

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final ProductRepository _productRepository = ProductRepository();
  final CartRepository _cartRepository = CartRepository();
  final WishlistRepository _wishlistRepository = WishlistRepository();
  final CompareRepository _compareRepository = CompareRepository();
  final ProductViewRepository _productViewRepository = ProductViewRepository();

  bool _isInComparison = false;
  bool _isUpdatingComparison = false;
  late Future<ProductModel?> _productFuture;

  bool _isAddingToCart = false;
  bool _isBuyingNow = false;
  bool _isInWishlist = false;
  bool _isCheckingWishlist = true;
  bool _isUpdatingWishlist = false;
  bool _hasRecordedProductView = false;

  static const Color background = AppColors.background;
  static const Color surface = AppColors.surface;
  static const Color primary = AppColors.primary;
  static const Color gold = AppColors.gold;

  @override
  void didUpdateWidget(covariant ProductDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.productId != widget.productId) {
      _hasRecordedProductView = false;

      _loadProduct();
      _loadWishlistStatus();
      _loadComparisonStatus();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadProduct();
    _loadWishlistStatus();
    _loadComparisonStatus();
  }

  Future<void> _loadComparisonStatus() async {
    try {
      final isCompared = await _compareRepository.isProductCompared(
        widget.productId,
      );

      if (!mounted) return;

      setState(() {
        _isInComparison = isCompared;
      });
    } catch (_) {
      // Keep the default comparison state if loading fails.
    }
  }

  void _loadProduct() {
    _productFuture = _productRepository.getProductById(widget.productId);
  }

  Future<void> _recordProductView(String productId) async {
    try {
      await _productViewRepository.recordProductView(productId);
    } catch (error) {
      // Browsing tracking should never interrupt product viewing.
      debugPrint('Unable to record product view: $error');
    }
  }

  String _formatPrice(double price) {
    final amount = price.round().toString();

    final formatted = amount.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );

    return 'Rp $formatted';
  }

  String? _getDiscount(ProductModel product) {
    final oldPrice = product.compareAtPrice;

    if (oldPrice == null || oldPrice <= product.price || oldPrice == 0) {
      return null;
    }

    final discount = ((oldPrice - product.price) / oldPrice * 100).round();

    return '$discount% OFF';
  }

  List<String> _getProductImages(ProductModel product) {
    final images = <String>[];

    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      images.add(product.imageUrl!);
    }

    for (final image in product.images) {
      if (image.isNotEmpty && !images.contains(image)) {
        images.add(image);
      }
    }

    return images;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loadWishlistStatus() async {
    try {
      final isSaved = await _wishlistRepository.isInWishlist(widget.productId);

      if (!mounted) return;

      setState(() {
        _isInWishlist = isSaved;
        _isCheckingWishlist = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isInWishlist = false;
        _isCheckingWishlist = false;
      });
    }
  }

  Future<void> _toggleWishlist() async {
    if (_isUpdatingWishlist || _isCheckingWishlist) return;

    setState(() {
      _isUpdatingWishlist = true;
    });

    try {
      if (_isInWishlist) {
        await _wishlistRepository.removeFromWishlist(widget.productId);

        if (!mounted) return;

        setState(() {
          _isInWishlist = false;
        });

        _showMessage('Product removed from your wishlist.');
      } else {
        await _wishlistRepository.addToWishlist(widget.productId);

        if (!mounted) return;

        setState(() {
          _isInWishlist = true;
        });

        _showMessage('Product added to your wishlist!');
      }
    } catch (error) {
      if (!mounted) return;

      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingWishlist = false;
        });
      }
    }
  }

  Future<void> _toggleComparison(ProductModel product) async {
    if (_isUpdatingComparison) return;

    setState(() {
      _isUpdatingComparison = true;
    });

    try {
      if (_isInComparison) {
        await _compareRepository.removeProduct(product.id);

        if (!mounted) return;

        setState(() {
          _isInComparison = false;
        });

        _showMessage('${product.name} removed from comparison.');
      } else {
        final result = await _compareRepository.addProduct(product.id);

        if (!mounted) return;

        switch (result) {
          case CompareAddResult.added:
            setState(() {
              _isInComparison = true;
            });
            _showMessage('${product.name} added to comparison!');

          case CompareAddResult.alreadyAdded:
            setState(() {
              _isInComparison = true;
            });
            _showMessage('This product is already in comparison.');

          case CompareAddResult.limitReached:
            _showMessage(
              'You can compare up to ${CompareRepository.maxProducts} products.',
            );

          case CompareAddResult.differentType:
            _showMessage(
              'You can only compare products from the same product type.',
            );

          case CompareAddResult.productUnavailable:
            _showMessage('This product is currently unavailable.');
        }
      }
    } catch (error) {
      if (!mounted) return;

      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingComparison = false;
        });
      }
    }
  }

  Future<void> _addToCart(ProductModel product) async {
    if (_isAddingToCart) return;

    setState(() {
      _isAddingToCart = true;
    });

    try {
      final variants = await _productRepository.getProductVariants(product.id);

      if (!mounted) return;

      final selection = await _showVariantSelection(variants, product);

      if (!mounted || selection == null) return;

      if (selection.quantity <= 0) return;

      await _cartRepository.addToCart(
        product.id,
        quantity: selection.quantity,
        variantId: selection.variant?.id,
      );

      if (!mounted) return;

      _showMessage('${product.name} added to your cart successfully!');
    } catch (error) {
      if (!mounted) return;

      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isAddingToCart = false;
        });
      }
    }
  }

  Future<void> _buyNow(ProductModel product) async {
    if (_isBuyingNow || _isAddingToCart) return;

    if (!product.isActive) {
      _showMessage('This product is currently unavailable.');
      return;
    }

    setState(() {
      _isBuyingNow = true;
    });

    try {
      final variants = await _productRepository.getProductVariants(product.id);

      if (!mounted) return;

      // A product without variants must have available product stock.
      if (variants.isEmpty && product.stockQuantity <= 0) {
        _showMessage('This product is currently out of stock.');
        return;
      }

      final selection = await _showVariantSelection(
        variants,
        product,
        actionLabel: 'Continue to Checkout',
      );

      if (!mounted || selection == null) return;

      if (selection.quantity <= 0) return;

      final directPurchase = DirectPurchaseData(
        product: product,
        variant: selection.variant,
        quantity: selection.quantity,
      );

      // Direct checkout: do not add anything to the cart.
      await context.push(AppRoutes.checkout, extra: directPurchase);
    } catch (error) {
      if (!mounted) return;

      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isBuyingNow = false;
        });
      }
    }
  }

  Future<void> _saveCartChanges(ProductModel product) async {
    if (_isAddingToCart || widget.cartItemId == null) return;

    setState(() {
      _isAddingToCart = true;
    });

    try {
      final variants = await _productRepository.getProductVariants(product.id);

      if (!mounted) return;

      final selection = await _showVariantSelection(
        variants,
        product,
        initialVariantId: widget.initialVariantId,
        initialQuantity: widget.initialQuantity,
        isEditing: true,
      );

      if (!mounted || selection == null) return;

      await _cartRepository.updateCartItemVariant(
        cartItemId: widget.cartItemId!,
        variantId: selection.variant?.id,
        quantity: selection.quantity,
      );

      if (!mounted) return;

      // Update the quantity as well if the user changed it.

      if (!mounted) return;

      _showMessage('Cart item updated successfully!');
      context.pop();
    } catch (error) {
      if (!mounted) return;

      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isAddingToCart = false;
        });
      }
    }
  }

  Future<_CartSelection?> _showVariantSelection(
    List<ProductVariantModel> variants,
    ProductModel product, {
    String? initialVariantId,
    int? initialQuantity,
    bool isEditing = false,
    String? actionLabel,
  }) async {
    final initialVariant = initialVariantId == null
        ? null
        : variants.cast<ProductVariantModel?>().firstWhere(
            (variant) => variant?.id == initialVariantId,
            orElse: () => null,
          );

    return showModalBottomSheet<_CartSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return _VariantSelectionSheet(
          product: product,
          variants: variants,
          formatPrice: _formatPrice,
          initialVariant: initialVariant,
          initialQuantity: initialQuantity,
          isEditing: isEditing,
          actionLabel: actionLabel,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      // Fixed bottom Add to Cart button
      bottomNavigationBar: FutureBuilder<ProductModel?>(
        future: _productFuture,
        builder: (context, snapshot) {
          final product = snapshot.data;

          if (product == null ||
              snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox.shrink();
          }

          final isOutOfStock = product.stockQuantity <= 0;

          return Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.surface, AppColors.background],
              ),
              border: Border(
                top: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.22),
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: widget.isCartEditMode
                  ? SizedBox(
                      width: double.infinity,
                      height: AppSpacing.buttonHeight,
                      child: ElevatedButton.icon(
                        onPressed: _isAddingToCart
                            ? null
                            : () => _saveCartChanges(product),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          disabledBackgroundColor: Colors.grey.shade800,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMedium,
                            ),
                          ),
                        ),
                        icon: _isAddingToCart
                            ? const SizedBox(
                                width: 19,
                                height: 19,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined, size: 20),
                        label: Text(
                          _isAddingToCart
                              ? 'Saving Changes...'
                              : 'Save Changes',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Primary shopping actions.
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: AppSpacing.buttonHeight,
                                child: ElevatedButton.icon(
                                  onPressed:
                                      _isBuyingNow ||
                                          _isAddingToCart ||
                                          isOutOfStock
                                      ? null
                                      : () => _buyNow(product),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: gold,
                                    disabledBackgroundColor:
                                        Colors.grey.shade800,
                                    foregroundColor: Colors.black,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppSpacing.radiusMedium,
                                      ),
                                    ),
                                  ),
                                  icon: _isBuyingNow
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            color: Colors.black,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.flash_on_rounded,
                                          size: 19,
                                        ),
                                  label: Text(
                                    _isBuyingNow ? 'Loading...' : 'Buy Now',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SizedBox(
                                height: AppSpacing.buttonHeight,
                                child: ElevatedButton.icon(
                                  onPressed: _isAddingToCart || _isBuyingNow
                                      ? null
                                      : () => _addToCart(product),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primary,
                                    disabledBackgroundColor:
                                        Colors.grey.shade800,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppSpacing.radiusMedium,
                                      ),
                                    ),
                                  ),
                                  icon: _isAddingToCart
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.shopping_bag_outlined,
                                          size: 18,
                                        ),
                                  label: Text(
                                    _isAddingToCart
                                        ? 'Adding...'
                                        : isOutOfStock
                                        ? 'Choose Options'
                                        : 'Add to Cart',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 9),

                        // Secondary navigation actions.
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  context.push(AppRoutes.cart);
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: primary.withValues(alpha: 0.5),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.shopping_cart_outlined,
                                  size: 17,
                                ),
                                label: const Text(
                                  'Go to Cart',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  context.go(AppRoutes.home);
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: gold,
                                  side: BorderSide(
                                    color: gold.withValues(alpha: 0.5),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.storefront_outlined,
                                  size: 17,
                                ),
                                label: const Text(
                                  'Continue Shopping',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          );
        },
      ),

      // Product details content
      body: FutureBuilder<ProductModel?>(
        future: _productFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: primary),
            );
          }

          if (snapshot.hasError) {
            return _buildErrorState();
          }

          final product = snapshot.data;

          if (product == null) {
            return _buildNotFoundState();
          }

          if (!_hasRecordedProductView) {
            _hasRecordedProductView = true;
            _recordProductView(product.id);
          }

          return _buildProductDetails(product);
        },
      ),
    );
  }

  Widget _buildProductDetails(ProductModel product) {
    final images = _getProductImages(product);
    final discount = _getDiscount(product);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: background,
          surfaceTintColor: Colors.transparent,
          pinned: true,
          expandedHeight: 410,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          actions: [
            // Wishlist Button
            // Functional Wishlist Button
            IconButton(
              tooltip: _isInWishlist
                  ? 'Remove from Wishlist'
                  : 'Add to Wishlist',
              onPressed: _isCheckingWishlist || _isUpdatingWishlist
                  ? null
                  : _toggleWishlist,
              icon: _isUpdatingWishlist || _isCheckingWishlist
                  ? const SizedBox(
                      height: 19,
                      width: 19,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(
                      _isInWishlist
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: _isInWishlist ? Colors.redAccent : Colors.white,
                    ),
            ),

            const SizedBox(width: 8),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: _buildImageGallery(images),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              AppSpacing.xl,
              AppSpacing.pageHorizontal,
              120,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSmall,
                        ),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        product.category.toUpperCase(),
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (discount != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF263D32).withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSmall,
                          ),
                          border: Border.all(
                            color: const Color(0xFF70D6A0)
                                .withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          discount,
                          style: const TextStyle(
                            color: Color(0xFF70D6A0),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 18),

                Text(
                  product.name,
                  style: AppTextStyles.headingMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: gold, size: 21),
                    const SizedBox(width: 5),
                    Text(
                      product.rating.toStringAsFixed(1),
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${product.reviewCount} reviews)',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _formatPrice(product.price),
                      style: AppTextStyles.headingMedium.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (product.compareAtPrice != null &&
                        product.compareAtPrice! > product.price) ...[
                      const SizedBox(width: 12),
                      Text(
                        _formatPrice(product.compareAtPrice!),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textMuted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 20),

                // Compare Product Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isUpdatingComparison
                            ? null
                            : () => _toggleComparison(product),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFA78BFA),
                          side: BorderSide(
                            color: primary.withValues(alpha: 0.6),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMedium,
                            ),
                          ),
                        ),
                        icon: _isUpdatingComparison
                            ? const SizedBox(
                                height: 17,
                                width: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFA78BFA),
                                ),
                              )
                            : Icon(
                                _isInComparison
                                    ? Icons.check_circle_rounded
                                    : Icons.compare_arrows_rounded,
                                size: 19,
                              ),
                        label: Text(
                          _isInComparison
                              ? 'Added to Compare'
                              : 'Add to Compare',
                          style: AppTextStyles.labelMedium.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () => context.push(AppRoutes.compare),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: gold,
                        side: BorderSide(color: gold.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMedium,
                          ),
                        ),
                      ),
                      child: const Icon(Icons.open_in_new_rounded, size: 19),
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                _buildDivider(),

                const SizedBox(height: 22),

                Text(
                  'Product Description',
                  style: AppTextStyles.headingSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  product.description?.trim().isNotEmpty == true
                      ? product.description!
                      : 'Discover this premium ${product.name.toLowerCase()} '
                            'from Steal Here. Enjoy quality, style, and '
                            'exceptional value with your purchase.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textMuted,
                    height: 1.8,
                  ),
                ),

                const SizedBox(height: 25),

                _buildDivider(),

                const SizedBox(height: 22),

                Text(
                  'Availability',
                  style: AppTextStyles.headingSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Icon(
                      product.stockQuantity > 0
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: product.stockQuantity > 0
                          ? const Color(0xFF70D6A0)
                          : Colors.redAccent,
                      size: 19,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      product.stockQuantity > 0
                          ? 'In Stock (${product.stockQuantity} available)'
                          : 'Currently Out of Stock',
                      style: TextStyle(
                        color: product.stockQuantity > 0
                            ? const Color(0xFF70D6A0)
                            : Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                _buildDivider(),

                const SizedBox(height: 22),

                _buildFeatureRow(
                  Icons.verified_user_outlined,
                  'Quality Assured',
                  'Carefully selected products.',
                ),

                const SizedBox(height: 17),

                _buildFeatureRow(
                  Icons.local_shipping_outlined,
                  'Reliable Delivery',
                  'Convenient shopping experience.',
                ),

                const SizedBox(height: 17),

                _buildFeatureRow(
                  Icons.lock_outline_rounded,
                  'Secure Shopping',
                  'Shop with confidence.',
                ),

                const SizedBox(height: 30),
                _buildDivider(),
                const SizedBox(height: 25),

                // PRODUCT QUESTIONS & ANSWERS
                ProductQuestionsSection(productId: product.id),

                const SizedBox(height: 30),
                _buildDivider(),
                const SizedBox(height: 25),

                // PRODUCT REVIEWS
                ProductReviewsSection(
                  productId: product.id,
                  initiallyOpenReviewForm: widget.openReviewForm,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageGallery(List<String> images) {
    if (images.isEmpty) {
      return Container(
        color: AppColors.background,
        child: const Center(
          child: Icon(Icons.shopping_bag_outlined, color: primary, size: 100),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: images.length,
          itemBuilder: (context, index) {
            return Container(
              color: AppColors.background,
              child: Image.network(
                images[index],
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white38,
                      size: 70,
                    ),
                  );
                },
                loadingBuilder: (context, child, progress) {
                  if (progress == null) {
                    return child;
                  }

                  return const Center(
                    child: CircularProgressIndicator(color: primary),
                  );
                },
              ),
            );
          },
        ),

        if (images.length > 1)
          Positioned(
            bottom: 18,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: background.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${images.length} Images',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          ),
          child: Icon(icon, color: primary, size: 21),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      color: AppColors.textMuted.withValues(alpha: 0.14),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: Colors.redAccent,
              size: 55,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Unable to Load Product',
              style: AppTextStyles.headingSmall.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Please check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: () {
                setState(_loadProduct);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.md,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFoundState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              color: Colors.white38,
              size: 65,
            ),
            const SizedBox(height: 18),
            Text(
              'Product Not Found',
              style: AppTextStyles.headingSmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'This product may no longer be available.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartSelection {
  final ProductVariantModel? variant;
  final int quantity;

  const _CartSelection({required this.variant, required this.quantity});
}

class _VariantSelectionSheet extends StatefulWidget {
  final ProductModel product;
  final List<ProductVariantModel> variants;
  final String Function(double) formatPrice;
  final ProductVariantModel? initialVariant;
  final int? initialQuantity;
  final bool isEditing;
  final String? actionLabel;

  const _VariantSelectionSheet({
    required this.product,
    required this.variants,
    required this.formatPrice,
    this.initialVariant,
    this.initialQuantity,
    this.isEditing = false,
    this.actionLabel,
  });

  @override
  State<_VariantSelectionSheet> createState() => _VariantSelectionSheetState();
}

class _VariantSelectionSheetState extends State<_VariantSelectionSheet> {
  static const Color primary = Color(0xFF8B5CF6);
  static const Color gold = Color(0xFFF5C76A);

  final Map<String, dynamic> _selectedAttributes = {};

  int _quantity = 1;

  bool get _hasVariants => widget.variants.isNotEmpty;

  @override
  void initState() {
    super.initState();

    // Restore the existing variant when editing a cart item.
    if (widget.initialVariant != null) {
      _selectedAttributes.addAll(widget.initialVariant!.attributes);
    }

    _quantity = widget.initialQuantity ?? 1;

    if (_quantity < 1) {
      _quantity = 1;
    }
  }

  List<String> get _attributeNames {
    final names = <String>{};

    for (final variant in widget.variants) {
      names.addAll(variant.attributes.keys);
    }

    return names.toList();
  }

  ProductVariantModel? get _selectedVariant {
    if (!_hasVariants) return null;

    for (final variant in widget.variants) {
      if (!variant.isActive) continue;

      final matches = _selectedAttributes.entries.every(
        (entry) =>
            variant.attributes[entry.key]?.toString() == entry.value.toString(),
      );

      if (matches && variant.attributes.length == _selectedAttributes.length) {
        return variant;
      }
    }

    return null;
  }

  int get _availableStock {
    if (_hasVariants) {
      return _selectedVariant?.stockQuantity ?? 0;
    }

    return widget.product.stockQuantity;
  }

  double get _selectedPrice {
    if (_hasVariants && _selectedVariant != null) {
      return _selectedVariant!.getEffectivePrice(widget.product.price);
    }

    return widget.product.price;
  }

  List<String> _getAttributeValues(String attribute) {
    return widget.variants
        .where((variant) => variant.attributes.containsKey(attribute))
        .map((variant) => variant.attributes[attribute].toString())
        .toSet()
        .toList();
  }

  bool _isOptionAvailable(String attribute, String value) {
    return widget.variants.any((variant) {
      if (!variant.isActive || variant.stockQuantity <= 0) {
        return false;
      }

      if (variant.attributes[attribute]?.toString() != value) {
        return false;
      }

      for (final entry in _selectedAttributes.entries) {
        if (entry.key == attribute) continue;

        if (variant.attributes[entry.key]?.toString() !=
            entry.value.toString()) {
          return false;
        }
      }

      return true;
    });
  }

  Widget _buildAttributeSection(String attribute) {
    final values = _getAttributeValues(attribute);

    if (values.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            attribute.replaceAll('_', ' ').toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: values.map((value) {
              final isSelected =
                  _selectedAttributes[attribute]?.toString() == value;

              final isAvailable = _isOptionAvailable(attribute, value);

              return ChoiceChip(
                label: Text(value),
                selected: isSelected,
                onSelected: !isAvailable
                    ? null
                    : (selected) {
                        if (!selected) return;

                        setState(() {
                          _selectedAttributes[attribute] = value;
                          _quantity = 1;
                        });
                      },
                selectedColor: primary,
                backgroundColor: const Color(0xFF252535),
                disabledColor: Colors.black26,
                labelStyle: TextStyle(
                  color: !isAvailable
                      ? Colors.white24
                      : isSelected
                      ? Colors.white
                      : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                side: BorderSide(
                  color: isSelected
                      ? primary
                      : Colors.white.withValues(alpha: 0.1),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector() {
    final stock = _availableStock;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'QUANTITY',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _quantityButton(
              icon: Icons.remove,
              enabled: _quantity > 1,
              onPressed: () {
                setState(() {
                  _quantity--;
                });
              },
            ),
            Container(
              width: 55,
              alignment: Alignment.center,
              child: Text(
                '$_quantity',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _quantityButton(
              icon: Icons.add,
              enabled: _quantity < stock,
              onPressed: () {
                setState(() {
                  _quantity++;
                });
              },
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                stock > 0 ? '$stock available' : 'Out of stock',
                style: TextStyle(
                  color: stock > 0 ? const Color(0xFF70D6A0) : Colors.redAccent,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _quantityButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 38,
      height: 38,
      child: IconButton(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, size: 18),
        color: Colors.white,
        disabledColor: Colors.white24,
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFF252535),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      ),
    );
  }

  Widget _buildVariantSummary() {
    final variant = _selectedVariant;

    final displayName =
        variant?.displayName ??
        (widget.variants.isEmpty ? 'Standard Product' : 'Select an option');

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF252535),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Your Selection',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ),
              Text(
                _availableStock > 0
                    ? '$_availableStock available'
                    : 'Out of Stock',
                style: TextStyle(
                  color: _availableStock > 0
                      ? const Color(0xFF70D6A0)
                      : Colors.redAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.formatPrice(_selectedPrice),
            style: const TextStyle(
              color: gold,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Total: ${widget.formatPrice(_selectedPrice * _quantity)}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canAdd =
        _availableStock > 0 &&
        _quantity > 0 &&
        _quantity <= _availableStock &&
        (!_hasVariants || _selectedVariant != null);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.pageHorizontal,
          right: AppSpacing.pageHorizontal,
          top: AppSpacing.xl,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                widget.isEditing
                    ? 'Change Product Variant'
                    : 'Choose Your Options',
                style: AppTextStyles.headingMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                widget.product.name,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 25),

              if (_hasVariants)
                ..._attributeNames.map(_buildAttributeSection)
              else
                const Text(
                  'Standard Product',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),

              _buildQuantitySelector(),

              const SizedBox(height: 20),

              _buildVariantSummary(),

              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                height: 53,
                child: ElevatedButton(
                  onPressed: !canAdd
                      ? null
                      : () {
                          Navigator.of(context).pop(
                            _CartSelection(
                              variant: _selectedVariant,
                              quantity: _quantity,
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    disabledBackgroundColor: Colors.grey.shade800,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: Text(
                    widget.isEditing
                        ? 'Save Changes'
                        : widget.actionLabel ?? 'Confirm & Add to Cart',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
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
}
