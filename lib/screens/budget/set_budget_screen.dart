import 'package:flutter/material.dart';

import '../../models/budget_model.dart';
import '../../repositories/budget_repository.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_spacing.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/themes/app_decorations.dart';

class SetBudgetScreen extends StatefulWidget {
  final BudgetModel? existingBudget;

  const SetBudgetScreen({super.key, this.existingBudget});

  @override
  State<SetBudgetScreen> createState() => _SetBudgetScreenState();
}

class _SetBudgetScreenState extends State<SetBudgetScreen> {
  static const Color _background = AppColors.background;
  static const Color _primary = AppColors.primary;
  static const Color _gold = AppColors.gold;
  static const Color _green = Color(0xFF34D399);

  final BudgetRepository _repository = BudgetRepository();
  final TextEditingController _amountController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isSaving = false;

  bool get _isEditing => widget.existingBudget != null;

  @override
  void initState() {
    super.initState();

    final existingAmount = widget.existingBudget?.budgetAmount;

    if (existingAmount != null) {
      _amountController.text = existingAmount.toStringAsFixed(0);
    }
  }

  String get _currentMonth {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final now = DateTime.now();

    return '${months[now.month - 1]} ${now.year}';
  }

  Future<void> _saveBudget() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final amount = double.parse(_amountController.text.trim());

    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.saveMonthlyBudget(budgetAmount: amount);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Monthly budget updated successfully!'
                : 'Monthly budget created successfully!',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save budget. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.premiumCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
            ),
            child: const Icon(
              Icons.shield_moon_outlined,
              color: _gold,
              size: 29,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            _isEditing ? 'UPDATE YOUR BUDGET' : 'TAKE CONTROL OF SPENDING',
            style: AppTextStyles.labelSmall.copyWith(
              color: _gold,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _isEditing
                ? 'Adjust your monthly shopping limit.'
                : 'Set a spending limit and shop smarter this month.',
            style: AppTextStyles.headingSmall.copyWith(
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                color: AppColors.textMuted,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                _currentMonth,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountField() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Spending Limit',
            style: AppTextStyles.headingSmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'How much do you want to spend this month?',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          Form(
            key: _formKey,
            child: TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: AppTextStyles.headingSmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                prefixText: 'Rp ',
                prefixStyle: AppTextStyles.headingSmall.copyWith(
                  color: _gold,
                  fontWeight: FontWeight.bold,
                ),
                hintText: 'Enter amount',
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textMuted,
                ),
                filled: true,
                fillColor: _background,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.lg,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
                  borderSide: const BorderSide(color: _primary, width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
                  borderSide: const BorderSide(color: Colors.redAccent),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
                  borderSide: const BorderSide(
                    color: Colors.redAccent,
                    width: 1.5,
                  ),
                ),
              ),
              validator: (value) {
                final amount = double.tryParse((value ?? '').trim());

                if (amount == null || !amount.isFinite || amount <= 0) {
                  return 'Enter a valid budget amount.';
                }

                return null;
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Your budget will be used to calculate your monthly '
            'spending progress and alerts.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertInformation() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.card.copyWith(
        border: Border.all(color: _primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  color: _gold,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Budget Guardian Alerts',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildAlertRow('80%', 'Spending warning', _gold),
          const SizedBox(height: AppSpacing.md),
          _buildAlertRow('100%', 'Budget limit reached', Colors.orange),
          const SizedBox(height: AppSpacing.md),
          _buildAlertRow('>100%', 'Budget exceeded', Colors.redAccent),
        ],
      ),
    );
  }

  Widget _buildAlertRow(String percentage, String description, Color color) {
    return Row(
      children: [
        Container(
          width: 62,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          ),
          child: Text(
            percentage,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelMedium.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            description,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const Icon(Icons.check_circle_outline, color: _green, size: 19),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: AppSpacing.buttonHeight,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _saveBudget,
        icon: _isSaving
            ? const SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check_circle_outline_rounded),
        label: Text(
          _isSaving
              ? 'Saving Budget...'
              : _isEditing
              ? 'Update Monthly Budget'
              : 'Save Monthly Budget',
          style: AppTextStyles.buttonMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _primary.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text(
          _isEditing ? 'Edit Monthly Budget' : 'Set Monthly Budget',
          style: AppTextStyles.headingSmall.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            AppSpacing.md,
            AppSpacing.pageHorizontal,
            AppSpacing.xxxl,
          ),
          children: [
            _buildHeaderCard(),
            const SizedBox(height: AppSpacing.lg),
            _buildAmountField(),
            const SizedBox(height: AppSpacing.lg),
            _buildAlertInformation(),
            const SizedBox(height: AppSpacing.xl),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }
}
