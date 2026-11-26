import 'package:flutter/material.dart';

import '../../models/budget_model.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_spacing.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/themes/app_decorations.dart';
import '../../repositories/budget_repository.dart';
import 'set_budget_screen.dart';
import 'budget_history_screen.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  static const Color _background = AppColors.background;
  static const Color _surface = AppColors.surface;
  static const Color _primary = AppColors.primary;
  static const Color _gold = AppColors.gold;
  static const Color _muted = AppColors.textMuted;
  static const Color _green = Color(0xFF34D399);
  static const Color _red = Color(0xFFEF4444);
  static const Color _orange = Color(0xFFF59E0B);

  final BudgetRepository _budgetRepository = BudgetRepository();

  BudgetModel? _budget;
  double _totalSpent = 0;

  bool _isLoading = true;
  final bool _isSaving = false;
  bool _isDeleting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBudgetData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Future<void> _loadBudgetData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _budgetRepository.getCurrentMonthBudget(),
        _budgetRepository.getMonthlySpending(),
      ]);

      if (!mounted) return;

      setState(() {
        _budget = results[0] as BudgetModel?;
        _totalSpent = results[1] as double;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load budget information.';
      });
    }
  }

  String _formatPrice(double amount) {
    final value = amount.round().toString();
    final buffer = StringBuffer();

    for (int i = 0; i < value.length; i++) {
      if (i > 0 && (value.length - i) % 3 == 0) {
        buffer.write('.');
      }

      buffer.write(value[i]);
    }

    return 'Rp ${buffer.toString()}';
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

  double get _budgetAmount => _budget?.budgetAmount ?? 0;

  double get _remainingBudget => _budgetAmount - _totalSpent;

  double get _progress {
    if (_budgetAmount <= 0) return 0;

    return (_totalSpent / _budgetAmount).clamp(0.0, 1.0);
  }

  double get _percentage {
    if (_budgetAmount <= 0) return 0;

    return (_totalSpent / _budgetAmount) * 100;
  }

  Color get _progressColor {
    if (_percentage >= 100) return _red;
    if (_percentage >= 90) return _orange;
    if (_percentage >= 70) return _gold;

    return _green;
  }

  String get _budgetMessage {
    if (_budgetAmount <= 0) {
      return 'Set a monthly budget to start tracking your spending.';
    }

    if (_percentage >= 100) {
      return 'You have exceeded your monthly shopping budget!';
    }

    if (_percentage >= 90) {
      return 'Warning! You are very close to your spending limit.';
    }

    if (_percentage >= 70) {
      return 'Careful! You have used most of your budget.';
    }

    return 'Great job! You are managing your spending well.';
  }

  IconData get _budgetIcon {
    if (_budgetAmount <= 0) return Icons.account_balance_wallet_outlined;
    if (_percentage >= 100) return Icons.warning_amber_rounded;
    if (_percentage >= 70) return Icons.notifications_active_outlined;

    return Icons.check_circle_outline;
  }

  Future<void> _showBudgetDialog() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SetBudgetScreen(existingBudget: _budget),
      ),
    );

    if (result == true && mounted) {
      await _loadBudgetData();
    }
  }

  Future<void> _openBudgetHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BudgetHistoryScreen()),
    );
  }

  Future<void> _deleteCurrentMonthBudget() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _surface,
          title: const Text(
            'Delete Monthly Budget?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to delete your current monthly budget? '
            'Your orders and spending records will remain preserved.',
            style: TextStyle(color: _muted, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete', style: TextStyle(color: _red)),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      await _budgetRepository.deleteMonthlyBudget();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Monthly budget deleted successfully.')),
      );

      await _loadBudgetData();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to delete monthly budget. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  Widget _buildSummaryCard({
    required String title,
    required String amount,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: AppTextStyles.headingSmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetProgress() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Spending Progress',
                  style: AppTextStyles.headingSmall.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${_percentage.toStringAsFixed(1)}%',
                style: AppTextStyles.labelLarge.copyWith(
                  color: _progressColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _progress),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusCircular),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 13,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(_progressColor),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatPrice(_totalSpent),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                'of',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              Expanded(
                child: Text(
                  _formatPrice(_budgetAmount),
                  textAlign: TextAlign.end,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Spent',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                'Monthly limit',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: _progressColor.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        border: Border.all(color: _progressColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: _progressColor.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            ),
            child: Icon(_budgetIcon, color: _progressColor, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _percentage >= 100
                      ? 'Budget Exceeded'
                      : _percentage >= 70
                      ? 'Spending Alert'
                      : 'Smart Budget Insight',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: _progressColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _budgetMessage,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBudget() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: AppDecorations.premiumCard,
      child: Column(
        children: [
          Container(
            height: 88,
            width: 88,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(AppSpacing.radiusXXLarge),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: AppColors.gold,
              size: 44,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Take Control of Your Spending',
            textAlign: TextAlign.center,
            style: AppTextStyles.headingSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Create a monthly shopping budget and let Budget Guardian '
            'help you spend smarter.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
              height: 1.6,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            height: AppSpacing.buttonHeight,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _showBudgetDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Monthly Budget'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: AppDecorations.premiumCard,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusMedium,
                      ),
                    ),
                    child: const Icon(
                      Icons.shield_moon_outlined,
                      color: AppColors.gold,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'BUDGET GUARDIAN',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                _currentMonth,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _formatPrice(_remainingBudget),
                  style: AppTextStyles.headingMedium.copyWith(
                    color: _remainingBudget >= 0 ? AppColors.textPrimary : _red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Remaining shopping budget',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _showBudgetDialog,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit Monthly Budget'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusMedium,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _isDeleting ? null : _deleteCurrentMonthBudget,
                  icon: _isDeleting
                      ? SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _red,
                          ),
                        )
                      : const Icon(Icons.delete_outline_rounded),
                  label: Text(
                    _isDeleting
                        ? 'Deleting Budget...'
                        : 'Delete Monthly Budget',
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: _red,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: 'Monthly Budget',
                amount: _formatPrice(_budgetAmount),
                icon: Icons.account_balance_wallet_outlined,
                color: _primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildSummaryCard(
                title: 'Total Spent',
                amount: _formatPrice(_totalSpent),
                icon: Icons.shopping_bag_outlined,
                color: _gold,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildBudgetProgress(),
        const SizedBox(height: AppSpacing.lg),
        _buildAlertCard(),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Smart Shopping Tip',
          style: AppTextStyles.headingSmall.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: AppDecorations.card,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.lightbulb_outline_rounded,
                color: AppColors.gold,
                size: 25,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Before purchasing, compare prices and ask yourself '
                  'whether the product is something you really need.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Text(
          'Budget Guardian',
          style: AppTextStyles.headingSmall.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: _primary),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Loading your budget...',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              )
            : _errorMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off_outlined,
                        color: AppColors.textMuted,
                        size: 48,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      ElevatedButton.icon(
                        onPressed: _loadBudgetData,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try Again'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                color: _primary,
                backgroundColor: _surface,
                onRefresh: _loadBudgetData,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
                  children: [
                    if (_budget == null)
                      _buildEmptyBudget()
                    else
                      _buildDashboard(),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openBudgetHistory,
                        icon: const Icon(Icons.history_rounded),
                        label: const Text('View Budget History'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _gold,
                          side: BorderSide(color: _gold.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMedium,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
      ),
    );
  }
}
