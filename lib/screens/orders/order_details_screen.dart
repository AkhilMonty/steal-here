import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/order_model.dart';
import '../../models/order_item_model.dart';
import '../../core/routes/app_routes.dart';
import '../../repositories/order_repository.dart';

import '../../core/themes/app_colors.dart';
import '../../core/themes/app_spacing.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/themes/app_decorations.dart';

class OrderDetailsScreen extends StatefulWidget {
  final OrderModel order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  static const Color _background = AppColors.background;
  static const Color _surface = AppColors.surface;
  static const Color _primary = AppColors.primary;
  static const Color _gold = AppColors.gold;
  static const Color _muted = AppColors.textMuted;

  final OrderRepository _orderRepository = OrderRepository();

  late OrderModel _order;

  Map<String, dynamic>? _cancellationRequest;
  List<Map<String, dynamic>> _returnRequests = [];
  Map<String, List<Map<String, dynamic>>> _returnStatusHistory = {};

  bool _isLoadingRequests = true;
  bool _isSubmittingRequest = false;

  OrderModel get order => _order;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _loadRequestHistory();
  }

  Future<void> _loadRequestHistory() async {
    try {
      final cancellationRequest = await _orderRepository.getCancellationRequest(
        order.id,
      );

      final returnRequests = await _orderRepository.getReturnRequests(order.id);

      final historyResults = await Future.wait(
        returnRequests.map((request) {
          return _orderRepository.getReturnStatusHistory(
            request['id'].toString(),
          );
        }),
      );

      final Map<String, List<Map<String, dynamic>>> historyMap = {};

      for (int i = 0; i < returnRequests.length; i++) {
        final requestId = returnRequests[i]['id'].toString();

        historyMap[requestId] = historyResults[i];
      }

      if (!mounted) return;

      setState(() {
        _cancellationRequest = cancellationRequest;
        _returnRequests = returnRequests;
        _returnStatusHistory = historyMap;
        _isLoadingRequests = false;
      });
    } catch (error) {
      debugPrint('ORDER REQUEST HISTORY ERROR: $error');

      if (mounted) {
        setState(() {
          _isLoadingRequests = false;
        });
      }
    }
  }

  Future<void> _refreshOrder() async {
    try {
      final updatedOrder = await _orderRepository.getOrderById(order.id);

      if (!mounted) return;

      if (updatedOrder != null) {
        setState(() {
          _order = updatedOrder;
        });
      }

      await _loadRequestHistory();
    } catch (error) {
      debugPrint('ORDER REFRESH ERROR: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to refresh order details.')),
      );
    }
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

  String _formatDate(DateTime date) {
    final local = date.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
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

  int _statusStep(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return 1;
      case 'processing':
        return 2;
      case 'shipped':
        return 3;
      case 'delivered':
        return 4;
      default:
        return 0;
    }
  }

  String _trackingDescription(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Your order has been placed and is awaiting confirmation.';
      case 'confirmed':
        return 'Your order has been confirmed and is awaiting processing.';
      case 'processing':
        return 'Your order is being prepared for shipment.';
      case 'shipped':
        return 'Your order has been dispatched and is on its way.';
      case 'delivered':
        return 'Your order has been successfully delivered. Enjoy your purchase!';
      case 'cancelled':
        return 'This order was cancelled and will not proceed to delivery.';
      default:
        return 'Your order status is being updated.';
    }
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.orders);
            }
          },
        ),
        title: const Text(
          'Order Details',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            tooltip: 'Home',
            icon: const Icon(Icons.home_outlined),
            onPressed: () => context.go(AppRoutes.home),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal,
          AppSpacing.md,
          AppSpacing.pageHorizontal,
          AppSpacing.xxxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderHeader(),
            const SizedBox(height: AppSpacing.lg),
            _buildTrackingSection(),
            const SizedBox(height: AppSpacing.lg),
            if (_returnRequests.isNotEmpty) ...[
              _buildReturnTrackingSection(),
              const SizedBox(height: 20),
            ],
            _buildProductsSection(),
            const SizedBox(height: AppSpacing.lg),
            _buildShippingSection(),
            const SizedBox(height: AppSpacing.lg),
            _buildPaymentSection(),
            const SizedBox(height: AppSpacing.lg),
            _buildPriceSection(),
            const SizedBox(height: AppSpacing.lg),
            _buildOrderActionsSection(),
            const SizedBox(height: AppSpacing.lg),
            _buildRequestHistorySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderHeader() {
    final color = _statusColor(order.status);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.premiumCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ORDER NUMBER',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textMuted,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            order.orderNumber,
            style: AppTextStyles.headingSmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Placed on ${_formatDate(order.createdAt)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(
                    AppSpacing.radiusCircular,
                  ),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Text(
                  _formatStatus(order.status),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            ),
            child: Icon(icon, color: _gold, size: AppSpacing.iconMedium),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              title,
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

  Widget _buildTrackingSection() {
    final status = order.status.toLowerCase();
    final isCancelled = status == 'cancelled';
    final currentStep = _statusStep(status);

    const steps = [
      'Order Placed',
      'Confirmed',
      'Processing',
      'Shipped',
      'Delivered',
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Order Tracking', Icons.local_shipping_outlined),
          if (isCancelled)
            const Text(
              'This order has been cancelled.',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            ...List.generate(steps.length, (index) {
              final completed = index <= currentStep;
              final isCurrent = index == currentStep;
              final isLast = index == steps.length - 1;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Icon(
                        isCurrent
                            ? Icons.radio_button_checked
                            : completed
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: isCurrent
                            ? _gold
                            : completed
                            ? _primary
                            : _muted,
                        size: isCurrent ? 26 : 23,
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 34,
                          color: completed ? _primary : const Color(0xFF383847),
                        ),
                    ],
                  ),
                  const SizedBox(width: 13),
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[index],
                          style: TextStyle(
                            color: completed ? Colors.white : _muted,
                            fontSize: 13,
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'CURRENT STATUS',
                              style: TextStyle(
                                color: _primary,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            }),
          const SizedBox(height: 8),
          if (!isCancelled) ...[
            const SizedBox(height: 12),
            Text(
              _trackingDescription(status),
              style: const TextStyle(color: _muted, fontSize: 12, height: 1.5),
            ),
          ],
          const Text(
            'Tracking updates depend on the order status recorded by the store.',
            style: TextStyle(color: _muted, fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Purchased Products', Icons.shopping_bag_outlined),
          ...order.items.map(_buildProductItem),
        ],
      ),
    );
  }

  Widget _buildProductItem(OrderItemModel item) {
    final variantDetails = item.variantAttributes.entries
        .where((entry) => entry.value.toString().trim().isNotEmpty)
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

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            child: SizedBox(
              width: 76,
              height: 76,
              child: item.productImage != null && item.productImage!.isNotEmpty
                  ? Image.network(
                      item.productImage!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _imagePlaceholder(),
                    )
                  : _imagePlaceholder(),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                if (variantDetails.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSmall,
                      ),
                      border: Border.all(
                        color: _primary.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Text(
                      variantDetails,
                      style: const TextStyle(
                        color: _gold,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 7),
                Text(
                  '${_formatPrice(item.unitPrice)} × ${item.quantity}',
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              _formatPrice(item.lineTotal),
              style: const TextStyle(
                color: _gold,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
      ),
      child: const Icon(
        Icons.image_outlined,
        color: AppColors.textMuted,
        size: 30,
      ),
    );
  }

  Widget _buildShippingSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Delivery Address', Icons.location_on_outlined),
          Text(
            order.recipientName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            order.phone,
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 7),
          Text(
            [
                  order.addressLine,
                  order.city,
                  order.state,
                  order.postalCode,
                  order.country,
                ]
                .where((value) => value != null && value.trim().isNotEmpty)
                .join(', '),
            style: const TextStyle(color: _muted, fontSize: 12, height: 1.6),
          ),
          if (order.customerNote != null &&
              order.customerNote!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Delivery Note',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              order.customerNote!,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Payment Information', Icons.payment_outlined),
          _buildInfoRow('Payment Method', _formatStatus(order.paymentMethod)),
          const SizedBox(height: 12),
          _buildInfoRow(
            'Payment Status',
            _formatStatus(order.paymentStatus),
            valueColor: _statusColor(order.paymentStatus),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Price Summary', Icons.receipt_long_outlined),
          _buildInfoRow('Subtotal', _formatPrice(order.subtotal)),
          const SizedBox(height: 12),
          _buildInfoRow('Shipping Fee', _formatPrice(order.shippingFee)),
          const SizedBox(height: 12),
          _buildInfoRow(
            'Discount',
            '- ${_formatPrice(order.discount)}',
            valueColor: Colors.greenAccent,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 15),
            child: Divider(color: Color(0xFF383847), height: 1),
          ),
          _buildInfoRow(
            'Total Amount',
            _formatPrice(order.totalAmount),
            valueColor: _gold,
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    Color? valueColor,
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: isTotal ? AppColors.textPrimary : AppColors.textMuted,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style:
                (isTotal ? AppTextStyles.headingSmall : AppTextStyles.bodySmall)
                    .copyWith(
                      color: valueColor ?? AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
          ),
        ),
      ],
    );
  }

  bool get _canCancelOrder {
    return [
      'pending',
      'confirmed',
      'processing',
    ].contains(order.status.toLowerCase());
  }

  Map<String, dynamic>? get _activeReturnRequest {
    for (final request in _returnRequests) {
      final status = request['status']?.toString().toLowerCase();

      if ([
        'pending',
        'approved',
        'pickup_scheduled',
        'picked_up',
        'in_transit',
        'received',
        'quality_check',
        'refund_processing',
        'completed',
      ].contains(status)) {
        return request;
      }
    }

    return null;
  }

  Widget _buildOrderActionsSection() {
    final returnRequest = _activeReturnRequest;
    final returnStatus = returnRequest?['status']?.toString().toLowerCase();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Order Actions', Icons.settings_outlined),

          if (_canCancelOrder) ...[
            const Text(
              'Changed your mind? You can cancel this order before it is shipped.',
              style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isSubmittingRequest ? null : _cancelOrder,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel Order'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: BorderSide(
                    color: Colors.redAccent.withValues(alpha: 0.7),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusMedium,
                    ),
                  ),
                ),
              ),
            ),
          ] else if (order.status.toLowerCase() == 'delivered') ...[
            if (_isLoadingRequests)
              const Row(
                children: [
                  SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      color: _primary,
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Checking return request...',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              )
            else if (returnStatus == 'pending')
              _buildReturnStatusMessage(
                icon: Icons.hourglass_top_rounded,
                color: Colors.orangeAccent,
                title: 'Return Request Pending',
                message:
                    'Your return request is awaiting review. '
                    'You cannot submit another request while this one is pending.',
              )
            else if (returnStatus == 'approved')
              _buildReturnStatusMessage(
                icon: Icons.check_circle_outline_rounded,
                color: Colors.greenAccent,
                title: 'Return Request Approved',
                message:
                    'Your return request has been approved. '
                    'You can follow its progress in Return History.',
              )
            else if (returnStatus == 'completed')
              _buildReturnStatusMessage(
                icon: Icons.task_alt_rounded,
                color: Colors.greenAccent,
                title: 'Return Completed',
                message:
                    'Your return has been completed. '
                    'A new return request cannot be submitted for this order.',
              )
            else ...[
              Text(
                returnStatus == 'rejected'
                    ? 'Your previous return request was rejected. You can submit a new request if needed.'
                    : 'Your order has been delivered. If something is wrong, you can submit a return request.',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmittingRequest ? null : _requestReturn,
                  icon: const Icon(Icons.assignment_return_outlined),
                  label: const Text('Request a Return'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
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
          ] else
            Text(
              order.status.toLowerCase() == 'cancelled'
                  ? 'This order has been cancelled. No further actions are available.'
                  : 'No cancellation or return actions are currently available for this order.',
              style: const TextStyle(color: _muted, fontSize: 12, height: 1.5),
            ),
        ],
      ),
    );
  }

  Widget _buildReturnStatusMessage({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.10), _surface],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 23),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
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

  Future<Map<String, String>?> _showRequestDialog({
    required String title,
    required String description,
    required List<String> reasons,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    String selectedReason = reasons.first;
    final noteController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
                side: BorderSide(color: _primary.withValues(alpha: 0.25)),
              ),
              title: Text(
                title,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                  height: 1.6,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      description,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Select a reason',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedReason,
                      dropdownColor: _surface,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF20202D),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items: reasons.map((reason) {
                        return DropdownMenuItem(
                          value: reason,
                          child: Text(reason),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedReason = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Additional notes (optional)',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: noteController,
                      maxLines: 3,
                      maxLength: 300,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Enter additional details...',
                        hintStyle: const TextStyle(color: _muted),
                        filled: true,
                        fillColor: const Color(0xFF20202D),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Go Back', style: TextStyle(color: _muted)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, {
                      'reason': selectedReason,
                      'note': noteController.text.trim(),
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: confirmColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(confirmLabel),
                ),
              ],
            );
          },
        );
      },
    );

    noteController.dispose();

    return result;
  }

  Future<void> _cancelOrder() async {
    final confirmed = await _showRequestDialog(
      title: 'Cancel Order',
      description:
          'Please tell us why you want to cancel this order. '
          'Cancellation takes effect immediately after confirmation.',
      reasons: const [
        'Changed my mind',
        'Ordered by mistake',
        'Found a better price',
        'Delivery takes too long',
        'Ordered the wrong product',
        'Other',
      ],
      confirmLabel: 'Confirm Cancellation',
      confirmColor: Colors.redAccent,
    );

    if (confirmed == null || !mounted) return;

    setState(() {
      _isSubmittingRequest = true;
    });

    try {
      await _orderRepository.requestOrderCancellation(
        orderId: order.id,
        reason: confirmed['reason']!,
        customerNote: confirmed['note']!.isEmpty ? null : confirmed['note'],
      );

      if (!mounted) return;

      await _refreshOrder();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your order has been cancelled successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      debugPrint('ORDER CANCELLATION ERROR: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to cancel order: ${error.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingRequest = false;
        });
      }
    }
  }

  Future<void> _requestReturn() async {
    final confirmed = await _showRequestDialog(
      title: 'Request a Return',
      description:
          'Tell us why you want to return this delivered order. '
          'Your request will be submitted for review.',
      reasons: const [
        'Product is damaged',
        'Received the wrong product',
        'Product is defective',
        'Product does not match description',
        'Missing items',
        'Other',
      ],
      confirmLabel: 'Submit Return Request',
      confirmColor: _primary,
    );

    if (confirmed == null || !mounted) return;

    setState(() {
      _isSubmittingRequest = true;
    });

    try {
      await _orderRepository.requestOrderReturn(
        orderId: order.id,
        reason: confirmed['reason']!,
        customerNote: confirmed['note']!.isEmpty ? null : confirmed['note'],
      );

      if (!mounted) return;

      await _loadRequestHistory();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your return request has been submitted.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      debugPrint('RETURN REQUEST ERROR: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to submit return request: ${error.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingRequest = false;
        });
      }
    }
  }

  Widget _buildReturnTrackingSection() {
    if (_returnRequests.isEmpty) {
      return const SizedBox.shrink();
    }

    // Requests are sorted newest first.
    final request = _returnRequests.first;

    final requestId = request['id'].toString();

    final status = request['status']?.toString().toLowerCase() ?? 'pending';

    final adminNote = request['admin_note']?.toString().trim();

    final history = _returnStatusHistory[requestId] ?? [];

    const statusDetails = {
      'pending': {
        'title': 'Return Requested',
        'description': 'Your return request has been submitted.',
        'icon': Icons.assignment_outlined,
      },
      'approved': {
        'title': 'Return Approved',
        'description': 'Your return request has been approved.',
        'icon': Icons.verified_outlined,
      },
      'pickup_scheduled': {
        'title': 'Pickup Scheduled',
        'description': 'A pickup has been scheduled for your product.',
        'icon': Icons.calendar_month_outlined,
      },
      'picked_up': {
        'title': 'Product Picked Up',
        'description': 'Your product has been collected.',
        'icon': Icons.inventory_2_outlined,
      },
      'in_transit': {
        'title': 'Product In Transit',
        'description': 'Your returned product is on its way.',
        'icon': Icons.local_shipping_outlined,
      },
      'received': {
        'title': 'Product Received',
        'description': 'Your returned product has been received.',
        'icon': Icons.inventory_outlined,
      },
      'quality_check': {
        'title': 'Quality Inspection',
        'description': 'Your returned product is being inspected.',
        'icon': Icons.fact_check_outlined,
      },
      'refund_processing': {
        'title': 'Refund Processing',
        'description': 'Your refund is being processed.',
        'icon': Icons.account_balance_wallet_outlined,
      },
      'completed': {
        'title': 'Refund Completed',
        'description': 'Your return and refund process is complete.',
        'icon': Icons.check_circle_outline,
      },
      'rejected': {
        'title': 'Return Rejected',
        'description': 'Your return request was rejected.',
        'icon': Icons.cancel_outlined,
      },
    };

    final isRejected = status == 'rejected';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (isRejected ? Colors.redAccent : _gold).withValues(alpha: 0.08),
            _surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        border: Border.all(
          color: (isRejected ? Colors.redAccent : _gold).withValues(
            alpha: 0.25,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.assignment_turned_in_outlined,
                color: isRejected ? Colors.redAccent : _gold,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Return Tracking',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh tracking',
                onPressed: _loadRequestHistory,
                icon: const Icon(Icons.refresh_rounded, color: _gold, size: 20),
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (history.isEmpty)
            const Text(
              'Return tracking history is not available yet.',
              style: TextStyle(color: _muted, fontSize: 12),
            )
          else
            ...List.generate(history.length, (index) {
              final event = history[index];

              final eventStatus =
                  event['status']?.toString().toLowerCase() ?? '';

              final details = statusDetails[eventStatus];

              final title =
                  details?['title'] as String? ?? _formatStatus(eventStatus);

              final description = details?['description'] as String? ?? '';

              final icon =
                  details?['icon'] as IconData? ?? Icons.circle_outlined;

              final createdAt = event['created_at']?.toString();

              final date = createdAt == null
                  ? null
                  : DateTime.tryParse(createdAt);

              final note = event['note']?.toString().trim();

              final isLast = index == history.length - 1;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Icon(
                        icon,
                        color: eventStatus == 'rejected'
                            ? Colors.redAccent
                            : _gold,
                        size: 24,
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 55,
                          color: const Color(0xFF444455),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: eventStatus == 'rejected'
                                  ? Colors.redAccent
                                  : Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              description,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 11,
                                height: 1.5,
                              ),
                            ),
                          ],
                          if (date != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              '${_formatDate(date)} '
                              '${date.toLocal().hour.toString().padLeft(2, '0')}:'
                              '${date.toLocal().minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                color: _gold,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (note != null && note.isNotEmpty) ...[
                            const SizedBox(height: 7),
                            Text(
                              note,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),

          if (isRejected && adminNote != null && adminNote.isNotEmpty) ...[
            const Divider(color: Color(0xFF383847)),
            const SizedBox(height: 10),
            const Text(
              'Store Response',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              adminNote,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRequestHistorySection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            'Cancellation & Return History',
            Icons.history_rounded,
          ),
          if (_isLoadingRequests)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: _primary),
              ),
            )
          else if (_cancellationRequest == null && _returnRequests.isEmpty)
            const Text(
              'No cancellation or return requests for this order.',
              style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
            )
          else ...[
            if (_cancellationRequest != null)
              _buildRequestHistoryCard(
                title: 'Cancellation Request',
                reason: _cancellationRequest!['reason']?.toString() ?? '',
                note: _cancellationRequest!['customer_note']?.toString(),
                status:
                    _cancellationRequest!['status']?.toString() ?? 'completed',
                createdAt: _cancellationRequest!['created_at']?.toString(),
                color: Colors.redAccent,
              ),
            ..._returnRequests.map((request) {
              return _buildRequestHistoryCard(
                title: 'Return Request',
                reason: request['reason']?.toString() ?? '',
                note: request['customer_note']?.toString(),
                status: request['status']?.toString() ?? 'pending',
                createdAt: request['created_at']?.toString(),
                color: _primary,
                adminNote: request['admin_note']?.toString(),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildRequestHistoryCard({
    required String title,
    required String reason,
    required String status,
    required String? createdAt,
    required Color color,
    String? note,
    String? adminNote,
  }) {
    DateTime? date;

    if (createdAt != null) {
      date = DateTime.tryParse(createdAt);
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.07), _surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _formatStatus(status),
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildHistoryDetail('Reason', reason),
          if (note != null && note.trim().isNotEmpty) ...[
            const SizedBox(height: 7),
            _buildHistoryDetail('Customer Note', note),
          ],
          if (adminNote != null && adminNote.trim().isNotEmpty) ...[
            const SizedBox(height: 7),
            _buildHistoryDetail('Store Response', adminNote),
          ],
          if (date != null) ...[
            const SizedBox(height: 7),
            _buildHistoryDetail('Submitted', _formatDate(date)),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryDetail(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: _muted, fontSize: 11, height: 1.5),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}
