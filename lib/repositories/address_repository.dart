import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_address_model.dart';
import 'notification_repository.dart';

class AddressRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  final NotificationRepository _notificationRepository =
      NotificationRepository();

  String get _userId {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw const AuthException('You must be logged in to manage addresses.');
    }

    return user.id;
  }

  Future<void> _createAddressNotification({
    required String title,
    required String message,
    required String event,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _notificationRepository.createNotification(
        title: title,
        message: message,
        category: 'account',
        metadata: {'event': event, ...?metadata},
      );
    } catch (error) {
      debugPrint('ADDRESS NOTIFICATION ERROR: $error');
    }
  }

  // Fetch all saved addresses.
  Future<List<UserAddressModel>> getAddresses() async {
    final response = await _supabase
        .from('user_addresses')
        .select()
        .eq('user_id', _userId)
        .order('is_default', ascending: false)
        .order('created_at', ascending: false);

    return response.map((item) => UserAddressModel.fromMap(item)).toList();
  }

  // Save a new address.
  // Save a new address.
  Future<UserAddressModel> saveAddress({
    required String label,
    required String recipientName,
    required String phone,
    required String addressLine,
    String? village,
    String? district,
    required String city,
    String? state,
    String? postalCode,
    String? deliveryInstructions,
    String country = 'Indonesia',
  }) async {
    final addresses = await getAddresses();

    final addressData = {
      'user_id': _userId,
      'label': label,
      'recipient_name': recipientName,
      'phone': phone,
      'address_line': addressLine,
      'village': village,
      'district': district,
      'city': city,
      'state': state,
      'postal_code': postalCode,
      'delivery_instructions': deliveryInstructions,
      'country': country,
      'is_default': addresses.isEmpty,
    };

    final response = await _supabase
        .from('user_addresses')
        .insert(addressData)
        .select()
        .single();

    final savedAddress = UserAddressModel.fromMap(response);

    await _createAddressNotification(
      title: 'Delivery Address Added',
      message:
          'Your ${savedAddress.label} delivery address has been saved successfully.',
      event: 'address_added',
      metadata: {
        'address_id': savedAddress.id,
        'label': savedAddress.label,
        'city': savedAddress.city,
        'is_default': addresses.isEmpty,
      },
    );

    return savedAddress;
  }

  // Update an existing address.
  // Update an existing address without changing its default status.
  Future<UserAddressModel> updateAddress(UserAddressModel address) async {
    final updateData = address.toInsertMap()
      ..remove('is_default')
      ..['updated_at'] = DateTime.now().toUtc().toIso8601String();

    final response = await _supabase
        .from('user_addresses')
        .update(updateData)
        .eq('id', address.id)
        .eq('user_id', _userId)
        .select()
        .single();

    final updatedAddress = UserAddressModel.fromMap(response);

    await _createAddressNotification(
      title: 'Delivery Address Updated',
      message:
          'Your ${updatedAddress.label} delivery address was updated successfully.',
      event: 'address_updated',
      metadata: {
        'address_id': updatedAddress.id,
        'label': updatedAddress.label,
        'city': updatedAddress.city,
      },
    );

    return updatedAddress;
  }

  // Delete an address.
  // Delete an address and assign a new default if necessary.
  Future<void> deleteAddress(String addressId) async {
    final existingAddress = await _supabase
        .from('user_addresses')
        .select('label, city, is_default')
        .eq('id', addressId)
        .eq('user_id', _userId)
        .maybeSingle();

    if (existingAddress == null) {
      return;
    }

    final wasDefault = existingAddress['is_default'] == true;
    final label = existingAddress['label'] as String;
    final city = existingAddress['city'] as String;

    await _supabase
        .from('user_addresses')
        .delete()
        .eq('id', addressId)
        .eq('user_id', _userId);

    if (wasDefault) {
      final remainingAddresses = await getAddresses();

      if (remainingAddresses.isNotEmpty) {
        await setDefaultAddress(remainingAddresses.first.id);
      }
    }

    await _createAddressNotification(
      title: 'Delivery Address Removed',
      message: 'Your $label delivery address in $city was removed.',
      event: 'address_deleted',
      metadata: {
        'address_id': addressId,
        'label': label,
        'city': city,
        'was_default': wasDefault,
      },
    );
  }

  // Set an address as the default address.
  // Set an address as the default address.
  Future<void> setDefaultAddress(String addressId) async {
    final address = await _supabase
        .from('user_addresses')
        .select('id, label, city, is_default')
        .eq('id', addressId)
        .eq('user_id', _userId)
        .maybeSingle();

    await _supabase.rpc(
      'set_default_user_address',
      params: {'p_address_id': addressId},
    );

    // Do not notify if the address was already the default.
    if (address == null || address['is_default'] == true) {
      return;
    }

    await _createAddressNotification(
      title: 'Default Address Changed',
      message:
      'Your ${address['label']} address in ${address['city']} is now your default delivery address.',
      event: 'default_address_changed',
      metadata: {
        'address_id': addressId,
        'label': address['label'],
        'city': address['city'],
      },
    );
  }
}
