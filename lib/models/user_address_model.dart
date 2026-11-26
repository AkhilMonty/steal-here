class UserAddressModel {
  final String id;
  final String userId;
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
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserAddressModel({
    required this.id,
    required this.userId,
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
    required this.isDefault,
    this.createdAt,
    this.updatedAt,
  });

  factory UserAddressModel.fromMap(Map<String, dynamic> map) {
    return UserAddressModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      label: map['label'] as String? ?? 'Home',
      recipientName: map['recipient_name'] as String,
      phone: map['phone'] as String,
      addressLine: map['address_line'] as String,
      village: map['village'] as String?,
      district: map['district'] as String?,
      city: map['city'] as String,
      state: map['state'] as String?,
      postalCode: map['postal_code'] as String?,
      country: map['country'] as String? ?? 'Indonesia',
      deliveryInstructions: map['delivery_instructions'] as String?,
      isDefault: map['is_default'] as bool? ?? false,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] == null
          ? null
          : DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'label': label,
      'recipient_name': recipientName,
      'phone': phone,
      'address_line': addressLine,
      'village': village,
      'district': district,
      'city': city,
      'state': state,
      'postal_code': postalCode,
      'country': country,
      'delivery_instructions': deliveryInstructions,
      'is_default': isDefault,
    };
  }
}
