import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order_item_model.dart';
import '../models/order_model.dart';
import 'notification_repository.dart';

class OrderRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  String get _userId {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw StateError('Please login to view your orders.');
    }

    return user.id;
  }

  // =====================================================
  // FETCH ALL ORDERS
  // =====================================================

  Future<List<OrderModel>> getOrders() async {
    final ordersResponse = await _supabase
        .from('orders')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false);

    final orders = List<Map<String, dynamic>>.from(ordersResponse);

    if (orders.isEmpty) {
      return [];
    }

    final orderIds = orders.map((order) => order['id'] as String).toList();

    final itemsResponse = await _supabase
        .from('order_items')
        .select()
        .inFilter('order_id', orderIds)
        .order('created_at', ascending: true);

    final items = List<Map<String, dynamic>>.from(itemsResponse);

    final Map<String, List<OrderItemModel>> groupedItems = {};

    for (final itemJson in items) {
      final item = OrderItemModel.fromJson(itemJson);

      groupedItems.putIfAbsent(item.orderId, () => []);
      groupedItems[item.orderId]!.add(item);
    }

    return orders.map((orderJson) {
      final orderId = orderJson['id'] as String;

      return OrderModel.fromJson({
        ...orderJson,
        'order_items': groupedItems[orderId] ?? [],
      });
    }).toList();
  }

  // =====================================================
  // FETCH ONE ORDER
  // =====================================================

  Future<OrderModel?> getOrderById(String orderId) async {
    final orderResponse = await _supabase
        .from('orders')
        .select()
        .eq('id', orderId)
        .eq('user_id', _userId)
        .maybeSingle();

    if (orderResponse == null) {
      return null;
    }

    final itemsResponse = await _supabase
        .from('order_items')
        .select()
        .eq('order_id', orderId)
        .order('created_at', ascending: true);

    final items = List<Map<String, dynamic>>.from(itemsResponse)
        .map(OrderItemModel.fromJson)
        .toList();

    return OrderModel.fromJson({
      ...orderResponse,
      'order_items': items,
    });
  }

  // =====================================================
  // REQUEST ORDER CANCELLATION
  // =====================================================

  Future<void> requestOrderCancellation({
    required String orderId,
    required String reason,
    String? customerNote,
  }) async {
    await _supabase.rpc(
      'request_order_cancellation',
      params: {
        'p_order_id': orderId,
        'p_reason': reason,
        'p_customer_note': customerNote,
      },
    );

    // The existing database trigger automatically
    // creates the cancellation notification.
  }

  // =====================================================
  // REQUEST ORDER RETURN
  // =====================================================

  Future<Map<String, dynamic>> requestOrderReturn({
    required String orderId,
    required String reason,
    String? customerNote,
  }) async {
    final response = await _supabase.rpc(
      'request_order_return',
      params: {
        'p_order_id': orderId,
        'p_reason': reason,
        'p_customer_note': customerNote,
      },
    );

    final result = Map<String, dynamic>.from(response as Map);

    // Notification failure must not undo a return request.
    try {
      await NotificationRepository().createNotification(
        title: 'Return Request Submitted',
        message:
        'Your return request for order $orderId has been submitted '
            'and is awaiting review.',
        category: 'order',
        relatedOrderId: orderId,
        metadata: {
          'event': 'return_request_submitted',
          'request_id': result['request_id'],
        },
        dedupeKey: 'return_request_${result['request_id']}',
      );
    } catch (error) {
      // ignore: avoid_print
      print('RETURN NOTIFICATION ERROR: $error');
    }

    return result;
  }

  // =====================================================
  // FETCH CANCELLATION REQUEST
  // =====================================================

  Future<Map<String, dynamic>?> getCancellationRequest(
      String orderId,
      ) async {
    final response = await _supabase
        .from('order_cancellation_requests')
        .select()
        .eq('order_id', orderId)
        .eq('user_id', _userId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return Map<String, dynamic>.from(response);
  }

  // =====================================================
  // FETCH RETURN REQUEST HISTORY
  // =====================================================

  Future<List<Map<String, dynamic>>> getReturnRequests(
      String orderId,
      ) async {
    final response = await _supabase
        .from('order_return_requests')
        .select()
        .eq('order_id', orderId)
        .eq('user_id', _userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // =====================================================
  // FETCH RETURN STATUS TRACKING HISTORY
  // =====================================================

  Future<List<Map<String, dynamic>>> getReturnStatusHistory(
      String returnRequestId,
      ) async {
    final response = await _supabase
        .from('order_return_status_history')
        .select()
        .eq('return_request_id', returnRequestId)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  // =====================================================
  // FETCH RETURN REQUESTS FOR MULTIPLE ORDERS
  // =====================================================

  Future<List<Map<String, dynamic>>> getReturnRequestsForOrders(
      List<String> orderIds,
      ) async {
    if (orderIds.isEmpty) {
      return [];
    }

    final response = await _supabase
        .from('order_return_requests')
        .select()
        .eq('user_id', _userId)
        .inFilter('order_id', orderIds)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // =====================================================
  // FETCH COMPLETED RETURN ORDER IDS
  // =====================================================

  Future<Set<String>> getCompletedReturnedOrderIds(
      List<String> orderIds,
      ) async {
    if (orderIds.isEmpty) {
      return {};
    }

    final response = await _supabase
        .from('order_return_requests')
        .select('order_id')
        .eq('user_id', _userId)
        .inFilter('order_id', orderIds)
        .eq('status', 'completed');

    return {
      for (final item in response) item['order_id'] as String,
    };
  }
}