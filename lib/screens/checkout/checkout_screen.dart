import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routes/app_routes.dart';
import '../../models/cart_item_model.dart';
import '../../models/shipping_address_model.dart';
import '../../repositories/cart_repository.dart';
import '../../repositories/checkout_repository.dart';
import '../../repositories/notification_repository.dart';
import '../../models/user_address_model.dart';
import '../../repositories/address_repository.dart';
import '../../models/order_confirmation_data.dart';
import '../../core/services/global_location_service.dart';
import '../../core/themes/app_text_styles.dart';

import 'package:intl_phone_field/intl_phone_field.dart';

import '../../core/themes/app_colors.dart';
import '../../core/themes/app_spacing.dart';
import '../../models/direct_purchase_data.dart';
import '../../models/order_confirmation_item.dart';
import '../../repositories/purchase_history_repository.dart';
import '../../models/previous_purchase_model.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.selectedCartItemIds,
    this.directPurchase,
  });

  final List<String> selectedCartItemIds;
  final DirectPurchaseData? directPurchase;

  bool get isDirectPurchase => directPurchase != null;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const Color _background = AppColors.background;
  static const Color _surface = AppColors.surface;
  static const Color _primary = AppColors.primary;
  static const Color _gold = AppColors.gold;
  static const Color _muted = AppColors.textMuted;

  final _formKey = GlobalKey<FormState>();

  final _cartRepository = CartRepository();
  final _checkoutRepository = CheckoutRepository();
  final _addressRepository = AddressRepository();
  final _notificationRepository = NotificationRepository();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _completePhone;
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _noteController = TextEditingController();
  final _addressLabelController = TextEditingController(text: 'Home');
  final _purchaseHistoryRepository = PurchaseHistoryRepository();

  List<UserAddressModel> _savedAddresses = [];

  List<GlobalLocation> _countries = [];
  List<GlobalLocation> _states = [];

  GlobalLocation? _selectedCountry;
  GlobalLocation? _selectedState;

  bool _isLoadingCountries = false;
  bool _isLoadingStates = false;

  String? _locationError;

  int _stateRequestId = 0;

  String? _selectedAddressId;

  bool _isAddingNewAddress = true;

  List<CartItemModel> _cartItems = [];

  List<String> _selectedCartItemIds = [];

  bool _isLoading = true;
  bool _isPlacingOrder = false;

  bool _isConfirmingOrder = false;
  bool _isConfirmingLeave = false;
  bool _allowCheckoutPop = false;
  bool _hasCheckedRepeatPurchase = false;

  String? _selectionError;

  String _paymentMethod = 'cash_on_delivery';

  static const double _shippingFee = 15000;

  double _discount = 0;

  final TextEditingController _couponController = TextEditingController();

  bool _isApplyingCoupon = false;

  String? _appliedCouponCode;
  String? _couponMessage;

  bool _couponMessageIsSuccess = false;

  List<Map<String, dynamic>> _availableCoupons = [];

  bool _isLoadingCoupons = false;

  String? _couponLoadError;

  int _couponRequestId = 0;

  @override
  void initState() {
    super.initState();

    _selectedCartItemIds = List<String>.from(widget.selectedCartItemIds);

    _loadCart();
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    if (!mounted) return;

    setState(() {
      _isLoadingCountries = true;
      _locationError = null;
    });

    try {
      final countries = await GlobalLocationService.getCountries();

      if (!mounted) return;

      UserAddressModel? selectedAddress;

      // Find the currently selected saved address.
      if (!_isAddingNewAddress && _selectedAddressId != null) {
        for (final address in _savedAddresses) {
          if (address.id == _selectedAddressId) {
            selectedAddress = address;
            break;
          }
        }
      }

      setState(() {
        _countries = countries;
        _isLoadingCountries = false;

        // Restore the selected country for a saved address.
        if (selectedAddress != null) {
          _selectedCountry = _findLocation(_countries, selectedAddress.country);
        }
      });

      // Restore the saved state and city after countries are available.
      if (selectedAddress != null && _selectedCountry != null) {
        await _loadSavedAddressLocations(selectedAddress);
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoadingCountries = false;
        _locationError = 'Unable to load countries. Please try again.';
      });

      debugPrint('CHECKOUT COUNTRY ERROR: $error');
    }
  }

  Future<bool> _loadStates(String country) async {
    final requestId = ++_stateRequestId;

    if (!mounted) return false;

    setState(() {
      _states = [];
      _selectedState = null;
      _isLoadingStates = true;
      _locationError = null;
    });

    try {
      final states = await GlobalLocationService.getStates(country);

      // Ignore outdated requests.
      if (!mounted || requestId != _stateRequestId) {
        return false;
      }

      setState(() {
        _states = states;
        _isLoadingStates = false;
      });

      return true;
    } catch (error) {
      if (!mounted || requestId != _stateRequestId) {
        return false;
      }

      setState(() {
        _isLoadingStates = false;
        _locationError = 'Unable to load states. Please try again.';
      });

      debugPrint('CHECKOUT STATE ERROR: $error');

      return false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _postalCodeController.dispose();
    _noteController.dispose();
    _addressLabelController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _loadCart({bool preserveAddress = false}) async {
    try {
      List<CartItemModel> items = [];

      final directPurchase = widget.directPurchase;

      if (directPurchase != null) {
        // Direct Buy Now checkout.
        final product = directPurchase.product;
        final variant = directPurchase.variant;

        if (!product.isActive) {
          throw StateError('This product is no longer available.');
        }

        if (directPurchase.quantity < 1) {
          throw StateError('Invalid product quantity.');
        }

        if (variant != null) {
          if (!variant.isActive) {
            throw StateError('The selected product variant is unavailable.');
          }

          if (variant.productId != product.id) {
            throw StateError('Invalid product variant.');
          }

          if (variant.stockQuantity < directPurchase.quantity) {
            throw StateError(
              'Not enough stock available for the selected variant.',
            );
          }
        } else if (product.stockQuantity < directPurchase.quantity) {
          throw StateError('Not enough stock available.');
        }
      } else {
        // Existing cart checkout.
        final allItems = await _cartRepository.getCartItems();

        final selectedIds = _selectedCartItemIds.toSet();

        if (selectedIds.isEmpty) {
          throw StateError(
            'No products were selected. Please return to your cart and select products.',
          );
        }

        items = allItems
            .where((item) => selectedIds.contains(item.id))
            .toList();

        if (items.length != selectedIds.length) {
          throw StateError(
            'Some selected products are no longer available in your cart. '
            'Please return to your cart and try again.',
          );
        }
      }

      List<UserAddressModel> addresses = _savedAddresses;

      if (!preserveAddress) {
        try {
          addresses = await _addressRepository.getAddresses();
        } catch (error) {
          debugPrint('Unable to load saved addresses: $error');
        }
      }

      if (!mounted) return;

      UserAddressModel? defaultAddress;

      if (!preserveAddress && addresses.isNotEmpty) {
        defaultAddress = addresses.firstWhere(
          (address) => address.isDefault,
          orElse: () => addresses.first,
        );
      }

      setState(() {
        _cartItems = items;
        _savedAddresses = addresses;

        if (!preserveAddress) {
          if (defaultAddress != null) {
            _selectedAddressId = defaultAddress.id;
            _isAddingNewAddress = false;
          } else {
            _selectedAddressId = null;
            _isAddingNewAddress = true;
          }
        }

        _selectionError = null;
        _isLoading = false;
      });

      if (!preserveAddress && defaultAddress != null) {
        _populateAddressFields(defaultAddress);
      }

      await _loadAvailableCoupons();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _selectionError = error.toString();
      });

      _showMessage('Unable to load checkout: $error');
    }
  }

  void _populateAddressFields(UserAddressModel address) {
    _nameController.text = address.recipientName;
    _phoneController.text = address.phone;
    _completePhone = address.phone;
    _addressController.text = address.addressLine;
    _cityController.text = address.city;
    _stateController.text = address.state ?? '';
    _countryController.text = address.country;
    _postalCodeController.text = address.postalCode ?? '';

    _selectedCountry = _findLocation(_countries, address.country);
    _selectedState = null;

    if (_selectedCountry != null) {
      _loadSavedAddressLocations(address);
    }
  }

  GlobalLocation? _findLocation(List<GlobalLocation> locations, String name) {
    for (final location in locations) {
      if (location.name.toLowerCase() == name.trim().toLowerCase()) {
        return location;
      }
    }

    return null;
  }

  Future<void> _loadSavedAddressLocations(UserAddressModel address) async {
    final loaded = await _loadStates(address.country);

    if (!mounted || !loaded) return;

    // Ignore outdated address or country selections.
    if (_selectedAddressId != address.id ||
        _selectedCountry?.name.toLowerCase() !=
            address.country.trim().toLowerCase()) {
      return;
    }

    final savedState = address.state;

    setState(() {
      _selectedState = savedState == null || savedState.trim().isEmpty
          ? null
          : _findLocation(_states, savedState);
    });
  }

  void _selectSavedAddress(UserAddressModel address) {
    setState(() {
      _selectedAddressId = address.id;
      _isAddingNewAddress = false;
    });

    _populateAddressFields(address);
  }

  Future<GlobalLocation?> _openLocationPicker({
    required String label,
    required List<GlobalLocation> items,
    required GlobalLocation? selectedValue,
  }) {
    return showModalBottomSheet<GlobalLocation>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return _CheckoutLocationPickerSheet(
          label: label,
          items: items,
          selectedValue: selectedValue,
        );
      },
    );
  }

  void _onCountrySelected(GlobalLocation country) {
    setState(() {
      _selectedCountry = country;
      _selectedState = null;

      _countryController.text = country.name;
      _stateController.clear();
      _cityController.clear();
    });

    _loadStates(country.name);
  }

  void _onStateSelected(GlobalLocation state) {
    setState(() {
      _selectedState = state;

      _stateController.text = state.name;
    });
  }

  void _startAddingNewAddress() {
    // Invalidate any pending state-loading request.
    _stateRequestId++;

    setState(() {
      _selectedAddressId = null;
      _isAddingNewAddress = true;

      // Reset address label.
      _addressLabelController.text = 'Home';

      // Clear form controllers.
      _nameController.clear();
      _phoneController.clear();
      _completePhone = null;
      _addressController.clear();
      _cityController.clear();
      _stateController.clear();
      _countryController.clear();
      _postalCodeController.clear();

      // Reset selected locations.
      _selectedCountry = null;
      _selectedState = null;

      // Clear previously loaded states.
      _states = [];

      // Reset location loading state.
      _isLoadingStates = false;
      _locationError = null;
    });

    // Refresh the form's validation state.
    _formKey.currentState?.reset();
  }

  double get _subtotal {
    final directPurchase = widget.directPurchase;

    if (directPurchase != null) {
      return directPurchase.totalPrice;
    }

    return _cartItems.fold(0, (total, item) => total + item.totalPrice);
  }

  double get _total {
    return _subtotal + _shippingFee - _discount;
  }

  int get _totalItems {
    final directPurchase = widget.directPurchase;

    if (directPurchase != null) {
      return directPurchase.quantity;
    }

    return _cartItems.fold(0, (total, item) => total + item.quantity);
  }

  Map<String, dynamic>? get _bestAvailableCoupon {
    final eligibleCoupons = _availableCoupons.where(
      (coupon) => coupon['eligible'] == true,
    );

    if (eligibleCoupons.isEmpty) return null;

    final sortedCoupons = eligibleCoupons.toList()
      ..sort((a, b) {
        final aDiscount = (a['estimated_discount'] as num?)?.toDouble() ?? 0;

        final bDiscount = (b['estimated_discount'] as num?)?.toDouble() ?? 0;

        return bDiscount.compareTo(aDiscount);
      });

    return sortedCoupons.first;
  }

  int get _eligibleCouponCount {
    return _availableCoupons
        .where((coupon) => coupon['eligible'] == true)
        .length;
  }

  int get _unavailableCouponCount {
    return _availableCoupons.length - _eligibleCouponCount;
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

  String? _validateField(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required.';
    }

    return null;
  }

  Future<void> _loadAvailableCoupons() async {
    final requestId = ++_couponRequestId;

    if (!mounted) return;

    setState(() {
      _isLoadingCoupons = true;
      _couponLoadError = null;
    });

    try {
      final directPurchase = widget.directPurchase;

      final Map<String, dynamic> result;

      if (directPurchase != null) {
        result = await _checkoutRepository.getAvailableDirectCoupons(
          productId: directPurchase.product.id,
          variantId: directPurchase.variant?.id,
          quantity: directPurchase.quantity,
        );
      } else {
        result = await _checkoutRepository.getAvailableCoupons(
          selectedCartItemIds: List<String>.from(_selectedCartItemIds),
        );
      }

      if (!mounted || requestId != _couponRequestId) return;

      final coupons = result['coupons'];

      if (coupons is! List) {
        throw const FormatException('Invalid coupon list received.');
      }

      final parsedCoupons = coupons
          .whereType<Map>()
          .map((coupon) => Map<String, dynamic>.from(coupon))
          .toList();

      parsedCoupons.sort((a, b) {
        final aEligible = a['eligible'] == true;
        final bEligible = b['eligible'] == true;

        if (aEligible != bEligible) {
          return aEligible ? -1 : 1;
        }

        final aDiscount = (a['estimated_discount'] as num?)?.toDouble() ?? 0;

        final bDiscount = (b['estimated_discount'] as num?)?.toDouble() ?? 0;

        return bDiscount.compareTo(aDiscount);
      });

      setState(() {
        _availableCoupons = parsedCoupons;
        _isLoadingCoupons = false;
      });
    } catch (error) {
      if (!mounted || requestId != _couponRequestId) return;

      setState(() {
        _isLoadingCoupons = false;
        _couponLoadError = 'Unable to load available coupons.';
      });

      debugPrint('AVAILABLE COUPONS ERROR: $error');
    }
  }

  Future<void> _selectAvailableCoupon(String code) async {
    if (_isPlacingOrder || _isApplyingCoupon) return;

    setState(() {
      _couponController.text = code;
      _appliedCouponCode = null;
      _discount = 0;
      _couponMessage = null;
      _couponMessageIsSuccess = false;
    });

    await _applyCoupon();
  }

  Future<void> _applyCoupon() async {
    if (_isApplyingCoupon || _isPlacingOrder) return;

    final code = _couponController.text.trim();

    if (code.isEmpty) {
      setState(() {
        _couponMessage = 'Please enter a coupon code.';
        _couponMessageIsSuccess = false;
        _appliedCouponCode = null;
        _discount = 0;
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isApplyingCoupon = true;
      _couponMessage = null;
    });

    try {
      final directPurchase = widget.directPurchase;

      final Map<String, dynamic> result;

      if (directPurchase != null) {
        result = await _checkoutRepository.validateDirectCoupon(
          code,
          productId: directPurchase.product.id,
          variantId: directPurchase.variant?.id,
          quantity: directPurchase.quantity,
        );
      } else {
        result = await _checkoutRepository.validateCoupon(
          code,
          selectedCartItemIds: _cartItems.map((item) => item.id).toList(),
        );
      }

      if (!mounted) return;

      if (result['valid'] != true) {
        setState(() {
          _appliedCouponCode = null;
          _discount = 0;

          _couponMessage =
              result['message']?.toString() ?? 'This coupon cannot be applied.';

          _couponMessageIsSuccess = false;
        });

        return;
      }

      final discountValue = result['discount'];

      if (discountValue is! num) {
        throw const FormatException('Invalid discount amount received.');
      }

      setState(() {
        _appliedCouponCode =
            result['coupon_code']?.toString() ?? code.toUpperCase();

        _couponController.text = _appliedCouponCode!;

        _discount = discountValue.toDouble();

        _couponMessage =
            result['message']?.toString() ?? 'Coupon applied successfully!';

        _couponMessageIsSuccess = true;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _appliedCouponCode = null;
        _discount = 0;

        _couponMessage = 'Unable to validate coupon. Please try again.';

        _couponMessageIsSuccess = false;
      });

      debugPrint('COUPON VALIDATION ERROR: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isApplyingCoupon = false;
        });
      }
    }
  }

  void _removeCoupon() {
    if (_isPlacingOrder || _isApplyingCoupon) return;

    setState(() {
      _couponController.clear();

      _appliedCouponCode = null;
      _couponMessage = null;

      _couponMessageIsSuccess = false;

      _discount = 0;
    });
  }

  Future<void> _editCart() async {
    if (_isPlacingOrder) return;

    final updatedIds = await context.push<List<String>>(
      AppRoutes.cart,
      extra: List<String>.from(_selectedCartItemIds),
    );

    if (!mounted || updatedIds == null) return;

    setState(() {
      _selectedCartItemIds = List<String>.from(updatedIds);

      // A previous coupon may no longer be valid for the updated cart.
      _couponController.clear();
      _appliedCouponCode = null;
      _couponMessage = null;
      _couponMessageIsSuccess = false;
      _discount = 0;

      // Clear old products and coupon data while refreshing.
      _availableCoupons = [];
      _couponLoadError = null;

      _selectionError = null;
      _isLoading = true;
    });

    await _loadCart(preserveAddress: true);
  }

  Future<void> _confirmLeaveCheckout() async {
    if (_isPlacingOrder ||
        _isConfirmingOrder ||
        _isConfirmingLeave ||
        _allowCheckoutPop) {
      return;
    }

    _isConfirmingLeave = true;

    final shouldLeave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Leave Checkout?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Are you sure you want to leave checkout? '
            'Your current checkout progress may not be saved.',
            style: TextStyle(color: _muted, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Stay Here', style: TextStyle(color: _muted)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Leave Checkout',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    _isConfirmingLeave = false;

    if (shouldLeave == true) {
      setState(() {
        _allowCheckoutPop = true;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.pop();
        }
      });
    }
  }

  Future<bool> _showPlaceOrderConfirmation() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return AlertDialog(
              backgroundColor: _surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Row(
                children: [
                  Icon(Icons.shopping_bag_outlined, color: _gold, size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Confirm Your Order',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Please review your payment details before placing '
                      'your order.',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  _confirmationPriceRow('Subtotal', _formatPrice(_subtotal)),

                  const SizedBox(height: 12),

                  _confirmationPriceRow(
                    'Shipping Fee',
                    _formatPrice(_shippingFee),
                  ),

                  const SizedBox(height: 12),

                  _confirmationPriceRow(
                    'Discount',
                    '- ${_formatPrice(_discount)}',
                    valueColor: Colors.greenAccent,
                  ),

                  const Divider(color: Color(0xFF303040), height: 28),

                  _confirmationPriceRow(
                    'Total Payment',
                    _formatPrice(_total),
                    isTotal: true,
                  ),

                  const SizedBox(height: 18),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: _background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF303040)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.payment_outlined,
                          color: _gold,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Payment Method',
                                style: TextStyle(color: _muted, fontSize: 11),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Cash on Delivery',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.check_circle,
                          color: Colors.greenAccent,
                          size: 19,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text(
                    'Review Again',
                    style: TextStyle(color: _muted),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Confirm & Place Order',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Widget _confirmationPriceRow(
    String title,
    String value, {
    Color? valueColor,
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: isTotal ? Colors.white : _muted,
            fontSize: isTotal ? 14 : 12,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? (isTotal ? _gold : Colors.white),
            fontSize: isTotal ? 17 : 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildReorderDetail(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: const Color(0xFFF5C76A)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _placeOrder() async {
    if (_isPlacingOrder || _isConfirmingOrder) return;

    final directPurchase = widget.directPurchase;

    if (directPurchase == null && _cartItems.isEmpty) {
      _showMessage('Your shopping cart is empty.');
      return;
    }

    final form = _formKey.currentState;

    if (form == null) {
      debugPrint('PLACE ORDER ERROR: Checkout form is unavailable.');
      _showMessage('Unable to validate checkout. Please try again.');
      return;
    }

    if (!form.validate()) {
      debugPrint('PLACE ORDER STOPPED: Form validation failed.');
      _showMessage('Please complete all required shipping details.');
      return;
    }

    debugPrint('PLACE ORDER: Form validation successful.');

    FocusScope.of(context).unfocus();

    setState(() {
      _isConfirmingOrder = true;
    });

    // Smart Reorder Alert for Buy Now purchases.
    // Cart Checkout already checks purchase history in CartScreen,
    // so we deliberately skip the check for normal cart checkout.
    if (directPurchase != null && !_hasCheckedRepeatPurchase) {
      try {
        debugPrint('SMART REORDER: Checking previous direct purchases...');

        final previousPurchase = await _purchaseHistoryRepository
            .getPreviousPurchaseForDirectPurchase(directPurchase);

        if (!mounted) return;

        _hasCheckedRepeatPurchase = true;

        if (previousPurchase != null) {
          debugPrint(
            'SMART REORDER: Previous purchase found: '
            '${previousPurchase.orderNumber}',
          );

          final continuePurchase = await _showSmartReorderWarning(
            previousPurchase,
          );

          if (!mounted) return;

          if (!continuePurchase) {
            setState(() {
              _isConfirmingOrder = false;
            });

            return;
          }
        } else {
          debugPrint('SMART REORDER: No previous purchase found.');
        }
      } catch (error, stackTrace) {
        debugPrint('SMART REORDER CHECK ERROR: $error');
        debugPrint('$stackTrace');

        if (!mounted) return;

        // Fail open: a purchase-history error must not prevent ordering.
        _hasCheckedRepeatPurchase = true;

        _showMessage(
          'Could not check purchase history. You can still continue.',
        );
      }
    }

    final confirmed = await _showPlaceOrderConfirmation();

    if (!mounted) return;

    if (!confirmed) {
      setState(() {
        _isConfirmingOrder = false;
      });
      return;
    }

    setState(() {
      _isConfirmingOrder = false;
      _isPlacingOrder = true;
    });

    try {
      final address = ShippingAddressModel(
        recipientName: _nameController.text.trim(),
        phone: (_completePhone ?? _phoneController.text).trim(),
        addressLine: _addressController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        postalCode: _postalCodeController.text.trim(),
        country: _countryController.text.trim(),
        customerNote: _noteController.text.trim(),
      );

      // Preserve cart items for normal checkout.
      final purchasedItems = List<CartItemModel>.from(_cartItems);

      // Determine the purchased item for order confirmation.
      final List<OrderConfirmationItem> confirmationItems;

      if (directPurchase != null) {
        confirmationItems = [
          OrderConfirmationItem(
            productName: directPurchase.productName,
            imageUrl: directPurchase.imageUrl,
            unitPrice: directPurchase.unitPrice,
            quantity: directPurchase.quantity,
            variantName: directPurchase.variantName,
            totalPrice: directPurchase.totalPrice,
          ),
        ];
      } else {
        confirmationItems = purchasedItems
            .map(OrderConfirmationItem.fromCartItem)
            .toList();
      }

      // Determine address label.
      String addressLabel = 'Saved Address';

      if (_isAddingNewAddress) {
        addressLabel = _addressLabelController.text.trim().isEmpty
            ? 'Home'
            : _addressLabelController.text.trim();
      } else {
        final selectedIndex = _savedAddresses.indexWhere(
          (item) => item.id == _selectedAddressId,
        );

        if (selectedIndex >= 0) {
          addressLabel = _savedAddresses[selectedIndex].label;
        }
      }

      debugPrint('========== PLACE ORDER START ==========');
      debugPrint(
        'Checkout mode: ${directPurchase != null ? 'BUY NOW' : 'CART'}',
      );
      debugPrint('Payment method: $_paymentMethod');
      debugPrint('Recipient: ${address.recipientName}');
      debugPrint('Phone: ${address.phone}');
      debugPrint('Address: ${address.addressLine}');
      debugPrint('City: ${address.city}');
      debugPrint('Country: ${address.country}');
      debugPrint('Applied coupon: $_appliedCouponCode');
      debugPrint('Subtotal: $_subtotal');
      debugPrint('Discount: $_discount');
      debugPrint('Total: $_total');

      if (directPurchase != null) {
        debugPrint('Direct product: ${directPurchase.product.id}');
        debugPrint('Direct variant: ${directPurchase.variant?.id}');
        debugPrint('Direct quantity: ${directPurchase.quantity}');
      } else {
        debugPrint(
          'Selected cart item IDs: '
          '${_cartItems.map((item) => item.id).toList()}',
        );
      }

      // Place the order using the appropriate checkout method.
      final order = directPurchase != null
          ? await _checkoutRepository.placeDirectOrder(
              address: address,
              paymentMethod: _paymentMethod,
              productId: directPurchase.product.id,
              variantId: directPurchase.variant?.id,
              quantity: directPurchase.quantity,
              couponCode: _appliedCouponCode,
            )
          : await _checkoutRepository.placeOrder(
              address: address,
              paymentMethod: _paymentMethod,
              selectedCartItemIds: _cartItems.map((item) => item.id).toList(),
              couponCode: _appliedCouponCode,
            );

      debugPrint('========== PLACE ORDER RESPONSE ==========');
      debugPrint('Order ID: ${order.orderId}');
      debugPrint('Order Number: ${order.orderNumber}');
      debugPrint('Order Status: ${order.status}');
      debugPrint('Order Total: ${order.totalAmount}');
      debugPrint('Duplicate Order: ${order.isDuplicate}');

      // Create notification after successful order placement.
      if (!order.isDuplicate) {
        try {
          await _notificationRepository.createNotification(
            title: 'Order Placed Successfully!',
            message:
                'Your order #${order.orderNumber} has been placed '
                'successfully. Total: ${_formatPrice(order.totalAmount)}.',
            category: 'order',
            relatedOrderId: order.orderId,
            metadata: {
              'event': 'order_placed',
              'order_number': order.orderNumber,
              'total_amount': order.totalAmount,
              'status': order.status,
              'payment_method': _paymentMethod,
            },
            dedupeKey: 'order_placed_${order.orderId}',
          );
        } catch (error) {
          debugPrint('ORDER NOTIFICATION ERROR: $error');
        }
      }

      bool addressSaved = true;

      // Save new address after successful order placement.
      if (_isAddingNewAddress) {
        try {
          await _addressRepository.saveAddress(
            label: addressLabel,
            recipientName: address.recipientName,
            phone: address.phone,
            addressLine: address.addressLine,
            city: address.city,
            state: address.state,
            postalCode: address.postalCode,
            country: address.country,
          );
        } catch (error) {
          addressSaved = false;
          debugPrint('Order placed, but address could not be saved: $error');
        }
      }

      if (!mounted) return;

      // Prepare order confirmation.
      final confirmation = OrderConfirmationData(
        order: order,
        items: confirmationItems,
        shippingAddress: address,
        paymentMethod: _paymentMethod,
        addressLabel: addressLabel,
        addressSaved: addressSaved,
      );

      context.go(AppRoutes.orderConfirmation, extra: confirmation);
    } catch (error, stackTrace) {
      debugPrint('========== PLACE ORDER FAILED ==========');
      debugPrint('Error type: ${error.runtimeType}');
      debugPrint('Error details: $error');
      debugPrint('Stack trace: $stackTrace');

      if (!mounted) return;

      setState(() {
        _isPlacingOrder = false;
      });

      _showMessage('Unable to place order: ${error.toString()}');
    }
  }

  Future<bool> _showSmartReorderWarning(
    PreviousPurchaseModel previousPurchase,
  ) async {
    final purchasedDate = previousPurchase.purchasedAt;

    final formattedDate =
        '${purchasedDate.day.toString().padLeft(2, '0')}/'
        '${purchasedDate.month.toString().padLeft(2, '0')}/'
        '${purchasedDate.year}';

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return AlertDialog(
              backgroundColor: const Color(0xFF171722),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.history_rounded,
                    color: Color(0xFFF5C76A),
                    size: 27,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Smart Reorder Alert',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
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
                    const Text(
                      'You have purchased this product before!',
                      style: TextStyle(
                        color: Color(0xFFF5C76A),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      previousPurchase.productName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildReorderDetail(
                      Icons.calendar_today_rounded,
                      'Previous purchase',
                      formattedDate,
                    ),
                    _buildReorderDetail(
                      Icons.shopping_bag_outlined,
                      'Previous quantity',
                      '${previousPurchase.quantity}',
                    ),
                    _buildReorderDetail(
                      Icons.payments_outlined,
                      'Previous unit price',
                      _formatPrice(previousPurchase.unitPrice),
                    ),
                    _buildReorderDetail(
                      Icons.receipt_long_outlined,
                      'Order number',
                      previousPurchase.orderNumber,
                    ),
                    _buildReorderDetail(
                      Icons.local_shipping_outlined,
                      'Order status',
                      previousPurchase.orderStatus,
                    ),
                    _buildReorderDetail(
                      Icons.category_outlined,
                      'Previous variant',
                      previousPurchase.variantDisplayName,
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5C76A).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFF5C76A)
                              .withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Text(
                        'Before ordering again, please check whether you really '
                        'need this product. This reminder helps you avoid '
                        'unnecessary purchases.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext, false);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel Purchase'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext, true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Continue Purchase',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: _allowCheckoutPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _confirmLeaveCheckout();
        }
      },
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _background,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Checkout',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: _isLoading
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: _primary,
                      strokeWidth: 2.5,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Preparing your checkout...',
                      style: AppTextStyles.bodyMedium.copyWith(color: _muted),
                    ),
                  ],
                ),
              )
            : _selectionError != null
            ? _buildInvalidSelection()
            : (!widget.isDirectPurchase && _cartItems.isEmpty)
            ? _buildEmptyCart()
            : _buildCheckoutContent(),
      ),
    );
  }

  Widget _buildCheckoutContent() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal,
          AppSpacing.md,
          AppSpacing.pageHorizontal,
          AppSpacing.xxxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Shipping Address', Icons.location_on_outlined),
            const SizedBox(height: AppSpacing.md),
            _buildAddressCard(),

            const SizedBox(height: AppSpacing.xxl),

            _buildSectionTitle('Order Summary', Icons.shopping_bag_outlined),
            const SizedBox(height: AppSpacing.md),
            _buildOrderSummary(),

            const SizedBox(height: AppSpacing.md),

            SizedBox(
              width: double.infinity,
              height: AppSpacing.buttonHeight,
              child: OutlinedButton.icon(
                onPressed: _isPlacingOrder ? null : _editCart,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text(
                  'Edit Cart & Selected Products',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _gold,
                  side: BorderSide(color: _gold.withValues(alpha: 0.55)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusMedium,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            _buildSectionTitle('Coupon & Offers', Icons.local_offer_outlined),
            const SizedBox(height: AppSpacing.md),
            _buildCouponCard(),

            const SizedBox(height: AppSpacing.xxl),

            _buildSectionTitle('Payment Method', Icons.payment_outlined),
            const SizedBox(height: AppSpacing.md),
            _buildPaymentCard(),

            const SizedBox(height: AppSpacing.xxl),

            _buildSectionTitle('Price Details', Icons.receipt_long_outlined),
            const SizedBox(height: AppSpacing.md),
            _buildPriceDetails(),

            const SizedBox(height: AppSpacing.xxl),

            _buildPlaceOrderButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            border: Border.all(color: _gold.withValues(alpha: 0.20)),
          ),
          child: Icon(icon, color: _gold, size: 21),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSavedAddressTile(
    UserAddressModel address, {
    VoidCallback? onTap,
  }) {
    final selected = _selectedAddressId == address.id;

    return InkWell(
      onTap: _isPlacingOrder
          ? null
          : onTap ?? () => _selectSavedAddress(address),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          border: Border.all(
            color: selected
                ? _gold.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.07),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _gold.withValues(alpha: 0.07),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: (selected ? _gold : _primary).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              ),
              child: Icon(
                address.label.toLowerCase() == 'office'
                    ? Icons.work_outline
                    : Icons.home_outlined,
                color: selected ? _gold : AppColors.textMuted,
                size: 23,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          address.label,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (address.isDefault) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: _gold.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusCircular,
                            ),
                          ),
                          child: Text(
                            'DEFAULT',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: _gold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    address.recipientName,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${address.addressLine}, ${address.city}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? _gold : AppColors.textMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationField({
    required String label,
    required String hint,
    required IconData icon,
    required List<GlobalLocation> items,
    required GlobalLocation? selectedValue,
    required bool isLoading,
    required VoidCallback onRetry,
    required ValueChanged<GlobalLocation> onSelected,
    bool requiredField = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: FormField<String>(
        validator: requiredField
            ? (_) => selectedValue == null ? '$label is required.' : null
            : null,
        builder: (field) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: isLoading || _isPlacingOrder || items.isEmpty
                    ? null
                    : () async {
                        final selected = await _openLocationPicker(
                          label: label,
                          items: items,
                          selectedValue: selectedValue,
                        );

                        if (selected != null) {
                          field.didChange(selected.name);
                          onSelected(selected);
                        }
                      },
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                child: InputDecorator(
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      icon,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    suffixIcon: isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _primary,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.textMuted,
                          ),
                    errorText: field.errorText,
                    filled: true,
                    fillColor: _background,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.lg,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusMedium,
                      ),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusMedium,
                      ),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusMedium,
                      ),
                      borderSide: const BorderSide(color: _primary, width: 1.4),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusMedium,
                      ),
                      borderSide: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                  child: SizedBox(
                    height: 22,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        isLoading ? 'Loading...' : selectedValue?.name ?? hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: selectedValue == null
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_locationError != null && !isLoading && items.isEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onRetry,
                    child: Text(
                      'Retry loading',
                      style: AppTextStyles.labelMedium.copyWith(color: _gold),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool requiredField = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
        validator: requiredField
            ? (value) => _validateField(value, label)
            : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
          labelStyle: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textMuted,
          ),
          hintStyle: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textMuted,
          ),
          filled: true,
          fillColor: _background,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            borderSide: const BorderSide(color: _primary, width: 1.4),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    final directPurchase = widget.directPurchase;

    String formatPrice(double price) {
      final amount = price.round().toString();

      final formatted = amount.replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (match) => '.',
      );

      return 'Rp $formatted';
    }

    Widget buildDirectPurchaseItem(DirectPurchaseData purchase) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              child: SizedBox(
                width: 65,
                height: 65,
                child:
                    purchase.imageUrl != null && purchase.imageUrl!.isNotEmpty
                    ? Image.network(
                        purchase.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const ColoredBox(
                            color: Color(0xFF252535),
                            child: Icon(
                              Icons.shopping_bag_outlined,
                              color: Colors.white54,
                            ),
                          );
                        },
                      )
                    : const ColoredBox(
                        color: Color(0xFF252535),
                        child: Icon(
                          Icons.shopping_bag_outlined,
                          color: Colors.white54,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    purchase.productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (purchase.variantName != null &&
                      purchase.variantName!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      purchase.variantName!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Qty: ${purchase.quantity}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    formatPrice(purchase.unitPrice),
                    style: AppTextStyles.labelMedium.copyWith(
                      color: _gold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              formatPrice(purchase.totalPrice),
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          if (directPurchase != null)
            buildDirectPurchaseItem(directPurchase)
          else
            ..._cartItems.map(_buildProductItem),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Divider(color: Color(0xFF303040), height: 1),
          ),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: _gold,
                  size: 19,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Total Items',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              Text(
                '$_totalItems items',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductItem(CartItemModel item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              child: SizedBox(
                width: 76,
                height: 76,
                child: item.product.imageUrl != null
                    ? Image.network(
                        item.product.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _imagePlaceholder(),
                      )
                    : _imagePlaceholder(),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusCircular,
                    ),
                  ),
                  child: Text(
                    'Qty: ${item.quantity}',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              _formatPrice(item.totalPrice),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: AppTextStyles.bodyMedium.copyWith(
                color: _gold,
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
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      ),
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: AppColors.textMuted,
        size: 28,
      ),
    );
  }

  Widget _buildAvailableCoupons() {
    if (_isLoadingCoupons) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 22),
        child: Center(child: CircularProgressIndicator(color: _primary)),
      );
    }

    if (_couponLoadError != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _couponLoadError!,
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: _loadAvailableCoupons,
              child: const Text('Retry', style: TextStyle(color: _gold)),
            ),
          ],
        ),
      );
    }

    if (_availableCoupons.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          children: [
            Icon(Icons.local_offer_outlined, color: _muted, size: 30),
            SizedBox(height: 8),
            Text(
              'No coupons available right now.',
              style: TextStyle(color: _muted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final bestCoupon = _bestAvailableCoupon;
    final bestCouponCode = bestCoupon?['code']?.toString() ?? '';
    final isBestCouponApplied =
        bestCouponCode.isNotEmpty &&
        _appliedCouponCode?.toUpperCase() == bestCouponCode.toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (bestCoupon != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.greenAccent.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.workspace_premium, color: _gold, size: 27),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'BEST DEAL FOR YOUR ORDER',
                        style: TextStyle(
                          color: _gold,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        bestCoupon['code']?.toString() ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Save ${_formatPrice((bestCoupon['estimated_discount'] as num?)?.toDouble() ?? 0)}',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      isBestCouponApplied ||
                          _isApplyingCoupon ||
                          _isPlacingOrder
                      ? null
                      : () => _selectAvailableCoupon(bestCouponCode),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBestCouponApplied
                        ? const Color(0xFF6D4BA8)
                        : const Color(0xFF302443),
                    foregroundColor: const Color(0xFFD8C2FF),
                    disabledBackgroundColor: const Color(0xFF6D4BA8),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 34),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isBestCouponApplied
                            ? const Color(0xFF9B7BD0)
                            : const Color(0xFF8B5CF6).withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                  child: Text(
                    isBestCouponApplied ? 'Applied ✓' : 'Apply',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ] else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: _muted),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No coupon currently qualifies for your selected products.',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

        Row(
          children: [
            Expanded(
              child: Text(
                '$_eligibleCouponCount eligible offers'
                '${_unavailableCouponCount > 0 ? ' • $_unavailableCouponCount unavailable' : ''}',
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
            ),
            IconButton(
              onPressed: _isApplyingCoupon || _isPlacingOrder
                  ? null
                  : _loadAvailableCoupons,
              icon: const Icon(Icons.refresh, color: _gold, size: 19),
              tooltip: 'Refresh coupons',
            ),
          ],
        ),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showAllCoupons(),
            icon: const Icon(Icons.local_offer_outlined, size: 18),
            label: const Text(
              'View All Available Coupons',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _gold,
              side: const BorderSide(color: _gold),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showAllCoupons() async {
    if (_availableCoupons.isEmpty || _isPlacingOrder) return;

    final couponScrollController = ScrollController();
    final appliedCouponKey = GlobalKey();

    bool initialScrollScheduled = false;

    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: _surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              final eligibleCoupons = _availableCoupons
                  .where((coupon) => coupon['eligible'] == true)
                  .toList();

              final unavailableCoupons = _availableCoupons
                  .where((coupon) => coupon['eligible'] != true)
                  .toList();

              if (!initialScrollScheduled) {
                initialScrollScheduled = true;

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final targetContext = appliedCouponKey.currentContext;

                  if (targetContext != null) {
                    Scrollable.ensureVisible(
                      targetContext,
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeInOutCubic,
                      alignment: 0.08,
                    );
                  }
                });
              }

              return SizedBox(
                height: MediaQuery.of(context).size.height * 0.82,
                child: Column(
                  children: [
                    const SizedBox(height: 12),

                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Smart Coupon Centre',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Your selected order value: ${_formatPrice(_subtotal)}',
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    Expanded(
                      child: ListView(
                        controller: couponScrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        children: [
                          if (eligibleCoupons.isNotEmpty) ...[
                            _couponGroupHeading(
                              'AVAILABLE OFFERS',
                              eligibleCoupons.length,
                              Colors.greenAccent,
                            ),

                            const SizedBox(height: 12),

                            ...eligibleCoupons.map((coupon) {
                              final code = coupon['code']?.toString() ?? '';

                              return _buildAvailableCouponTile(
                                coupon,
                                key: _appliedCouponCode == code
                                    ? appliedCouponKey
                                    : null,
                                onChanged: () => setSheetState(() {}),
                              );
                            }),
                          ],

                          if (unavailableCoupons.isNotEmpty) ...[
                            const SizedBox(height: 12),

                            _couponGroupHeading(
                              'UNAVAILABLE OFFERS',
                              unavailableCoupons.length,
                              _muted,
                            ),

                            const SizedBox(height: 12),

                            ...unavailableCoupons.map((coupon) {
                              final code = coupon['code']?.toString() ?? '';

                              return _buildAvailableCouponTile(
                                coupon,
                                key: _appliedCouponCode == code
                                    ? appliedCouponKey
                                    : null,
                                onChanged: () => setSheetState(() {}),
                              );
                            }),
                          ],

                          if (_availableCoupons.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(30),
                              child: Text(
                                'No coupons found.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: _muted),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } finally {
      couponScrollController.dispose();
    }
  }

  Widget _couponGroupHeading(String title, int count, Color color) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.7,
            ),
          ),
        ),
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildAddressCard() {
    final selectedAddress = _savedAddresses
        .cast<UserAddressModel?>()
        .firstWhere(
          (address) => address?.id == _selectedAddressId,
          orElse: () => null,
        );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_savedAddresses.isNotEmpty) ...[
            if (!_isAddingNewAddress && selectedAddress != null) ...[
              _buildSelectedAddressPreview(selectedAddress),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isPlacingOrder ? null : _showAllSavedAddresses,
                  icon: const Icon(Icons.location_on_outlined, size: 18),
                  label: const Text('View All Saved Addresses'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _gold,
                    side: const BorderSide(color: _gold),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                ),
              ),
            ] else ...[
              const Text(
                'Choose a Saved Address',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isPlacingOrder ? null : _showAllSavedAddresses,
                  icon: const Icon(Icons.location_on_outlined, size: 18),
                  label: const Text('View All Saved Addresses'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _gold,
                    side: const BorderSide(color: _gold),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],

          OutlinedButton.icon(
            onPressed: _isPlacingOrder ? null : _startAddingNewAddress,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Add New Address'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _gold,
              side: const BorderSide(color: _gold),
              minimumSize: const Size(double.infinity, 46),
            ),
          ),

          if (_isAddingNewAddress) ...[
            const SizedBox(height: 22),
            const Text(
              'New Shipping Address',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),

            _buildTextField(
              controller: _addressLabelController,
              label: 'Address Label',
              hint: 'Home, Office, Other',
              icon: Icons.bookmark_outline,
            ),

            _buildTextField(
              controller: _nameController,
              label: 'Recipient Name',
              hint: 'Enter full name',
              icon: Icons.person_outline,
            ),

            IntlPhoneField(
              controller: _phoneController,
              initialCountryCode: 'ID',
              disableLengthCheck: false,
              style: const TextStyle(color: Colors.white),
              dropdownTextStyle: const TextStyle(color: Colors.white),
              dropdownIcon: const Icon(
                Icons.arrow_drop_down,
                color: Color(0xFF9A9AAF),
              ),
              decoration: InputDecoration(
                labelText: 'Phone Number',
                hintText: 'Enter phone number',
                labelStyle: const TextStyle(color: _muted),
                hintStyle: const TextStyle(color: _muted),
                prefixIcon: const Icon(Icons.phone_outlined, color: _muted),
                filled: true,
                fillColor: _surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _primary),
                ),
              ),
              validator: (phone) {
                if (phone == null || phone.number.trim().isEmpty) {
                  return 'Phone number is required.';
                }

                if (!phone.isValidNumber()) {
                  return 'Please enter a valid phone number.';
                }

                return null;
              },
              onChanged: (phone) {
                _completePhone = phone.completeNumber;
              },
            ),

            _buildTextField(
              controller: _addressController,
              label: 'Street Address',
              hint: 'House number, street, apartment',
              icon: Icons.home_outlined,
              maxLines: 2,
            ),

            _buildLocationField(
              label: 'Country',
              hint: 'Select your country',
              icon: Icons.public_outlined,
              items: _countries,
              selectedValue: _selectedCountry,
              isLoading: _isLoadingCountries,
              onRetry: _loadCountries,
              onSelected: _onCountrySelected,
            ),

            _buildLocationField(
              label: 'Province / State',
              hint: _selectedCountry == null
                  ? 'Select a country first'
                  : 'Select province or state',
              icon: Icons.map_outlined,
              items: _states,
              selectedValue: _selectedState,
              isLoading: _isLoadingStates,
              onRetry: () {
                final country = _selectedCountry;
                if (country != null) {
                  _loadStates(country.name);
                }
              },
              onSelected: _onStateSelected,
              requiredField: false,
            ),

            _buildTextField(
              controller: _cityController,
              label: 'City',
              hint: 'Enter your city',
              icon: Icons.location_city_outlined,
            ),

            _buildTextField(
              controller: _postalCodeController,
              label: 'Postal Code',
              hint: 'Enter postal code',
              icon: Icons.markunread_mailbox_outlined,
              keyboardType: TextInputType.text,
              requiredField: false,
            ),
          ],

          const SizedBox(height: 16),

          _buildTextField(
            controller: _noteController,
            label: 'Order Note',
            hint: 'Any special delivery instructions?',
            icon: Icons.edit_note,
            maxLines: 2,
            requiredField: false,
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedAddressPreview(UserAddressModel address) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_rounded,
                color: Colors.greenAccent,
                size: 19,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Selected Delivery Address',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: Colors.greenAccent,
                  ),
                ),
              ),
              if (address.isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusCircular,
                    ),
                  ),
                  child: Text(
                    'DEFAULT',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: _gold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            address.label,
            style: AppTextStyles.headingSmall.copyWith(color: _gold),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            address.recipientName,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              const Icon(
                Icons.phone_outlined,
                color: AppColors.textMuted,
                size: 15,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  address.phone,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: AppColors.textMuted,
                size: 16,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${address.addressLine}, ${address.city}, '
                  '${address.state ?? ''}, ${address.country}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAllSavedAddresses() {
    if (_savedAddresses.isEmpty || _isPlacingOrder) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.75,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Saved Delivery Addresses',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_savedAddresses.length} saved addresses',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: _savedAddresses.length,
                  itemBuilder: (context, index) {
                    final address = _savedAddresses[index];

                    return _buildSavedAddressTile(
                      address,
                      onTap: () {
                        _selectSavedAddress(address);
                        Navigator.pop(sheetContext);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvailableCouponTile(
    Map<String, dynamic> coupon, {
    VoidCallback? onChanged,
    Key? key,
  }) {
    final code = coupon['code']?.toString() ?? '';
    final eligible = coupon['eligible'] == true;

    final hasBeenUsed = coupon['has_been_used'] == true;

    final usageCount = (coupon['user_usage_count'] as num?)?.toInt() ?? 0;

    final usageLimit = (coupon['user_usage_limit'] as num?)?.toInt();

    final reason = coupon['reason']?.toString() ?? '';

    final discountType = coupon['discount_type']?.toString() ?? '';
    final discountValue = (coupon['discount_value'] as num?)?.toDouble() ?? 0;

    final minimumAmount =
        (coupon['minimum_order_amount'] as num?)?.toDouble() ?? 0;

    final maxDiscount = (coupon['max_discount'] as num?)?.toDouble();

    final remainingAmount =
        (coupon['remaining_amount'] as num?)?.toDouble() ?? 0;

    final estimatedDiscount =
        (coupon['estimated_discount'] as num?)?.toDouble() ?? 0;

    final description = coupon['description']?.toString();

    final expiryDate = _formatCouponExpiry(coupon['valid_until']);

    final isApplied = _appliedCouponCode == code;

    final discountLabel = discountType == 'percentage'
        ? '${discountValue.toStringAsFixed(0)}% OFF'
        : '${_formatPrice(discountValue)} OFF';

    final hasReachedUsageLimit = usageLimit != null && usageCount >= usageLimit;

    final status = _couponStatus(
      reason,
      eligible,
      hasBeenUsed,
      hasReachedUsageLimit,
    );

    final statusLabel = status['label'] as String;
    final statusColor = status['color'] as Color;

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_surface, _background],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        border: Border.all(
          color: isApplied
              ? Colors.greenAccent.withValues(alpha: 0.75)
              : eligible
              ? _primary.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.07),
          width: isApplied ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isApplied ? Colors.greenAccent : _primary).withValues(
              alpha: 0.05,
            ),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.confirmation_number_outlined,
                  color: _gold,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      code,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      discountLabel,
                      style: const TextStyle(
                        color: _gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              if (isApplied)
                _buildCouponStatusBadge('APPLIED', Colors.greenAccent)
              else if (eligible)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (hasBeenUsed)
                      _buildCouponStatusBadge('USED BEFORE', _gold),

                    if (hasBeenUsed) const SizedBox(height: 6),

                    SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: !_isApplyingCoupon && !_isPlacingOrder
                            ? () async {
                                await _selectAvailableCoupon(code);
                                onChanged?.call();
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: const Color(0xFF171722),
                          disabledBackgroundColor: const Color(0xFF292938),
                          disabledForegroundColor: _muted,
                          elevation: 3,
                          shadowColor: _gold.withValues(alpha: 0.3),
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: const Text(
                          'Apply',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                _buildCouponStatusBadge(statusLabel, statusColor),
            ],
          ),

          if (description != null && description.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(color: _muted, fontSize: 12, height: 1.4),
            ),
          ],

          const SizedBox(height: 13),

          if (minimumAmount > 0)
            _couponDetailRow(
              Icons.shopping_bag_outlined,
              'Minimum order',
              _formatPrice(minimumAmount),
            ),

          if (maxDiscount != null && maxDiscount > 0) ...[
            const SizedBox(height: 9),
            _couponDetailRow(
              Icons.discount_outlined,
              'Maximum discount',
              _formatPrice(maxDiscount),
            ),
          ],

          if (expiryDate != null) ...[
            const SizedBox(height: 9),
            _couponDetailRow(
              Icons.event_outlined,
              'Valid until',
              expiryDate,
              valueColor: eligible ? _gold : _muted,
            ),
          ],

          if (hasBeenUsed) ...[
            const SizedBox(height: 9),
            _couponDetailRow(
              Icons.history,
              'Previously used',
              usageLimit != null
                  ? '$usageCount of $usageLimit uses'
                  : '$usageCount ${usageCount == 1 ? 'time' : 'times'}',
              valueColor: _gold,
            ),
          ],

          const SizedBox(height: 11),

          if (eligible)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: Colors.greenAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isApplied
                          ? 'You are saving ${_formatPrice(estimatedDiscount)}.'
                          : 'You can save up to ${_formatPrice(estimatedDiscount)}.',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: statusColor.withValues(alpha: 0.18)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: statusColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _couponUnavailableMessage(coupon, remainingAmount),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        height: 1.4,
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

  Widget _buildCouponStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Map<String, dynamic> _couponStatus(
    String reason,
    bool eligible,
    bool hasBeenUsed,
    bool hasReachedUsageLimit,
  ) {
    if (hasReachedUsageLimit || reason == 'user_limit_reached') {
      return {'label': 'ALREADY USED', 'color': Colors.orangeAccent};
    }

    if (eligible && hasBeenUsed) {
      return {'label': 'USED BEFORE', 'color': _gold};
    }

    if (eligible) {
      return {'label': 'AVAILABLE', 'color': Colors.greenAccent};
    }

    switch (reason) {
      case 'global_redemption_limit_reached':
        return {'label': 'FULLY REDEEMED', 'color': Colors.redAccent};

      case 'expired':
        return {'label': 'EXPIRED', 'color': Colors.redAccent};

      case 'not_started':
        return {'label': 'COMING SOON', 'color': Colors.blueAccent};

      case 'inactive':
        return {'label': 'INACTIVE', 'color': Colors.redAccent};

      case 'minimum_order_not_met':
        return {'label': 'NOT ELIGIBLE', 'color': Colors.orangeAccent};

      default:
        return {'label': 'UNAVAILABLE', 'color': _muted};
    }
  }

  Widget _couponDetailRow(
    IconData icon,
    String label,
    String value, {
    Color valueColor = _muted,
  }) {
    return Row(
      children: [
        Icon(icon, color: _muted, size: 15),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String? _formatCouponExpiry(dynamic value) {
    if (value == null) return null;

    final date = DateTime.tryParse(value.toString());

    if (date == null) return null;

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

    return '${localDate.day.toString().padLeft(2, '0')} '
        '${months[localDate.month - 1]} ${localDate.year}';
  }

  String _couponUnavailableMessage(
    Map<String, dynamic> coupon,
    double remainingAmount,
  ) {
    final usageCount = (coupon['user_usage_count'] as num?)?.toInt() ?? 0;

    final usageLimit = (coupon['user_usage_limit'] as num?)?.toInt();

    if (usageLimit != null && usageCount >= usageLimit) {
      return 'Already used. You have reached your personal usage limit '
          '($usageCount of $usageLimit uses).';
    }

    final message = coupon['unavailable_message']?.toString();

    if (message != null && message.trim().isNotEmpty) {
      return message;
    }

    final reason = coupon['reason']?.toString() ?? '';

    switch (reason) {
      case 'inactive':
        return 'This coupon is currently inactive.';

      case 'not_started':
        return 'This coupon is not active yet.';

      case 'expired':
        return 'This coupon has expired.';

      case 'minimum_order_not_met':
        return 'Add ${_formatPrice(remainingAmount)} more to unlock this coupon.';

      case 'global_redemption_limit_reached':
        return 'This coupon has reached its total redemption limit.';

      case 'user_limit_reached':
        return 'Already used. You have reached your personal usage limit.';

      default:
        return 'This coupon is not applicable to your current order.';
    }
  }

  Widget _buildCouponCard() {
    final isApplied = _appliedCouponCode != null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.confirmation_number_outlined, color: _gold, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Have a promo code?',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          const Text(
            'Choose an available offer or enter a promo code manually.',
            style: TextStyle(color: _muted, fontSize: 12),
          ),

          const SizedBox(height: 14),

          _buildAvailableCoupons(),

          const SizedBox(height: 18),

          const Divider(color: Color(0xFF303040)),

          const SizedBox(height: 14),

          const Text(
            'Have another promo code?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _couponController,
                  enabled: !isApplied && !_isApplyingCoupon && !_isPlacingOrder,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter coupon code',
                    hintStyle: const TextStyle(color: _muted, fontSize: 13),
                    prefixIcon: const Icon(
                      Icons.local_offer_outlined,
                      color: _muted,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: _background,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF292938)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF292938)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _primary),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isApplyingCoupon || _isPlacingOrder
                      ? null
                      : isApplied
                      ? _removeCoupon
                      : _applyCoupon,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isApplied
                        ? const Color(0xFF292938)
                        : _gold,
                    foregroundColor: isApplied
                        ? Colors.white
                        : const Color(0xFF171722),
                    disabledBackgroundColor: _gold.withValues(alpha: 0.4),
                    disabledForegroundColor: Colors.white70,
                    elevation: isApplied ? 0 : 4,
                    shadowColor: _gold.withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  child: _isApplyingCoupon
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isApplied ? 'Remove' : 'Apply',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),

          if (_couponMessage != null) ...[
            const SizedBox(height: 14),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _couponMessageIsSuccess
                      ? Icons.check_circle
                      : Icons.error_outline,
                  color: _couponMessageIsSuccess
                      ? Colors.greenAccent
                      : Colors.redAccent,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _couponMessage!,
                    style: TextStyle(
                      color: _couponMessageIsSuccess
                          ? Colors.greenAccent
                          : Colors.redAccent,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (isApplied) ...[
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.greenAccent.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.discount_outlined,
                    color: Colors.greenAccent,
                    size: 19,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You saved ${_formatPrice(_discount)}!',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentCard() {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _buildPaymentOption(
            value: 'cash_on_delivery',
            title: 'Cash on Delivery',
            subtitle: 'Pay when your order arrives',
            icon: Icons.local_shipping_outlined,
          ),
          const Divider(color: Color(0xFF303040), height: 1),
          _buildComingSoonPaymentOption(
            title: 'Bank Transfer',
            subtitle: 'Pay through your bank',
            icon: Icons.account_balance_outlined,
          ),
          const Divider(color: Color(0xFF303040), height: 1),
          _buildComingSoonPaymentOption(
            title: 'E-Wallet',
            subtitle: 'Pay using a digital wallet',
            icon: Icons.account_balance_wallet_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return InkWell(
      onTap: _isPlacingOrder
          ? null
          : () {
              setState(() {
                _paymentMethod = value;
              });
            },
      borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              ),
              child: Icon(icon, color: _gold, size: 23),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            RadioGroup<String>(
              groupValue: _paymentMethod,
              onChanged: (selectedValue) {
                if (selectedValue == null || _isPlacingOrder) return;

                setState(() {
                  _paymentMethod = selectedValue;
                });
              },
              child: Radio<String>(value: value, activeColor: _gold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComingSoonPaymentOption({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Opacity(
      opacity: 0.55,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              ),
              child: Icon(icon, color: AppColors.textMuted, size: 23),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
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
                border: Border.all(color: _gold.withValues(alpha: 0.25)),
              ),
              child: Text(
                'Coming Soon',
                style: AppTextStyles.labelSmall.copyWith(
                  color: _gold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceDetails() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _priceRow('Subtotal', _formatPrice(_subtotal)),
          const SizedBox(height: AppSpacing.md),
          _priceRow('Shipping Fee', _formatPrice(_shippingFee)),
          const SizedBox(height: AppSpacing.md),
          _priceRow(
            'Discount',
            '- ${_formatPrice(_discount)}',
            valueColor: Colors.greenAccent,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Divider(color: Color(0xFF303040), height: 1),
          ),
          _priceRow('Total Payment', _formatPrice(_total), isTotal: true),
        ],
      ),
    );
  }

  Widget _priceRow(
    String title,
    String value, {
    Color? valueColor,
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.bodyMedium.copyWith(
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
                (isTotal
                        ? AppTextStyles.headingSmall
                        : AppTextStyles.bodyMedium)
                    .copyWith(
                      color: valueColor ?? (isTotal ? _gold : Colors.white),
                      fontWeight: FontWeight.bold,
                    ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceOrderButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isPlacingOrder ? null : _placeOrder,
        style: ElevatedButton.styleFrom(
          backgroundColor: _gold,
          foregroundColor: const Color(0xFF171722),
          disabledBackgroundColor: _gold.withValues(alpha: 0.4),
          elevation: 4,
          shadowColor: _gold.withValues(alpha: 0.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          ),
        ),
        child: _isPlacingOrder
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF171722),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline, size: 19),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Place Order • ${_formatPrice(_total)}',
                    style: AppTextStyles.buttonMedium.copyWith(
                      color: const Color(0xFF171722),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildInvalidSelection() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orangeAccent,
              size: 70,
            ),
            const SizedBox(height: 18),
            const Text(
              'Unable to Continue Checkout',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _selectionError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, height: 1.5),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: () => context.go(AppRoutes.cart),
              icon: const Icon(Icons.shopping_cart_outlined),
              label: const Text('Return to Cart'),
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

  Widget _buildEmptyCart() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_cart_outlined, color: _muted, size: 70),
            const SizedBox(height: 18),
            const Text(
              'Your cart is empty',
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Add some products before proceeding to checkout.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted),
            ),
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.home),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Continue Shopping'),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [_surface, _background],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
      border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}

class _CheckoutLocationPickerSheet extends StatefulWidget {
  final String label;
  final List<GlobalLocation> items;
  final GlobalLocation? selectedValue;

  const _CheckoutLocationPickerSheet({
    required this.label,
    required this.items,
    required this.selectedValue,
  });

  @override
  State<_CheckoutLocationPickerSheet> createState() =>
      _CheckoutLocationPickerSheetState();
}

class _CheckoutLocationPickerSheetState
    extends State<_CheckoutLocationPickerSheet> {
  static const Color _primary = Color(0xFF8B5CF6);
  static const Color _muted = Color(0xFF9A9AAF);
  static const Color _background = Color(0xFF0B0B12);

  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<GlobalLocation> get _filteredItems {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) return widget.items;

    return widget.items.where((item) {
      return item.name.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    final availableHeight = (screenHeight - keyboardHeight)
        .clamp(250.0, screenHeight)
        .toDouble();

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: availableHeight * 0.85,
          child: Column(
            children: [
              const SizedBox(height: 12),

              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 15),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Select ${widget.label}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search ${widget.label}...',
                    hintStyle: const TextStyle(color: _muted),
                    prefixIcon: const Icon(Icons.search, color: _primary),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear, color: _muted),
                          )
                        : null,
                    filled: true,
                    fillColor: _background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_filteredItems.length} results',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Expanded(
                child: _filteredItems.isEmpty
                    ? const Center(
                        child: Text(
                          'No locations found.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        itemCount: _filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = _filteredItems[index];

                          final isSelected =
                              widget.selectedValue?.name == item.name;

                          return Material(
                            color: Colors.transparent,
                            child: ListTile(
                              title: Text(
                                item.name,
                                style: TextStyle(
                                  color: isSelected ? _primary : Colors.white,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              trailing: isSelected
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: _primary,
                                    )
                                  : null,
                              onTap: () {
                                Navigator.of(context).pop(item);
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
