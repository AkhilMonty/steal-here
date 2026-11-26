/// Centralized route paths for the Steal Here application.
///
/// Keeping route paths in one place prevents spelling mistakes
/// and makes navigation easier to maintain.
abstract final class AppRoutes {
  // Prevent instantiation.
  AppRoutes._();

  // ---------------------------------------------------------------------------
  // Initial Routes
  // ---------------------------------------------------------------------------

  /// Initial application entry route.
  static const String splash = '/';

  /// Introduction screens for new users.
  static const String onboarding = '/onboarding';

  /// Welcome screen shown after onboarding.
  static const String welcome = '/welcome';

  // ---------------------------------------------------------------------------
  // Authentication Routes
  // ---------------------------------------------------------------------------

  static const String login = '/login';

  static const String register = '/register';

  static const String emailVerification = '/email-verification';

  static const String emailVerified = '/email-verified';

  static const String forgotPassword = '/forgot-password';

  static const String resetPassword = '/reset-password';

  // ---------------------------------------------------------------------------
  // Main Shopping Routes
  // ---------------------------------------------------------------------------

  static const String home = '/home';

  static const String categories = '/categories';

  static const String search = '/search';

  static const String wishlist = '/wishlist';

  static const String cart = '/cart';

  static const String checkout = '/checkout';

  static const String orderConfirmation = '/order-confirmation';

  static const String orders = '/orders';

  static const String orderDetails = '/order-details';

  static const String profile = '/profile';

  static const String changeEmail = '/change-email';

  static const String changePassword = '/change-password';

  static const String accountActivity = '/account-activity';

  static const String editProfile = '/edit-profile';

  static const String browsingHistory = '/browsing-history';

  static const String addresses = '/addresses';

  static const String notifications = '/notifications';

  // ---------------------------------------------------------------------------
  // Product Routes
  // ---------------------------------------------------------------------------

  /// Product details route.
  ///
  /// Example: /product/123
  static const String product = '/product/:productId';

  /// Creates a product details path for a specific product.
  static String productDetails(String productId, {bool openReview = false}) {
    final path = '/product/$productId';

    return openReview ? '$path?review=true' : path;
  }

  // ---------------------------------------------------------------------------
  // Smart Shopping Routes
  // ---------------------------------------------------------------------------

  static const String budget = '/budget';

  static const String analytics = '/analytics';

  static const String compare = '/compare';

  // ---------------------------------------------------------------------------
  // Administration Routes
  // ---------------------------------------------------------------------------

  static const String admin = '/admin';

  static const String adminProducts = '/admin/products';

  static const String adminOrders = '/admin/orders';

  static const String adminUsers = '/admin/users';
}
