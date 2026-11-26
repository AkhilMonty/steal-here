import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product_question_model.dart';
import '../repositories/product_question_repository.dart';
import '../core/themes/app_colors.dart';
import '../core/themes/app_spacing.dart';
import '../core/themes/app_text_styles.dart';
import '../core/themes/app_decorations.dart';

class ProductQuestionsSection extends StatefulWidget {
  const ProductQuestionsSection({super.key, required this.productId});

  final String productId;

  @override
  State<ProductQuestionsSection> createState() =>
      _ProductQuestionsSectionState();
}

class _ProductQuestionDialog extends StatefulWidget {
  const _ProductQuestionDialog({
    required this.title,
    required this.buttonText,
    this.initialValue = '',
  });

  final String title;
  final String buttonText;
  final String initialValue;

  @override
  State<_ProductQuestionDialog> createState() => _ProductQuestionDialogState();
}

class _ProductQuestionDialogState extends State<_ProductQuestionDialog> {
  static const Color _surface = AppColors.surface;
  static const Color _muted = AppColors.textMuted;

  late final TextEditingController _controller;

  String? _validationError;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();

    if (value.length < 10 || value.length > 1000) {
      setState(() {
        _validationError = 'Enter between 10 and 1000 characters.';
      });
      return;
    }

    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _surface,
      scrollable: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        widget.title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Share your question about this product.',
            style: TextStyle(color: _muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 3,
            maxLines: 5,
            maxLength: 1000,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Write your question here...',
              hintStyle: const TextStyle(color: _muted),
              errorText: _validationError,
              filled: true,
              fillColor: const Color(0xFF0B0B12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          const Text(
            'Minimum 10 characters. Maximum 1000 characters.',
            style: TextStyle(color: _muted, fontSize: 10),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel', style: TextStyle(color: _muted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: _submit,
          child: Text(widget.buttonText),
        ),
      ],
    );
  }
}

class _ProductQuestionsSectionState extends State<ProductQuestionsSection> {
  static const Color _surface = AppColors.surface;
  static const Color _muted = AppColors.textMuted;

  final ProductQuestionRepository _repository = ProductQuestionRepository();

  List<ProductQuestionModel> _questions = [];

  bool _isLoading = true;
  bool _isSubmitting = false;

  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  // =========================================
  // LOAD QUESTIONS
  // =========================================

  Future<void> _loadQuestions() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final questions = await _repository.getProductQuestions(widget.productId);

      if (!mounted) return;

      setState(() {
        _questions = questions;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('LOAD PRODUCT QUESTIONS ERROR: $error');

      if (!mounted) return;

      setState(() => _isLoading = false);

      _showMessage('Could not load product questions.');
    }
  }

  // =========================================
  // ADD QUESTION
  // =========================================

  Future<void> _addQuestion() async {
    if (_currentUserId == null) {
      _showMessage('Please log in to ask a question.');
      return;
    }

    final question = await _showQuestionDialog(
      title: 'Ask a Question',
      buttonText: 'Submit Question',
    );

    if (question == null || !mounted) return;

    await _saveQuestion(question: question);
  }

  // =========================================
  // EDIT QUESTION
  // =========================================

  Future<void> _editQuestion(ProductQuestionModel item) async {
    final question = await _showQuestionDialog(
      title: 'Edit Your Question',
      buttonText: 'Save Changes',
      initialValue: item.question,
    );

    if (question == null || !mounted) return;

    await _saveQuestion(question: question, questionId: item.id);
  }

  // =========================================
  // QUESTION DIALOG
  // =========================================

