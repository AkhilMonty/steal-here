import 'package:flutter/material.dart';

import '../../core/themes/app_colors.dart';
import '../../core/themes/app_spacing.dart';
import '../../core/themes/app_text_styles.dart';

enum AppButtonVariant { primary, secondary, outlined, text }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool isDisabled;
  final IconData? icon;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.isDisabled = false,
    this.icon,
    this.width,
    this.height,
    this.padding,
    this.borderRadius,
  });

  bool get _isDisabled => isDisabled || isLoading || onPressed == null;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height:
          height ??
          (variant == AppButtonVariant.text ? null : AppSpacing.buttonHeight),
      child: _buildButton(),
    );
  }

  Widget _buildButton() {
    switch (variant) {
      case AppButtonVariant.primary:
        return _buildPrimaryButton();

      case AppButtonVariant.secondary:
        return _buildSecondaryButton();

      case AppButtonVariant.outlined:
        return _buildOutlinedButton();

      case AppButtonVariant.text:
        return _buildTextButton();
    }
  }

  Widget _buildPrimaryButton() {
    return ElevatedButton(
      onPressed: _isDisabled ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        disabledBackgroundColor: AppColors.surfaceElevated,
        disabledForegroundColor: AppColors.textMuted,
        elevation: _isDisabled ? 0 : 3,
        shadowColor: AppColors.primary.withValues(alpha: 0.30),
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        shape: RoundedRectangleBorder(
          borderRadius:
              borderRadius ?? BorderRadius.circular(AppSpacing.radiusMedium),
        ),
      ),
      child: _buildContent(
        textStyle: AppTextStyles.buttonLarge,
        loaderColor: AppColors.textOnPrimary,
      ),
    );
  }

  Widget _buildSecondaryButton() {
    return ElevatedButton(
      onPressed: _isDisabled ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.surfaceElevated,
        foregroundColor: AppColors.textPrimary,
        disabledBackgroundColor: AppColors.surface,
        disabledForegroundColor: AppColors.textMuted,
        elevation: 0,
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        shape: RoundedRectangleBorder(
          borderRadius:
              borderRadius ?? BorderRadius.circular(AppSpacing.radiusMedium),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      child: _buildContent(
        textStyle: AppTextStyles.buttonLarge.copyWith(
          color: AppColors.textPrimary,
        ),
        loaderColor: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildOutlinedButton() {
    return OutlinedButton(
      onPressed: _isDisabled ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryLight,
        disabledForegroundColor: AppColors.textMuted,
        side: BorderSide(
          color: _isDisabled ? AppColors.border : AppColors.primary,
        ),
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        shape: RoundedRectangleBorder(
          borderRadius:
              borderRadius ?? BorderRadius.circular(AppSpacing.radiusMedium),
        ),
      ),
      child: _buildContent(
        textStyle: AppTextStyles.buttonLarge.copyWith(
          color: _isDisabled ? AppColors.textMuted : AppColors.primaryLight,
        ),
        loaderColor: AppColors.primaryLight,
      ),
    );
  }

  Widget _buildTextButton() {
    return TextButton(
      onPressed: _isDisabled ? null : onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryLight,
        disabledForegroundColor: AppColors.textMuted,
        padding:
            padding ??
            const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
        shape: RoundedRectangleBorder(
          borderRadius:
              borderRadius ?? BorderRadius.circular(AppSpacing.radiusMedium),
        ),
      ),
      child: _buildContent(
        textStyle: AppTextStyles.buttonMedium.copyWith(
          color: _isDisabled ? AppColors.textMuted : AppColors.primaryLight,
        ),
        loaderColor: AppColors.primaryLight,
      ),
    );
  }

  Widget _buildContent({
    required TextStyle textStyle,
    required Color loaderColor,
  }) {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(loaderColor),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: AppSpacing.iconMedium),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              text,
              style: textStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return Text(text, style: textStyle, overflow: TextOverflow.ellipsis);
  }
}
