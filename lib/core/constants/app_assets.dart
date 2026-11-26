/// Centralized asset paths for the Steal Here application.
///
/// Keep all local asset references here instead of hard-coding paths
/// throughout screens and widgets.
abstract final class AppAssets {
  // ---------------------------------------------------------------------------
  // Base Paths
  // ---------------------------------------------------------------------------

  static const String _images = 'assets/images';
  static const String _icons = 'assets/icons';
  static const String _animations = 'assets/animations';

  // ---------------------------------------------------------------------------
  // Branding
  // ---------------------------------------------------------------------------

  static const String logo = '$_images/logo.png';

  static const String logoMark = '$_images/logo_mark.png';

  // ---------------------------------------------------------------------------
  // Onboarding
  // ---------------------------------------------------------------------------

  static const String onboardingShopping =
      '$_images/onboarding_shopping.png';

  static const String onboardingSmart =
      '$_images/onboarding_smart.png';

  static const String onboardingSavings =
      '$_images/onboarding_savings.png';

  // ---------------------------------------------------------------------------
  // Icons
  // ---------------------------------------------------------------------------

  static const String appIcon = '$_icons/app_icon.png';

  // ---------------------------------------------------------------------------
  // Animations
  // ---------------------------------------------------------------------------

  static const String splashAnimation =
      '$_animations/splash.json';

  static const String loadingAnimation =
      '$_animations/loading.json';

  static const String emptyCartAnimation =
      '$_animations/empty_cart.json';

  static const String emptyWishlistAnimation =
      '$_animations/empty_wishlist.json';

  static const String successAnimation =
      '$_animations/success.json';
}