  Future<String?> _showQuestionDialog({
    required String title,
    required String buttonText,
    String initialValue = '',
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _ProductQuestionDialog(
          title: title,
          buttonText: buttonText,
          initialValue: initialValue,
        );
      },
    );
  }

  // =========================================
  // SAVE QUESTION
  // =========================================

  Future<void> _saveQuestion({
    required String question,
    String? questionId,
  }) async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      if (questionId == null) {
        await _repository.addQuestion(
          productId: widget.productId,
          question: question,
        );
      } else {
        await _repository.updateQuestion(
          questionId: questionId,
          question: question,
        );
      }

      if (!mounted) return;

      _showMessage(
        questionId == null
            ? 'Your question has been submitted.'
            : 'Your question has been updated.',
      );

      await _loadQuestions();
    } catch (error) {
      debugPrint('SAVE PRODUCT QUESTION ERROR: $error');

      if (!mounted) return;

      _showMessage('Could not save your question. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // =========================================
  // DELETE QUESTION
  // =========================================

  Future<void> _deleteQuestion(ProductQuestionModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _surface,
          title: const Text(
            'Delete Question?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to delete this question?',
            style: TextStyle(color: _muted),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel', style: TextStyle(color: _muted)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
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

    try {
      await _repository.deleteQuestion(item.id);

      if (!mounted) return;

      _showMessage('Question deleted.');

      await _loadQuestions();
    } catch (error) {
      debugPrint('DELETE PRODUCT QUESTION ERROR: $error');

      if (!mounted) return;

      _showMessage('Could not delete this question.');
    }
  }

  // =========================================
  // MESSAGE
  // =========================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  // =========================================
  // FORMAT DATE
  // =========================================

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();

    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');

    return '$day/$month/${localDate.year}';
  }

  // =========================================
  // QUESTION CARD
  // =========================================

  Widget _buildQuestionCard(ProductQuestionModel item) {
    final isOwner = item.isOwner;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.card.copyWith(
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                ),
                child: const Icon(
                  Icons.help_outline_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    item.question,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              if (isOwner && !item.isAnswered)
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                  color: AppColors.surface,
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editQuestion(item);
                    } else if (value == 'delete') {
                      _deleteQuestion(item);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_outlined,
                            color: Colors.white70,
                            size: 18,
                          ),
                          SizedBox(width: 10),
                          Text('Edit', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                          SizedBox(width: 10),
                          Text('Delete', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Asked on ${_formatDate(item.createdAt)}',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          if (item.isAnswered) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(color: Colors.green.withValues(alpha: 0.18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_outlined,
                        color: Colors.greenAccent,
                        size: 18,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Answered',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: Colors.greenAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    item.answer!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.6,
                    ),
                  ),
                  if (item.answeredAt != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Answered on ${_formatDate(item.answeredAt!)}',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  color: Colors.orangeAccent,
                  size: 16,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Waiting for an answer',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.orangeAccent.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // =========================================
  // BUILD
  // =========================================

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.premiumCard.copyWith(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                ),
                child: const Icon(
                  Icons.question_answer_outlined,
                  color: AppColors.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Questions & Answers',
                      style: AppTextStyles.headingSmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Have a question about this product?',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _isLoading ? null : _loadQuestions,
                tooltip: 'Refresh questions',
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _addQuestion,
              icon: const Icon(Icons.add_comment_outlined, size: 18),
              label: const Text('Ask a Question'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                ),
                textStyle: AppTextStyles.buttonMedium,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (_questions.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.xxl,
                horizontal: AppSpacing.lg,
              ),
              decoration: AppDecorations.card,
              child: Column(
                children: [
                  Icon(
                    Icons.question_answer_outlined,
                    color: AppColors.textMuted.withValues(alpha: 0.7),
                    size: 38,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No questions yet',
                    style: AppTextStyles.headingSmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Be the first to ask something about this product.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Row(
              children: [
                Text(
                  '${_questions.length} ${_questions.length == 1 ? 'Question' : 'Questions'}',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusCircular,
                    ),
                  ),
                  child: Text(
                    'Community Q&A',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ..._questions.map(_buildQuestionCard),
          ],
        ],
      ),
    );
  }
}
