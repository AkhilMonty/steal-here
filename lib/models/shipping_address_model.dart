class ShippingAddressModel {
  final String recipientName;
  final String phone;
  final String addressLine;
  final String city;
  final String? state;
  final String? postalCode;
  final String country;
  final String? customerNote;

  const ShippingAddressModel({
    required this.recipientName,
    required this.phone,
    required this.addressLine,
    required this.city,
    this.state,
    this.postalCode,
    this.country = 'Indonesia',
    this.customerNote,
  });
}
