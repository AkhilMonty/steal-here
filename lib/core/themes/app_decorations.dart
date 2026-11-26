import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// Centralized reusable decorations for Steal Here.
abstract final class AppDecorations {
  // -------------------------------------------------------------------------
  // Standard Borders
  // -------------------------------------------------------------------------

  static const BorderSide defaultBorder = BorderSide(
    color: AppColors.border,
    width: 1,
  );

  static const BorderSide strongBorder = BorderSide(
    color: AppColors.borderStrong,
    width: 1,
  );

  static const BorderSide primaryBorder = BorderSide(
    color: AppColors.primary,
    width: 1,
  );

  static const BorderSide goldBorder = BorderSide(
    color: AppColors.goldBorder,
    width: 1,
  );

  // -------------------------------------------------------------------------
  // Standard Box Decorations
  // -------------------------------------------------------------------------

  static BoxDecoration get card => BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
    border: Border.all(color: AppColors.border, width: 1),
  );

  static BoxDecoration get elevatedCard => BoxDecoration(
    color: AppColors.surfaceElevated,
    borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
    border: Border.all(color: AppColors.border, width: 1),
    boxShadow: const [
      BoxShadow(color: Color(0x26000000), blurRadius: 16, offset: Offset(0, 6)),
    ],
  );

  static BoxDecoration get premiumCard => BoxDecoration(
    gradient: AppColors.premiumGradient,
    borderRadius: BorderRadius.circular(AppSpacing.radiusXLarge),
    border: Border.all(color: AppColors.goldBorder, width: 1),
    boxShadow: const [
      BoxShadow(color: AppColors.goldGlow, blurRadius: 20, spreadRadius: 1),
    ],
  );

  static BoxDecoration get glassCard => BoxDecoration(
    color: AppColors.glass,
    borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
    border: Border.all(color: AppColors.glassBorder, width: 1),
  );

  // -------------------------------------------------------------------------
  // Input Decorations
  // -------------------------------------------------------------------------

  static BoxDecoration get input => BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
    border: Border.all(color: AppColors.border, width: 1),
  );

  static BoxDecoration get focusedInput => BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
    border: Border.all(color: AppColors.primary, width: 1.8),
  );

  // -------------------------------------------------------------------------
  // Gradients
  // -------------------------------------------------------------------------

  static const LinearGradient primaryGradient = AppColors.primaryGradient;

  static const LinearGradient premiumGradient = AppColors.premiumGradient;

  static const LinearGradient backgroundGradient = AppColors.backgroundGradient;

  // -------------------------------------------------------------------------
  // Shadows
  // -------------------------------------------------------------------------

  static const List<BoxShadow> softShadow = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> mediumShadow = [
    BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> purpleGlow = [
    BoxShadow(color: AppColors.purpleGlow, blurRadius: 20, spreadRadius: 1),
  ];

  static const List<BoxShadow> goldGlow = [
    BoxShadow(color: AppColors.goldGlow, blurRadius: 20, spreadRadius: 1),
  ];

  // -------------------------------------------------------------------------
  // Rounded Shapes
  // -------------------------------------------------------------------------

  static BorderRadius get smallRadius =>
      BorderRadius.circular(AppSpacing.radiusSmall);

  static BorderRadius get mediumRadius =>
      BorderRadius.circular(AppSpacing.radiusMedium);

  static BorderRadius get largeRadius =>
      BorderRadius.circular(AppSpacing.radiusLarge);

  static BorderRadius get extraLargeRadius =>
      BorderRadius.circular(AppSpacing.radiusXLarge);

  static BorderRadius get circularRadius =>
      BorderRadius.circular(AppSpacing.radiusCircular);
}
