import 'package:flutter/material.dart';

import '../../core/themes/app_colors.dart';
import '../../core/themes/app_spacing.dart';
import '../../core/themes/app_text_styles.dart';

class AppLoading extends StatelessWidget {
  final String? message;
  final double size;
  final double strokeWidth;
  final Color? color;
  final bool fullScreen;
  final bool showMessage;
  final EdgeInsetsGeometry? padding;

  const AppLoading({
    super.key,
    this.message,
    this.size = 32,
    this.strokeWidth = 3,
    this.color,
    this.fullScreen = false,
    this.showMessage = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final loader = _buildLoader();

    if (!fullScreen) {
      return Padding(
        padding: padding ?? const EdgeInsets.all(AppSpacing.xl),
        child: loader,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(child: loader),
    );
  }

  Widget _buildLoader() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size + 16,
            height: size + 16,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (color ?? AppColors.primary).withValues(alpha: 0.08),
              boxShadow: [
                BoxShadow(
                  color: (color ?? AppColors.primary).withValues(alpha: 0.12),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                strokeWidth: strokeWidth,
                valueColor: AlwaysStoppedAnimation<Color>(
                  color ?? AppColors.primary,
                ),
              ),
            ),
          ),
          if (showMessage && message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
