import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product_review_model.dart';
import '../models/product_review_report_model.dart';

class ProductReviewRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  String get _userId {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Please log in to continue.');
    }

    return user.id;
  }

  Future<void> submitReviewReport({
    required String reviewId,
    required String reason,
    String? details,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Please log in to report a review.');
    }

    const allowedReasons = {
      'spam',
      'offensive',
      'fake_information',
      'irrelevant',
      'other',
    };

    if (!allowedReasons.contains(reason)) {
      throw Exception('Invalid report reason.');
    }

    final trimmedDetails = details?.trim();

    if (trimmedDetails != null && trimmedDetails.length > 1000) {
      throw Exception('Report details cannot exceed 1000 characters.');
    }

    await _supabase.from('product_review_reports').insert({
      'review_id': reviewId,
      'reporter_user_id': user.id,
      'reason': reason,
      'details': trimmedDetails == null || trimmedDetails.isEmpty
          ? null
          : trimmedDetails,
    });
  }

  Future<List<ProductReviewReportModel>> getMyReviewReports() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Please log in to view your reports.');
    }

    final response = await _supabase
        .from('product_review_reports')
        .select()
        .eq('reporter_user_id', user.id)
        .order('created_at', ascending: false);

    return response
        .map<ProductReviewReportModel>(
          (item) => ProductReviewReportModel.fromJson(item),
        )
        .toList();
  }

  // Fetch all reviews for a product.
  Future<List<ProductReviewModel>> getReviews(String productId) async {
    final response = await _supabase
        .from('product_reviews_with_verification')
        .select()
        .eq('product_id', productId)
        .order('created_at', ascending: false);

    return (response as List)
        .map(
          (item) =>
              ProductReviewModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  // Fetch the current customer's review for a product.
  Future<ProductReviewModel?> getMyReview(String productId) async {
    final response = await _supabase
        .from('product_reviews_with_verification')
        .select()
        .eq('product_id', productId)
        .eq('user_id', _userId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return ProductReviewModel.fromJson(Map<String, dynamic>.from(response));
  }

  // Check whether the customer has a paid and delivered order
  // containing this product.
  Future<bool> canReviewProduct(String productId) async {
    final userId = _userId;

    final response = await _supabase
        .from('orders')
        .select('id, order_items!inner(id)')
        .eq('user_id', userId)
        .eq('status', 'delivered')
        .eq('payment_status', 'paid')
        .eq('order_items.product_id', productId)
        .limit(1);

    return response.isNotEmpty;
  }

  // Submit a new review or update an existing review.
  Future<ProductReviewModel> saveReview({
    required String productId,
    required int rating,
    required String reviewText,
  }) async {
    final userId = _userId;
    final trimmedReview = reviewText.trim();

    if (rating < 1 || rating > 5) {
      throw Exception('Please select a rating between 1 and 5 stars.');
    }

    if (trimmedReview.isEmpty) {
      throw Exception('Please write your review.');
    }

    if (trimmedReview.length > 2000) {
      throw Exception('Your review cannot exceed 2000 characters.');
    }

    final response = await _supabase
        .from('product_reviews')
        .upsert({
          'product_id': productId,
          'user_id': userId,
          'rating': rating,
          'review_text': trimmedReview,
        }, onConflict: 'product_id,user_id')
        .select()
        .single();

    return ProductReviewModel.fromJson(Map<String, dynamic>.from(response));
  }

  // Delete the current customer's review.
  Future<void> deleteReview(String reviewId) async {
    await _supabase
        .from('product_reviews')
        .delete()
        .eq('id', reviewId)
        .eq('user_id', _userId);
  }

  // ==========================================
  // GET HELPFUL VOTE COUNTS
  // ==========================================

  Future<Map<String, int>> getHelpfulVoteCounts(List<String> reviewIds) async {
    if (reviewIds.isEmpty) {
      return {};
    }

    final response = await _supabase
        .from('product_review_helpful_counts')
        .select('review_id, helpful_count')
        .inFilter('review_id', reviewIds);

    return {
      for (final item in response)
        item['review_id'] as String: (item['helpful_count'] as num).toInt(),
    };
  }

  // ==========================================
  // GET CURRENT USER'S HELPFUL VOTES
  // ==========================================

  Future<Set<String>> getMyHelpfulVotes(List<String> reviewIds) async {
    if (reviewIds.isEmpty) {
      return {};
    }

    final user = _supabase.auth.currentUser;

    if (user == null) {
      return {};
    }

    final response = await _supabase
        .from('product_review_helpful_votes')
        .select('review_id')
        .eq('user_id', user.id)
        .inFilter('review_id', reviewIds);

    return {for (final item in response) item['review_id'] as String};
  }

  // ==========================================
  // TOGGLE HELPFUL VOTE
  // ==========================================

  Future<void> toggleHelpfulVote(String reviewId) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Please log in to vote on reviews.');
    }

    final existingVote = await _supabase
        .from('product_review_helpful_votes')
        .select('review_id')
        .eq('review_id', reviewId)
        .eq('user_id', user.id)
        .maybeSingle();

    if (existingVote != null) {
      await _supabase
          .from('product_review_helpful_votes')
          .delete()
          .eq('review_id', reviewId)
          .eq('user_id', user.id);
    } else {
      await _supabase.from('product_review_helpful_votes').insert({
        'review_id': reviewId,
        'user_id': user.id,
      });
    }
  }
}
