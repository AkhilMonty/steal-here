import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routes/app_routes.dart';
import '../../models/order_confirmation_data.dart';
import '../../models/order_confirmation_item.dart';

class OrderConfirmationScreen extends StatelessWidget {
  const OrderConfirmationScreen({super.key, required this.confirmation});

  final OrderConfirmationData confirmation;

  static const Color _background = Color(0xFF0B0B12);
  static const Color _surface = Color(0xFF171722);
  static const Color _primary = Color(0xFF8B5CF6);
  static const Color _gold = Color(0xFFF5C76A);
  static const Color _muted = Color(0xFF9A9AAF);

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

  String get _paymentLabel {
    switch (confirmation.paymentMethod) {
      case 'cash_on_delivery':
        return 'Cash on Delivery';
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'e_wallet':
        return 'E-Wallet';
      default:
        return confirmation.paymentMethod;
    }
  }

  String get _statusLabel {
    final status = confirmation.order.status;

    if (status.isEmpty) return 'Pending';

    return status
        .split('_')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  String get _deliveryAddress {
    final address = confirmation.shippingAddress;
    final parts = [
      address.addressLine,
      address.city,
      address.state ?? '',
      address.postalCode ?? '',
      address.country,
    ];

    return parts.where((part) => part.trim().isNotEmpty).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        context.go(AppRoutes.home);
      },
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: _background,
          elevation: 0,
          title: const Text(
            'Order Confirmation',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSuccessHeader(),
                const SizedBox(height: 24),
                _buildOrderNumberCard(),
                const SizedBox(height: 24),
                _buildSectionTitle(
                  'Order Items',
                  Icons.shopping_bag_outlined,
                ),
                const SizedBox(height: 12),
                _buildItemsCard(),
                const SizedBox(height: 24),
                _buildSectionTitle(
                  'Delivery Address',
                  Icons.location_on_outlined,
                ),
                const SizedBox(height: 12),
                _buildAddressCard(),
                const SizedBox(height: 24),
                _buildSectionTitle(
                  'Payment Information',
                  Icons.payment_outlined,
                ),
                const SizedBox(height: 12),
                _buildPaymentCard(),
                const SizedBox(height: 24),
                _buildSectionTitle(
                  'Price Details',
                  Icons.receipt_long_outlined,
                ),
                const SizedBox(height: 12),
                _buildPriceCard(),
                const SizedBox(height: 30),
                _buildActionButtons(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessHeader() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: Colors.greenAccent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Colors.greenAccent,
              size: 68,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Order Placed Successfully!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 9),
          const Text(
            'Thank you for shopping with Steal Here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 14),
          ),
          if (confirmation.addressSaved) ...[
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bookmark_added_outlined,
                  color: Colors.greenAccent,
                  size: 17,
                ),
                SizedBox(width: 7),
                Text(
                  'Delivery address saved',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderNumberCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primary.withValues(alpha: 0.24), _surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _primary.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          const Text(
            'YOUR ORDER NUMBER',
            style: TextStyle(
              color: _muted,
              fontSize: 11,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            confirmation.order.orderNumber,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _gold,
              fontSize: 21,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              _statusLabel,
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _gold, size: 21),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildItemsCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          ...confirmation.items.map(_buildProductItem),
          const Divider(color: Color(0xFF303040), height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Items', style: TextStyle(color: _muted)),
              Text(
                '${confirmation.items.fold<int>(
                  0,
                      (total, item) => total + item.quantity,
                )} items',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductItem(OrderConfirmationItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 65,
              height: 65,
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? Image.network(
                item.imageUrl!,
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
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.variantName != null &&
                    item.variantName!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.variantName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'Quantity: ${item.quantity}',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatPrice(item.unitPrice),
                  style: const TextStyle(
                    color: _gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatPrice(item.totalPrice),
            style: const TextStyle(
              color: Colors.white,
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
      child: const Icon(Icons.image_outlined, color: _muted, size: 28),
    );
  }

  Widget _buildAddressCard() {
    final address = confirmation.shippingAddress;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline, color: _gold, size: 20),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  address.recipientName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _addressRow(Icons.phone_outlined, address.phone),
          const SizedBox(height: 10),
          _addressRow(Icons.location_on_outlined, _deliveryAddress),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              confirmation.addressLabel,
              style: const TextStyle(
                color: _gold,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addressRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _muted, size: 18),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: _muted, height: 1.5, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _informationRow(
            'Payment Method',
            _paymentLabel,
            Icons.account_balance_wallet_outlined,
          ),
          const Divider(color: Color(0xFF303040), height: 24),
          _informationRow(
            'Payment Status',
            confirmation.order.status == 'pending'
                ? 'Pending'
                : 'Order Confirmed',
            Icons.receipt_outlined,
          ),
        ],
      ),
    );
  }

  Widget _informationRow(String title, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _gold, size: 19),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title, style: const TextStyle(color: _muted)),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceCard() {
    final order = confirmation.order;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _priceRow('Subtotal', order.subtotal),
          const SizedBox(height: 14),
          _priceRow('Shipping Fee', order.shippingFee),
          const SizedBox(height: 14),
          _priceRow(
            'Discount',
            -order.discount,
            valueColor: Colors.greenAccent,
          ),
          const Divider(color: Color(0xFF303040), height: 28),
          _priceRow('Total Payment', order.totalAmount, isTotal: true),
        ],
      ),
    );
  }

  Widget _priceRow(
    String title,
    double amount, {
    Color? valueColor,
    bool isTotal = false,
  }) {
    final prefix = amount < 0 ? '- ' : '';
    final formatted = _formatPrice(amount.abs());

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: isTotal ? Colors.white : _muted,
            fontSize: isTotal ? 15 : 13,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          '$prefix$formatted',
          style: TextStyle(
            color: valueColor ?? (isTotal ? _gold : Colors.white),
            fontSize: isTotal ? 18 : 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: () => context.go(AppRoutes.orders),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text(
              'View My Orders',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton.icon(
            onPressed: () => context.go(AppRoutes.home),
            icon: const Icon(Icons.shopping_bag_outlined),
            label: const Text(
              'Continue Shopping',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _gold,
              side: const BorderSide(color: _gold),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF292938)),
    );
  }
}
