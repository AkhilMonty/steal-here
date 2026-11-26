import 'package:flutter/material.dart';

import '../../core/themes/app_colors.dart';
import '../../core/themes/app_spacing.dart';
import '../../core/themes/app_text_styles.dart';
import 'app_button.dart';

class AppErrorState extends StatelessWidget {
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onRetry;
  final IconData icon;
  final Color? iconColor;
  final bool showCard;
  final Widget? customIllustration;
  final EdgeInsetsGeometry? padding;

  const AppErrorState({
    super.key,
    this.title = 'Something Went Wrong',
    required this.message,
    this.actionLabel = 'Try Again',
    this.onRetry,
    this.icon = Icons.error_outline_rounded,
    this.iconColor,
    this.showCard = false,
    this.customIllustration,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding ?? const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIllustration(),
          const SizedBox(height: AppSpacing.xl),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.headingMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (onRetry != null && actionLabel != null) ...[
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              text: actionLabel!,
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
              width: double.infinity,
            ),
          ],
        ],
      ),
    );

    if (showCard) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: AppColors.error.withValues(alpha: 0.06),
              blurRadius: 20,
              spreadRadius: 1,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: content,
      );
    }

    return Center(child: content);
  }

  Widget _buildIllustration() {
    if (customIllustration != null) {
      return customIllustration!;
    }

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: (iconColor ?? AppColors.error).withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(
          color: (iconColor ?? AppColors.error).withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: (iconColor ?? AppColors.error).withValues(alpha: 0.10),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(icon, size: 42, color: iconColor ?? AppColors.error),
    );
  }
}
