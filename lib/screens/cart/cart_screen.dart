import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routes/app_routes.dart';
import '../../models/cart_item_model.dart';
import '../../repositories/cart_repository.dart';
import '../../models/previous_purchase_model.dart';
import '../../repositories/purchase_history_repository.dart';
import '../../repositories/budget_repository.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_spacing.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/themes/app_decorations.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key, this.initialSelectedItemIds});

  final List<String>? initialSelectedItemIds;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartRepository _cartRepository = CartRepository();

  late Future<List<CartItemModel>> _cartFuture;

  List<CartItemModel>? _cachedCartItems;

  final Set<String> _updatingItems = {};
  final Set<String> _selectedItemIds = {};
  final Set<String> _knownCartItemIds = {};

  final PurchaseHistoryRepository _purchaseHistoryRepository =
      PurchaseHistoryRepository();
  final BudgetRepository _budgetRepository = BudgetRepository();

  bool _isCheckingPurchaseHistory = false;

  bool _isRemoving = false;

  bool _hasInitializedSelection = false;

  bool get _isCheckoutEditMode => widget.initialSelectedItemIds != null;

  static const Color _background = AppColors.background;
  static const Color _surface = AppColors.surface;
  static const Color _primary = AppColors.primary;
  static const Color _gold = AppColors.gold;

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  void _loadCart() {
    _cartFuture = _cartRepository.getCartItems();
  }

  void _syncSelection(List<CartItemModel> items) {
    final currentIds = items.map((item) => item.id).toSet();

    if (!_hasInitializedSelection) {
      if (_isCheckoutEditMode) {
        _selectedItemIds
          ..clear()
          ..addAll(
            widget.initialSelectedItemIds!.where(
              (id) => currentIds.contains(id),
            ),
          );
      } else {
        _selectedItemIds.addAll(currentIds);
      }

      _knownCartItemIds
        ..clear()
        ..addAll(currentIds);

      _hasInitializedSelection = true;
      return;
    }

    // Remove selection for items no longer in the cart.
    _selectedItemIds.removeWhere((id) => !currentIds.contains(id));

    // Automatically select newly added items.
    for (final id in currentIds) {
      if (!_knownCartItemIds.contains(id)) {
        _selectedItemIds.add(id);
      }
    }

    _knownCartItemIds
      ..clear()
      ..addAll(currentIds);
  }

  Future<void> _refreshCart() async {
    final future = _cartRepository.getCartItems();

    setState(() {
      _cartFuture = future;
    });

    try {
      final items = await future;

      if (!mounted) return;

      setState(() {
        _cachedCartItems = items;
        _syncSelection(items);
      });
    } catch (_) {
      rethrow;
    }
  }

  String _formatPrice(double price) {
    final formatted = price
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => '.');

    return 'Rp $formatted';
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _surface,
        ),
      );
  }

  Future<void> _openProductDetails(
    CartItemModel item, {
    bool editVariant = false,
  }) async {
    if (_updatingItems.contains(item.id)) return;

    await context.push<void>(
      AppRoutes.productDetails(item.productId),
      extra: editVariant
          ? <String, dynamic>{
              'isCartEditMode': true,
              'cartItemId': item.id,
              'variantId': item.variantId,
              'quantity': item.quantity,
            }
          : null,
    );

    if (!mounted) return;

    // Refresh only after returning from variant editing.
    if (editVariant) {
      await _refreshCart();
    }
  }

  void _toggleItemSelection(CartItemModel item, bool selected) {
    setState(() {
      if (selected) {
        _selectedItemIds.add(item.id);
      } else {
        _selectedItemIds.remove(item.id);
      }
    });
  }

  void _toggleSelectAll(List<CartItemModel> items, bool selected) {
    setState(() {
      if (selected) {
        _selectedItemIds.addAll(items.map((item) => item.id));
      } else {
        _selectedItemIds.clear();
      }
    });
  }

  List<CartItemModel> _getSelectedItems(List<CartItemModel> items) {
    return items.where((item) => _selectedItemIds.contains(item.id)).toList();
  }

  double _calculateSubtotal(List<CartItemModel> items) {
    return items.fold(0, (total, item) => total + item.totalPrice);
  }

  int _calculateTotalItems(List<CartItemModel> items) {
    return items.fold(0, (total, item) => total + item.quantity);
  }

  Future<void> _updateQuantity(CartItemModel item, int newQuantity) async {
    if (_updatingItems.contains(item.id)) return;

    if (newQuantity < 1) {
      await _removeItem(item);
      return;
    }

    setState(() {
      _updatingItems.add(item.id);
    });

    try {
      await _cartRepository.updateQuantity(item.id, newQuantity);

      if (!mounted) return;

      await _refreshCart();
    } catch (error) {
      if (!mounted) return;

      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _updatingItems.remove(item.id);
        });
      }
    }
  }

  Future<void> _removeItem(CartItemModel item) async {
    if (_isRemoving || _updatingItems.contains(item.id)) {
      return;
    }

    setState(() {
      _updatingItems.add(item.id);
      _isRemoving = true;
    });

    try {
      await _cartRepository.removeFromCart(item.id);

      if (!mounted) return;

      _showMessage('${item.product.name} removed from cart.');

      await _refreshCart();
    } catch (error) {
      if (!mounted) return;

      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _updatingItems.remove(item.id);
          _isRemoving = false;
        });
      }
    }
  }

  Future<void> _proceedToCheckout(List<CartItemModel> selectedItems) async {
    if (selectedItems.isEmpty) {
      _showMessage('Please select at least one item to continue.');
      return;
    }

    if (_isCheckingPurchaseHistory) return;

    setState(() {
      _isCheckingPurchaseHistory = true;
    });

    try {
      // STEP 1: Check previous purchases.
      Map<String, PreviousPurchaseModel> previousPurchases = {};

      try {
        previousPurchases = await _purchaseHistoryRepository
            .getPreviousPurchases(selectedItems);
      } catch (error) {
        debugPrint('PURCHASE HISTORY CHECK ERROR: $error');

        if (mounted) {
          _showMessage(
            'Could not check purchase history. You can still continue.',
          );
        }
      }

      if (!mounted) return;

      // STEP 2: Show Smart Reorder Warning.
      if (previousPurchases.isNotEmpty) {
        final shouldContinue = await _showSmartReorderWarning(
          selectedItems,
          previousPurchases,
        );

        if (!mounted || shouldContinue != true) return;
      }

      // STEP 3: Check the monthly budget.
      try {
        final budget = await _budgetRepository.getCurrentMonthBudget();

        if (!mounted) return;

        if (budget != null) {
          final currentSpending = await _budgetRepository.getMonthlySpending();

          if (!mounted) return;

          // Only count the selected cart items.
          final selectedSubtotal = _calculateSubtotal(selectedItems);

          final projectedSpending = currentSpending + selectedSubtotal;

          final budgetPercentage =
              (projectedSpending / budget.budgetAmount) * 100;

          // Show a warning only when projected spending reaches 80%.
          if (budgetPercentage >= 80) {
            final shouldContinue = await _showBudgetWarning(
              budgetAmount: budget.budgetAmount,
              currentSpending: currentSpending,
              selectedSubtotal: selectedSubtotal,
              projectedSpending: projectedSpending,
              percentage: budgetPercentage,
            );

            if (!mounted || shouldContinue != true) return;
          }
        }
      } catch (error) {
        // Budget checking must never prevent checkout.
        debugPrint('BUDGET CHECK ERROR: $error');

        if (mounted) {
          _showMessage(
            'Could not check your monthly budget. You can still continue.',
          );
        }
      }

      // STEP 4: Continue to checkout.
      if (!mounted) return;

      final selectedIds = selectedItems.map((item) => item.id).toList();

      context.push(AppRoutes.checkout, extra: selectedIds);
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingPurchaseHistory = false;
        });
      }
    }
  }

  Future<bool?> _showSmartReorderWarning(
    List<CartItemModel> selectedItems,
    Map<String, PreviousPurchaseModel> previousPurchases,
  ) {
    String formatDate(DateTime date) {
      final localDate = date.toLocal();

      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];

      return '${localDate.day} ${months[localDate.month - 1]} '
          '${localDate.year}';
    }

    final matchingItems = selectedItems
        .where((item) => previousPurchases.containsKey(item.id))
        .toList();

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.shopping_bag_outlined, color: _gold),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Smart Reorder Alert',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'You have purchased some of these products before.',
                    style: TextStyle(
                      color: Color(0xFFB9B9C8),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  ...matchingItems.map((item) {
                    final purchase = previousPurchases[item.id]!;
                    final variantName = item.variantDisplayName;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _gold.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.product.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          if (variantName != null &&
                              variantName.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              'Variant: $variantName',
                              style: const TextStyle(
                                color: Color(0xFFA78BFA),
                                fontSize: 11,
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),

                          _buildPurchaseDetail(
                            'Last purchased',
                            formatDate(purchase.purchasedAt),
                          ),

                          _buildPurchaseDetail(
                            'Previous quantity',
                            '${purchase.quantity}',
                          ),

                          _buildPurchaseDetail(
                            'Previous unit price',
                            _formatPrice(purchase.unitPrice),
                          ),

                          _buildPurchaseDetail(
                            'Order number',
                            purchase.orderNumber,
                          ),

                          _buildPurchaseDetail(
                            'Order status',
                            purchase.orderStatus.toUpperCase(),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 4),

                  const Text(
                    'Do you still want to purchase these products again?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF555566)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Review My Cart'),
              ),
            ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: _surface,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Continue to Checkout',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _showBudgetWarning({
    required double budgetAmount,
    required double currentSpending,
    required double selectedSubtotal,
    required double projectedSpending,
    required double percentage,
  }) {
    final bool isExceeded = projectedSpending > budgetAmount;
    final bool isReached = projectedSpending >= budgetAmount;

    final Color alertColor = isExceeded
        ? Colors.redAccent
        : isReached
        ? Colors.orangeAccent
        : _gold;

    final IconData alertIcon = isExceeded
        ? Icons.warning_amber_rounded
        : isReached
        ? Icons.error_outline
        : Icons.account_balance_wallet_outlined;

    final String title = isExceeded
        ? 'Budget Exceeded!'
        : isReached
        ? 'Budget Limit Reached!'
        : 'Budget Warning!';

    final String description = isExceeded
        ? 'This purchase will take your monthly shopping spending beyond your budget.'
        : isReached
        ? 'This purchase will bring your monthly shopping spending to your budget limit.'
        : 'This purchase will take your monthly shopping spending to at least 80% of your budget.';

    final double remaining = budgetAmount - projectedSpending;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: alertColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(alertIcon, color: alertColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFFB9B9C8),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 20),

                _buildPurchaseDetail(
                  'Monthly budget',
                  _formatPrice(budgetAmount),
                ),

                _buildPurchaseDetail(
                  'Already spent',
                  _formatPrice(currentSpending),
                ),

                _buildPurchaseDetail(
                  'Selected cart total',
                  _formatPrice(selectedSubtotal),
                ),

                const Divider(color: Color(0xFF383846), height: 24),

                _buildPurchaseDetail(
                  'Projected spending',
                  _formatPrice(projectedSpending),
                ),

                _buildPurchaseDetail(
                  'Budget usage',
                  '${percentage.toStringAsFixed(1)}%',
                ),

                const SizedBox(height: 12),

                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: (percentage / 100).clamp(0.0, 1.0),
                    minHeight: 9,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(alertColor),
                  ),
                ),

                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: alertColor.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: alertColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isExceeded
                            ? Icons.trending_up
                            : Icons.account_balance_wallet_outlined,
                        color: alertColor,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isExceeded
                              ? 'You will exceed your budget by ${_formatPrice(remaining.abs())}.'
                              : isReached
                              ? 'You will reach your monthly budget limit.'
                              : 'You will have ${_formatPrice(remaining)} remaining.',
                          style: TextStyle(
                            color: alertColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                const Text(
                  'Do you still want to continue with this purchase?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF555566)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Review My Cart'),
              ),
            ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: alertColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Continue Anyway',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPurchaseDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF9A9AAF), fontSize: 11),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _returnToCheckout(List<CartItemModel> selectedItems) {
    if (selectedItems.isEmpty) {
      _showMessage('Please select at least one item for checkout.');
      return;
    }

    final selectedIds = selectedItems.map((item) => item.id).toList();

    context.pop<List<String>>(selectedIds);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            if (_isCheckoutEditMode) {
              final items = _cachedCartItems ?? [];
              _returnToCheckout(_getSelectedItems(items));
            } else if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
        title: const Text(
          'My Cart',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<CartItemModel>>(
        future: _cartFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            if (_cachedCartItems != null) {
              if (_cachedCartItems!.isEmpty) {
                return _buildEmptyCart();
              }

              return _buildCartContent(_cachedCartItems!);
            }

            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: _primary),
                  SizedBox(height: 18),
                  Text(
                    'Loading your cart...',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return _buildErrorState();
          }

          final items = snapshot.data ?? [];

          _cachedCartItems = items;
          _syncSelection(items);

          if (items.isEmpty) {
            return _buildEmptyCart();
          }

          return _buildCartContent(items);
        },
      ),
    );
  }

  Widget _buildCartContent(List<CartItemModel> items) {
    final selectedItems = _getSelectedItems(items);
    final subtotal = _calculateSubtotal(selectedItems);
    final totalItems = _calculateTotalItems(items);

    final allSelected =
        items.isNotEmpty && selectedItems.length == items.length;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: _primary,
            backgroundColor: _surface,
            onRefresh: _refreshCart,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _buildCartHeader(totalItems),

                const SizedBox(height: 15),

                _buildSelectAllSection(items, allSelected),

                const SizedBox(height: 15),

                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _buildCartItem(item),
                  ),
                ),

                const SizedBox(height: 12),

                _buildShoppingTip(),
              ],
            ),
          ),
        ),

        _buildCheckoutSection(selectedItems, subtotal),
      ],
    );
  }

  Widget _buildCartHeader(int totalItems) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.premiumCard,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
            ),
            child: const Icon(
              Icons.shopping_bag_rounded,
              color: _gold,
              size: 26,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your Shopping Bag', style: AppTextStyles.headingSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$totalItems ${totalItems == 1 ? 'item' : 'items'} in your cart',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: Colors.greenAccent,
              size: 21,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectAllSection(List<CartItemModel> items, bool allSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: AppDecorations.card,
      child: Row(
        children: [
          Checkbox(
            value: allSelected,
            tristate: false,
            activeColor: _primary,
            checkColor: Colors.white,
            side: const BorderSide(color: Colors.white54),
            onChanged: (value) {
              _toggleSelectAll(items, value ?? false);
            },
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Select All Items',
              style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppSpacing.radiusCircular),
            ),
            child: Text(
              '${_getSelectedItems(items).length}/${items.length} selected',
              style: AppTextStyles.labelSmall.copyWith(
                color: _gold,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(CartItemModel item) {
    final product = item.product;
    final isUpdating = _updatingItems.contains(item.id);
    final isSelected = _selectedItemIds.contains(item.id);

    final imageUrl = item.displayImageUrl;
    final variantName = item.variantDisplayName;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_surface, _surface.withValues(alpha: 0.88)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        border: Border.all(
          color: isSelected
              ? _primary.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.07),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: isSelected,
            activeColor: _primary,
            checkColor: Colors.white,
            side: const BorderSide(color: Colors.white54),
            onChanged: (value) {
              _toggleItemSelection(item, value ?? false);
            },
          ),

          const SizedBox(width: 3),

          InkWell(
            onTap: isUpdating ? null : () => _openProductDetails(item),
            borderRadius: BorderRadius.circular(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 92,
                height: 116,
                color: Colors.white.withValues(alpha: 0.04),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.white38,
                            size: 32,
                          );
                        },
                      )
                    : const Icon(
                        Icons.shopping_bag_outlined,
                        color: Colors.white38,
                        size: 32,
                      ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: isUpdating
                            ? null
                            : () => _openProductDetails(item),
                        borderRadius: BorderRadius.circular(5),
                        child: Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: isUpdating ? null : () => _removeItem(item),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 30,
                        minHeight: 30,
                      ),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                Text(
                  product.category,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
                ),

                if (variantName != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    variantName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFA78BFA),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                const SizedBox(height: 5),

                TextButton.icon(
                  onPressed: isUpdating
                      ? null
                      : () => _openProductDetails(item, editVariant: true),
                  style: TextButton.styleFrom(
                    foregroundColor: _primary,
                    disabledForegroundColor: Colors.white24,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    alignment: Alignment.centerLeft,
                  ),
                  icon: const Icon(Icons.tune, size: 15),
                  label: const Text(
                    'Change Variant',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  _formatPrice(item.effectivePrice),
                  style: const TextStyle(
                    color: _gold,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 9),

                Row(
                  children: [
                    _buildQuantityButton(
                      icon: Icons.remove,
                      onPressed: isUpdating
                          ? null
                          : () => _updateQuantity(item, item.quantity - 1),
                    ),

                    SizedBox(
                      width: 35,
                      child: Center(
                        child: isUpdating
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _primary,
                                ),
                              )
                            : Text(
                                '${item.quantity}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                      ),
                    ),

                    _buildQuantityButton(
                      icon: Icons.add,
                      onPressed: isUpdating
                          ? null
                          : () => _updateQuantity(item, item.quantity + 1),
                    ),

                    const Spacer(),

                    Text(
                      _formatPrice(item.totalPrice),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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

  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 29,
        height: 29,
        decoration: BoxDecoration(
          color: _primary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _primary.withValues(alpha: 0.3)),
        ),
        child: Icon(
          icon,
          color: onPressed == null ? Colors.white24 : _primary,
          size: 16,
        ),
      ),
    );
  }

  Widget _buildShoppingTip() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _primary.withValues(alpha: 0.15),
            _primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        border: Border.all(color: _primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            ),
            child: const Icon(Icons.lightbulb_rounded, color: _gold, size: 23),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Shopping Tip',
                  style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Review your selected items before purchasing to avoid unnecessary spending.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutSection(
    List<CartItemModel> selectedItems,
    double subtotal,
  ) {
    final selectedQuantity = _calculateTotalItems(selectedItems);
    final hasSelection = selectedItems.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(
          top: BorderSide(color: _primary.withValues(alpha: 0.20)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Selected Items',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  '$selectedQuantity ${selectedQuantity == 1 ? 'item' : 'items'}',
                  style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtotal',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  _formatPrice(subtotal),
                  style: AppTextStyles.headingMedium.copyWith(color: _gold),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.sm),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Shipping and taxes calculated at checkout.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: hasSelection && !_isCheckingPurchaseHistory
                    ? () {
                        if (_isCheckoutEditMode) {
                          _returnToCheckout(selectedItems);
                        } else {
                          _proceedToCheckout(selectedItems);
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  disabledBackgroundColor: Colors.grey.shade800,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
                  ),
                ),
                child: _isCheckingPurchaseHistory && !_isCheckoutEditMode
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Checking Smart Shopping Alerts...',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isCheckoutEditMode
                                ? 'Return to Checkout ($selectedQuantity items)'
                                : 'Checkout ($selectedQuantity items)',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            _isCheckoutEditMode
                                ? Icons.arrow_back
                                : Icons.arrow_forward,
                            size: 19,
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _primary.withValues(alpha: 0.22),
                    _primary.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: _primary.withValues(alpha: 0.22)),
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                color: _primary,
                size: 58,
              ),
            ),
            const SizedBox(height: 25),
            const Text(
              'Your Cart is Empty',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Looks like you haven\'t added anything to your cart yet. Discover something you love!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  context.go(AppRoutes.home);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Continue Shopping',
                  style: TextStyle(fontWeight: FontWeight.bold),
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
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 55),
            const SizedBox(height: 18),
            const Text(
              'Unable to Load Cart',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Something went wrong while loading your shopping cart.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: _refreshCart,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
