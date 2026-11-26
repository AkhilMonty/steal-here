import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product_question_model.dart';

class ProductQuestionRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _table = 'product_questions';

  String get _userId {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw const AuthException(
        'You must be logged in to perform this action.',
      );
    }

    return user.id;
  }

  // =========================================
  // GET PRODUCT QUESTIONS
  // =========================================

  Future<List<ProductQuestionModel>> getProductQuestions(
    String productId,
  ) async {
    final response = await _supabase
        .from('product_questions_public')
        .select()
        .eq('product_id', productId)
        .order('created_at', ascending: false);

    return (response as List)
        .map(
          (item) =>
              ProductQuestionModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  // =========================================
  // ADD QUESTION
  // =========================================

  Future<ProductQuestionModel> addQuestion({
    required String productId,
    required String question,
  }) async {
    final cleanedQuestion = question.trim();

    if (cleanedQuestion.length < 10 || cleanedQuestion.length > 1000) {
      throw ArgumentError(
        'Question must contain between 10 and 1000 characters.',
      );
    }

    final response = await _supabase
        .from(_table)
        .insert({
          'product_id': productId,
          'user_id': _userId,
          'question': cleanedQuestion,
        })
        .select()
        .single();

    return ProductQuestionModel.fromJson(response).copyWith(isOwner: true);
  }

  // =========================================
  // UPDATE QUESTION
  // =========================================

  Future<ProductQuestionModel> updateQuestion({
    required String questionId,
    required String question,
  }) async {
    final cleanedQuestion = question.trim();

    if (cleanedQuestion.length < 10 || cleanedQuestion.length > 1000) {
      throw ArgumentError(
        'Question must contain between 10 and 1000 characters.',
      );
    }

    final response = await _supabase
        .from(_table)
        .update({'question': cleanedQuestion})
        .eq('id', questionId)
        .eq('user_id', _userId)
        .isFilter('answer', null)
        .select()
        .maybeSingle();

    if (response == null) {
      throw Exception(
        'Question could not be updated. It may already have been answered or you may not own it.',
      );
    }

    return ProductQuestionModel.fromJson(response).copyWith(isOwner: true);
  }

  // =========================================
  // DELETE QUESTION
  // =========================================

  Future<void> deleteQuestion(String questionId) async {
    await _supabase
        .from(_table)
        .delete()
        .eq('id', questionId)
        .eq('user_id', _userId)
        .isFilter('answer', null);
  }
}
