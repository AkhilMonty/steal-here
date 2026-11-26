import 'package:flutter/material.dart';

/// Centralized color palette for the Steal Here application.
///
/// Keeping colors in one place makes the design system easier to maintain
/// and ensures visual consistency across every screen and widget.
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Brand Colors
  // ---------------------------------------------------------------------------

  /// Main Steal Here brand color.
  static const Color primary = Color(0xFF7C3AED);

  /// A darker version of the primary purple.
  static const Color primaryDark = Color(0xFF5B21B6);

  /// A lighter version of the primary purple.
  static const Color primaryLight = Color(0xFFA78BFA);

  /// Luxury accent used for offers, discounts and premium highlights.
  static const Color gold = Color(0xFFF59E0B);

  /// Lighter gold for highlighted states.
  static const Color goldLight = Color(0xFFFBBF24);

  /// Darker gold for pressed/active states.
  static const Color goldDark = Color(0xFFD97706);

  // ---------------------------------------------------------------------------
  // Background Colors
  // ---------------------------------------------------------------------------

  /// Main application background.
  static const Color background = Color(0xFF0B0B16);

  /// Alternative dark background used for sections and gradients.
  static const Color backgroundSecondary = Color(0xFF10101F);

  /// Surface color for cards and elevated components.
  static const Color surface = Color(0xFF161625);

  /// Slightly lighter surface for nested/elevated content.
  static const Color surfaceElevated = Color(0xFF1D1D30);

  /// Darkest surface used for overlays and navigation areas.
  static const Color surfaceDark = Color(0xFF090910);

  // ---------------------------------------------------------------------------
  // Text Colors
  // ---------------------------------------------------------------------------

  /// Primary text.
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// Secondary/supporting text.
  static const Color textSecondary = Color(0xFFA7A7B5);

  /// Muted text for less important information.
  /// Kept bright enough for comfortable reading on dark surfaces.
  static const Color textMuted = Color(0xFF9696A8);

  /// Text placed on primary purple backgrounds.
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  /// Text placed on gold backgrounds.
  static const Color textOnGold = Color(0xFF0B0B16);

  // ---------------------------------------------------------------------------
  // Status Colors
  // ---------------------------------------------------------------------------

  static const Color success = Color(0xFF22C55E);

  static const Color warning = Color(0xFFF59E0B);

  static const Color error = Color(0xFFEF4444);

  static const Color info = Color(0xFF3B82F6);

  // ---------------------------------------------------------------------------
  // Product / Shopping Colors
  // ---------------------------------------------------------------------------

  /// Discount and sale price.
  static const Color discount = Color(0xFFEF4444);

  /// Positive savings.
  static const Color savings = Color(0xFF22C55E);

  /// Star/review color.
  static const Color rating = Color(0xFFFBBF24);

  /// Wishlist active state.
  static const Color wishlist = Color(0xFFEC4899);

  // ---------------------------------------------------------------------------
  // Border Colors
  // ---------------------------------------------------------------------------

  /// Standard subtle border.
  static const Color border = Color(0xFF29293D);

  /// More visible border for selected components.
  static const Color borderStrong = Color(0xFF3B3B55);

  /// Purple glassmorphism border.
  static const Color glassBorder = Color(0x557C3AED);

  /// Gold glassmorphism border.
  static const Color goldBorder = Color(0x55F59E0B);

  // ---------------------------------------------------------------------------
  // Glassmorphism Colors
  // ---------------------------------------------------------------------------

  /// Dark translucent glass surface.
  static const Color glass = Color(0x66161625);

  /// Stronger glass surface for important cards.
  static const Color glassStrong = Color(0x99161625);

  /// Purple translucent glow.
  static const Color purpleGlow = Color(0x337C3AED);

  /// Gold translucent glow.
  static const Color goldGlow = Color(0x33F59E0B);

  // ---------------------------------------------------------------------------
  // Utility Colors
  // ---------------------------------------------------------------------------

  static const Color transparent = Colors.transparent;

  static const Color white = Colors.white;

  static const Color black = Colors.black;

  // ---------------------------------------------------------------------------
  // Gradients
  // ---------------------------------------------------------------------------

  /// Main brand gradient.
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  /// Premium purple-to-gold gradient.
  static const LinearGradient premiumGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, gold],
  );

  /// Dark background gradient used by premium screens.
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [background, backgroundSecondary],
  );
}
