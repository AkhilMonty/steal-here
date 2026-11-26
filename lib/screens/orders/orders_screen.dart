import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routes/app_routes.dart';
import '../../models/order_model.dart';
import '../../repositories/order_repository.dart';
import '../../models/order_item_model.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_spacing.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/themes/app_decorations.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  static const Color _background = AppColors.background;
  static const Color _surface = AppColors.surface;
  static const Color _primary = AppColors.primary;
  static const Color _gold = AppColors.gold;
  static const Color _muted = AppColors.textMuted;

  final OrderRepository _orderRepository = OrderRepository();
  final TextEditingController _searchController = TextEditingController();

  late Future<List<OrderModel>> _ordersFuture;

  String _selectedStatus = 'all';
  String _searchQuery = '';
  String _selectedSort = 'newest';

  List<Map<String, dynamic>> _returnRequests = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadOrders() {
    _ordersFuture = _fetchOrdersAndReturns();
  }

  Future<List<OrderModel>> _fetchOrdersAndReturns() async {
    final orders = await _orderRepository.getOrders();

    if (orders.isEmpty) {
      _returnRequests = [];
      return orders;
    }

    final orderIds = orders.map((order) => order.id).toList();

    _returnRequests = await _orderRepository.getReturnRequestsForOrders(
      orderIds,
    );

    return orders;
  }

  Future<void> _refreshOrders() async {
    setState(_loadOrders);
    await _ordersFuture;
  }

  String _formatPrice(double price) {
    final value = price.round().toString();
    final formatted = StringBuffer();

    for (int i = 0; i < value.length; i++) {
      if (i > 0 && (value.length - i) % 3 == 0) {
        formatted.write('.');
      }

      formatted.write(value[i]);
    }

    return 'Rp $formatted';
  }

  String _formatDate(DateTime date) {
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

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return Colors.greenAccent;

      case 'shipped':
        return Colors.lightBlueAccent;

      case 'processing':
        return Colors.orangeAccent;

      case 'confirmed':
        return Colors.cyanAccent;

      case 'cancelled':
        return Colors.redAccent;

      default:
        return _gold;
    }
  }

  String _formatStatus(String status) {
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  bool _hasReturnRequest(OrderModel order) {
    return _returnRequests.any((request) => request['order_id'] == order.id);
  }

  Map<String, dynamic>? _getLatestReturnRequest(OrderModel order) {
    for (final request in _returnRequests) {
      if (request['order_id'] == order.id) {
        return request;
      }
    }

    return null;
  }

  String _getReturnStatus(OrderModel order) {
    final request = _getLatestReturnRequest(order);

    if (request == null) return 'Return Requested';

    return _formatStatus(request['status']?.toString() ?? 'pending');
  }

  String _formatVariantAttributes(Map<String, dynamic> attributes) {
    return attributes.entries
        .map((entry) {
          final label = entry.key
              .replaceAll('_', ' ')
              .replaceAll('-', ' ')
              .split(' ')
              .map(
                (word) => word.isEmpty
                    ? word
                    : '${word[0].toUpperCase()}${word.substring(1)}',
              )
              .join(' ');

          return '$label: ${entry.value}';
        })
        .join(' • ');
  }

  List<OrderModel> _getFilteredOrders(List<OrderModel> orders) {
    return orders.where((order) {
      final matchesStatus = _selectedStatus == 'all'
          ? true
          : _selectedStatus == 'returns'
          ? _hasReturnRequest(order)
          : order.status.toLowerCase() == _selectedStatus;

      final matchesSearch = order.orderNumber.toLowerCase().contains(
        _searchQuery.trim().toLowerCase(),
      );

      return matchesStatus && matchesSearch;
    }).toList();
  }

  List<OrderModel> _getSortedOrders(List<OrderModel> orders) {
    final sortedOrders = [..._getFilteredOrders(orders)];

    sortedOrders.sort((a, b) {
      final comparison = a.createdAt.compareTo(b.createdAt);

      return _selectedSort == 'newest' ? -comparison : comparison;
    });

    return sortedOrders;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go(AppRoutes.home);
        }
      },
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _background,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,

          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            tooltip: 'Go Back',
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(AppRoutes.home);
              }
            },
          ),

          title: const Text(
            'My Orders',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 21),
          ),

          actions: [
            IconButton(
              icon: const Icon(Icons.home_outlined),
              tooltip: 'Go Home',
              onPressed: () {
                context.go(AppRoutes.home);
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: FutureBuilder<List<OrderModel>>(
          future: _ordersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Loading your orders...',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.hasError) {
              debugPrint('ORDERS LOADING ERROR: ${snapshot.error}');
              return _buildErrorState(snapshot.error.toString());
            }

            final orders = snapshot.data ?? [];

            if (orders.isEmpty) {
              return _buildEmptyState();
            }

            return RefreshIndicator(
              color: _primary,
              backgroundColor: _surface,
              onRefresh: _refreshOrders,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
                children: [
                  _buildHeader(orders.length),
                  const SizedBox(height: 18),

                  _buildSearchField(),
                  const SizedBox(height: 18),

                  _buildStatusFilters(orders),
                  const SizedBox(height: 16),

                  _buildStatusSummary(orders),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Your Orders',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      _buildSortDropdown(),
                    ],
                  ),

                  const SizedBox(height: 16),

                  if (_getSortedOrders(orders).isEmpty)
                    _buildNoFilteredOrdersState()
                  else
                    ..._getSortedOrders(orders).map(_buildOrderCard),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Search by order number...',
        hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.textMuted,
        ),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  _searchController.clear();

                  setState(() {
                    _searchQuery = '';
                  });
                },
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textMuted,
                ),
              ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
    );
  }

  Widget _buildSortDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: AppDecorations.card,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSort,
          dropdownColor: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textMuted,
          ),
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
          items: const [
            DropdownMenuItem(value: 'newest', child: Text('Newest First')),
            DropdownMenuItem(value: 'oldest', child: Text('Oldest First')),
          ],
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              _selectedSort = value;
            });
          },
        ),
      ),
    );
  }

  Widget _buildStatusSummary(List<OrderModel> orders) {
    final statuses = [
      ('Pending', 'pending'),
      ('Processing', 'processing'),
      ('Shipped', 'shipped'),
      ('Delivered', 'delivered'),
      ('Cancelled', 'cancelled'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: statuses.map((entry) {
          final count = orders
              .where((order) => order.status.toLowerCase() == entry.$2)
              .length;

          final color = _statusColor(entry.$2);

          return Container(
            margin: const EdgeInsets.only(right: AppSpacing.sm),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.10), AppColors.surface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
              border: Border.all(color: color.withValues(alpha: 0.20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.$1,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '$count',
                  style: AppTextStyles.headingMedium.copyWith(color: color),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusFilters(List<OrderModel> orders) {
    const statuses = [
      'all',
      'pending',
      'confirmed',
      'processing',
      'shipped',
      'delivered',
      'cancelled',
      'returns',
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: statuses.length,
        separatorBuilder: (_, _) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final status = statuses[index];
          final isSelected = _selectedStatus == status;

          final count = status == 'all'
              ? orders.length
              : status == 'returns'
              ? orders.where(_hasReturnRequest).length
              : orders
                    .where((order) => order.status.toLowerCase() == status)
                    .length;

          final label = status == 'all'
              ? 'All Orders'
              : status == 'returns'
              ? 'Returns'
              : _formatStatus(status);

          return ChoiceChip(
            label: Text('$label ($count)'),
            selected: isSelected,
            onSelected: (_) {
              setState(() {
                _selectedStatus = status;
              });
            },
            backgroundColor: _surface,
            selectedColor: _primary,
            side: BorderSide(
              color: isSelected ? _primary : const Color(0xFF303040),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : _muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 9),
          );
        },
      ),
    );
  }

  Widget _buildNoFilteredOrdersState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 65, horizontal: 20),
      child: Column(
        children: [
          const Icon(Icons.inventory_2_outlined, color: _muted, size: 55),
          const SizedBox(height: 16),
          Text(
            'No ${_formatStatus(_selectedStatus)} Orders',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Orders with this status will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedStatus = 'all';
              });
            },
            child: const Text(
              'View All Orders',
              style: TextStyle(color: _gold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int orderCount) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.premiumCard,
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.28),
                  AppColors.primary.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              color: AppColors.gold,
              size: 27,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Shopping History',
                  style: AppTextStyles.headingSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$orderCount ${orderCount == 1 ? 'order' : 'orders'} placed',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.receipt_long_outlined,
            color: AppColors.gold,
            size: 28,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final statusColor = _statusColor(order.status);

    return InkWell(
      borderRadius: BorderRadius.circular(17),
      onTap: () async {
        await context.push(AppRoutes.orderDetails, extra: order);

        if (!mounted) return;

        await _refreshOrders();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: AppDecorations.premiumCard,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_outlined, color: _gold, size: 19),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    order.orderNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _formatStatus(order.status),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  color: _muted,
                  size: 14,
                ),
                const SizedBox(width: 7),
                Text(
                  _formatDate(order.createdAt),
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
                const SizedBox(width: 16),
                const Icon(
                  Icons.shopping_basket_outlined,
                  color: _muted,
                  size: 15,
                ),
                const SizedBox(width: 7),
                Text(
                  '${order.totalItems} items',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Divider(color: Color(0xFF303040), height: 1),
            ),

            ...order.items.take(3).map(_buildOrderProduct),

            if (order.items.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '+ ${order.items.length - 3} more products',
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Divider(color: Color(0xFF303040), height: 1),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount',
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
                Text(
                  _formatPrice(order.totalAmount),
                  style: const TextStyle(
                    color: _gold,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            const SizedBox(height: 14),

            // Payment information
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF20202D),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payment_outlined, color: _muted, size: 17),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment Method',
                          style: TextStyle(color: _muted, fontSize: 10),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _formatStatus(order.paymentMethod),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(order.paymentStatus)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _formatStatus(order.paymentStatus),
                      style: TextStyle(
                        color: _statusColor(order.paymentStatus),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Delivery information
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF20202D),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.local_shipping_outlined,
                        color: _gold,
                        size: 17,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Delivery Information',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        color: _muted,
                        size: 15,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          order.recipientName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: _muted,
                        size: 15,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          [
                                order.addressLine,
                                order.city,
                                order.state,
                                order.postalCode,
                                order.country,
                              ]
                              .where(
                                (value) =>
                                    value != null && value.trim().isNotEmpty,
                              )
                              .join(', '),
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_hasReturnRequest(order)) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _gold.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.assignment_return_outlined,
                            color: _gold,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Return Status:',
                            style: TextStyle(color: _muted, fontSize: 11),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getReturnStatus(order),
                            style: const TextStyle(
                              color: _gold,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (order.status.toLowerCase() == 'delivered') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await context.push(AppRoutes.orderDetails, extra: order);

                    if (!mounted) return;

                    await _refreshOrders();
                  },
                  icon: const Icon(Icons.assignment_return_outlined),
                  label: const Text('Return Product'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _gold,
                    side: const BorderSide(color: _gold),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrderProduct(OrderItemModel item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            child: SizedBox(
              width: 64,
              height: 64,
              child: item.productImage != null && item.productImage!.isNotEmpty
                  ? Image.network(
                      item.productImage!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _imagePlaceholder(),
                    )
                  : _imagePlaceholder(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                if (item.variantAttributes.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    _formatVariantAttributes(item.variantAttributes),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _gold,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],

                const SizedBox(height: 5),
                Text(
                  'Qty: ${item.quantity}',
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatPrice(item.lineTotal),
            style: const TextStyle(
              color: _gold,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFF252535),
      child: const Icon(Icons.image_outlined, color: _muted, size: 25),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_outlined, color: _muted, size: 75),
            const SizedBox(height: 20),
            const Text(
              'No Orders Yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your shopping journey starts here. '
              'Explore our products and find something you love.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, height: 1.6),
            ),
            const SizedBox(height: 25),
            ElevatedButton.icon(
              onPressed: () => context.go(AppRoutes.home),
              icon: const Icon(Icons.shopping_bag_outlined),
              label: const Text('Start Shopping'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: Colors.redAccent,
              size: 65,
            ),
            const SizedBox(height: 18),
            const Text(
              'Unable to Load Orders',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Something went wrong while loading your order history.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, height: 1.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(_loadOrders);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
              ),
            ),
            if (error.isNotEmpty) const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
