import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/product_model.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/wishlist_repository.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_spacing.dart';
import '../../core/themes/app_text_styles.dart';
import '../../widgets/common/app_loading.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_error_state.dart';
import '../../core/themes/app_decorations.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key, this.initialCategory});

  final String? initialCategory;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final ProductRepository _productRepository = ProductRepository();
  final WishlistRepository _wishlistRepository = WishlistRepository();

  late Future<List<ProductModel>> _productsFuture;

  String? _selectedCategory;

  final Set<String> _wishlistIds = {};
  final Set<String> _wishlistLoadingIds = {};

  @override
  void initState() {
    super.initState();

    _selectedCategory = widget.initialCategory;

    _productsFuture = _productRepository.getProducts();

    _loadWishlist();
  }

  Future<void> _loadWishlist() async {
    try {
      final products = await _wishlistRepository.getWishlistItems();

      if (!mounted) return;

      setState(() {
        _wishlistIds.addAll(products.map((product) => product.id));
      });
    } catch (error) {
      debugPrint('WISHLIST ERROR: $error');
    }
  }

  Future<void> _toggleWishlist(ProductModel product) async {
    final productId = product.id;

    if (_wishlistLoadingIds.contains(productId)) return;

    final isSaved = _wishlistIds.contains(productId);

    setState(() {
      _wishlistLoadingIds.add(productId);
    });

    try {
      if (isSaved) {
        await _wishlistRepository.removeFromWishlist(productId);
      } else {
        await _wishlistRepository.addToWishlist(productId);
      }

      if (!mounted) return;

      setState(() {
        if (isSaved) {
          _wishlistIds.remove(productId);
        } else {
          _wishlistIds.add(productId);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isSaved ? 'Removed from wishlist.' : 'Added to wishlist!',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Wishlist update failed: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _wishlistLoadingIds.remove(productId);
        });
      }
    }
  }

  Future<void> _refreshProducts() async {
    setState(() {
      _productsFuture = _productRepository.getProducts();
    });

    await _productsFuture;
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase().trim()) {
      case 'fashion':
        return Icons.checkroom_rounded;
      case 'electronics':
        return Icons.devices_rounded;
      case 'beauty':
        return Icons.spa_rounded;
      case 'home':
        return Icons.chair_alt_rounded;
      case 'accessories':
        return Icons.watch_rounded;
      case 'sports':
        return Icons.sports_basketball_rounded;
      case 'books':
        return Icons.menu_book_rounded;
      case 'toys':
        return Icons.toys_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Color _categoryColor(int index) {
    const colors = [
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
      Color(0xFF06B6D4),
      Color(0xFFF59E0B),
      Color(0xFF10B981),
      Color(0xFF6366F1),
    ];

    return colors[index % colors.length];
  }

  int? _discountPercentage(ProductModel product) {
    final originalPrice = product.compareAtPrice;

    if (originalPrice == null ||
        originalPrice <= product.price ||
        originalPrice <= 0) {
      return null;
    }

    return (((originalPrice - product.price) / originalPrice) * 100).round();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Categories',
          style: AppTextStyles.headingMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh categories',
            onPressed: _refreshProducts,
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: FutureBuilder<List<ProductModel>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoading(
              message: 'Loading categories...',
              size: 32,
              fullScreen: true,
            );
          }

          if (snapshot.hasError) {
            return AppErrorState(
              title: 'Unable to Load Categories',
              message:
                  'We could not fetch categories right now. Please try again.',
              actionLabel: 'Try Again',
              icon: Icons.cloud_off_rounded,
              onRetry: _refreshProducts,
            );
          }

          final products = snapshot.data ?? [];

          if (products.isEmpty) {
            return const AppEmptyState(
              icon: Icons.category_outlined,
              title: 'No Categories Yet',
              message: 'Products will appear here once they are added.',
            );
          }

          // Build categories dynamically from Supabase products.
          final Map<String, List<ProductModel>> categoryMap = {};

          for (final product in products) {
            final category = product.category.trim();

            if (category.isEmpty) continue;

            categoryMap.putIfAbsent(category, () => []);
            categoryMap[category]!.add(product);
          }

          final categories = categoryMap.keys.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

          final selectedProducts = _selectedCategory == null
              ? <ProductModel>[]
              : categoryMap[_selectedCategory] ?? [];

          return RefreshIndicator(
            onRefresh: _refreshProducts,
            color: AppColors.primaryLight,
            backgroundColor: AppColors.surfaceElevated,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeader(categories.length, products.length),
                ),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageHorizontal,
                    AppSpacing.xl,
                    AppSpacing.pageHorizontal,
                    AppSpacing.md,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _buildSectionTitle(
                      'Explore Categories',
                      'Find exactly what you are looking for.',
                    ),
                  ),
                ),

                SliverPadding(
                  padding: AppSpacing.sectionPadding,
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount =
                          ((constraints.crossAxisExtent + AppSpacing.sm) / 170)
                              .floor()
                              .clamp(2, 4)
                              .toInt();

                      return SliverGrid.builder(
                        itemCount: categories.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: AppSpacing.sm,
                          crossAxisSpacing: AppSpacing.sm,
                          childAspectRatio: 1.4,
                        ),
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          final isSelected = _selectedCategory == category;

                          return _buildCategoryCard(
                            category: category,
                            count: categoryMap[category]!.length,
                            color: _categoryColor(index),
                            icon: _categoryIcon(category),
                            isSelected: isSelected,
                            onTap: () {
                              setState(() {
                                _selectedCategory = isSelected
                                    ? null
                                    : category;
                              });
                            },
                          );
                        },
                      );
                    },
                  ),
                ),

                if (_selectedCategory != null) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageHorizontal,
                      AppSpacing.xxl,
                      AppSpacing.pageHorizontal,
                      AppSpacing.md,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _buildSectionTitle(
                        _selectedCategory!,
                        '${selectedProducts.length} products available',
                      ),
                    ),
                  ),

                  if (selectedProducts.isEmpty)
                    SliverToBoxAdapter(child: _buildCategoryEmptyState())
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageHorizontal,
                        0,
                        AppSpacing.pageHorizontal,
                        AppSpacing.xxl,
                      ),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) {
                          final crossAxisCount =
                              ((constraints.crossAxisExtent + AppSpacing.sm) /
                                      190)
                                  .floor()
                                  .clamp(2, 4)
                                  .toInt();

                          return SliverGrid.builder(
                            itemCount: selectedProducts.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  mainAxisSpacing: AppSpacing.md,
                                  crossAxisSpacing: AppSpacing.md,
                                  childAspectRatio: 0.66,
                                ),
                            itemBuilder: (context, index) {
                              final product = selectedProducts[index];

                              return _buildProductCard(product);
                            },
                          );
                        },
                      ),
                    ),
                ],

                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.xxxl),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(int categoryCount, int productCount) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.md,
        AppSpacing.pageHorizontal,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXXLarge),
        gradient: AppColors.premiumGradient,
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: AppDecorations.purpleGlow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.gold,
              size: AppSpacing.iconXLarge,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Discover Your Style',
            style: AppTextStyles.headingLarge.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Explore collections and find deals worth shopping for.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              _buildStat(categoryCount.toString(), 'Categories'),
              const SizedBox(width: AppSpacing.xxl),
              _buildStat(productCount.toString(), 'Products'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppTextStyles.headingMedium.copyWith(
            color: AppColors.gold,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.headingSmall.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildCategoryCard({
    required String category,
    required int count,
    required Color color,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
            border: Border.all(
              color: isSelected ? color : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
            color: isSelected
                ? color.withValues(alpha: 0.08)
                : Colors.transparent,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                ),
                child: Icon(icon, color: color, size: AppSpacing.iconLarge),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '$count products',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(ProductModel product) {
    final isWishlisted = _wishlistIds.contains(product.id);
    final isLoading = _wishlistLoadingIds.contains(product.id);
    final discount = _discountPercentage(product);

    return GestureDetector(
      onTap: () {
        context.push('/product/${product.id}');
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  product.imageUrl != null && product.imageUrl!.isNotEmpty
                      ? Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;

                            return Container(
                              color: AppColors.surfaceElevated,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryLight,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return _buildImagePlaceholder();
                          },
                        )
                      : _buildImagePlaceholder(),

                  // Wishlist button
                  Positioned(
                    top: AppSpacing.xs,
                    right: AppSpacing.xs,
                    child: Material(
                      color: AppColors.background.withValues(alpha: 0.8),
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: isWishlisted
                            ? 'Remove from wishlist'
                            : 'Add to wishlist',
                        visualDensity: VisualDensity.compact,
                        onPressed: isLoading
                            ? null
                            : () => _toggleWishlist(product),
                        icon: isLoading
                            ? const SizedBox(
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryLight,
                                ),
                              )
                            : Icon(
                                isWishlisted
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: isWishlisted
                                    ? AppColors.wishlist
                                    : AppColors.textPrimary,
                                size: AppSpacing.iconMedium,
                              ),
                      ),
                    ),
                  ),

                  // Discount badge
                  if (discount != null)
                    Positioned(
                      bottom: AppSpacing.xs,
                      left: AppSpacing.xs,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.discount,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSmall,
                          ),
                        ),
                        child: Text(
                          '$discount% OFF',
                          style: AppTextStyles.discount.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Product information
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.productName.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xs),

                  // Current price
                  Text(
                    _formatPrice(product.price),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.price.copyWith(color: AppColors.gold),
                  ),

                  // Original price
                  if (product.compareAtPrice != null &&
                      product.compareAtPrice! > product.price) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      _formatPrice(product.compareAtPrice!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.originalPrice.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xs),

                  // Rating
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: AppColors.rating,
                        size: AppSpacing.iconSmall,
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      Expanded(
                        child: Text(
                          '${product.rating.toStringAsFixed(1)} (${product.reviewCount})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
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
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: AppColors.surfaceElevated,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: AppColors.textMuted,
          size: 36,
        ),
      ),
    );
  }

  Widget _buildCategoryEmptyState() {
    return const AppEmptyState(
      icon: Icons.inventory_2_outlined,
      title: 'No Products Available',
      message: 'There are currently no products in this category. Explore another category to discover more.',
    );
  }
}
