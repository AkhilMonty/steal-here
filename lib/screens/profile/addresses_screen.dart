import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../../models/user_address_model.dart';
import '../../repositories/address_repository.dart';
import '../../core/services/global_location_service.dart';

import '../../core/themes/app_spacing.dart';
import '../../core/themes/app_text_styles.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  static const Color _background = Color(0xFF0B0B12);
  static const Color _surface = Color(0xFF171722);
  static const Color _primary = Color(0xFF8B5CF6);
  static const Color _gold = Color(0xFFF5C76A);
  static const Color _muted = Color(0xFF9A9AAF);

  final AddressRepository _repository = AddressRepository();

  List<UserAddressModel> _addresses = [];

  bool _isLoading = true;
  String? _errorMessage;
  String? _processingAddressId;
  bool _isAddingAddress = false;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final addresses = await _repository.getAddresses();

      if (!mounted) return;

      setState(() {
        _addresses = addresses;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load your saved addresses.';
      });
    }
  }

  Future<void> _openAddressForm({UserAddressModel? address}) async {
    final result = await showModalBottomSheet<_AddressFormData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _AddressFormSheet(address: address),
    );

    if (result == null || !mounted) return;

    setState(() {
      _isAddingAddress = true;
    });

    try {
      if (address == null) {
        await _repository.saveAddress(
          label: result.label,
          recipientName: result.recipientName,
          phone: result.phone,
          addressLine: result.addressLine,
          village: result.village,
          district: result.district,
          city: result.city,
          state: result.state,
          postalCode: result.postalCode,
          deliveryInstructions: result.deliveryInstructions,
          country: result.country,
        );
      } else {
        final updatedAddress = UserAddressModel(
          id: address.id,
          userId: address.userId,
          label: result.label,
          recipientName: result.recipientName,
          phone: result.phone,
          addressLine: result.addressLine,
          village: result.village,
          district: result.district,
          city: result.city,
          state: result.state,
          postalCode: result.postalCode,
          country: result.country,
          deliveryInstructions: result.deliveryInstructions,
          isDefault: address.isDefault,
          createdAt: address.createdAt,
          updatedAt: DateTime.now().toUtc(),
        );

        await _repository.updateAddress(updatedAddress);
      }

      if (!mounted) return;

      _showMessage(
        address == null
            ? 'Address added successfully.'
            : 'Address updated successfully.',
      );

      await _loadAddresses();
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Unable to ${address == null ? 'add' : 'update'} address. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAddingAddress = false;
        });
      }
    }
  }

  Future<void> _setDefaultAddress(UserAddressModel address) async {
    if (address.isDefault) return;

    setState(() {
      _processingAddressId = address.id;
    });

    try {
      await _repository.setDefaultAddress(address.id);

      if (!mounted) return;

      _showMessage('Default address updated.');

      await _loadAddresses();
    } catch (error) {
      if (!mounted) return;

      _showMessage('Unable to update default address.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _processingAddressId = null;
        });
      }
    }
  }

  Future<void> _deleteAddress(UserAddressModel address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _surface,
          title: const Text(
            'Delete Address?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to delete this saved address?',
            style: TextStyle(color: _muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel', style: TextStyle(color: _muted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _processingAddressId = address.id;
    });

    try {
      await _repository.deleteAddress(address.id);

      if (!mounted) return;

      _showMessage('Address deleted successfully.');

      await _loadAddresses();
    } catch (error) {
      if (!mounted) return;

      _showMessage('Unable to delete this address.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _processingAddressId = null;
        });
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : _primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Addresses',
          style: AppTextStyles.headingMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildAddButton(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_addresses.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: _primary,
      backgroundColor: _surface,
      onRefresh: _loadAddresses,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          const Text(
            'DELIVERY LOCATIONS',
            style: TextStyle(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_addresses.length} saved ${_addresses.length == 1 ? 'address' : 'addresses'}',
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          const SizedBox(height: 20),
          ..._addresses.map(_buildAddressCard),
        ],
      ),
    );
  }

  Widget _buildAddressCard(UserAddressModel address) {
    final isProcessing = _processingAddressId == address.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: address.isDefault
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_primary.withValues(alpha: 0.13), _surface, _surface],
              )
            : null,
        color: address.isDefault ? null : _surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        border: Border.all(
          color: address.isDefault
              ? _primary.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.07),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getAddressIcon(address.label),
                  color: _primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  address.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (address.isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'DEFAULT',
                    style: TextStyle(
                      color: _gold,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            address.recipientName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            address.phone,
            style: const TextStyle(color: _muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Text(
            _formatAddress(address),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.6,
            ),
          ),
          if (address.deliveryInstructions?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              'Delivery instructions: ${address.deliveryInstructions}',
              style: const TextStyle(color: _muted, fontSize: 12, height: 1.5),
            ),
          ],
          const SizedBox(height: 18),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          const SizedBox(height: 10),
          if (isProcessing)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(
                  color: _primary,
                  strokeWidth: 2,
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!address.isDefault)
                  _buildActionButton(
                    label: 'Set Default',
                    icon: Icons.check_circle_outline,
                    color: _gold,
                    onPressed: () => _setDefaultAddress(address),
                  ),
                _buildActionButton(
                  label: 'Edit',
                  icon: Icons.edit_outlined,
                  color: _primary,
                  onPressed: () => _openAddressForm(address: address),
                ),
                _buildActionButton(
                  label: 'Delete',
                  icon: Icons.delete_outline,
                  color: Colors.redAccent,
                  onPressed: () => _deleteAddress(address),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 15),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.35)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on_outlined,
                color: _primary,
                size: 55,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Saved Addresses',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Add your delivery address to make checkout faster and easier.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 13, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 55),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _loadAddresses,
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

  Widget _buildAddButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: SizedBox(
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _isAddingAddress ? null : () => _openAddressForm(),
            icon: _isAddingAddress
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.add_location_alt_outlined),
            label: Text(
              _isAddingAddress ? 'Saving Address...' : 'Add New Address',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _primary.withValues(alpha: 0.5),
              elevation: 4,
              shadowColor: _primary.withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
              ),
              textStyle: AppTextStyles.buttonMedium,
            ),
          ),
        ),
      ),
    );
  }

  IconData _getAddressIcon(String label) {
    switch (label.toLowerCase()) {
      case 'home':
        return Icons.home_outlined;
      case 'work':
      case 'office':
        return Icons.work_outline;
      default:
        return Icons.location_on_outlined;
    }
  }

  String _formatAddress(UserAddressModel address) {
    return [
      address.addressLine,
      address.village,
      address.district,
      address.city,
      address.state,
      address.postalCode,
      address.country,
    ].where((part) => part != null && part.trim().isNotEmpty).join(', ');
  }
}

