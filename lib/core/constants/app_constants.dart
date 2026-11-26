/// Application-wide constants for Steal Here.
///
/// Keep reusable, non-UI configuration values here so they are not duplicated
/// throughout the application.
abstract final class AppConstants {
  // ---------------------------------------------------------------------------
  // Application Information
  // ---------------------------------------------------------------------------

  static const String appName = 'Steal Here';

  static const String appTagline = 'Luxury Deals. Powerful Experience.';

  static const String appDescription =
      'A smart e-commerce platform that helps you shop better, '
      'spend smarter, and avoid unnecessary purchases.';

  // ---------------------------------------------------------------------------
  // App Configuration
  // ---------------------------------------------------------------------------

  /// Current application version.
  static const String appVersion = '1.0.0';

  /// Maximum number of products displayed in one paginated request.
  static const int defaultPageSize = 20;

  /// Maximum number of products that can be compared at once.
  static const int maxCompareProducts = 4;

  /// Maximum number of products allowed in the cart.
  static const int maxCartQuantity = 99;

  // ---------------------------------------------------------------------------
  // Shopping Configuration
  // ---------------------------------------------------------------------------

  /// Minimum quantity allowed for a product.
  static const int minProductQuantity = 1;

  /// Default product rating shown before real reviews are available.
  static const double defaultProductRating = 0.0;

  /// Maximum product rating.
  static const double maxProductRating = 5.0;

  // ---------------------------------------------------------------------------
  // Smart Shopping
  // ---------------------------------------------------------------------------

  /// Smart Buy Advisor score considered a strong recommendation.
  static const int smartBuyStrongScore = 80;

  /// Smart Buy Advisor score considered a moderate recommendation.
  static const int smartBuyModerateScore = 60;

  /// Smart Buy Advisor score below this value indicates caution.
  static const int smartBuyCautionScore = 40;

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  /// Minimum number of characters before performing a search.
  static const int minimumSearchCharacters = 2;

  // ---------------------------------------------------------------------------
  // UI Configuration
  // ---------------------------------------------------------------------------

  /// Standard page padding used throughout the application.
  static const double pagePadding = 16.0;

  /// Standard small spacing.
  static const double spacingSmall = 8.0;

  /// Standard medium spacing.
  static const double spacingMedium = 16.0;

  /// Standard large spacing.
  static const double spacingLarge = 24.0;

  /// Standard extra-large spacing.
  static const double spacingXLarge = 32.0;

  /// Standard card border radius.
  static const double cardRadius = 16.0;

  /// Standard button border radius.
  static const double buttonRadius = 14.0;

  /// Standard input field border radius.
  static const double inputRadius = 14.0;

  // ---------------------------------------------------------------------------
  // Animation Durations
  // ---------------------------------------------------------------------------

  static const Duration animationFast = Duration(milliseconds: 200);

  static const Duration animationMedium = Duration(milliseconds: 300);

  static const Duration animationSlow = Duration(milliseconds: 500);

  // ---------------------------------------------------------------------------
  // Timeouts
  // ---------------------------------------------------------------------------

  /// Default network request timeout.
  static const Duration networkTimeout = Duration(seconds: 30);

  /// Splash screen minimum display duration.
  static const Duration splashDuration = Duration(seconds: 10);

  // ---------------------------------------------------------------------------
  // Storage Keys
  // ---------------------------------------------------------------------------

  static const String onboardingCompletedKey = 'onboarding_completed';

  static const String themeModeKey = 'theme_mode';

  static const String guestCartKey = 'guest_cart';

  static const String recentlyViewedKey = 'recently_viewed';

  static const String searchHistoryKey = 'search_history';
}