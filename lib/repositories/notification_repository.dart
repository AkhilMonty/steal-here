import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_model.dart';

class NotificationRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const int defaultPageSize = 20;

  String get _userId {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw StateError('Please login to access notifications.');
    }

    return user.id;
  }

  // Fetch notifications with pagination and optional category filtering.
  Future<List<NotificationModel>> getNotifications({
    int page = 0,
    int limit = defaultPageSize,
    String? category,
    bool? unreadOnly,
  }) async {
    if (page < 0 || limit <= 0) {
      throw ArgumentError('Invalid notification pagination values.');
    }

    final start = page * limit;
    final end = start + limit - 1;

    var query = _supabase
        .from('notifications')
        .select()
        .eq('user_id', _userId);

    if (category == 'returns') {
      query = query.eq(
        'metadata->>event',
        'return_request_submitted',
      );
    } else if (category != null && category != 'all') {
      query = query.eq('category', category);
    }

    if (unreadOnly == true) {
      query = query.eq('is_read', false);
    }

    final response = await query
        .order('created_at', ascending: false)
        .range(start, end);

    return (response as List)
        .map(
          (item) => NotificationModel.fromMap(
        Map<String, dynamic>.from(item as Map),
      ),
    )
        .toList();
  }

  // Fetch account and security activity with pagination.
  Future<List<NotificationModel>> getAccountActivity({
    int page = 0,
    int limit = 20,
  }) async {
    if (page < 0 || limit <= 0) {
      throw ArgumentError('Invalid activity pagination values.');
    }

    final start = page * limit;
    final end = start + limit - 1;

    final response = await _supabase
        .from('notifications')
        .select()
        .eq('user_id', _userId)
        .inFilter('category', ['account', 'security'])
        .order('created_at', ascending: false)
        .range(start, end);

    return (response as List)
        .map(
          (item) => NotificationModel.fromMap(
        Map<String, dynamic>.from(item as Map),
      ),
    )
        .toList();
  }

  // Fetch unread notification count.
  Future<int> getUnreadCount() async {
    final response = await _supabase
        .from('notifications')
        .select('id')
        .eq('user_id', _userId)
        .eq('is_read', false);

    return (response as List).length;
  }

  // Create a notification for the currently logged-in user.
  Future<void> createNotification({
    required String title,
    required String message,
    required String category,
    String? relatedProductId,
    String? relatedOrderId,
    Map<String, dynamic> metadata = const {},
    String? dedupeKey,
  }) async {
    final userId = _userId;

    try {
      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': title.trim(),
        'message': message.trim(),
        'category': category,
        'related_product_id': relatedProductId,
        'related_order_id': relatedOrderId,
        'metadata': metadata,
        'dedupe_key': dedupeKey,
      });
    } on PostgrestException catch (error) {
      // Ignore duplicate notifications only when deduplication was requested.
      if (error.code == '23505' && dedupeKey != null) {
        return;
      }

      rethrow;
    }
  }

  // Mark one notification as read.
  Future<void> markAsRead(String notificationId) async {
    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId)
        .eq('user_id', _userId);
  }

  // Mark all notifications as read.
  Future<void> markAllAsRead() async {
    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', _userId)
        .eq('is_read', false);
  }

  // Delete one notification.
  Future<void> deleteNotification(String notificationId) async {
    await _supabase
        .from('notifications')
        .delete()
        .eq('id', notificationId)
        .eq('user_id', _userId);
  }

  // Delete all notifications belonging to the logged-in user.
  Future<void> clearAllNotifications() async {
    await _supabase
        .from('notifications')
        .delete()
        .eq('user_id', _userId);
  }

  // Subscribe to live changes for the logged-in user's notifications.
  RealtimeChannel subscribeToNotifications({
    required void Function() onChanged,
  }) {
    final userId = _userId;

    return _supabase
        .channel('notifications_$userId')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (_) => onChanged(),
    )
        .subscribe();
  }

  // Unsubscribe from notification updates.
  Future<void> unsubscribeFromNotifications(
      RealtimeChannel channel,
      ) async {
    await _supabase.removeChannel(channel);
  }
}