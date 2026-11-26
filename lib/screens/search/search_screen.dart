import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routes/app_routes.dart';
import '../../models/product_model.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/wishlist_repository.dart';
import '../../repositories/compare_repository.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/product_recommendation_model.dart';
import '../../repositories/recommendation_repository.dart';
import '../../repositories/product_view_repository.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_spacing.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/themes/app_decorations.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _PriceFilterSheet extends StatefulWidget {
  final double? minimumPrice;
  final double? maximumPrice;

  const _PriceFilterSheet({
    required this.minimumPrice,
    required this.maximumPrice,
  });

  @override
  State<_PriceFilterSheet> createState() => _PriceFilterSheetState();
}

class _PriceFilterSheetState extends State<_PriceFilterSheet> {
  late final TextEditingController _minimumController;
  late final TextEditingController _maximumController;

  @override
  void initState() {
    super.initState();

    _minimumController = TextEditingController(
      text: widget.minimumPrice?.toStringAsFixed(0) ?? '',
    );

    _maximumController = TextEditingController(
      text: widget.maximumPrice?.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    _minimumController.dispose();
    _maximumController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _applyFilters() {
    final minimumText = _minimumController.text.trim();
    final maximumText = _maximumController.text.trim();

    final minimum = double.tryParse(minimumText);
    final maximum = double.tryParse(maximumText);

    if (minimumText.isNotEmpty && (minimum == null || minimum < 0)) {
      _showError('Enter a valid minimum price.');
      return;
    }

    if (maximumText.isNotEmpty && (maximum == null || maximum < 0)) {
      _showError('Enter a valid maximum price.');
      return;
    }

    if (minimum != null && maximum != null && minimum > maximum) {
      _showError('Minimum price cannot exceed maximum price.');
      return;
    }

    Navigator.pop(context, (minimum, maximum));
  }

  Widget _buildPriceInput({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textSecondary,
        ),
        prefixText: 'Rp ',
        prefixStyle: AppTextStyles.labelLarge.copyWith(color: AppColors.gold),
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(
                    AppSpacing.radiusCircular,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Price Filter',
              style: AppTextStyles.headingMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Choose your preferred price range.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            Row(
              children: [
                Expanded(
                  child: _buildPriceInput(
                    controller: _minimumController,
                    label: 'Minimum Price',
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _buildPriceInput(
                    controller: _maximumController,
                    label: 'Maximum Price',
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            SizedBox(
              width: double.infinity,
              height: AppSpacing.buttonHeight,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context, (null, null));
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.borderStrong),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusMedium,
                    ),
                  ),
                ),
                child: Text('Reset Filters', style: AppTextStyles.buttonMedium),
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            SizedBox(
              width: double.infinity,
              height: AppSpacing.buttonHeight,
              child: ElevatedButton(
                onPressed: _applyFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusMedium,
                    ),
                  ),
                ),
                child: Text('Apply Filters', style: AppTextStyles.buttonMedium),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchScreenState extends State<SearchScreen> {
  static const Color _background = AppColors.background;
  static const Color _surface = AppColors.surface;
  static const Color _primary = AppColors.primary;

  static const List<String> _popularSearchTerms = [
    'Wireless Headphones',
    'Smart Watches',
    'Sneakers',
    'Skincare',
    'Bluetooth Speakers',
    'Men\'s Fashion',
    'Women\'s Fashion',
    'Home Decor',
  ];

  final ProductRepository _productRepository = ProductRepository();
  final WishlistRepository _wishlistRepository = WishlistRepository();
  final CompareRepository _compareRepository = CompareRepository();
  final RecommendationRepository _recommendationRepository =
      RecommendationRepository();

  final ProductViewRepository _productViewRepository = ProductViewRepository();

  late Future<List<ProductRecommendationModel>> _recommendationsFuture;

  late Future<List<ProductModel>> _recentlyViewedProductsFuture;

  final Map<String, Future<bool>> _wishlistStatusFutures = {};
  final Map<String, Future<bool>> _compareStatusFutures = {};
  final Set<String> _updatingCompareProducts = {};
  int _comparisonCount = 0;
  ProductModel? _comparisonReferenceProduct;

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  List<ProductModel> _products = [];
  final List<String> _recentSearches = [];

  String get _recentSearchesKey {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) {
      return 'recent_searches_guest';
    }

    return 'recent_searches_$userId';
  }

  void _refreshDiscoverySections() {
    _recommendationsFuture = _recommendationRepository.getRecommendations(
      limit: 8,
    );

    _recentlyViewedProductsFuture = _productViewRepository
        .getRecentlyViewedProducts(limit: 10);
  }

  Future<void> _loadRecentSearches() async {
    final preferences = await SharedPreferences.getInstance();

    // Remove the old shared history because its owner cannot
    // be reliably identified.
    await preferences.remove('recent_searches');

    final key = _recentSearchesKey;
    final searches = preferences.getStringList(key) ?? [];

    if (!mounted) return;

    setState(() {
      _recentSearches
        ..clear()
        ..addAll(searches);
    });
  }

  Future<void> _saveRecentSearch(String query) async {
    final value = query.trim();

    if (value.isEmpty) return;

    final preferences = await SharedPreferences.getInstance();
    final key = _recentSearchesKey;

    final searches = preferences.getStringList(key) ?? [];

    searches.remove(value);
    searches.insert(0, value);

    if (searches.length > 8) {
      searches.removeRange(8, searches.length);
    }

    await preferences.setStringList(key, searches);

    if (!mounted) return;

    setState(() {
      _recentSearches
        ..clear()
        ..addAll(searches);
    });
  }

  Future<void> _clearRecentSearches() async {
    final preferences = await SharedPreferences.getInstance();
    final key = _recentSearchesKey;

    await preferences.remove(key);

    if (!mounted) return;

    setState(() {
      _recentSearches.clear();
    });
  }

  Future<void> _removeRecentSearch(String search) async {
    final preferences = await SharedPreferences.getInstance();
    final key = _recentSearchesKey;

    final searches = preferences.getStringList(key) ?? [];

    searches.remove(search);

    await preferences.setStringList(key, searches);

    if (!mounted) return;

    setState(() {
      _recentSearches
        ..clear()
        ..addAll(searches);
    });
  }

  String _selectedCategory = 'All';
  String _selectedBrand = 'All';
  String _selectedProductType = 'All';
  String _sortOption = 'Newest';

  double? _minimumPrice;
  double? _maximumPrice;
  bool _inStockOnly = false;
  bool _onSaleOnly = false;
  double _minimumRating = 0;

  bool get _hasActiveFilters =>
      _searchController.text.trim().isNotEmpty ||
      _selectedCategory != 'All' ||
      _selectedBrand != 'All' ||
      _selectedProductType != 'All' ||
      _minimumPrice != null ||
      _maximumPrice != null ||
      _sortOption != 'Newest' ||
      _inStockOnly ||
      _onSaleOnly ||
      _minimumRating > 0;

  void _clearAllFilters() {
    setState(() {
      _searchController.clear();
      _selectedCategory = 'All';
      _selectedBrand = 'All';
      _selectedProductType = 'All';
      _minimumPrice = null;
      _maximumPrice = null;
      _sortOption = 'Newest';
      _inStockOnly = false;
      _onSaleOnly = false;
      _minimumRating = 0;
    });
  }

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    CompareRepository.comparisonChanges.addListener(_onComparisonChanged);

    _recommendationsFuture = _recommendationRepository.getRecommendations(
      limit: 8,
    );

    _recentlyViewedProductsFuture = _productViewRepository
        .getRecentlyViewedProducts(limit: 10);

    _loadProducts();
    _loadRecentSearches();
    _refreshComparisonState();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();

    CompareRepository.comparisonChanges.removeListener(_onComparisonChanged);

    _searchController.dispose();
    super.dispose();
  }

  void _onComparisonChanged() {
    _refreshComparisonState();
  }

  Future<void> _refreshComparisonState() async {
    try {
      final comparedProducts = await _compareRepository.getComparedProducts();
      final productIds = comparedProducts.map((product) => product.id).toSet();

      if (!mounted) return;

      setState(() {
        _comparisonCount = productIds.length;
        _comparisonReferenceProduct = comparedProducts.isEmpty
            ? null
            : comparedProducts.first;

        _compareStatusFutures
          ..clear()
          ..addEntries(
            _products.map(
              (product) => MapEntry(
                product.id,
                Future<bool>.value(productIds.contains(product.id)),
              ),
            ),
          );
      });
    } catch (error) {
      debugPrint('Unable to refresh comparison state: $error');
    }
  }

  Future<void> _loadProducts({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final products = await _productRepository.getProducts();

      if (!mounted) return;

      setState(() {
        _products = products;
        _refreshDiscoverySections();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;

        if (_products.isEmpty) {
          _errorMessage = 'Unable to load products. Please try again.';
        }
      });

      if (_products.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to refresh products. Please try again.'),
          ),
        );
      }
    }
  }

  List<String> get _categories {
    final categories = _products
        .map((product) => product.category)
        .where((category) => category.trim().isNotEmpty)
        .toSet()
        .toList();

    categories.sort();

    return ['All', ...categories];
  }

  List<String> get _brands {
    final brands = _products
        .map((product) => product.brand?.trim() ?? '')
        .where((brand) => brand.isNotEmpty)
        .toSet()
        .toList();

    brands.sort();

    return ['All', ...brands];
  }

  List<String> get _productTypes {
    final types = _products
        .map((product) => product.productType?.trim() ?? '')
        .where((type) => type.isNotEmpty)
        .toSet()
        .toList();

    types.sort();

    return ['All', ...types];
  }

  List<ProductModel> get _filteredProducts {
    final query = _searchController.text.trim().toLowerCase();

    List<ProductModel> results = _products.where((product) {
      final matchesSearch =
          query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query) ||
          (product.brand?.toLowerCase().contains(query) ?? false) ||
          (product.sku?.toLowerCase().contains(query) ?? false) ||
          (product.description?.toLowerCase().contains(query) ?? false);

      final matchesCategory =
          _selectedCategory == 'All' || product.category == _selectedCategory;

      final matchesBrand =
          _selectedBrand == 'All' || product.brand?.trim() == _selectedBrand;

      final matchesProductType =
          _selectedProductType == 'All' ||
          product.productType?.trim() == _selectedProductType;

      final matchesMinimumPrice =
          _minimumPrice == null || product.price >= _minimumPrice!;

      final matchesMaximumPrice =
          _maximumPrice == null || product.price <= _maximumPrice!;

      final matchesInStock = !_inStockOnly || product.stockQuantity > 0;

      final matchesOnSale =
          !_onSaleOnly ||
          (product.compareAtPrice != null &&
              product.compareAtPrice! > product.price);

      final matchesMinimumRating =
          _minimumRating == 0 || product.rating >= _minimumRating;

      return matchesSearch &&
          matchesCategory &&
          matchesBrand &&
          matchesProductType &&
          matchesMinimumPrice &&
          matchesMaximumPrice &&
          matchesInStock &&
          matchesOnSale &&
          matchesMinimumRating;
    }).toList();

    switch (_sortOption) {
      case 'Price: Low to High':
        results.sort((a, b) => a.price.compareTo(b.price));
        break;

      case 'Price: High to Low':
        results.sort((a, b) => b.price.compareTo(a.price));
        break;

      case 'Newest':
        results.sort((a, b) {
          final dateA = a.createdAt;
          final dateB = b.createdAt;

          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;

          return dateB.compareTo(dateA);
        });
        break;

      case 'Highest Rated':
        results.sort((a, b) => b.rating.compareTo(a.rating));
        break;

      case 'Most Reviewed':
        results.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
        break;
    }

    return results;
  }

