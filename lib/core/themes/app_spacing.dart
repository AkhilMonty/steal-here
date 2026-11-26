import 'package:flutter/material.dart';

/// Centralized spacing and border-radius system for Steal Here.
abstract final class AppSpacing {
  // -------------------------------------------------------------------------
  // Spacing
  // -------------------------------------------------------------------------

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double huge = 48;

  // -------------------------------------------------------------------------
  // Standard Page Layout
  // -------------------------------------------------------------------------

  static const double pageHorizontal = 20;
  static const double pageVertical = 16;

  static const double sectionSpacing = 28;
  static const double cardSpacing = 12;
  static const double itemSpacing = 8;

  // -------------------------------------------------------------------------
  // Border Radius
  // -------------------------------------------------------------------------

  static const double radiusSmall = 8;
  static const double radiusMedium = 12;
  static const double radiusLarge = 16;
  static const double radiusXLarge = 20;
  static const double radiusXXLarge = 24;

  static const double radiusCircular = 100;

  // -------------------------------------------------------------------------
  // Standard Sizes
  // -------------------------------------------------------------------------

  static const double buttonHeight = 52;
  static const double inputHeight = 56;

  static const double iconSmall = 16;
  static const double iconMedium = 20;
  static const double iconLarge = 24;
  static const double iconXLarge = 32;

  // -------------------------------------------------------------------------
  // Reusable Edge Insets
  // -------------------------------------------------------------------------

  static const EdgeInsets pagePadding = EdgeInsets.symmetric(
    horizontal: pageHorizontal,
    vertical: pageVertical,
  );

  static const EdgeInsets cardPadding = EdgeInsets.all(md);

  static const EdgeInsets sectionPadding = EdgeInsets.symmetric(
    horizontal: pageHorizontal,
  );
}
