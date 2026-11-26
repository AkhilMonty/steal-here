import 'package:flutter/material.dart';

import '../../models/product_review_report_model.dart';
import '../../repositories/product_review_repository.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_spacing.dart';
import '../../core/themes/app_text_styles.dart';

class MyReviewReportsScreen extends StatefulWidget {
  const MyReviewReportsScreen({super.key});

  @override
  State<MyReviewReportsScreen> createState() => _MyReviewReportsScreenState();
}

class _MyReviewReportsScreenState extends State<MyReviewReportsScreen> {
  final ProductReviewRepository _repository = ProductReviewRepository();

  static const Color _background = AppColors.background;
  static const Color _primary = AppColors.primary;
  static const Color _muted = AppColors.textMuted;

  List<ProductReviewReportModel> _reports = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final reports = await _repository.getMyReviewReports();

      if (!mounted) return;

      setState(() {
        _reports = reports;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Unable to load your reports.';
        _isLoading = false;
      });
    }
  }

  String _formatReason(String reason) {
    switch (reason) {
      case 'spam':
        return 'Spam or promotional content';

      case 'offensive':
        return 'Offensive or abusive language';

      case 'fake_information':
        return 'Fake or misleading information';

      case 'irrelevant':
        return 'Irrelevant content';

      case 'other':
        return 'Other';

      default:
        return reason;
    }
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';

      case 'reviewed':
        return 'Reviewed';

      case 'dismissed':
        return 'Dismissed';

      case 'action_taken':
        return 'Action Taken';

      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orangeAccent;

      case 'reviewed':
        return Colors.blueAccent;

      case 'dismissed':
        return Colors.grey;

      case 'action_taken':
        return Colors.greenAccent;

      default:
        return _muted;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_top_rounded;

      case 'reviewed':
        return Icons.visibility_outlined;

      case 'dismissed':
        return Icons.cancel_outlined;

      case 'action_taken':
        return Icons.check_circle_outline;

      default:
        return Icons.info_outline;
    }
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();

    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');

    return '$day/$month/${localDate.year}';
  }

  Widget _buildStatusBadge(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status), color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            _formatStatus(status),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(ProductReviewReportModel report) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C1B2B), Color(0xFF171722)],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.flag_outlined,
                color: Colors.redAccent,
                size: 20,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Review Report',
                  style: AppTextStyles.headingSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildStatusBadge(report.status),
            ],
          ),
          const SizedBox(height: 16),
          Text('Reason', style: TextStyle(color: _muted, fontSize: 12)),
          const SizedBox(height: 5),
          Text(
            _formatReason(report.reason),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (report.details != null && report.details!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Additional Details',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
            const SizedBox(height: 5),
            Text(
              report.details!,
              style: const TextStyle(color: Colors.white70, height: 1.5),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, color: _muted, size: 14),
              const SizedBox(width: 7),
              Text(
                'Submitted on ${_formatDate(report.createdAt)}',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
          if (report.reviewedAt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: _statusColor(report.status),
                  size: 14,
                ),
                const SizedBox(width: 7),
                Text(
                  'Reviewed on ${_formatDate(report.reviewedAt!)}',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_outlined, color: AppColors.primary, size: 58),
            const SizedBox(height: 18),
            Text(
              'No Reports Yet',
              style: AppTextStyles.headingMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Reviews you report will appear here. '
              'You can track their moderation status anytime.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: Text(
          'My Review Reports',
          style: AppTextStyles.headingMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: 45,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loadReports,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusLarge,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _reports.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              color: _primary,
              onRefresh: _loadReports,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    '${_reports.length} '
                    '${_reports.length == 1 ? 'Report' : 'Reports'} Submitted',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._reports.map(_buildReportCard),
                ],
              ),
            ),
    );
  }
}