  void _selectRecentSearch(String query) {
    _searchController.text = query;
    _searchController.selection = TextSelection.collapsed(offset: query.length);

    setState(() {});
  }

  String _formatPrice(double price) {
    final amount = price.round().toString();
    final buffer = StringBuffer();

    for (int i = 0; i < amount.length; i++) {
      if (i > 0 && (amount.length - i) % 3 == 0) {
        buffer.write('.');
      }

      buffer.write(amount[i]);
    }

    return 'Rp ${buffer.toString()}';
  }

  Future<bool> _getWishlistStatus(String productId) {
    return _wishlistStatusFutures.putIfAbsent(
      productId,
      () => _wishlistRepository.isInWishlist(productId),
    );
  }

  Future<bool> _getCompareStatus(String productId) {
    return _compareStatusFutures.putIfAbsent(
      productId,
      () => _compareRepository.isProductCompared(productId),
    );
  }

  Future<void> _toggleCompare(ProductModel product, bool isCompared) async {
    if (_updatingCompareProducts.contains(product.id)) return;

    setState(() {
      _updatingCompareProducts.add(product.id);
    });

    try {
      if (isCompared) {
        await _compareRepository.removeProduct(product.id);

        if (!mounted) return;

        _compareStatusFutures[product.id] = Future<bool>.value(false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product removed from comparison.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        final result = await _compareRepository.addProduct(product.id);

        if (!mounted) return;

        switch (result) {
          case CompareAddResult.added:
            _compareStatusFutures[product.id] = Future<bool>.value(true);

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Product added to comparison!'),
                behavior: SnackBarBehavior.floating,
              ),
            );
            break;

          case CompareAddResult.alreadyAdded:
            _compareStatusFutures[product.id] = Future<bool>.value(true);

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
          _updatingCompareProducts.remove(product.id);
        });
      }
    }
  }

  Future<void> _toggleWishlist(ProductModel product, bool isSaved) async {
    try {
      if (isSaved) {
        await _wishlistRepository.removeFromWishlist(product.id);
      } else {
        await _wishlistRepository.addToWishlist(product.id);
      }

      if (!mounted) return;

      // Update cached wishlist status.
      _wishlistStatusFutures[product.id] = Future<bool>.value(!isSaved);

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isSaved ? 'Removed from wishlist' : 'Added to wishlist',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update wishlist. Please try again.'),
        ),
      );
    }
  }

  Future<void> _showPriceFilters() async {
    final result = await showModalBottomSheet<(double?, double?)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PriceFilterSheet(
        minimumPrice: _minimumPrice,
        maximumPrice: _maximumPrice,
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _minimumPrice = result.$1;
      _maximumPrice = result.$2;
    });
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXXLarge),
        ),
      ),
      builder: (context) {
        final options = [
          'Newest',
          'Price: Low to High',
          'Price: High to Low',
          'Highest Rated',
          'Most Reviewed',
        ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderStrong,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusCircular,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Sort Products',
                  style: AppTextStyles.headingMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ...options.map((option) {
                  final isSelected = _sortOption == option;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    title: Text(
                      option,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isSelected
                            ? AppColors.primaryLight
                            : AppColors.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.primaryLight,
                          )
                        : const Icon(
                            Icons.circle_outlined,
                            color: AppColors.textMuted,
                          ),
                    onTap: () {
                      setState(() {
                        _sortOption = option;
                      });

                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) {
          _searchDebounce?.cancel();

          _searchDebounce = Timer(const Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() {});
            }
          });
        },
        onSubmitted: _saveRecentSearch,
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search products, brands, categories...',
          hintStyle: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textMuted,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.primaryLight,
            size: AppSpacing.iconLarge,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary,
                  ),
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSuggestions() {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return const SizedBox.shrink();
    }

    final suggestions = _products
        .where((product) {
          return product.name.toLowerCase().contains(query) ||
              product.category.toLowerCase().contains(query) ||
              (product.brand?.toLowerCase().contains(query) ?? false) ||
              (product.sku?.toLowerCase().contains(query) ?? false);
        })
        .take(5)
        .toList();

    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      decoration: AppDecorations.elevatedCard,
      child: Column(
        children: suggestions.map((product) {
          return ListTile(
            dense: true,
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              ),
              child: const Icon(
                Icons.search_rounded,
                color: AppColors.primaryLight,
                size: AppSpacing.iconMedium,
              ),
            ),
            title: Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              [
                if (product.brand != null && product.brand!.trim().isNotEmpty)
                  product.brand!,
                product.category,
              ].join(' • '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            trailing: const Icon(
              Icons.north_west_rounded,
              color: AppColors.textMuted,
              size: AppSpacing.iconSmall,
            ),
            onTap: () {
              _searchController.text = product.name;
              _searchController.selection = TextSelection.collapsed(
                offset: product.name.length,
              );

              _saveRecentSearch(product.name);
              setState(() {});
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final selected = category == _selectedCategory;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = category;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusCircular),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                  width: selected ? 1.3 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  category,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: selected
                        ? AppColors.primaryLight
                        : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBrandFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: AppDecorations.card,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            ),
            child: const Icon(
              Icons.branding_watermark_outlined,
              color: AppColors.primaryLight,
              size: AppSpacing.iconLarge,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Brand',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          DropdownButton<String>(
            value: _selectedBrand,
            dropdownColor: AppColors.surfaceElevated,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            style: AppTextStyles.labelMedium.copyWith(color: AppColors.gold),
            items: _brands.map((brand) {
              return DropdownMenuItem<String>(
                value: brand,
                child: Text(
                  brand == 'All' ? 'All Brands' : brand,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value == null) return;

              setState(() {
                _selectedBrand = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProductTypeFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: AppDecorations.card,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            ),
            child: const Icon(
              Icons.category_outlined,
              color: AppColors.gold,
              size: AppSpacing.iconLarge,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Product Type',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          DropdownButton<String>(
            value: _selectedProductType,
            dropdownColor: AppColors.surfaceElevated,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            style: AppTextStyles.labelMedium.copyWith(color: AppColors.gold),
            items: _productTypes.map((type) {
              return DropdownMenuItem<String>(
                value: type,
                child: Text(
                  type == 'All' ? 'All Types' : type,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value == null) return;

              setState(() {
                _selectedProductType = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterChips() {
    final List<Widget> chips = [];

    void addChip(String label, VoidCallback onDeleted) {
      chips.add(
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppSpacing.radiusCircular),
            border: Border.all(color: AppColors.borderStrong),
          ),
          child: Chip(
            label: Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            deleteIcon: const Icon(
              Icons.close_rounded,
              size: AppSpacing.iconSmall,
              color: AppColors.gold,
            ),
            onDeleted: onDeleted,
            backgroundColor: Colors.transparent,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusCircular),
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      );
    }

    if (_searchController.text.trim().isNotEmpty) {
      addChip('Search: ${_searchController.text.trim()}', () {
        _searchController.clear();
        setState(() {});
      });
    }

    if (_selectedCategory != 'All') {
      addChip('Category: $_selectedCategory', () {
        setState(() {
          _selectedCategory = 'All';
        });
      });
    }

    if (_selectedBrand != 'All') {
      addChip('Brand: $_selectedBrand', () {
        setState(() {
          _selectedBrand = 'All';
        });
      });
    }

    if (_selectedProductType != 'All') {
      addChip('Type: $_selectedProductType', () {
        setState(() {
          _selectedProductType = 'All';
        });
      });
    }

    if (_minimumPrice != null) {
      addChip('Min: ${_formatPrice(_minimumPrice!)}', () {
        setState(() {
          _minimumPrice = null;
        });
      });
    }

    if (_maximumPrice != null) {
      addChip('Max: ${_formatPrice(_maximumPrice!)}', () {
        setState(() {
          _maximumPrice = null;
        });
      });
    }

    if (_inStockOnly) {
      addChip('In Stock Only', () {
        setState(() {
          _inStockOnly = false;
        });
      });
    }

    if (_onSaleOnly) {
      addChip('On Sale Only', () {
        setState(() {
          _onSaleOnly = false;
        });
      });
    }

    if (_minimumRating > 0) {
      addChip('${_minimumRating.toStringAsFixed(1)}+ Stars', () {
        setState(() {
          _minimumRating = 0;
        });
      });
    }

    if (_sortOption != 'Newest') {
      addChip('Sort: $_sortOption', () {
        setState(() {
          _sortOption = 'Newest';
        });
      });
    }

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.filter_alt_rounded,
                color: AppColors.gold,
                size: AppSpacing.iconMedium,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Active Filters',
                  style: AppTextStyles.headingSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${chips.length} applied',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: chips,
          ),
        ],
      ),
    );
  }

  Widget _buildPopularSearches() {
    if (_searchController.text.trim().isNotEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.trending_up_rounded,
              color: AppColors.gold,
              size: AppSpacing.iconMedium,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Popular Searches',
              style: AppTextStyles.headingSmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Explore what shoppers are looking for.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: _popularSearchTerms.map((search) {
            return ActionChip(
              avatar: const Icon(
                Icons.search_rounded,
                color: AppColors.primaryLight,
                size: AppSpacing.iconSmall,
              ),
              label: Text(
                search,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              backgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusCircular),
              ),
              onPressed: () {
                _searchController.text = search;
                _searchController.selection = TextSelection.collapsed(
                  offset: search.length,
                );

                _saveRecentSearch(search);

                setState(() {});
              },
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  Widget _buildRecentSearches() {
    if (_recentSearches.isEmpty || _searchController.text.isNotEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.history_rounded,
                  color: AppColors.primaryLight,
                  size: AppSpacing.iconMedium,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Recent Searches',
                  style: AppTextStyles.headingSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: _clearRecentSearches,
              style: TextButton.styleFrom(foregroundColor: AppColors.gold),
              child: Text(
                'Clear',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.gold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ..._recentSearches.map(
          (search) => ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
            ),
            leading: const Icon(
              Icons.history_rounded,
              color: AppColors.textMuted,
              size: AppSpacing.iconMedium,
            ),
            title: Text(
              search,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            trailing: IconButton(
              tooltip: 'Remove search',
              icon: const Icon(
                Icons.close_rounded,
                color: AppColors.textMuted,
                size: AppSpacing.iconMedium,
              ),
              onPressed: () => _removeRecentSearch(search),
            ),
            onTap: () => _selectRecentSearch(search),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  Future<void> _openProduct(ProductModel product) async {
    await _saveRecentSearch(_searchController.text);

    if (!mounted) return;

    await context.push(AppRoutes.productDetails(product.id));

    if (!mounted) return;

    setState(() {
      _refreshDiscoverySections();
    });
  }

  bool _matchesComparisonGroup(ProductModel product) {
    final reference = _comparisonReferenceProduct;

    if (reference == null) return false;

    final sameCategory =
        product.category.trim().toLowerCase() ==
        reference.category.trim().toLowerCase();

    if (!sameCategory) return false;

    final productType = product.productType?.trim().toLowerCase() ?? '';
    final referenceType = reference.productType?.trim().toLowerCase() ?? '';

    if (productType.isEmpty && referenceType.isEmpty) {
      return true;
    }

    return productType.isNotEmpty &&
        referenceType.isNotEmpty &&
        productType == referenceType;
  }

  Widget _buildProductCard(ProductModel product) {
    final isMatchingComparisonGroup = _matchesComparisonGroup(product);
    return GestureDetector(
      onTap: () => _openProduct(product),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          border: Border.all(
            color: isMatchingComparisonGroup
                ? AppColors.gold.withValues(alpha: 0.75)
                : AppColors.border,
            width: isMatchingComparisonGroup ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: AppColors.surfaceElevated,
                    child:
                        product.imageUrl != null && product.imageUrl!.isNotEmpty
                        ? Image.network(
                            product.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.image_not_supported_outlined,
                              color: AppColors.textMuted,
                              size: 40,
                            ),
                          )
                        : const Icon(
                            Icons.shopping_bag_outlined,
                            color: AppColors.textMuted,
                            size: 40,
                          ),
                  ),

                  // Compare button
                  // Clear comparison action.
                  Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: FutureBuilder<bool>(
                      future: _getCompareStatus(product.id),
                      builder: (context, snapshot) {
                        final isCompared = snapshot.data ?? false;
                        final isUpdating = _updatingCompareProducts.contains(
                          product.id,
                        );

                        return Material(
                          color: isCompared
                              ? AppColors.gold
                              : AppColors.surface.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusLarge,
                          ),
                          child: InkWell(
                            onTap: isUpdating
                                ? null
                                : () => _toggleCompare(product, isCompared),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusLarge,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 7,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isUpdating)
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  else
                                    Icon(
                                      isCompared
                                          ? Icons.check_circle_rounded
                                          : Icons.compare_arrows_rounded,
                                      size: 15,
                                      color: isCompared
                                          ? AppColors.background
                                          : AppColors.textPrimary,
                                    ),
                                  const SizedBox(width: 5),
                                  Text(
                                    isUpdating
                                        ? 'Please wait'
                                        : isCompared
                                        ? 'Added'
                                        : 'Compare',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: isCompared
                                          ? AppColors.background
                                          : AppColors.textPrimary,
                                      fontWeight: FontWeight.w800,
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

                  // Wishlist button
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: FutureBuilder<bool>(
                      future: _getWishlistStatus(product.id),
                      builder: (context, snapshot) {
                        final isSaved = snapshot.data ?? false;

                        return Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface.withValues(alpha: 0.92),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: isSaved
                                ? 'Remove from Wishlist'
                                : 'Add to Wishlist',
                            onPressed: () => _toggleWishlist(product, isSaved),
                            icon: Icon(
                              isSaved
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: isSaved
                                  ? Colors.pinkAccent
                                  : AppColors.textPrimary,
                              size: 19,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Discount badge
                  if (product.compareAtPrice != null &&
                      product.compareAtPrice! > product.price)
                    Positioned(
                      bottom: AppSpacing.sm,
                      left: AppSpacing.sm,
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
                        ),
                        child: Text(
                          '${(((product.compareAtPrice! - product.price) / product.compareAtPrice!) * 100).round()}% OFF',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.background,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Category and product-type tags.
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isMatchingComparisonGroup
                        ? AppColors.gold.withValues(alpha: 0.16)
                        : AppColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  ),
                  child: Text(
                    product.category.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.overline.copyWith(
                      color: isMatchingComparisonGroup
                          ? AppColors.gold
                          : AppColors.primaryLight,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (product.productType != null &&
                    product.productType!.trim().isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxWidth: 105),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSmall,
                      ),
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
                if (isMatchingComparisonGroup)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSmall,
                      ),
                    ),
                    child: Text(
                      'MATCHES COMPARISON',
                      style: AppTextStyles.overline.copyWith(
                        color: AppColors.gold,
                        fontSize: 7,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: AppSpacing.sm),

            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xs),

                  Text(
                    product.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  Text(
                    _formatPrice(product.price),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.headingSmall.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  if (product.compareAtPrice != null &&
                      product.compareAtPrice! > product.price) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _formatPrice(product.compareAtPrice!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.sm),

                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: AppColors.gold,
                        size: AppSpacing.iconSmall,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        product.rating.toStringAsFixed(1),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Flexible(
                        child: Text(
                          '${product.reviewCount} reviews',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textMuted,
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

  Widget _buildHorizontalProductSection({
    required String title,
    required String subtitle,
    required List<ProductModel> products,
    IconData icon = Icons.auto_awesome,
    VoidCallback? onSeeAll,
  }) {
    if (products.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              ),
              child: Icon(
                icon,
                color: AppColors.gold,
                size: AppSpacing.iconLarge,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.headingSmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (onSeeAll != null)
              TextButton(
                onPressed: onSeeAll,
                child: Text(
                  'See All',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.primaryLight,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: AppSpacing.xs),

        Text(
          subtitle,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
        ),

        const SizedBox(height: AppSpacing.md),

        SizedBox(
          height: 290,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              return SizedBox(
                width: 175,
                child: _buildProductCard(products[index]),
              );
            },
          ),
        ),

        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  Widget _buildPersonalizedForYou() {
    return FutureBuilder<List<ProductRecommendationModel>>(
      future: _recommendationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator(color: _primary)),
          );
        }

        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        final recommendations = snapshot.data ?? [];

        if (recommendations.isEmpty) {
          return const SizedBox.shrink();
        }

        final products = recommendations
            .map((recommendation) => recommendation.product)
            .toList();

        return _buildHorizontalProductSection(
          title: 'Personalized For You',
          subtitle: 'Discover products selected around your interests.',
          products: products,
          icon: Icons.auto_awesome,
        );
      },
    );
  }

  Widget _buildRecentlyViewed() {
    return FutureBuilder<List<ProductModel>>(
      future: _recentlyViewedProductsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        final products = snapshot.data ?? [];

        if (products.isEmpty) {
          return const SizedBox.shrink();
        }

        return _buildHorizontalProductSection(
          title: 'Recently Viewed',
          subtitle: 'Pick up where you left off.',
          products: products,
          icon: Icons.history_rounded,
        );
      },
    );
  }

  String _getFilterSummary() {
    final activeCriteria = <String>[];

    final query = _searchController.text.trim();

    if (query.isNotEmpty) {
      activeCriteria.add('Search: "$query"');
    }

    if (_selectedCategory != 'All') {
      activeCriteria.add('Category: $_selectedCategory');
    }

    if (_selectedBrand != 'All') {
      activeCriteria.add('Brand: $_selectedBrand');
    }

    if (_selectedProductType != 'All') {
      activeCriteria.add('Type: $_selectedProductType');
    }

    if (_minimumPrice != null && _maximumPrice != null) {
      activeCriteria.add(
        'Price: ${_formatPrice(_minimumPrice!)} - ${_formatPrice(_maximumPrice!)}',
      );
    } else if (_minimumPrice != null) {
      activeCriteria.add('Min: ${_formatPrice(_minimumPrice!)}');
    } else if (_maximumPrice != null) {
      activeCriteria.add('Max: ${_formatPrice(_maximumPrice!)}');
    }

    if (_inStockOnly) {
      activeCriteria.add('In Stock Only');
    }

    if (_onSaleOnly) {
      activeCriteria.add('On Sale Only');
    }

    if (_minimumRating > 0) {
      activeCriteria.add('${_minimumRating.toStringAsFixed(1)}+ Stars');
    }

    if (_sortOption != 'Newest') {
      activeCriteria.add('Sorted by: $_sortOption');
    }

    if (activeCriteria.isEmpty) {
      return 'Showing all available products';
    }

    return activeCriteria.join(' • ');
  }

  Widget _buildResults() {
    final results = _filteredProducts;
    final hasQuery = _searchController.text.trim().isNotEmpty;

    if (results.isEmpty) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: AppSpacing.lg),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xxxl,
        ),
        decoration: AppDecorations.card,
        child: Column(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                color: AppColors.primaryLight,
                size: 38,
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            Text(
              'No products found',
              style: AppTextStyles.headingSmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            Text(
              hasQuery
                  ? 'Try a different search term.'
                  : 'Try changing your filters.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _clearAllFilters,
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: const Text('Clear Search & Filters'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryLight,
                  side: const BorderSide(color: AppColors.borderStrong),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
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
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${results.length} products found',
                style: AppTextStyles.headingSmall.copyWith(
                  color: AppColors.gold,
                ),
              ),
            ),
            if (_hasActiveFilters)
              TextButton(
                onPressed: _clearAllFilters,
                child: Text(
                  'Clear Filters',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primaryLight,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: AppSpacing.xs),

        Text(
          _getFilterSummary(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
        ),

        const SizedBox(height: AppSpacing.lg),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: results.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: 0.64,
          ),
          itemBuilder: (context, index) {
            return _buildProductCard(results[index]);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      floatingActionButton: _comparisonCount > 0
          ? FloatingActionButton.extended(
              onPressed: () {
                context.push(AppRoutes.compare);
              },
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 8,
              icon: const Icon(Icons.compare_arrows_rounded),
              label: Text('Compare Selected ($_comparisonCount)'),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Discover Products',
          style: AppTextStyles.headingMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const SizedBox(
                        height: 32,
                        width: 32,
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Finding products...',
                      style: AppTextStyles.headingSmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Please wait while we prepare your results.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : _errorMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: AppDecorations.card,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.cloud_off_rounded,
                            color: Colors.redAccent,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Something went wrong',
                          style: AppTextStyles.headingSmall.copyWith(
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _errorMessage!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        ElevatedButton.icon(
                          onPressed: _loadProducts,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
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
              )
            : RefreshIndicator(
                color: _primary,
                onRefresh: () => _loadProducts(showLoading: false),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageHorizontal,
                    AppSpacing.lg,
                    AppSpacing.pageHorizontal,
                    100,
                  ),
                  children: [
                    _buildSearchField(),
                    _buildSearchSuggestions(),
                    const SizedBox(height: 20),
                    _buildCategoryFilters(),
                    const SizedBox(height: 12),
                    _buildBrandFilter(),
                    const SizedBox(height: 12),
                    _buildProductTypeFilter(),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showPriceFilters,
                            icon: const Icon(Icons.tune_rounded, size: 18),
                            label: Text(
                              'Price Filter',
                              style: AppTextStyles.labelLarge,
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              backgroundColor: AppColors.surface,
                              side: BorderSide(
                                color: AppColors.primary.withValues(
                                  alpha: 0.45,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMedium,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showSortOptions,
                            icon: const Icon(Icons.sort_rounded, size: 18),
                            label: Text(
                              'Sort By',
                              style: AppTextStyles.labelLarge,
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              backgroundColor: AppColors.surface,
                              side: BorderSide(
                                color: AppColors.primary.withValues(
                                  alpha: 0.45,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 12,
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

                    const SizedBox(height: 12),

                    // In Stock Only
                    Container(
                      decoration: AppDecorations.card,
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: SwitchListTile(
                        value: _inStockOnly,
                        onChanged: (value) {
                          setState(() {
                            _inStockOnly = value;
                          });
                        },
                        secondary: const Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.primary,
                        ),
                        title: Text(
                          'In Stock Only',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Show products currently available',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                        activeTrackColor: AppColors.primary.withValues(
                          alpha: 0.5,
                        ),
                        activeThumbColor: AppColors.primary,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                      ),
                    ),

                    // On Sale Only
                    Container(
                      decoration: AppDecorations.card,
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: SwitchListTile(
                        value: _onSaleOnly,
                        onChanged: (value) {
                          setState(() {
                            _onSaleOnly = value;
                          });
                        },
                        secondary: const Icon(
                          Icons.local_offer_outlined,
                          color: AppColors.gold,
                        ),
                        title: Text(
                          'On Sale Only',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Show discounted products only',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                        activeTrackColor: AppColors.primary.withValues(
                          alpha: 0.5,
                        ),
                        activeThumbColor: AppColors.primary,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    if (_hasActiveFilters)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _clearAllFilters,
                          icon: const Icon(
                            Icons.filter_alt_off_rounded,
                            size: 18,
                          ),
                          label: Text(
                            'Clear All Filters',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.gold,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 12),

                    Container(
                      decoration: AppDecorations.card,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusMedium,
                              ),
                            ),
                            child: const Icon(
                              Icons.star_rounded,
                              color: AppColors.gold,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Minimum Rating',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),

                                DropdownButton<double>(
                                  value: _minimumRating,
                                  dropdownColor: AppColors.surface,
                                  underline: const SizedBox.shrink(),
                                  iconEnabledColor: AppColors.gold,
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 0,
                                      child: Text('Any Rating'),
                                    ),
                                    DropdownMenuItem(
                                      value: 3,
                                      child: Text('3+ Stars'),
                                    ),
                                    DropdownMenuItem(
                                      value: 4,
                                      child: Text('4+ Stars'),
                                    ),
                                    DropdownMenuItem(
                                      value: 4.5,
                                      child: Text('4.5+ Stars'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value == null) return;

                                    setState(() {
                                      _minimumRating = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),
                    _buildActiveFilterChips(),

                    const SizedBox(height: 18),

                    _buildRecentSearches(),
                    _buildPopularSearches(),

                    if (_searchController.text.trim().isEmpty &&
                        !_hasActiveFilters) ...[
                      _buildPersonalizedForYou(),
                      _buildRecentlyViewed(),
                    ],

                    if (_searchController.text.trim().isEmpty &&
                        _recentSearches.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 18),
                        child: Text(
                          'Explore our collection',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                    _buildResults(),
                  ],
                ),
              ),
      ),
    );
  }
}
