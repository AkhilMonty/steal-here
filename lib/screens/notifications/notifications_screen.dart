import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/routes/app_routes.dart';
import '../../models/notification_model.dart';
import '../../repositories/notification_repository.dart';
import '../../repositories/order_repository.dart';

import '../../core/themes/app_colors.dart';
import '../../core/themes/app_spacing.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/themes/app_decorations.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationRepository _repository = NotificationRepository();

  static const Color _background = AppColors.background;
  static const Color _surface = AppColors.surface;
  static const Color _primary = AppColors.primary;
  static const Color _muted = AppColors.textMuted;

  List<NotificationModel> _notifications = [];

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isUnreadOnly = false;
  bool _hasMore = true;
  bool _isRefreshing = false;

  int _unreadCount = 0;
  int _currentPage = 0;

  String _selectedCategory = 'all';

  String? _errorMessage;

  RealtimeChannel? _notificationChannel;
  Timer? _realtimeDebounce;

  static const int _pageSize = 20;

  final List<Map<String, dynamic>> _categories = [
    {'value': 'all', 'label': 'All'},
    {'value': 'order', 'label': 'Orders'},
    {'value': 'returns', 'label': 'Returns'},
    {'value': 'delivery', 'label': 'Delivery'},
    {'value': 'price_drop', 'label': 'Price Drops'},
    {'value': 'offer', 'label': 'Offers'},
    {'value': 'cart', 'label': 'Cart'},
    {'value': 'wishlist', 'label': 'Wishlist'},
    {'value': 'review', 'label': 'Reviews'},
    {'value': 'payment', 'label': 'Payments'},
    {'value': 'security', 'label': 'Security'},
    {'value': 'account', 'label': 'Account'},
    {'value': 'budget', 'label': 'Budget'},
    {'value': 'recommendation', 'label': 'Recommendations'},
    {'value': 'announcement', 'label': 'Announcements'},
    {'value': 'general', 'label': 'General'},
  ];

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  void _handleRealtimeChange() {
    if (!mounted) return;

    _realtimeDebounce?.cancel();

    _realtimeDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;

      _loadNotifications(showLoading: false, reset: true);
    });
  }

  Future<void> _initializeNotifications() async {
    try {
      _notificationChannel = _repository.subscribeToNotifications(
        onChanged: _handleRealtimeChange,
      );
    } catch (error) {
      debugPrint('Notification subscription error: $error');
    }

    await _loadNotifications();
  }

  @override
  void dispose() {
    _realtimeDebounce?.cancel();

    final channel = _notificationChannel;

    if (channel != null) {
      _repository.unsubscribeFromNotifications(channel);
    }

    super.dispose();
  }

  Future<void> _loadNotifications({
    bool showLoading = true,
    bool reset = true,
  }) async {
    if (!mounted) return;

    if (_isRefreshing) return;

    _isRefreshing = true;

    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _isRefreshing = false;
      });
    }

    if (reset) {
      _currentPage = 0;
      _hasMore = true;
    }

    try {
      final results = await Future.wait([
        _repository.getNotifications(
          page: reset ? 0 : _currentPage,
          limit: _pageSize,
          category: _selectedCategory,
          unreadOnly: _isUnreadOnly,
        ),
        _repository.getUnreadCount(),
      ]);

      final newNotifications = results[0] as List<NotificationModel>;
      final unreadCount = results[1] as int;

      if (!mounted) return;

      setState(() {
        if (reset) {
          _notifications = newNotifications;
        } else {
          _notifications.addAll(newNotifications);
        }

        _unreadCount = unreadCount;
        _hasMore = newNotifications.length == _pageSize;
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _isRefreshing = false;

        if (showLoading || _notifications.isEmpty) {
          _errorMessage = error.toString();
        } else {
          _errorMessage = null;
        }
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;

    final nextPage = _currentPage + 1;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final newNotifications = await _repository.getNotifications(
        page: nextPage,
        limit: _pageSize,
        category: _selectedCategory,
        unreadOnly: _isUnreadOnly,
      );

      if (!mounted) return;

      setState(() {
        final existingIds = _notifications.map((item) => item.id).toSet();

        _notifications.addAll(
          newNotifications.where(
            (notification) => !existingIds.contains(notification.id),
          ),
        );

        _currentPage = nextPage;
        _hasMore = newNotifications.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoadingMore = false;
      });

      _showMessage('Could not load more notifications. Please try again.');
    }
  }

  Future<void> _refresh() async {
    await _loadNotifications();
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    if (notification.isRead) return;

    try {
      await _repository.markAsRead(notification.id);

      if (!mounted) return;

      setState(() {
        final index = _notifications.indexWhere(
          (item) => item.id == notification.id,
        );

        if (index != -1) {
          _notifications[index] = notification.copyWith(isRead: true);
        }

        if (_unreadCount > 0) {
          _unreadCount--;
        }

        if (_isUnreadOnly) {
          _notifications.removeWhere((item) => item.id == notification.id);
        }
      });
    } catch (error) {
      _showMessage('Could not mark notification as read.');
    }
  }

  Future<void> _markAllAsRead() async {
    if (_unreadCount == 0) return;

    try {
      await _repository.markAllAsRead();

      if (!mounted) return;

      setState(() {
        _unreadCount = 0;

        if (_isUnreadOnly) {
          _notifications.clear();
        } else {
          _notifications = _notifications
              .map((item) => item.copyWith(isRead: true))
              .toList();
        }
      });

      _showMessage('All notifications marked as read.');
    } catch (error) {
      _showMessage('Could not update notifications.');
    }
  }

  Future<void> _deleteNotification(NotificationModel notification) async {
    try {
      await _repository.deleteNotification(notification.id);

      if (!mounted) return;

      setState(() {
        _notifications.removeWhere((item) => item.id == notification.id);

        if (!notification.isRead && _unreadCount > 0) {
          _unreadCount--;
        }
      });

      _showMessage('Notification deleted.');
    } catch (error) {
      debugPrint('DELETE NOTIFICATION ERROR: $error');

      if (!mounted) return;

      _showMessage('Could not delete notification. Restoring the list...');

      await _loadNotifications(showLoading: false);
    }
  }

  Future<void> _clearAllNotifications() async {
    if (_notifications.isEmpty && _unreadCount == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('Clear all notifications?'),
        content: const Text(
          'This will permanently delete all your notifications. '
          'This action cannot be undone.',
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

    if (confirmed != true || !mounted) return;

    try {
      await _repository.clearAllNotifications();

      if (!mounted) return;

      setState(() {
        _notifications.clear();
        _unreadCount = 0;
        _currentPage = 0;
        _hasMore = false;
      });

      _showMessage('All notifications cleared.');
    } catch (error) {
      _showMessage('Could not clear notifications.');
    }
  }

  Future<void> _openNotification(NotificationModel notification) async {
    await _markAsRead(notification);

    if (!mounted) return;

    if (notification.relatedProductId != null) {
      context.push(AppRoutes.productDetails(notification.relatedProductId!));
      return;
    }

    if (notification.relatedOrderId != null) {
      try {
        final order = await OrderRepository().getOrderById(
          notification.relatedOrderId!,
        );

        if (!mounted) return;

        if (order == null) {
          _showMessage('This order could not be found.');
          return;
        }

        context.push(AppRoutes.orderDetails, extra: order);
      } catch (error) {
        debugPrint('OPEN ORDER NOTIFICATION ERROR: $error');

        if (mounted) {
          _showMessage('Could not open this order. Please try again.');
        }
      }

      return;
    }

    switch (notification.category) {
      case 'cart':
        context.push(AppRoutes.cart);
        break;

      case 'wishlist':
      case 'price_drop':
        context.push(AppRoutes.wishlist);
        break;

      case 'order':
      case 'delivery':
      case 'payment':
        context.push(AppRoutes.orders);
        break;

      case 'account':
      case 'security':
        context.push(AppRoutes.accountActivity);
        break;

      case 'recommendation':
        context.push(AppRoutes.home);
        break;

      case 'budget':
        context.push(AppRoutes.budget);
        break;

      default:
        break;
    }
  }

  bool _isDeliveredNotification(NotificationModel notification) {
    return notification.category == 'delivery' &&
        notification.relatedOrderId != null &&
        notification.metadata['event'] == 'order_status_changed' &&
        notification.metadata['new_status'] == 'delivered';
  }

  Future<void> _rateAndReviewOrder(NotificationModel notification) async {
    await _markAsRead(notification);

    if (!mounted) return;

    final orderId = notification.relatedOrderId;

    if (orderId == null) {
      _showMessage('Order information is unavailable.');
      return;
    }

    try {
      final order = await OrderRepository().getOrderById(orderId);

      if (!mounted) return;

      if (order == null) {
        _showMessage('This order could not be found.');
        return;
      }

      if (order.status.toLowerCase() != 'delivered') {
        _showMessage(
          'You can review products after the order has been delivered.',
        );
        return;
      }

      // Collect unique products from the delivered order.
      final uniqueItems = <String, dynamic>{};

      for (final item in order.items) {
        final productId = item.productId;

        if (productId == null || productId.trim().isEmpty) {
          continue;
        }

        uniqueItems.putIfAbsent(productId, () => item);
      }

      if (uniqueItems.isEmpty) {
        _showMessage('No reviewable products were found in this order.');
        return;
      }

      String? selectedProductId;

      // Directly open the review form for a single product.
      if (uniqueItems.length == 1) {
        selectedProductId = uniqueItems.keys.first;
      } else {
        // Let the customer select a product when the order has multiple items.
        selectedProductId = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: _surface,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (sheetContext) {
            final items = uniqueItems.values.toList();

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        height: 4,
                        width: 42,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Rate Your Products',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Choose a product you want to review.',
                      style: TextStyle(color: _muted, fontSize: 13),
                    ),
                    const SizedBox(height: 18),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder: (_, _) =>
                            const Divider(color: Colors.white10, height: 1),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final imageUrl = item.productImage;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 6,
                            ),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child:
                                  imageUrl != null && imageUrl.trim().isNotEmpty
                                  ? Image.network(
                                      imageUrl,
                                      width: 54,
                                      height: 54,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        width: 54,
                                        height: 54,
                                        color: Colors.white10,
                                        child: const Icon(
                                          Icons.shopping_bag_outlined,
                                          color: _muted,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: 54,
                                      height: 54,
                                      color: Colors.white10,
                                      child: const Icon(
                                        Icons.shopping_bag_outlined,
                                        color: _muted,
                                      ),
                                    ),
                            ),
                            title: Text(
                              item.productName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              'Quantity: ${item.quantity}',
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 11,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: _primary,
                              size: 16,
                            ),
                            onTap: () {
                              Navigator.pop(sheetContext, item.productId);
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      }

      if (!mounted || selectedProductId == null) return;

      context.push(
        AppRoutes.productDetails(selectedProductId, openReview: true),
      );
    } catch (error) {
      debugPrint('RATE AND REVIEW ORDER ERROR: $error');

      if (mounted) {
        _showMessage('Could not open the review form. Please try again.');
      }
    }
  }

  void _changeCategory(String category) {
    if (_selectedCategory == category) return;

    setState(() {
      _selectedCategory = category;
    });

    _loadNotifications();
  }

  void _changeUnreadFilter(bool unreadOnly) {
    if (_isUnreadOnly == unreadOnly) return;

    setState(() {
      _isUnreadOnly = unreadOnly;
    });

    _loadNotifications();
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

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'order':
        return Icons.receipt_long_rounded;
      case 'delivery':
        return Icons.local_shipping_rounded;
      case 'price_drop':
        return Icons.trending_down_rounded;
      case 'offer':
        return Icons.local_offer_rounded;
      case 'cart':
        return Icons.shopping_cart_rounded;
      case 'wishlist':
        return Icons.favorite_rounded;
      case 'review':
        return Icons.star_rounded;
      case 'payment':
        return Icons.payment_rounded;
      case 'security':
        return Icons.security_rounded;
      case 'account':
        return Icons.person_rounded;
      case 'budget':
        return Icons.account_balance_wallet_rounded;
      case 'recommendation':
        return Icons.auto_awesome_rounded;
      case 'announcement':
        return Icons.campaign_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'order':
      case 'delivery':
        return Colors.blueAccent;
      case 'price_drop':
      case 'offer':
        return Colors.greenAccent;
      case 'cart':
      case 'wishlist':
        return Colors.pinkAccent;
      case 'review':
        return Colors.amber;
      case 'payment':
        return Colors.tealAccent;
      case 'security':
        return Colors.redAccent;
      case 'account':
        return Colors.cyanAccent;
      case 'budget':
        return Colors.orangeAccent;
      case 'recommendation':
        return _primary;
      case 'announcement':
        return Colors.deepPurpleAccent;
      default:
        return _muted;
    }
  }

  String _formatTime(DateTime dateTime) {
    final localTime = dateTime.toLocal();
    final now = DateTime.now();
    final difference = now.difference(localTime);

    if (difference.isNegative || difference.inSeconds < 60) {
      return 'Just now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }

    if (difference.inDays == 1 && now.day != localTime.day) {
      return 'Yesterday, ${_formatClock(localTime)}';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }

    return '${localTime.day.toString().padLeft(2, '0')}/'
        '${localTime.month.toString().padLeft(2, '0')}/'
        '${localTime.year} at ${_formatClock(localTime)}';
  }

  String _formatClock(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Text(
          'Notifications',
          style: AppTextStyles.headingSmall.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_unreadCount > 0)
            IconButton(
              tooltip: 'Mark all as read',
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all_rounded),
            ),
          if (_notifications.isNotEmpty || _unreadCount > 0)
            IconButton(
              tooltip: 'Clear all',
              onPressed: _clearAllNotifications,
              icon: const Icon(
                Icons.delete_sweep_outlined,
                color: Colors.redAccent,
              ),
            ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: Column(
        children: [
          _buildSummary(),
          _buildReadFilters(),
          _buildCategoryFilters(),
          const SizedBox(height: AppSpacing.sm),
          Expanded(child: _buildNotificationList()),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.sm,
        AppSpacing.pageHorizontal,
        AppSpacing.md,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.premiumCard,
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
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
                  'Stay Updated',
                  style: AppTextStyles.headingSmall.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _unreadCount == 0
                      ? 'You are all caught up!'
                      : 'You have $_unreadCount unread '
                            '${_unreadCount == 1 ? 'notification' : 'notifications'}.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            ),
            child: Text(
              '$_unreadCount',
              style: AppTextStyles.headingMedium.copyWith(
                color: AppColors.gold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterButton(
              label: 'All Notifications',
              selected: !_isUnreadOnly,
              onTap: () => _changeUnreadFilter(false),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _buildFilterButton(
              label: 'Unread ($_unreadCount)',
              selected: _isUnreadOnly,
              onTap: () => _changeUnreadFilter(true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? _primary.withValues(alpha: 0.18) : _surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            border: Border.all(
              color: selected
                  ? _primary.withValues(alpha: 0.8)
                  : Colors.white10,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: selected ? const Color(0xFFC4B5FD) : AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    return SizedBox(
      height: 62,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal,
          AppSpacing.md,
          AppSpacing.pageHorizontal,
          AppSpacing.sm,
        ),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final value = category['value'] as String;
          final selected = _selectedCategory == value;

          return GestureDetector(
            onTap: () => _changeCategory(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? _primary.withValues(alpha: 0.18) : _surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusCircular),
                border: Border.all(
                  color: selected
                      ? _primary.withValues(alpha: 0.8)
                      : Colors.white10,
                ),
              ),
              child: Text(
                category['label'] as String,
                style: AppTextStyles.labelSmall.copyWith(
                  color: selected
                      ? const Color(0xFFC4B5FD)
                      : AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationList() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: _primary),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Loading notifications...',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_notifications.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: _primary,
      backgroundColor: _surface,
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal,
          AppSpacing.sm,
          AppSpacing.pageHorizontal,
          AppSpacing.xxl,
        ),
        itemCount: _notifications.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _notifications.length) {
            return _buildLoadMoreButton();
          }

          return _buildNotificationCard(_notifications[index]);
        },
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    final color = _getCategoryColor(notification.category);

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.redAccent,
          size: 26,
        ),
      ),
      onDismissed: (_) => _deleteNotification(notification),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openNotification(notification),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          child: Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: notification.isRead ? _surface : const Color(0xFF211B32),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
              border: Border.all(
                color: notification.isRead
                    ? Colors.white10
                    : _primary.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusMedium,
                    ),
                  ),
                  child: Icon(
                    _getCategoryIcon(notification.category),
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: notification.isRead
                                    ? FontWeight.w500
                                    : FontWeight.bold,
                              ),
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              height: 8,
                              width: 8,
                              decoration: const BoxDecoration(
                                color: _primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        notification.message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusSmall,
                              ),
                            ),
                            child: Text(
                              notification.formattedCategory,
                              style: AppTextStyles.labelSmall.copyWith(
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            _formatTime(notification.createdAt),
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      if (_isDeliveredNotification(notification)) ...[
                        const SizedBox(height: AppSpacing.md),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: () => _rateAndReviewOrder(notification),
                            icon: const Icon(
                              Icons.rate_review_outlined,
                              size: 16,
                            ),
                            label: const Text('Rate & Review'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFC4B5FD),
                              side: BorderSide(
                                color: _primary.withValues(alpha: 0.6),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMedium,
                                ),
                              ),
                              textStyle: AppTextStyles.labelMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  color: _surface,
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: _muted,
                    size: 20,
                  ),
                  onSelected: (value) {
                    if (value == 'read') {
                      _markAsRead(notification);
                    } else if (value == 'delete') {
                      _deleteNotification(notification);
                    }
                  },
                  itemBuilder: (context) => [
                    if (!notification.isRead)
                      const PopupMenuItem(
                        value: 'read',
                        child: Text('Mark as read'),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: TextButton(
          onPressed: _isLoadingMore ? null : _loadMore,
          child: _isLoadingMore
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _primary,
                  ),
                )
              : const Text(
                  'Load More',
                  style: TextStyle(color: Color(0xFFC4B5FD)),
                ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 96,
              width: 96,
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusXXLarge),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: AppColors.gold,
                size: 48,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              _isUnreadOnly
                  ? 'No Unread Notifications'
                  : 'No Notifications Yet',
              textAlign: TextAlign.center,
              style: AppTextStyles.headingSmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Important updates about your shopping activity '
              'will appear here.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
                height: 1.5,
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
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 76,
              width: 76,
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 42,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Could not load notifications',
              textAlign: TextAlign.center,
              style: AppTextStyles.headingSmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.md,
                ),
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
}
