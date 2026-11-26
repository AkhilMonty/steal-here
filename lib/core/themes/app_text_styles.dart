import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Centralized typography system for Steal Here.
///
/// All application text styles should be derived from this class rather than
/// creating individual TextStyle objects throughout the application.
abstract final class AppTextStyles {
  // ---------------------------------------------------------------------------
  // Display Styles
  // ---------------------------------------------------------------------------

  /// Very large text used for hero sections and major promotional content.
  static TextStyle displayLarge = GoogleFonts.poppins(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    height: 1.15,
    letterSpacing: -1.0,
    color: AppColors.textPrimary,
  );

  /// Large heading used for important screen sections.
  static TextStyle displayMedium = GoogleFonts.poppins(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: -0.6,
    color: AppColors.textPrimary,
  );

  /// Medium display heading.
  static TextStyle displaySmall = GoogleFonts.poppins(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.4,
    color: AppColors.textPrimary,
  );

  // ---------------------------------------------------------------------------
  // Headings
  // ---------------------------------------------------------------------------

  static TextStyle headingLarge = GoogleFonts.poppins(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: AppColors.textPrimary,
  );

  static TextStyle headingMedium = GoogleFonts.poppins(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  static TextStyle headingSmall = GoogleFonts.poppins(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  // ---------------------------------------------------------------------------
  // Body Text
  // ---------------------------------------------------------------------------

  static TextStyle bodyLarge = GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  static TextStyle bodyMedium = GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textSecondary,
  );

  static TextStyle bodySmall = GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.textSecondary,
  );

  // ---------------------------------------------------------------------------
  // Labels
  // ---------------------------------------------------------------------------

  static TextStyle labelLarge = GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: AppColors.textPrimary,
  );

  static TextStyle labelMedium = GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: AppColors.textSecondary,
  );

  static TextStyle labelSmall = GoogleFonts.poppins(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.4,
    color: AppColors.textMuted,
  );

  // ---------------------------------------------------------------------------
  // Product Styles
  // ---------------------------------------------------------------------------

  /// Product name displayed on product cards.
  static TextStyle productName = GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.35,
    color: AppColors.textPrimary,
  );

  /// Large product title used on product details.
  static TextStyle productTitle = GoogleFonts.poppins(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  /// Main product price.
  static TextStyle price = GoogleFonts.poppins(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: AppColors.textPrimary,
  );

  /// Large product price for product details.
  static TextStyle priceLarge = GoogleFonts.poppins(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    height: 1.2,
    color: AppColors.textPrimary,
  );

  /// Original price shown with a strike-through.
  static TextStyle originalPrice = GoogleFonts.poppins(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.2,
    decoration: TextDecoration.lineThrough,
    decorationColor: AppColors.textMuted,
    color: AppColors.textMuted,
  );

  /// Discount percentage.
  static TextStyle discount = GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: AppColors.discount,
  );

  // ---------------------------------------------------------------------------
  // Button Styles
  // ---------------------------------------------------------------------------

  static TextStyle buttonLarge = GoogleFonts.poppins(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: AppColors.textOnPrimary,
  );

  static TextStyle buttonMedium = GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: AppColors.textOnPrimary,
  );

  static TextStyle buttonSmall = GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: AppColors.textOnPrimary,
  );

  // ---------------------------------------------------------------------------
  // Special / Premium Styles
  // ---------------------------------------------------------------------------

  /// Gold promotional text.
  static TextStyle premium = GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.gold,
  );

  /// Small uppercase-style promotional label.
  static TextStyle overline = GoogleFonts.poppins(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 1.2,
    color: AppColors.gold,
  );

  /// Smart Buy score.
  static TextStyle smartScore = GoogleFonts.poppins(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    height: 1.1,
    color: AppColors.primaryLight,
  );

  /// Countdown timer text.
  static TextStyle timer = GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: AppColors.gold,
  );
}
