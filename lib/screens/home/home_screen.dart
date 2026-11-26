import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routes/app_routes.dart';
import '../../models/product_model.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/wishlist_repository.dart';
import '../../repositories/compare_repository.dart';
import '../../repositories/recommendation_repository.dart';
import '../../models/product_recommendation_model.dart';
import '../../repositories/product_view_repository.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../repositories/notification_repository.dart';
import '../../repositories/trending_repository.dart';
import '../../widgets/common/app_loading.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_error_state.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_spacing.dart';
import '../../core/themes/app_text_styles.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final GlobalKey _featuredProductsKey = GlobalKey();

  final ProductRepository _productRepository = ProductRepository();
  final WishlistRepository _wishlistRepository = WishlistRepository();
  final CompareRepository _compareRepository = CompareRepository();
  final RecommendationRepository _recommendationRepository =
      RecommendationRepository();
  final ProductViewRepository _productViewRepository = ProductViewRepository();
  final TrendingRepository _trendingRepository = TrendingRepository();

  final NotificationRepository _notificationRepository =
      NotificationRepository();

  int _unreadNotificationCount = 0;

  RealtimeChannel? _notificationsChannel;

  final Set<String> _comparedProductIds = {};
  final Set<String> _compareLoadingIds = {};

  ProductModel? _comparisonReferenceProduct;

  late Future<List<ProductModel>> _featuredProductsFuture;
  late Future<List<ProductRecommendationModel>> _recommendationsFuture;
  late Future<List<ProductModel>> _recentlyViewedProductsFuture;
  late Future<List<ProductModel>> _trendingProductsFuture;

  final Set<String> _wishlistProductIds = {};
  final Set<String> _wishlistLoadingIds = {};

  @override
  void initState() {
    super.initState();

    _featuredProductsFuture = _productRepository.getFeaturedProducts();
    _recommendationsFuture = _recommendationRepository.getRecommendations(
      limit: 6,
    );

    _recentlyViewedProductsFuture = _productViewRepository
        .getRecentlyViewedProducts(limit: 10);

    _trendingProductsFuture = _trendingRepository.getTrendingProducts(
      daysBack: 7,
      limit: 10,
    );

    CompareRepository.comparisonChanges.addListener(_onComparisonChanged);

    _loadWishlist();
    _loadComparison();
    _loadUnreadNotificationCount();

    try {
      _notificationsChannel = _notificationRepository.subscribeToNotifications(
        onChanged: _onNotificationsChanged,
      );
    } catch (error) {
      debugPrint('NOTIFICATION SUBSCRIPTION ERROR: $error');
    }
  }

  void _exploreDeals() {
    final targetContext = _featuredProductsKey.currentContext;

    if (targetContext == null) return;

    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOutCubic,
      alignment: 0.08,
    );
  }

  Future<void> _openProduct(ProductModel product) async {
    await context.push('/product/${product.id}');

    if (!mounted) return;

    setState(() {
      _recentlyViewedProductsFuture = _productViewRepository
          .getRecentlyViewedProducts(limit: 10);

      _recommendationsFuture = _recommendationRepository.getRecommendations(
        limit: 6,
      );

      _trendingProductsFuture = _trendingRepository.getTrendingProducts(
        daysBack: 7,
        limit: 10,
      );
    });
  }

  Future<void> _refreshHome() async {
    setState(() {
      _featuredProductsFuture = _productRepository.getFeaturedProducts();

      _recommendationsFuture = _recommendationRepository.getRecommendations(
        limit: 6,
      );

      _recentlyViewedProductsFuture = _productViewRepository
          .getRecentlyViewedProducts(limit: 10);

      _trendingProductsFuture = _trendingRepository.getTrendingProducts(
        daysBack: 7,
        limit: 10,
      );
    });

    await Future.wait([
      _featuredProductsFuture,
      _trendingProductsFuture,
      _recommendationsFuture,
      _recentlyViewedProductsFuture,
    ]);
  }

  Future<void> _loadWishlist() async {
    try {
      final products = await _wishlistRepository.getWishlistItems();

      if (!mounted) return;

      setState(() {
        _wishlistProductIds
          ..clear()
          ..addAll(products.map((product) => product.id));
      });
    } catch (error) {
      debugPrint('WISHLIST LOADING ERROR: $error');
    }
  }

  Future<void> _loadComparison() async {
    try {
      final products = await _compareRepository.getComparedProducts();

      if (!mounted) return;

      setState(() {
        _comparedProductIds
          ..clear()
          ..addAll(products.map((product) => product.id));

        _comparisonReferenceProduct = products.isNotEmpty
            ? products.first
            : null;
      });
    } catch (error) {
      debugPrint('COMPARISON LOADING ERROR: $error');
    }
  }

  void _onComparisonChanged() {
    _loadComparison();
  }

  bool _matchesComparisonGroup(ProductModel product) {
    final reference = _comparisonReferenceProduct;

    if (reference == null) return false;

    if (_comparedProductIds.contains(product.id)) {
      return false;
    }

    final referenceCategory = reference.category.trim().toLowerCase();
    final productCategory = product.category.trim().toLowerCase();

    if (referenceCategory != productCategory) {
      return false;
    }

    final referenceType = reference.productType?.trim().toLowerCase() ?? '';

    final productType = product.productType?.trim().toLowerCase() ?? '';

    if (referenceType.isEmpty && productType.isEmpty) {
      return true;
    }

    return referenceType.isNotEmpty &&
        productType.isNotEmpty &&
        referenceType == productType;
  }

  Future<void> _loadUnreadNotificationCount() async {
    try {
      final count = await _notificationRepository.getUnreadCount();

      if (!mounted) return;

      setState(() {
        _unreadNotificationCount = count;
      });
    } catch (error) {
      debugPrint('UNREAD NOTIFICATION COUNT ERROR: $error');
    }
  }

  void _onNotificationsChanged() {
    _loadUnreadNotificationCount();
  }

  Future<void> _toggleCompare(ProductModel product) async {
    final productId = product.id;

    if (_compareLoadingIds.contains(productId)) return;

    final isCompared = _comparedProductIds.contains(productId);

    setState(() {
      _compareLoadingIds.add(productId);
    });

    try {
      if (isCompared) {
        await _compareRepository.removeProduct(productId);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product removed from comparison.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        final result = await _compareRepository.addProduct(productId);

        if (!mounted) return;

        switch (result) {
          case CompareAddResult.added:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Product added to comparison!'),
                behavior: SnackBarBehavior.floating,
              ),
            );
            break;

          case CompareAddResult.alreadyAdded:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This product is already in comparison.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
            break;

          case CompareAddResult.limitReached:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'You can compare up to ${CompareRepository.maxProducts} products.',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
            break;

          case CompareAddResult.differentType:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'You can only compare products from the same product type.',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
            break;

          case CompareAddResult.productUnavailable:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This product is currently unavailable.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
            break;
        }
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update comparison. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _compareLoadingIds.remove(productId);
        });
      }
    }
  }

  Future<void> _toggleWishlist(ProductModel product) async {
    final productId = product.id;

    if (_wishlistLoadingIds.contains(productId)) {
      return;
    }

    final isCurrentlySaved = _wishlistProductIds.contains(productId);

    setState(() {
      _wishlistLoadingIds.add(productId);
    });

    try {
      if (isCurrentlySaved) {
        await _wishlistRepository.removeFromWishlist(productId);
      } else {
        await _wishlistRepository.addToWishlist(productId);
      }

      if (!mounted) return;

      setState(() {
        if (isCurrentlySaved) {
          _wishlistProductIds.remove(productId);
        } else {
          _wishlistProductIds.add(productId);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isCurrentlySaved
                ? 'Removed from your wishlist.'
                : 'Added to your wishlist!',
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

  @override
  void dispose() {
    CompareRepository.comparisonChanges.removeListener(_onComparisonChanged);

    final channel = _notificationsChannel;

    if (channel != null) {
      unawaited(_notificationRepository.unsubscribeFromNotifications(channel));
    }

    super.dispose();
  }

  final List<_CategoryItem> _categories = const [
    _CategoryItem(name: 'Fashion', icon: Icons.checkroom_outlined),
    _CategoryItem(name: 'Electronics', icon: Icons.devices_outlined),
    _CategoryItem(name: 'Beauty', icon: Icons.spa_outlined),
    _CategoryItem(name: 'Home', icon: Icons.chair_outlined),
    _CategoryItem(name: 'Accessories', icon: Icons.watch_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    const background = AppColors.background;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshHome,
          color: const Color(0xFFA78BFA),
          backgroundColor: const Color(0xFF171722),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageHorizontal,
                    AppSpacing.lg,
                    AppSpacing.pageHorizontal,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusLarge,
                          ),
                          gradient: AppColors.primaryGradient,
                        ),
                        child: const Icon(
                          Icons.shopping_bag_rounded,
                          color: AppColors.white,
                          size: 25,
                        ),
                      ),

                      const SizedBox(width: AppSpacing.sm),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'STEAL HERE',
                              style: AppTextStyles.headingSmall.copyWith(
                                color: AppColors.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              'Luxury Deals. Powerful Experience.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),

                      _HeaderButton(
                        icon: Icons.notifications_none_rounded,
                        badgeCount: _unreadNotificationCount,
                        onTap: () async {
                          await context.push(AppRoutes.notifications);

                          if (!mounted) return;

                          await _loadUnreadNotificationCount();
                        },
                      ),

                      const SizedBox(width: AppSpacing.xs),

                      _HeaderButton(
                        icon: Icons.person_outline_rounded,
                        onTap: () => context.push(AppRoutes.profile),
                      ),
                    ],
                  ),
                ),
              ),

              // Welcome
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageHorizontal,
                    AppSpacing.md,
                    AppSpacing.pageHorizontal,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good shopping starts here ✨',
                        style: AppTextStyles.headingLarge.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xs),

                      Text(
                        'Discover deals worth your money.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      // Search
                      AppCard(
                        variant: AppCardVariant.elevated,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.md,
                        ),
                        onTap: () => context.push(AppRoutes.search),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search_rounded,
                              color: AppColors.textSecondary,
                              size: 23,
                            ),

                            const SizedBox(width: AppSpacing.sm),

                            Expanded(
                              child: Text(
                                'Search products, brands...',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textMuted,
                                  fontSize: 14,
                                ),
                              ),
                            ),

                            const Icon(
                              Icons.tune_rounded,
                              color: AppColors.primary,
                              size: 21,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Promotional banner
              SliverToBoxAdapter(
                child: Padding(
                  padding: AppSpacing.sectionPadding,
                  child: AppCard(
                    variant: AppCardVariant.premium,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusXXLarge,
                      ),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF5727A8),
                          Color(0xFF28164D),
                          Color(0xFF171322),
                        ],
                      ),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Stack(
                      children: [
                        const Positioned(
                          right: 0,
                          top: 0,
                          child: Icon(
                            Icons.auto_awesome,
                            color: AppColors.gold,
                            size: 36,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusCircular,
                                ),
                              ),
                              child: Text(
                                'EXCLUSIVE COLLECTION',
                                style: AppTextStyles.overline.copyWith(
                                  color: AppColors.gold,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              'Luxury for less.',
                              style: AppTextStyles.displaySmall.copyWith(
                                color: AppColors.white,
                                fontSize: 27,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Find your favorites. Shop smarter.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: const Color(0xFFD5C8EF),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            AppButton(
                              text: 'Explore Deals',
                              onPressed: _exploreDeals,
                              variant: AppButtonVariant.primary,
                              height: 46,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Categories heading
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageHorizontal,
                    AppSpacing.sectionSpacing,
                    AppSpacing.pageHorizontal,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Shop by Category',
                        style: AppTextStyles.headingSmall.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 19,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push(AppRoutes.categories),
                        child: Text(
                          'See all',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Category list
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 108,
                  child: ListView.separated(
                    padding: AppSpacing.sectionPadding,
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final category = _categories[index];

                      return SizedBox(
                        width: 75,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              final categoryName = Uri.encodeQueryComponent(
                                category.name,
                              );

                              context.push(
                                '${AppRoutes.categories}?category=$categoryName',
                              );
                            },
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusLarge,
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 62,
                                  height: 62,
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusLarge,
                                    ),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.22,
                                      ),
                                    ),
                                  ),
                                  child: Icon(
                                    category.icon,
                                    color: AppColors.primaryLight,
                                    size: 27,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  category.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Featured products heading
              SliverToBoxAdapter(
                child: Padding(
                  key: _featuredProductsKey,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageHorizontal,
                    AppSpacing.sectionSpacing,
                    AppSpacing.pageHorizontal,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Featured Products',
                          style: AppTextStyles.headingSmall.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 19,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push(AppRoutes.categories),
                        child: Text(
                          'View all',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Products
              // Dynamic Featured Products from Supabase
              SliverToBoxAdapter(
                child: FutureBuilder<List<ProductModel>>(
                  future: _featuredProductsFuture,
                  builder: (context, snapshot) {
                    // Loading state
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const AppLoading(
                        message: 'Loading featured products...',
                        size: 30,
                        padding: EdgeInsets.all(40),
                      );
                    }

                    // Error state
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 20,
                        ),
                        child: AppErrorState(
                          title: 'Unable to Load Products',
                          message:
                              'We could not fetch featured products right now.',
                          actionLabel: 'Try Again',
                          icon: Icons.shopping_bag_outlined,
                          onRetry: () {
                            setState(() {
                              _featuredProductsFuture = _productRepository
                                  .getFeaturedProducts();
                            });
                          },
                        ),
                      );
                    }

                    final products = snapshot.data ?? [];

                    // Empty state
                    if (products.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        child: AppEmptyState(
                          icon: Icons.shopping_bag_outlined,
                          title: 'No Featured Products',
                          message: 'Featured products will appear here when available.',
                        ),
                      );
                    }

                    return Padding(
                      padding: AppSpacing.sectionPadding,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Adapt the number of columns to the available screen width.
                          final availableWidth = constraints.maxWidth;

                          final crossAxisCount =
                              ((availableWidth + AppSpacing.sm) /
                                      (190 + AppSpacing.sm))
                                  .floor()
                                  .clamp(2, 4);

                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: products.length > 6
                                ? 6
                                : products.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  mainAxisSpacing: AppSpacing.md,
                                  crossAxisSpacing: AppSpacing.sm,
                                  mainAxisExtent: 250,
                                ),
                            itemBuilder: (context, index) {
                              final product = products[index];

                              return _ProductCard(
                                product: product,
                                onTap: () => _openProduct(product),
                                isWishlisted: _wishlistProductIds.contains(
                                  product.id,
                                ),
                                isWishlistLoading: _wishlistLoadingIds.contains(
                                  product.id,
                                ),
                                onWishlistTap: () => _toggleWishlist(product),
                                isCompared: _comparedProductIds.contains(
                                  product.id,
                                ),
                                isCompatibleForComparison:
                                    _matchesComparisonGroup(product),
                                isCompareLoading: _compareLoadingIds.contains(
                                  product.id,
                                ),
                                onCompareTap: () => _toggleCompare(product),
                              );
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              ),

              // Trending Products heading
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageHorizontal,
                    AppSpacing.sectionSpacing,
                    AppSpacing.pageHorizontal,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        color: AppColors.gold,
                        size: AppSpacing.iconLarge,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Trending This Week',
                              style: AppTextStyles.headingSmall.copyWith(
                                color: AppColors.textPrimary,
                                fontSize: 19,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              'Popular picks shoppers are exploring.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh trending products',
                        onPressed: () {
                          setState(() {
                            _trendingProductsFuture = _trendingRepository
                                .getTrendingProducts(daysBack: 7, limit: 10);
                          });
                        },
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: AppColors.primaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Trending Products list
              SliverToBoxAdapter(
                child: FutureBuilder<List<ProductModel>>(
                  future: _trendingProductsFuture,
                  builder: (context, snapshot) {
                    // Loading state
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const AppLoading(
                        message: 'Finding trending products...',
                        size: 30,
                        padding: EdgeInsets.all(40),
                      );
                    }

                    // Error state
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        child: AppErrorState(
                          title: 'Trending Products Unavailable',
                          message:
                              'We could not load trending products right now.',
                          actionLabel: 'Try Again',
                          icon: Icons.local_fire_department_outlined,
                          onRetry: () {
                            setState(() {
                              _trendingProductsFuture = _trendingRepository
                                  .getTrendingProducts(daysBack: 7, limit: 10);
                            });
                          },
                        ),
                      );
                    }

                    final products = snapshot.data ?? [];

                    // Empty state
                    if (products.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        child: AppEmptyState(
                          icon: Icons.local_fire_department_outlined,
                          title: 'No Trending Products Yet',
                          message: 'Popular products will appear here as shoppers explore the store.',
                        ),
                      );
                    }
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final cardWidth = (constraints.maxWidth * 0.48)
                            .clamp(165.0, 220.0)
                            .toDouble();

                        return SizedBox(
                          height: 260,
                          child: ListView.separated(
                            padding: AppSpacing.sectionPadding,
                            scrollDirection: Axis.horizontal,
                            itemCount: products.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: AppSpacing.sm),
                            itemBuilder: (context, index) {
                              final product = products[index];

                              return SizedBox(
                                width: cardWidth,
                                child: _ProductCard(
                                  product: product,
                                  recommendationLabel: 'TRENDING',
                                  recommendationReason: 'Popular this week',
                                  onTap: () => _openProduct(product),
                                  isWishlisted: _wishlistProductIds.contains(
                                    product.id,
                                  ),
                                  isWishlistLoading: _wishlistLoadingIds
                                      .contains(product.id),
                                  onWishlistTap: () => _toggleWishlist(product),
                                  isCompared: _comparedProductIds.contains(
                                    product.id,
                                  ),
                                  isCompatibleForComparison:
                                      _matchesComparisonGroup(product),
                                  isCompareLoading: _compareLoadingIds.contains(
                                    product.id,
                                  ),
                                  onCompareTap: () => _toggleCompare(product),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Personalized recommendations heading
              // Dynamic recommendations section
              SliverToBoxAdapter(
                child: FutureBuilder<List<ProductRecommendationModel>>(
                  future: _recommendationsFuture,
                  builder: (context, snapshot) {
                    final recommendations = snapshot.data ?? [];

                    final isPersonalized =
                        recommendations.isNotEmpty &&
                        recommendations.first.isPersonalized;

                    final heading = isPersonalized
                        ? 'Personalized For You'
                        : 'Discover Something New';

                    final subtitle = isPersonalized
                        ? 'Picks based on your shopping activity.'
                        : 'Popular products customers are exploring.';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Dynamic heading
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.pageHorizontal,
                            AppSpacing.sectionSpacing,
                            AppSpacing.pageHorizontal,
                            AppSpacing.sm,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isPersonalized
                                    ? Icons.auto_awesome_rounded
                                    : Icons.explore_rounded,
                                color: const Color(0xFFF5C76A),
                                size: 21,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      heading,
                                      style: AppTextStyles.headingSmall
                                          .copyWith(
                                            color: AppColors.textPrimary,
                                            fontSize: 19,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      subtitle,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.textSecondary,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Refresh recommendations',
                                onPressed: () {
                                  setState(() {
                                    _recommendationsFuture =
                                        _recommendationRepository
                                            .getRecommendations(limit: 6);
                                  });
                                },
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  color: AppColors.primaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Loading state
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const AppLoading(
                            message: 'Finding recommendations for you...',
                            size: 30,
                            padding: EdgeInsets.all(35),
                          )
                        // Error state
                        else if (snapshot.hasError)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
                            ),
                            child: AppErrorState(
                              title: 'Recommendations Unavailable',
                              message: 'We could not load recommendations right now. Please try again.',
                              actionLabel: 'Try Again',
                              icon: Icons.auto_awesome_outlined,
                              onRetry: () {
                                setState(() {
                                  _recommendationsFuture =
                                      _recommendationRepository
                                          .getRecommendations(limit: 6);
                                });
                              },
                            ),
                          )
                        // Empty state
                        else if (recommendations.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
                            ),
                            child: AppEmptyState(
                              icon: Icons.auto_awesome_outlined,
                              title: 'Discover Something New',
                              message: 'Explore more products to discover recommendations picked for you.',
                            ),
                          )
                        // Recommendation products
                        else
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final cardWidth = (constraints.maxWidth * 0.48)
                                  .clamp(165.0, 220.0)
                                  .toDouble();

                              return SizedBox(
                                height: 260,
                                child: ListView.separated(
                                  padding: AppSpacing.sectionPadding,
                                  scrollDirection: Axis.horizontal,
                                  itemCount: recommendations.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: AppSpacing.sm),
                                  itemBuilder: (context, index) {
                                    final recommendation =
                                        recommendations[index];
                                    final product = recommendation.product;

                                    return SizedBox(
                                      width: cardWidth,
                                      child: _ProductCard(
                                        product: product,
                                        recommendationLabel:
                                            recommendation.reasonLabel,
                                        recommendationReason:
                                            recommendation.reason,
                                        onTap: () => _openProduct(product),
                                        isWishlisted: _wishlistProductIds
                                            .contains(product.id),
                                        isWishlistLoading: _wishlistLoadingIds
                                            .contains(product.id),
                                        onWishlistTap: () =>
                                            _toggleWishlist(product),
                                        isCompared: _comparedProductIds
                                            .contains(product.id),
                                        isCompatibleForComparison:
                                            _matchesComparisonGroup(product),
                                        isCompareLoading: _compareLoadingIds
                                            .contains(product.id),
                                        onCompareTap: () =>
                                            _toggleCompare(product),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                      ],
                    );
                  },
                ),
              ),

              // Recently Viewed section
              SliverToBoxAdapter(
                child: FutureBuilder<List<ProductModel>>(
                  future: _recentlyViewedProductsFuture,
                  builder: (context, snapshot) {
                    // Hide the section while loading or if an error occurs.
                    if (snapshot.connectionState == ConnectionState.waiting ||
                        snapshot.hasError) {
                      return const SizedBox.shrink();
                    }

                    final products = snapshot.data ?? [];

                    // Hide the entire section for customers without browsing history.
                    if (products.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Recently Viewed heading
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.pageHorizontal,
                            AppSpacing.sectionSpacing,
                            AppSpacing.pageHorizontal,
                            AppSpacing.sm,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.history_rounded,
                                color: Color(0xFFA78BFA),
                                size: 22,
                              ),
                              const SizedBox(width: 9),
                              const Expanded(
                                child: Text(
                                  'Recently Viewed',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),

                              // Open complete browsing history.
                              TextButton(
                                onPressed: () async {
                                  await context.push(AppRoutes.browsingHistory);

                                  if (!mounted) return;

                                  setState(() {
                                    _recentlyViewedProductsFuture =
                                        _productViewRepository
                                            .getRecentlyViewedProducts(
                                              limit: 10,
                                            );
                                  });
                                },
                                child: const Text(
                                  'See All',
                                  style: TextStyle(
                                    color: Color(0xFF8B5CF6),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),

                              // Refresh recently viewed products.
                              IconButton(
                                tooltip: 'Refresh recently viewed',
                                onPressed: () {
                                  setState(() {
                                    _recentlyViewedProductsFuture =
                                        _productViewRepository
                                            .getRecentlyViewedProducts(
                                              limit: 10,
                                            );
                                  });
                                },
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  color: Color(0xFFA78BFA),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Recently Viewed products
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final cardWidth = (constraints.maxWidth * 0.48)
                                .clamp(165.0, 220.0)
                                .toDouble();

                            return SizedBox(
                              height: 260,
                              child: ListView.separated(
                                padding: AppSpacing.sectionPadding,
                                scrollDirection: Axis.horizontal,
                                itemCount: products.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: AppSpacing.sm),
                                itemBuilder: (context, index) {
                                  final product = products[index];

                                  return SizedBox(
                                    width: cardWidth,
                                    child: _ProductCard(
                                      product: product,
                                      onTap: () => _openProduct(product),
                                      isWishlisted: _wishlistProductIds
                                          .contains(product.id),
                                      isWishlistLoading: _wishlistLoadingIds
                                          .contains(product.id),
                                      onWishlistTap: () =>
                                          _toggleWishlist(product),
                                      isCompared: _comparedProductIds.contains(
                                        product.id,
                                      ),
                                      isCompatibleForComparison:
                                          _matchesComparisonGroup(product),
                                      isCompareLoading: _compareLoadingIds
                                          .contains(product.id),
                                      onCompareTap: () =>
                                          _toggleCompare(product),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Smart shopping
              // Shop Smarter section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageHorizontal,
                    AppSpacing.sectionSpacing,
                    AppSpacing.pageHorizontal,
                    AppSpacing.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section heading
                      Text(
                        'Shop Smarter',
                        style: AppTextStyles.headingSmall.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 19,
                        ),
                      ),

                      const SizedBox(height: AppSpacing.md),

                      // Smart shopping feature cards
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _SmartFeatureCard(
                              icon: Icons.account_balance_wallet_outlined,
                              title: 'Budget Guardian',
                              subtitle: 'Stay in control',
                              onTap: () => context.push(AppRoutes.budget),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _SmartFeatureCard(
                              icon: Icons.compare_arrows_rounded,
                              title: 'Compare',
                              subtitle: 'Choose wisely',
                              onTap: () => context.push(AppRoutes.compare),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.md),

                      // Purchase Insights
                      AppCard(
                        variant: AppCardVariant.elevated,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        onTap: () => context.push(AppRoutes.analytics),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMedium,
                                ),
                              ),
                              child: const Icon(
                                Icons.analytics_rounded,
                                color: AppColors.white,
                                size: 26,
                              ),
                            ),

                            const SizedBox(width: AppSpacing.md),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Purchase Insights',
                                    style: AppTextStyles.headingSmall.copyWith(
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    'Track spending, orders and shopping habits.',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: AppSpacing.xs),

                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: AppColors.primaryLight,
                              size: 17,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom spacing — keep the final content clear of the floating button.
              SliverToBoxAdapter(
                child: SizedBox(
                  height: _comparedProductIds.isNotEmpty ? 120 : AppSpacing.xl,
                ),
              ),
            ],
          ),
        ),
      ),

      floatingActionButton: _comparedProductIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () {
                context.push(AppRoutes.compare);
              },
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              elevation: 6,
              icon: const Icon(Icons.compare_arrows_rounded),
              label: Text(
                'Compare Selected Products (${_comparedProductIds.length})',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      // Bottom navigation
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          border: Border(
            top: BorderSide(color: AppColors.border.withValues(alpha: 0.7)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BottomNavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  selected: _selectedIndex == 0,
                  onTap: () => _onNavigationTap(0),
                ),
                _BottomNavItem(
                  icon: Icons.grid_view_rounded,
                  label: 'Categories',
                  selected: _selectedIndex == 1,
                  onTap: () => _onNavigationTap(1),
                ),
                _BottomNavItem(
                  icon: Icons.favorite_border_rounded,
                  label: 'Wishlist',
                  selected: _selectedIndex == 2,
                  onTap: () => _onNavigationTap(2),
                ),
                _BottomNavItem(
                  icon: Icons.shopping_cart_outlined,
                  label: 'Cart',
                  selected: _selectedIndex == 3,
                  onTap: () => _onNavigationTap(3),
                ),
                _BottomNavItem(
                  icon: Icons.person_outline_rounded,
                  label: 'Profile',
                  selected: _selectedIndex == 4,
                  onTap: () => _onNavigationTap(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onNavigationTap(int index) async {
    if (index == 0) {
      setState(() {
        _selectedIndex = 0;
      });

      context.go(AppRoutes.home);
      return;
    }

    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 1:
        await context.push(AppRoutes.categories);
        break;

      case 2:
        await context.push(AppRoutes.wishlist);
        break;

      case 3:
        await context.push(AppRoutes.cart);
        break;

      case 4:
        await context.push(AppRoutes.profile);
        break;
    }

    if (!mounted) return;

    // Restore Home selection when returning from another screen.
    setState(() {
      _selectedIndex = 0;
    });
  }
}

class _CategoryItem {
  const _CategoryItem({required this.name, required this.icon});

  final String name;
  final IconData icon;
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(
                icon,
                color: AppColors.textPrimary,
                size: AppSpacing.iconLarge,
              ),
              if (badgeCount > 0)
                Positioned(
                  right: -5,
                  top: -5,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusCircular,
                      ),
                      border: Border.all(
                        color: AppColors.background,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : badgeCount.toString(),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
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

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    this.recommendationLabel,
    this.recommendationReason,
    required this.onTap,
    required this.isWishlisted,
    required this.isWishlistLoading,
    required this.onWishlistTap,
    required this.isCompared,
    required this.isCompatibleForComparison,
    required this.isCompareLoading,
    required this.onCompareTap,
  });

  final ProductModel product;
  final String? recommendationLabel;
  final String? recommendationReason;
  final VoidCallback onTap;
  final bool isWishlisted;
  final bool isWishlistLoading;
  final VoidCallback onWishlistTap;
  final bool isCompared;
  final bool isCompatibleForComparison;
  final bool isCompareLoading;
  final VoidCallback onCompareTap;

  String _formatPrice(double price) {
    final amount = price.round().toString();

    final formatted = amount.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );

    return 'Rp $formatted';
  }

  String? _discountLabel() {
    final oldPrice = product.compareAtPrice;

    if (oldPrice == null || oldPrice <= product.price || oldPrice == 0) {
      return null;
    }

    final discount = ((oldPrice - product.price) / oldPrice * 100).round();

    return '$discount% OFF';
  }

  IconData _categoryIcon() {
    switch (product.category.toLowerCase()) {
      case 'electronics':
        return Icons.headphones_rounded;
      case 'fashion':
        return Icons.checkroom_rounded;
      case 'beauty':
        return Icons.spa_rounded;
      case 'accessories':
        return Icons.watch_rounded;
      case 'home':
        return Icons.chair_rounded;
      default:
        return Icons.shopping_bag_rounded;
    }
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF30204F), Color(0xFF1C1C2B)],
        ),
      ),
      child: Icon(_categoryIcon(), color: AppColors.primaryLight, size: 52),
    );
  }

  Widget _buildActionButton({
    required String tooltip,
    required IconData icon,
    required Color iconColor,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return Material(
      color: AppColors.background.withValues(alpha: 0.82),
      shape: const CircleBorder(),
      child: SizedBox(
        width: 36,
        height: 36,
        child: IconButton(
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          onPressed: isLoading ? null : onPressed,
          icon: isLoading
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryLight,
                  ),
                )
              : Icon(icon, color: iconColor, size: AppSpacing.iconMedium),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final discount = _discountLabel();

    final hasOriginalPrice =
        product.compareAtPrice != null &&
        product.compareAtPrice! > product.price;

    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        side: BorderSide(
          color: isCompared
              ? AppColors.gold
              : isCompatibleForComparison
              ? AppColors.primaryLight
              : AppColors.border,
          width: isCompared
              ? 2.0
              : isCompatibleForComparison
              ? 1.6
              : 1.0,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image and floating actions.
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Product image.
                  product.imageUrl != null && product.imageUrl!.isNotEmpty
                      ? Image.network(
                          product.imageUrl!,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) {
                              return child;
                            }

                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                _buildImagePlaceholder(),
                                const Center(
                                  child: SizedBox(
                                    width: 23,
                                    height: 23,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primaryLight,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return _buildImagePlaceholder();
                          },
                        )
                      : _buildImagePlaceholder(),

                  // Discount badge.
                  if (discount != null)
                    Positioned(
                      left: AppSpacing.sm,
                      top: AppSpacing.sm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSmall,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          discount,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textOnGold,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),

                  // Wishlist button.
                  Positioned(
                    right: AppSpacing.sm,
                    top: AppSpacing.sm,
                    child: _buildActionButton(
                      tooltip: isWishlisted
                          ? 'Remove from wishlist'
                          : 'Add to wishlist',
                      icon: isWishlisted
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      iconColor: isWishlisted
                          ? AppColors.wishlist
                          : AppColors.white,
                      onPressed: onWishlistTap,
                      isLoading: isWishlistLoading,
                    ),
                  ),

                  // Comparison button.
                  // Clear comparison action.
                  Positioned(
                    left: AppSpacing.sm,
                    bottom: AppSpacing.sm,
                    child: Material(
                      color: isCompared
                          ? AppColors.gold
                          : AppColors.background.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusLarge,
                      ),
                      child: InkWell(
                        onTap: isCompareLoading ? null : onCompareTap,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusLarge,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isCompareLoading)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryLight,
                                  ),
                                )
                              else
                                Icon(
                                  isCompared
                                      ? Icons.check_circle_rounded
                                      : Icons.compare_arrows_rounded,
                                  size: 15,
                                  color: isCompared
                                      ? AppColors.textOnGold
                                      : AppColors.white,
                                ),
                              const SizedBox(width: 5),
                              Text(
                                isCompareLoading
                                    ? 'Please wait'
                                    : isCompared
                                    ? 'Added'
                                    : 'Compare',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: isCompared
                                      ? AppColors.textOnGold
                                      : AppColors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Recommendation label.
                  if (recommendationLabel != null)
                    Positioned(
                      right: AppSpacing.sm,
                      bottom: AppSpacing.sm,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 110),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSmall,
                          ),
                        ),
                        child: Text(
                          recommendationLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Product information.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Category.
                  // Category and product type tags.
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      if (isCompatibleForComparison && !isCompared)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: AppColors.primaryLight.withValues(
                                alpha: 0.65,
                              ),
                            ),
                          ),
                          child: Text(
                            'MATCHES',
                            style: AppTextStyles.overline.copyWith(
                              color: AppColors.primaryLight,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isCompared
                              ? AppColors.gold.withValues(alpha: 0.16)
                              : AppColors.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: isCompared
                                ? AppColors.gold.withValues(alpha: 0.55)
                                : AppColors.primary.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          product.category.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.overline.copyWith(
                            color: isCompared
                                ? AppColors.gold
                                : AppColors.primaryLight,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (product.productType != null &&
                          product.productType!.trim().isNotEmpty)
                        Container(
                          constraints: const BoxConstraints(maxWidth: 105),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundSecondary,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            product.productType!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.overline.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xxs),

                  const SizedBox(height: AppSpacing.xxs),

                  // Product name.
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.productName.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  // Recommendation reason.
                  if (recommendationReason != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      recommendationReason!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primaryLight,
                        fontSize: 9,
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xs),

                  // Rating and reviews.
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: AppColors.rating,
                        size: 15,
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      Text(
                        product.rating.toStringAsFixed(1),
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          '(${product.reviewCount} reviews)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 8,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xs),

                  // Current price.
                  Text(
                    _formatPrice(product.price),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.price.copyWith(
                      color: AppColors.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  // Original price.
                  if (hasOriginalPrice) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatPrice(product.compareAtPrice!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.originalPrice.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 9,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmartFeatureCard extends StatelessWidget {
  const _SmartFeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: AppCardVariant.elevated,
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            ),
            child: Icon(
              icon,
              color: AppColors.white,
              size: AppSpacing.iconLarge,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.headingSmall.copyWith(
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: AppSpacing.xs),

          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: AppSpacing.xs),

          const Align(
            alignment: Alignment.centerRight,
            child: Icon(
              Icons.arrow_forward_rounded,
              color: AppColors.primaryLight,
              size: AppSpacing.iconMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryLight : AppColors.textMuted;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: AppSpacing.iconLarge),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelSmall.copyWith(
                  color: color,
                  fontSize: 9,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