// ---------------------------------------------------------
// ADD / EDIT ADDRESS FORM
// ---------------------------------------------------------

class _AddressFormData {
  final String label;
  final String recipientName;
  final String phone;
  final String addressLine;
  final String? village;
  final String? district;
  final String city;
  final String? state;
  final String? postalCode;
  final String country;
  final String? deliveryInstructions;

  const _AddressFormData({
    required this.label,
    required this.recipientName,
    required this.phone,
    required this.addressLine,
    this.village,
    this.district,
    required this.city,
    this.state,
    this.postalCode,
    required this.country,
    this.deliveryInstructions,
  });
}

class _AddressFormSheet extends StatefulWidget {
  final UserAddressModel? address;

  const _AddressFormSheet({this.address});

  @override
  State<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<_AddressFormSheet> {
  static const Color _primary = Color(0xFF8B5CF6);
  static const Color _muted = Color(0xFF9A9AAF);
  static const Color _fieldBackground = Color(0xFF0B0B12);

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _villageController;
  late final TextEditingController _districtController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _countryController;
  late final TextEditingController _postalController;
  late final TextEditingController _instructionsController;

  List<GlobalLocation> _countries = [];
  List<GlobalLocation> _states = [];
  List<GlobalLocation> _cities = [];

  GlobalLocation? _selectedCountry;
  GlobalLocation? _selectedState;
  GlobalLocation? _selectedCity;

  bool _isLoadingCountries = false;
  bool _isLoadingStates = false;
  bool _isLoadingCities = false;

  String? _locationError;
  String _label = 'Home';
  String? _completePhone;

  int _stateRequestId = 0;
  int _cityRequestId = 0;

  @override
  void initState() {
    super.initState();

    final address = widget.address;

    _nameController = TextEditingController(text: address?.recipientName ?? '');
    _phoneController = TextEditingController(text: address?.phone ?? '');
    _addressController = TextEditingController(
      text: address?.addressLine ?? '',
    );
    _villageController = TextEditingController(text: address?.village ?? '');
    _districtController = TextEditingController(text: address?.district ?? '');
    _cityController = TextEditingController(text: address?.city ?? '');
    _stateController = TextEditingController(text: address?.state ?? '');
    _countryController = TextEditingController(
      text: address?.country ?? 'Indonesia',
    );
    _postalController = TextEditingController(text: address?.postalCode ?? '');
    _instructionsController = TextEditingController(
      text: address?.deliveryInstructions ?? '',
    );

    _label = address?.label ?? 'Home';
    _completePhone = address?.phone;

    // Initialize controllers before starting asynchronous location loading.
    _loadCountries();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _villageController.dispose();
    _districtController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _postalController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _loadCountries() async {
    setState(() {
      _isLoadingCountries = true;
      _locationError = null;
    });

    try {
      final countries = await GlobalLocationService.getCountries();
      if (!mounted) return;

      final savedCountry = _countryController.text.trim();
      GlobalLocation? match;

      for (final country in countries) {
        if (country.name.toLowerCase() == savedCountry.toLowerCase()) {
          match = country;
          break;
        }
      }

      // Indonesia is only the default for a new address, not a restriction.
      if (match == null && widget.address == null) {
        for (final country in countries) {
          if (country.name.toLowerCase() == 'indonesia') {
            match = country;
            break;
          }
        }
      }

      setState(() {
        _countries = countries;
        _selectedCountry = match;
        _isLoadingCountries = false;
        if (match != null) {
          _countryController.text = match.name;
        }
      });

      if (match != null) {
        await _loadStates(match.name, restoreSavedLocation: true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingCountries = false;
        _locationError = 'Location list is temporarily unavailable. You can enter locations manually.';
      });
    }
  }

  Future<void> _onCountryChanged(GlobalLocation? country) async {
    if (country == null) return;

    setState(() {
      _selectedCountry = country;
      _countryController.text = country.name;
      _selectedState = null;
      _selectedCity = null;
      _states = [];
      _cities = [];
      _stateController.clear();
      _cityController.clear();
      _locationError = null;
    });

    await _loadStates(country.name);
  }

  Future<void> _loadStates(
    String country, {
    bool restoreSavedLocation = false,
  }) async {
    final requestId = ++_stateRequestId;
    ++_cityRequestId;

    setState(() {
      _isLoadingStates = true;
      _isLoadingCities = false;
      _states = [];
      _cities = [];
      _selectedState = null;
      _selectedCity = null;
      if (!restoreSavedLocation) {
        _stateController.clear();
        _cityController.clear();
      }
    });

    try {
      final states = await GlobalLocationService.getStates(country);
      if (!mounted || requestId != _stateRequestId) return;

      GlobalLocation? selected;
      final savedState = restoreSavedLocation
          ? widget.address?.state?.trim()
          : null;

      if (savedState != null && savedState.isNotEmpty) {
        for (final state in states) {
          if (state.name.toLowerCase() == savedState.toLowerCase()) {
            selected = state;
            break;
          }
        }
      }

      setState(() {
        _states = states;
        _selectedState = selected;
        _isLoadingStates = false;
        if (selected != null) {
          _stateController.text = selected.name;
        }
      });

      if (selected != null) {
        await _loadCities(country, selected.name, restoreSavedLocation: true);
      }
    } catch (_) {
      if (!mounted || requestId != _stateRequestId) return;
      setState(() {
        _isLoadingStates = false;
        _states = [];
      });
    }
  }

  Future<void> _onStateChanged(GlobalLocation? state) async {
    if (state == null || _selectedCountry == null) return;

    setState(() {
      _selectedState = state;
      _stateController.text = state.name;
      _selectedCity = null;
      _cities = [];
      _cityController.clear();
    });

    await _loadCities(_selectedCountry!.name, state.name);
  }

  Future<void> _loadCities(
    String country,
    String state, {
    bool restoreSavedLocation = false,
  }) async {
    final requestId = ++_cityRequestId;

    setState(() {
      _isLoadingCities = true;
      _cities = [];
      _selectedCity = null;
      if (!restoreSavedLocation) {
        _cityController.clear();
      }
    });

    try {
      final cities = await GlobalLocationService.getCities(country, state);
      if (!mounted || requestId != _cityRequestId) return;

      GlobalLocation? selected;
      final savedCity = restoreSavedLocation
          ? widget.address?.city.trim()
          : null;

      if (savedCity != null && savedCity.isNotEmpty) {
        for (final city in cities) {
          if (city.name.toLowerCase() == savedCity.toLowerCase()) {
            selected = city;
            break;
          }
        }
      }

      setState(() {
        _cities = cities;
        _selectedCity = selected;
        _isLoadingCities = false;
        if (selected != null) {
          _cityController.text = selected.name;
        }
      });
    } catch (_) {
      if (!mounted || requestId != _cityRequestId) return;
      setState(() {
        _isLoadingCities = false;
        _cities = [];
      });
    }
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _muted),
      prefixIcon: Icon(icon, color: _muted, size: 20),
      filled: true,
      fillColor: _fieldBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: _primary),
      ),
    );
  }

  Widget _textField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    bool requiredField = true,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: _decoration(label, icon),
      validator: (value) {
        if (requiredField && (value == null || value.trim().isEmpty)) {
          return '$label is required.';
        }
        return null;
      },
    );
  }

  Widget _locationDropdown({
    required String label,
    required IconData icon,
    required List<GlobalLocation> items,
    required GlobalLocation? value,
    required ValueChanged<GlobalLocation?>? onChanged,
    bool isLoading = false,
    bool requiredField = true,
  }) {
    return FormField<GlobalLocation>(
      initialValue: value,
      validator: requiredField
          ? (selected) => selected == null ? 'Please select $label.' : null
          : null,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: isLoading || items.isEmpty
                  ? null
                  : () async {
                      final selected = await _openLocationPicker(
                        label: label,
                        items: items,
                        selectedValue: field.value,
                      );

                      if (selected != null) {
                        field.didChange(selected);
                        onChanged?.call(selected);
                      }
                    },
              child: InputDecorator(
                decoration: _decoration('', icon).copyWith(
                  labelText: null,
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                  errorText: field.errorText,
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
                      : const Icon(Icons.keyboard_arrow_down, color: _muted),
                ),
                child: SizedBox(
                  height: 22,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      isLoading
                          ? 'Loading...'
                          : field.value?.name ?? 'Select $label',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: field.value == null ? _muted : Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
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
      backgroundColor: const Color(0xFF171722),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return _LocationPickerSheet(
          label: label,
          items: items,
          selectedValue: selectedValue,
        );
      },
    );
  }

  void _submit() {
    FocusScope.of(context).unfocus();

    final form = _formKey.currentState;

    if (form == null) {
      _showFormMessage('Unable to validate the address form.');
      return;
    }

    if (!form.validate()) {
      _showFormMessage('Please correct the highlighted fields.');
      return;
    }

    final phone = (_completePhone ?? '').trim().isNotEmpty
        ? _completePhone!.trim()
        : _phoneController.text.trim();

    if (phone.isEmpty) {
      _showFormMessage('Phone number is required.');
      return;
    }

    final country = _selectedCountry?.name ?? _countryController.text.trim();

    if (country.isEmpty) {
      _showFormMessage('Please select or enter a country.');
      return;
    }

    final city = _selectedCity?.name ?? _cityController.text.trim();
    final state = _selectedState?.name ?? _stateController.text.trim();

    if (city.isEmpty) {
      _showFormMessage('City is required.');
      return;
    }

    Navigator.pop(
      context,
      _AddressFormData(
        label: _label,
        recipientName: _nameController.text.trim(),
        phone: phone,
        addressLine: _addressController.text.trim(),
        village: _villageController.text.trim().isEmpty
            ? null
            : _villageController.text.trim(),
        district: _districtController.text.trim().isEmpty
            ? null
            : _districtController.text.trim(),
        city: city,
        state: state.isEmpty ? null : state,
        postalCode: _postalController.text.trim().isEmpty
            ? null
            : _postalController.text.trim(),
        country: country,
        deliveryInstructions: _instructionsController.text.trim().isEmpty
            ? null
            : _instructionsController.text.trim(),
      ),
    );
  }

  void _showFormMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.88,
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
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.address == null
                            ? 'Add New Address'
                            : 'Edit Address',
                        style: AppTextStyles.headingMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(22, 5, 22, 25),
                    children: [
                      const Text(
                        'ADDRESS LABEL',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        children: ['Home', 'Work', 'Other'].map((label) {
                          final selected = _label == label;
                          return ChoiceChip(
                            label: Text(label),
                            selected: selected,
                            onSelected: (_) {
                              setState(() => _label = label);
                            },
                            selectedColor: _primary,
                            backgroundColor: _fieldBackground,
                            labelStyle: TextStyle(
                              color: selected ? Colors.white : _muted,
                            ),
                            side: BorderSide(
                              color: selected ? _primary : Colors.white12,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 22),
                      _textField(
                        label: 'Recipient Name',
                        icon: Icons.person_outline,
                        controller: _nameController,
                      ),
                      const SizedBox(height: 15),
                      IntlPhoneField(
                        controller: _phoneController,
                        initialCountryCode: 'ID',
                        disableLengthCheck: false,
                        style: const TextStyle(color: Colors.white),
                        dropdownTextStyle: const TextStyle(color: Colors.white),
                        dropdownIcon: const Icon(
                          Icons.arrow_drop_down,
                          color: _muted,
                        ),
                        decoration: _decoration(
                          'Phone Number',
                          Icons.phone_outlined,
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
                      const SizedBox(height: 15),
                      _textField(
                        label: 'Street Address',
                        icon: Icons.location_on_outlined,
                        controller: _addressController,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'LOCATION',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_countries.isNotEmpty)
                        _locationDropdown(
                          label: 'Country',
                          icon: Icons.public,
                          items: _countries,
                          value: _selectedCountry,
                          isLoading: _isLoadingCountries,
                          onChanged: _onCountryChanged,
                        )
                      else ...[
                        if (_isLoadingCountries)
                          const LinearProgressIndicator(color: _primary),
                        if (_locationError != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              _locationError!,
                              style: const TextStyle(
                                color: Colors.orangeAccent,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        _textField(
                          label: 'Country',
                          icon: Icons.public,
                          controller: _countryController,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _isLoadingCountries
                                ? null
                                : _loadCountries,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Retry location list'),
                            style: TextButton.styleFrom(
                              foregroundColor: _primary,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 15),
                      if (_states.isNotEmpty)
                        _locationDropdown(
                          label: 'State / Province / Region',
                          icon: Icons.map_outlined,
                          items: _states,
                          value: _selectedState,
                          isLoading: _isLoadingStates,
                          onChanged: _onStateChanged,
                          requiredField: false,
                        )
                      else ...[
                        if (_isLoadingStates)
                          const LinearProgressIndicator(color: _primary),
                        _textField(
                          label: 'State / Province / Region (if applicable)',
                          icon: Icons.map_outlined,
                          controller: _stateController,
                          requiredField: false,
                        ),
                      ],
                      const SizedBox(height: 15),
                      if (_cities.isNotEmpty)
                        _locationDropdown(
                          label: 'City',
                          icon: Icons.location_city,
                          items: _cities,
                          value: _selectedCity,
                          isLoading: _isLoadingCities,
                          onChanged: (city) {
                            if (city == null) return;
                            setState(() {
                              _selectedCity = city;
                              _cityController.text = city.name;
                            });
                          },
                        )
                      else ...[
                        if (_isLoadingCities)
                          const LinearProgressIndicator(color: _primary),
                        _textField(
                          label: 'City / Town',
                          icon: Icons.location_city,
                          controller: _cityController,
                        ),
                      ],
                      const SizedBox(height: 15),
                      _textField(
                        label: 'Village / Neighborhood (Optional)',
                        icon: Icons.location_city_outlined,
                        controller: _villageController,
                        requiredField: false,
                      ),
                      const SizedBox(height: 15),
                      _textField(
                        label: 'District / County (Optional)',
                        icon: Icons.map_outlined,
                        controller: _districtController,
                        requiredField: false,
                      ),
                      const SizedBox(height: 15),
                      _textField(
                        label: 'Postal Code (Optional)',
                        icon: Icons.markunread_mailbox_outlined,
                        controller: _postalController,
                        requiredField: false,
                        keyboardType: TextInputType.text,
                      ),
                      const SizedBox(height: 15),
                      _textField(
                        label: 'Delivery Instructions (Optional)',
                        icon: Icons.delivery_dining_outlined,
                        controller: _instructionsController,
                        requiredField: false,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 25),
                      SizedBox(
                        height: 53,
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            widget.address == null
                                ? 'Save Address'
                                : 'Update Address',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
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

// ---------------------------------------------------------
// SEARCHABLE LOCATION PICKER
// ---------------------------------------------------------

class _LocationPickerSheet extends StatefulWidget {
  final String label;
  final List<GlobalLocation> items;
  final GlobalLocation? selectedValue;

  const _LocationPickerSheet({
    required this.label,
    required this.items,
    required this.selectedValue,
  });

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  static const Color _primary = Color(0xFF8B5CF6);
  static const Color _muted = Color(0xFF9A9AAF);
  static const Color _fieldBackground = Color(0xFF0B0B12);

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

    if (query.isEmpty) {
      return widget.items;
    }

    return widget.items.where((item) {
      return item.name.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = mediaQuery.viewInsets.bottom;

    final availableHeight = (mediaQuery.size.height - keyboardHeight).clamp(
      250.0,
      mediaQuery.size.height,
    );

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
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
                        style: AppTextStyles.headingMedium.copyWith(
                          color: Colors.white,
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
                  onChanged: (_) {
                    setState(() {});
                  },
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
                    fillColor: _fieldBackground,
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off, color: _muted, size: 42),
                            SizedBox(height: 12),
                            Text(
                              'No locations found.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
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
