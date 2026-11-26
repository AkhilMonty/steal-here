import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/budget_model.dart';
import 'notification_repository.dart';

class BudgetRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  final NotificationRepository _notificationRepository =
      NotificationRepository();

  String get _userId {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw StateError('Please login to manage your budget.');
    }

    return user.id;
  }

  Future<void> _createBudgetNotification({
    required String title,
    required String message,
    required String event,
    required Map<String, dynamic> metadata,
    String? dedupeKey,
  }) async {
    try {
      await _notificationRepository.createNotification(
        title: title,
        message: message,
        category: 'budget',
        metadata: {'event': event, ...metadata},
        dedupeKey: dedupeKey,
      );
    } catch (error) {
      debugPrint('BUDGET NOTIFICATION ERROR: $error');
    }
  }

  // Get the first day of a particular month.
  DateTime _getMonthStart(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  // Format a date for the PostgreSQL DATE column.
  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$year-$month-01';
  }

  // Get the current month's budget.
  Future<BudgetModel?> getCurrentMonthBudget() async {
    final now = DateTime.now();
    final monthStart = _getMonthStart(now);

    // Check whether the previous month had a budget.
    final previousMonth = DateTime(now.year, now.month - 1, 1);

    final previousBudget = await getMonthlyBudget(previousMonth);

    if (previousBudget != null) {
      await _createBudgetNotification(
        title: 'New Budget Month Started',
        message: 'A new month has started! Set your shopping budget and stay in control of your spending.',
        event: 'monthly_budget_reset',
        metadata: {
          'previous_month': _formatDate(previousMonth),
          'current_month': _formatDate(monthStart),
          'previous_budget_amount': previousBudget.budgetAmount,
        },
        dedupeKey: 'budget_reset_${_formatDate(monthStart)}',
      );
    }

    final response = await _supabase
        .from('budgets')
        .select()
        .eq('user_id', _userId)
        .eq('month_start', _formatDate(monthStart))
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return BudgetModel.fromMap(response);
  }

  // Get the budget for a specific month.
  Future<BudgetModel?> getMonthlyBudget(DateTime month) async {
    final monthStart = _getMonthStart(month);

    final response = await _supabase
        .from('budgets')
        .select()
        .eq('user_id', _userId)
        .eq('month_start', _formatDate(monthStart))
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return BudgetModel.fromMap(response);
  }

  // Create or update a monthly budget.
  Future<BudgetModel> saveMonthlyBudget({
    required double budgetAmount,
    DateTime? month,
  }) async {
    if (!budgetAmount.isFinite || budgetAmount <= 0) {
      throw ArgumentError(
        'Budget amount must be a valid number greater than zero.',
      );
    }

    final now = DateTime.now();
    final monthStart = _getMonthStart(month ?? now);

    final existingBudget = await getMonthlyBudget(monthStart);

    final response = await _supabase
        .from('budgets')
        .upsert({
          'user_id': _userId,
          'month_start': _formatDate(monthStart),
          'budget_amount': budgetAmount,
          'updated_at': now.toUtc().toIso8601String(),
        }, onConflict: 'user_id,month_start')
        .select()
        .single();

    final savedBudget = BudgetModel.fromMap(response);

    await _createBudgetNotification(
      title: existingBudget == null
          ? 'Monthly Budget Created'
          : 'Monthly Budget Updated',
      message: existingBudget == null
          ? 'Your monthly shopping budget has been set successfully.'
          : 'Your monthly shopping budget has been updated successfully.',
      event: existingBudget == null ? 'budget_created' : 'budget_updated',
      metadata: {
        'month_start': _formatDate(monthStart),
        'budget_amount': budgetAmount,
        'previous_budget_amount': existingBudget?.budgetAmount,
      },
    );

    return savedBudget;
  }

  // Delete a monthly budget.
  Future<void> deleteMonthlyBudget({DateTime? month}) async {
    final monthStart = _getMonthStart(month ?? DateTime.now());

    final existingBudget = await getMonthlyBudget(monthStart);

    if (existingBudget == null) {
      return;
    }

    await _supabase
        .from('budgets')
        .delete()
        .eq('user_id', _userId)
        .eq('month_start', _formatDate(monthStart));

    await _createBudgetNotification(
      title: 'Monthly Budget Deleted',
      message: 'Your monthly shopping budget has been removed.',
      event: 'budget_deleted',
      metadata: {
        'month_start': _formatDate(monthStart),
        'previous_budget_amount': existingBudget.budgetAmount,
      },
    );
  }

  // Get all saved monthly budgets, newest month first.
  Future<List<BudgetModel>> getBudgetHistory() async {
    final response = await _supabase
        .from('budgets')
        .select()
        .eq('user_id', _userId)
        .order('month_start', ascending: false);

    return (response as List)
        .map((item) => BudgetModel.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  // Calculate spending for multiple budget months efficiently.
  Future<Map<String, double>> getMonthlySpendingForMonths(
    List<DateTime> months,
  ) async {
    if (months.isEmpty) {
      return {};
    }

    // Normalize and sort the requested months.
    final selectedMonths = months.map(_getMonthStart).toSet().toList()..sort();

    final spendingByMonth = <String, double>{
      for (final month in selectedMonths)
        '${month.year}-${month.month.toString().padLeft(2, '0')}': 0,
    };

    final firstMonth = selectedMonths.first;

    final lastMonth = selectedMonths.last;

    final startDate = firstMonth;

    final endDate = DateTime(lastMonth.year, lastMonth.month + 1, 1);

    // Fetch paid, non-cancelled orders across the requested date range.
    final response = await _supabase
        .from('orders')
        .select('id, total_amount, created_at')
        .eq('user_id', _userId)
        .inFilter('status', [
          'pending',
          'confirmed',
          'processing',
          'shipped',
          'delivered',
        ])
        .not('payment_status', 'in', '(failed,refunded)')
        .gte('created_at', startDate.toUtc().toIso8601String())
        .lt('created_at', endDate.toUtc().toIso8601String());

    final orders = List<Map<String, dynamic>>.from(response);

    if (orders.isEmpty) {
      return spendingByMonth;
    }

    // Fetch completed returns for all matching orders in one request.
    final orderIds = orders.map((order) => order['id'] as String).toList();

    final returnResponse = await _supabase
        .from('order_return_requests')
        .select('order_id')
        .inFilter('order_id', orderIds)
        .eq('status', 'completed');

    final returnedOrderIds = <String>{
      for (final item in returnResponse) item['order_id'] as String,
    };

    // Group eligible spending by calendar month.
    for (final order in orders) {
      final orderId = order['id'] as String;

      if (returnedOrderIds.contains(orderId)) {
        continue;
      }

      final amount = order['total_amount'];
      final createdAt = order['created_at'];

      if (amount is! num || createdAt is! String) {
        continue;
      }

      final orderDate = DateTime.parse(createdAt).toLocal();

      final monthKey =
          '${orderDate.year}-${orderDate.month.toString().padLeft(2, '0')}';

      if (spendingByMonth.containsKey(monthKey)) {
        spendingByMonth[monthKey] =
            spendingByMonth[monthKey]! + amount.toDouble();
      }
    }

    return spendingByMonth;
  }

  // Calculate spending from actual orders for a particular month.
  // Calculate actual spending from paid orders for a particular month.
  Future<double> getMonthlySpending({DateTime? month}) async {
    final selectedMonth = _getMonthStart(month ?? DateTime.now());

    final startDate = selectedMonth;
    final endDate = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);

    // Fetch only paid, non-cancelled orders.
    final response = await _supabase
        .from('orders')
        .select('id, total_amount')
        .eq('user_id', _userId)
        .inFilter('status', [
          'pending',
          'confirmed',
          'processing',
          'shipped',
          'delivered',
        ])
        .not('payment_status', 'in', '(failed,refunded)')
        .gte('created_at', startDate.toUtc().toIso8601String())
        .lt('created_at', endDate.toUtc().toIso8601String());

    final orders = List<Map<String, dynamic>>.from(response);

    if (orders.isEmpty) {
      return 0;
    }

    // Find orders with completed return requests.
    final orderIds = orders.map((order) => order['id'] as String).toList();

    final returnResponse = await _supabase
        .from('order_return_requests')
        .select('order_id')
        .inFilter('order_id', orderIds)
        .eq('status', 'completed');

    final returnedOrderIds = <String>{
      for (final item in returnResponse) item['order_id'] as String,
    };

    double totalSpent = 0;

    for (final order in orders) {
      final orderId = order['id'] as String;

      // Exclude orders with completed returns.
      if (returnedOrderIds.contains(orderId)) {
        continue;
      }

      final amount = order['total_amount'];

      if (amount is num) {
        totalSpent += amount.toDouble();
      }
    }

    return totalSpent;
  }
}
