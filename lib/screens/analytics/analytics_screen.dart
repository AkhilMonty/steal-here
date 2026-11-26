import 'package:flutter/material.dart';

import '../../models/order_model.dart';
import '../../repositories/order_repository.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_spacing.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/themes/app_decorations.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  static const Color _background = AppColors.background;
  static const Color _surface = AppColors.surface;
  static const Color _primary = AppColors.primary;
  static const Color _gold = AppColors.gold;
  static const Color _muted = AppColors.textMuted;

  late Future<List<OrderModel>> _ordersFuture;
  Set<String> _completedReturnedOrderIds = {};

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  void _loadOrders() {
    _ordersFuture = _loadAnalyticsOrders();
  }

  Future<List<OrderModel>> _loadAnalyticsOrders() async {
    final repository = OrderRepository();

    // Fetch all orders.
    final orders = await repository.getOrders();

    // Find completed returns for these orders.
    final orderIds = orders.map((order) => order.id).toList();

    _completedReturnedOrderIds = await repository.getCompletedReturnedOrderIds(
      orderIds,
    );

    return orders;
  }

  Future<void> _refresh() async {
    setState(_loadOrders);
    await _ordersFuture;
  }

  String _formatPrice(double amount) {
    final value = amount.round().toString();
    final buffer = StringBuffer();

    for (int i = 0; i < value.length; i++) {
      if (i > 0 && (value.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(value[i]);
    }

    return 'Rp ${buffer.toString()}';
  }

  bool _isEligible(OrderModel order) {
    return order.paymentStatus.toLowerCase() == 'paid' &&
        order.status.toLowerCase() != 'cancelled' &&
        !_completedReturnedOrderIds.contains(order.id);
  }

  List<OrderModel> _eligibleOrders(List<OrderModel> orders) {
    return orders.where(_isEligible).toList();
  }

  double _monthlySpending(List<OrderModel> orders, DateTime month) {
    return orders
        .where(
          (order) =>
              _isEligible(order) &&
              order.createdAt.year == month.year &&
              order.createdAt.month == month.month,
        )
        .fold<double>(0, (total, order) => total + order.totalAmount);
  }

  double _totalSpending(List<OrderModel> orders) {
    return orders
        .where(_isEligible)
        .fold<double>(0, (total, order) => total + order.totalAmount);
  }

  Map<String, int> _getTopProducts(List<OrderModel> orders) {
    final products = <String, int>{};

    for (final order in orders.where(_isEligible)) {
      for (final item in order.items) {
        products.update(
          item.productName,
          (quantity) => quantity + item.quantity,
          ifAbsent: () => item.quantity,
        );
      }
    }

    final sorted = products.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Map.fromEntries(sorted.take(5));
  }

  Map<String, double> _getCategorySpending(List<OrderModel> orders) {
    final categories = <String, double>{};

    for (final order in orders.where(_isEligible)) {
      for (final item in order.items) {
        final category = item.productCategory?.trim();

        final categoryName = (category == null || category.isEmpty)
            ? 'Uncategorized'
            : category;

        categories.update(
          categoryName,
          (amount) => amount + item.lineTotal,
          ifAbsent: () => item.lineTotal,
        );
      }
    }

    final sorted = categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Map.fromEntries(sorted);
  }

  Widget _buildCategorySpending(List<OrderModel> orders) {
    final categories = _getCategorySpending(orders);

    final totalCategorySpending = categories.values.fold<double>(
      0,
      (total, amount) => total + amount,
    );

    return _buildSectionCard(
      title: 'Category Spending Breakdown',
      subtitle: 'See how your product spending is distributed',
      child: categories.isEmpty || totalCategorySpending <= 0
          ? _buildSmallEmptyMessage('No category spending data available.')
          : Column(
              children: categories.entries.map((entry) {
                final percentage = entry.value / totalCategorySpending;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            _formatPrice(entry.value),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: percentage.clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: Colors.white.withValues(alpha: 0.06),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            _primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${(percentage * 100).toStringAsFixed(1)}% of product spending',
                        style: TextStyle(color: _muted, fontSize: 11),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Map<String, int> _getOrderStatuses(List<OrderModel> orders) {
    final statuses = <String, int>{
      'pending': 0,
      'confirmed': 0,
      'processing': 0,
      'shipped': 0,
      'delivered': 0,
      'cancelled': 0,
    };

    for (final order in orders) {
      final status = order.status.toLowerCase();

      if (statuses.containsKey(status)) {
        statuses[status] = statuses[status]! + 1;
      }
    }

    return statuses;
  }

  Map<String, int> _getPaymentStatuses(List<OrderModel> orders) {
    final statuses = <String, int>{
      'paid': 0,
      'pending': 0,
      'failed': 0,
      'refunded': 0,
    };

    for (final order in orders) {
      final status = order.paymentStatus.toLowerCase();

      if (statuses.containsKey(status)) {
        statuses[status] = statuses[status]! + 1;
      }
    }

    return statuses;
  }

  String _monthName(int month) {
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

    return months[month - 1];
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
          'Purchase Insights',
          style: AppTextStyles.headingSmall.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh analytics',
            onPressed: _refresh,
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: FutureBuilder<List<OrderModel>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _primary),
            );
          }

          if (snapshot.hasError) {
            return _buildErrorState();
          }

          final allOrders = snapshot.data ?? [];
          final orders = _eligibleOrders(allOrders);

          if (allOrders.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            color: _primary,
            backgroundColor: _surface,
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                AppSpacing.lg,
                AppSpacing.pageHorizontal,
                AppSpacing.xxxl,
              ),
              children: [
                _buildHeader(),
                const SizedBox(height: AppSpacing.xl),
                _buildOverview(orders, allOrders),

                if (orders.isEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _buildNoEligiblePurchasesMessage(),
                ] else ...[
                  const SizedBox(height: AppSpacing.xl),
                  _buildMonthlyTrend(orders),
                  const SizedBox(height: AppSpacing.xl),
                  _buildTopProducts(orders),
                  const SizedBox(height: AppSpacing.xl),
                  _buildCategorySpending(orders),
                ],

                const SizedBox(height: AppSpacing.xl),
                _buildOrderStatuses(allOrders),
                const SizedBox(height: AppSpacing.xl),
                _buildPaymentStatuses(allOrders),
                const SizedBox(height: AppSpacing.xl),
                _buildShoppingInsight(orders),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
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
            child: const Icon(Icons.insights_rounded, color: _gold, size: 27),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shop smarter. Spend better.',
                  style: AppTextStyles.headingSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Understand your shopping habits and make '
                  'better purchasing decisions.',
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

  Widget _buildNoEligiblePurchasesMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.card.copyWith(
        border: Border.all(color: _gold.withValues(alpha: 0.25)),
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
            child: const Icon(
              Icons.info_outline_rounded,
              color: _gold,
              size: 23,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No Eligible Purchases Yet',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Your spending trends and top products will '
                  'appear when you have eligible purchases. '
                  'Your order and payment history is still '
                  'available below.',
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

  Widget _buildOverview(List<OrderModel> orders, List<OrderModel> allOrders) {
    final now = DateTime.now();

    final monthlyOrders = orders
        .where(
          (order) =>
              order.createdAt.year == now.year &&
              order.createdAt.month == now.month,
        )
        .toList();

    final monthlySpent = _totalSpending(monthlyOrders);

    final previousMonth = DateTime(now.year, now.month - 1, 1);
    final previousMonthSpent = _monthlySpending(orders, previousMonth);

    final averageOrder = monthlyOrders.isEmpty
        ? 0.0
        : monthlySpent / monthlyOrders.length;

    final totalOrders = allOrders.length;

    final deliveredOrders = allOrders
        .where((order) => order.status.toLowerCase() == 'delivered')
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'This Month',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 14),
        _buildMainSpendingCard(monthlySpent, previousMonthSpent),
        const SizedBox(height: 12),
        _buildSpendingActivityIndicator(monthlySpent),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.shopping_bag_outlined,
                title: 'Orders',
                value: monthlyOrders.length.toString(),
                color: _primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.receipt_long_outlined,
                title: 'Average Order',
                value: _formatPrice(averageOrder),
                color: _gold,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.receipt_long_rounded,
                title: 'Lifetime Orders',
                value: totalOrders.toString(),
                color: _primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.check_circle_outline_rounded,
                title: 'Delivered Orders',
                value: deliveredOrders.toString(),
                color: Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMainSpendingCard(double amount, double previousMonthSpent) {
    final difference = amount - previousMonthSpent;

    final percentage = previousMonthSpent == 0
        ? 0.0
        : (difference.abs() / previousMonthSpent) * 100;

    final hasPreviousData = previousMonthSpent > 0;

    final isIncrease = difference > 0;
    final isDecrease = difference < 0;

    final comparisonColor = !hasPreviousData
        ? Colors.white70
        : isIncrease
        ? Colors.orangeAccent
        : isDecrease
        ? Colors.greenAccent
        : Colors.white70;

    final comparisonIcon = !hasPreviousData
        ? Icons.insights_rounded
        : isIncrease
        ? Icons.trending_up_rounded
        : isDecrease
        ? Icons.trending_down_rounded
        : Icons.horizontal_rule_rounded;

    final comparisonText = !hasPreviousData
        ? 'No previous month data to compare'
        : difference > 0
        ? '${percentage.toStringAsFixed(1)}% more than last month'
        : difference < 0
        ? '${percentage.toStringAsFixed(1)}% less than last month'
        : 'Same spending as last month';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B5CF6), Color(0xFF5B35B5), Color(0xFF40247F)],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXXLarge),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Total Spending',
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _formatPrice(amount),
              style: AppTextStyles.headingMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your spending this month',
            style: AppTextStyles.bodySmall.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            ),
            child: Row(
              children: [
                Icon(comparisonIcon, color: comparisonColor, size: 19),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    comparisonText,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: comparisonColor,
                      fontWeight: FontWeight.w600,
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

  Widget _buildSpendingActivityIndicator(double amount) {
    String title;
    String description;
    Color color;
    IconData icon;
    double progress;

    if (amount <= 0) {
      title = 'No Spending';
      description = 'No eligible purchases recorded this month.';
      color = _muted;
      icon = Icons.account_balance_wallet_outlined;
      progress = 0;
    } else if (amount < 500000) {
      title = 'Low Activity';
      description = 'Your spending is below Rp 500,000 this month.';
      color = Colors.green;
      icon = Icons.savings_outlined;
      progress = amount / 2000000;
    } else if (amount <= 2000000) {
      title = 'Moderate Activity';
      description = 'Your spending is between Rp 500,000 and Rp 2,000,000.';
      color = _gold;
      icon = Icons.insights_rounded;
      progress = amount / 2000000;
    } else {
      title = 'High Activity';
      description = 'Your spending is above Rp 2,000,000 this month.';
      color = Colors.orange;
      icon = Icons.trending_up_rounded;
      progress = 1;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.card.copyWith(
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 23),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Spending Activity',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              Text(
                title,
                style: AppTextStyles.labelMedium.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusCircular),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            description,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTextStyles.headingSmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyTrend(List<OrderModel> orders) {
    final now = DateTime.now();

    final months = List.generate(
      6,
      (index) => DateTime(now.year, now.month - 5 + index, 1),
    );

    final values = months
        .map((month) => _monthlySpending(orders, month))
        .toList();

    final maximum = values.fold<double>(
      0,
      (previous, value) => value > previous ? value : previous,
    );

    return _buildSectionCard(
      title: 'Monthly Spending Trend',
      subtitle: 'Your spending over the last 6 months',
      child: SizedBox(
        height: 190,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(months.length, (index) {
            final value = values[index];

            final barHeight = maximum == 0
                ? 5.0
                : (value / maximum * 115).clamp(5.0, 115.0);

            final isCurrentMonth =
                months[index].month == now.month &&
                months[index].year == now.year;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        value == 0 ? '-' : _formatCompact(value),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _muted, fontSize: 9),
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      height: barHeight,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isCurrentMonth ? _gold : _primary,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(7),
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      _monthName(months[index].month),
                      style: TextStyle(
                        color: isCurrentMonth ? Colors.white : _muted,
                        fontSize: 11,
                        fontWeight: isCurrentMonth
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  String _formatCompact(double amount) {
    if (amount >= 1000000000) {
      return 'Rp ${(amount / 1000000000).toStringAsFixed(1)}B';
    }

    if (amount >= 1000000) {
      return 'Rp ${(amount / 1000000).toStringAsFixed(1)}M';
    }

    if (amount >= 1000) {
      return 'Rp ${(amount / 1000).toStringAsFixed(0)}K';
    }

    return 'Rp ${amount.round()}';
  }

  Widget _buildTopProducts(List<OrderModel> orders) {
    final products = _getTopProducts(orders);

    return _buildSectionCard(
      title: 'Top Purchased Products',
      subtitle: 'Products you purchase most frequently',
      child: products.isEmpty
          ? _buildSmallEmptyMessage('No product purchases yet.')
          : Column(
              children: products.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Row(
                    children: [
                      Container(
                        height: 38,
                        width: 38,
                        decoration: BoxDecoration(
                          color: _primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(
                          Icons.shopping_bag_outlined,
                          color: _primary,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.key,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${entry.value} bought',
                        style: TextStyle(color: _muted, fontSize: 11),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildOrderStatuses(List<OrderModel> orders) {
    final statuses = _getOrderStatuses(orders);

    const statusColors = {
      'pending': Colors.orange,
      'confirmed': Colors.blue,
      'processing': Colors.purple,
      'shipped': Colors.teal,
      'delivered': Colors.green,
      'cancelled': Colors.red,
    };

    return _buildSectionCard(
      title: 'Order Overview',
      child: Column(
        children: statuses.entries.map((entry) {
          final color = statusColors[entry.key] ?? _muted;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      height: 9,
                      width: 9,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _capitalize(entry.key),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      '${entry.value} orders',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(entry.value / orders.length * 100).toStringAsFixed(0)}%',
                      style: TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: entry.value / orders.length,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
      subtitle: 'Your order status breakdown',
    );
  }

  Widget _buildPaymentStatuses(List<OrderModel> orders) {
    final statuses = _getPaymentStatuses(orders);

    const statusColors = {
      'paid': Colors.green,
      'pending': Colors.orange,
      'failed': Colors.red,
      'refunded': Colors.blue,
    };

    return _buildSectionCard(
      title: 'Payment Overview',
      subtitle: 'Your payment status breakdown',
      child: Column(
        children: statuses.entries.map((entry) {
          final color = statusColors[entry.key] ?? Colors.white;
          final percentage = orders.isEmpty ? 0.0 : entry.value / orders.length;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.key[0].toUpperCase() + entry.key.substring(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '${entry.value} payments',
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${(percentage * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: percentage,
                  minHeight: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;

    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  Widget _buildShoppingInsight(List<OrderModel> orders) {
    final now = DateTime.now();

    final currentMonthSpent = _monthlySpending(orders, now);

    final previousMonth = DateTime(now.year, now.month - 1, 1);

    final previousMonthSpent = _monthlySpending(orders, previousMonth);

    String title;
    String message;
    IconData icon;
    Color color;

    if (orders.isEmpty) {
      title = 'Your shopping journey starts here';
      message =
          'Once you have eligible purchases, your smart '
          'shopping insights will appear here.';
      icon = Icons.lightbulb_outline;
      color = _gold;
    } else if (previousMonthSpent == 0 && currentMonthSpent == 0) {
      title = 'Your spending history is growing';
      message =
          'You have eligible purchases, but no spending '
          'to compare for these two months yet.';
      icon = Icons.insights;
      color = _primary;
    } else if (previousMonthSpent == 0) {
      title = 'A new spending record';
      message =
          'You have started recording purchases this month. '
          'Keep tracking your shopping habits.';
      icon = Icons.trending_up;
      color = _primary;
    } else {
      final difference = currentMonthSpent - previousMonthSpent;

      final percentage = (difference.abs() / previousMonthSpent) * 100;

      if (difference > 0) {
        title = 'Spending increased';
        message =
            'Your spending is ${percentage.toStringAsFixed(1)}% '
            'higher than last month.';
        icon = Icons.trending_up;
        color = Colors.orange;
      } else if (difference < 0) {
        title = 'Great spending progress!';
        message =
            'You spent ${percentage.toStringAsFixed(1)}% '
            'less than last month.';
        icon = Icons.trending_down;
        color = Colors.green;
      } else {
        title = 'Consistent spending';
        message = 'Your spending matches last month.';
        icon = Icons.insights;
        color = _gold;
      }
    }

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 27),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Smart Shopping Insight',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  message,
                  style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.headingSmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }

  Widget _buildSmallEmptyMessage(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Center(
        child: Text(message, style: TextStyle(color: _muted, fontSize: 12)),
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
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.analytics_outlined,
                  color: _primary,
                  size: 52,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'No Shopping Insights Yet',
                textAlign: TextAlign.center,
                style: AppTextStyles.headingSmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Complete your first purchase to unlock '
                'your personal shopping analytics.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textMuted,
                  height: 1.5,
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
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.redAccent,
                  size: 42,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Unable to Load Analytics',
                textAlign: TextAlign.center,
                style: AppTextStyles.headingSmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Something went wrong while loading your '
                'purchase information.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: () {
                  setState(_loadOrders);
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(
                    double.infinity,
                    AppSpacing.buttonHeight,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
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
