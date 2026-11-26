import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../screens/onboarding/onboarding_screen.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/welcome/welcome_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/auth/email_verification_screen.dart';
import '../../screens/auth/email_verified_screen.dart';

import 'app_routes.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/product/product_details_screen.dart';
import '../../screens/cart/cart_screen.dart';
import '../../screens/wishlist/wishlist_screen.dart';
import '../../screens/checkout/checkout_screen.dart';
import '../../models/order_confirmation_data.dart';
import '../../screens/checkout/order_confirmation_screen.dart';
import '../../screens/orders/orders_screen.dart';
import '../../models/order_model.dart';
import '../../screens/orders/order_details_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/profile/change_email_screen.dart';
import '../../screens/profile/change_password_screen.dart';
import '../../screens/profile/edit_profile_screen.dart';
import '../../screens/profile/browsing_history_screen.dart';
import '../../screens/categories/categories_screen.dart';
import '../../screens/search/search_screen.dart';
import '../../screens/budget/budget_screen.dart';
import '../../screens/analytics/analytics_screen.dart';
import '../../screens/compare/compare_screen.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../../screens/auth/forgot_password_screen.dart';
import '../../screens/auth/reset_password_screen.dart';
import '../../screens/profile/addresses_screen.dart';
import '../../screens/profile/account_activity_screen.dart';

import '../../models/direct_purchase_data.dart';

/// Centralized navigation configuration for Steal Here.
abstract final class AppRouter {
  AppRouter._();

  /// Main application router.
  ///
  /// The splash screen controls startup navigation and timing.
  /// Authentication redirects are intentionally not handled here,
  /// so the splash screen remains visible when the app starts.
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.splash,

    routes: [
      // ---------------------------------------------------------------
      // Splash
      // ---------------------------------------------------------------

      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // ---------------------------------------------------------------
      // Onboarding and Authentication
      // ---------------------------------------------------------------
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),

      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),

      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) {
          final email = state.uri.queryParameters['email'];

          return LoginScreen(email: email);
        },
      ),

      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),

      GoRoute(
        path: AppRoutes.emailVerification,
        builder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';

          return EmailVerificationScreen(email: email);
        },
      ),

      GoRoute(
        path: AppRoutes.emailVerified,
        builder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';

          return EmailVerifiedScreen(email: email);
        },
      ),

      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) => const ResetPasswordScreen(),
      ),

      // ---------------------------------------------------------------
      // Main Shopping
      // ---------------------------------------------------------------
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),

      GoRoute(
        path: AppRoutes.categories,
        builder: (context, state) {
          final category = state.uri.queryParameters['category'];

          return CategoriesScreen(initialCategory: category);
        },
      ),

      GoRoute(
        path: AppRoutes.search,
        builder: (context, state) => const SearchScreen(),
      ),

      GoRoute(
        path: AppRoutes.wishlist,
        builder: (context, state) => const WishlistScreen(),
      ),

      GoRoute(
        path: AppRoutes.cart,
        builder: (context, state) {
          final extra = state.extra;

          final selectedIds = extra is List<String> ? extra : null;

          return CartScreen(initialSelectedItemIds: selectedIds);
        },
      ),

      GoRoute(
        path: AppRoutes.checkout,
        builder: (context, state) {
          final extra = state.extra;

          if (extra is DirectPurchaseData) {
            return CheckoutScreen(
              selectedCartItemIds: const [],
              directPurchase: extra,
            );
          }

          final selectedCartItemIds = extra is List<String>
              ? extra
              : <String>[];

          return CheckoutScreen(selectedCartItemIds: selectedCartItemIds);
        },
      ),

      GoRoute(
        path: AppRoutes.orderConfirmation,
        builder: (context, state) {
          final confirmation = state.extra as OrderConfirmationData;

          return OrderConfirmationScreen(confirmation: confirmation);
        },
      ),

      GoRoute(
        path: AppRoutes.orders,
        builder: (context, state) => const OrdersScreen(),
      ),

      GoRoute(
        path: AppRoutes.orderDetails,
        builder: (context, state) {
          final order = state.extra as OrderModel;

          return OrderDetailsScreen(order: order);
        },
      ),

      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),

      GoRoute(
        path: AppRoutes.changeEmail,
        builder: (context, state) => const ChangeEmailScreen(),
      ),

      GoRoute(
        path: AppRoutes.changePassword,
        builder: (context, state) => const ChangePasswordScreen(),
      ),

      GoRoute(
        path: AppRoutes.accountActivity,
        builder: (context, state) => const AccountActivityScreen(),
      ),

      GoRoute(
        path: AppRoutes.editProfile,
        builder: (context, state) => const EditProfileScreen(),
      ),

      GoRoute(
        path: AppRoutes.browsingHistory,
        builder: (context, state) => const BrowsingHistoryScreen(),
      ),

      GoRoute(
        path: AppRoutes.addresses,
        builder: (context, state) => const AddressesScreen(),
      ),

      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),

      // ---------------------------------------------------------------
      // Product Details
      // ---------------------------------------------------------------
      GoRoute(
        path: AppRoutes.product,
        builder: (context, state) {
          final productId = state.pathParameters['productId']!;
          final openReview = state.uri.queryParameters['review'] == 'true';

          final extra = state.extra;

          final cartEditData =
              extra is Map<String, dynamic> && extra['isCartEditMode'] == true
              ? extra
              : null;

          return ProductDetailsScreen(
            productId: productId,
            openReviewForm: openReview,

            // Cart editing information.
            cartItemId: cartEditData?['cartItemId'] as String?,
            initialVariantId: cartEditData?['variantId'] as String?,
            initialQuantity: cartEditData?['quantity'] as int?,
          );
        },
      ),

      // ---------------------------------------------------------------
      // Smart Shopping
      // ---------------------------------------------------------------
      GoRoute(
        path: AppRoutes.budget,
        builder: (context, state) => const BudgetScreen(),
      ),

      GoRoute(
        path: AppRoutes.analytics,
        builder: (context, state) => const AnalyticsScreen(),
      ),

      GoRoute(
        path: AppRoutes.compare,
        builder: (context, state) => const CompareScreen(),
      ),

      // ---------------------------------------------------------------
      // Administration
      // ---------------------------------------------------------------
      GoRoute(
        path: AppRoutes.admin,
        builder: (context, state) => const _PlaceholderScreen(
          title: 'Admin Dashboard',
          description: 'Manage the Steal Here platform.',
          icon: Icons.admin_panel_settings_outlined,
        ),
      ),

      GoRoute(
        path: AppRoutes.adminProducts,
        builder: (context, state) => const _PlaceholderScreen(
          title: 'Manage Products',
          description: 'Create and manage product listings.',
          icon: Icons.inventory_outlined,
        ),
      ),

      GoRoute(
        path: AppRoutes.adminOrders,
        builder: (context, state) => const _PlaceholderScreen(
          title: 'Manage Orders',
          description: 'Review and manage customer orders.',
          icon: Icons.local_shipping_outlined,
        ),
      ),

      GoRoute(
        path: AppRoutes.adminUsers,
        builder: (context, state) => const _PlaceholderScreen(
          title: 'Manage Users',
          description: 'View and manage user accounts.',
          icon: Icons.people_outline,
        ),
      ),
    ],

    // ---------------------------------------------------------------
    // Error Handling
    // ---------------------------------------------------------------
    errorBuilder: (context, state) => _PlaceholderScreen(
      title: 'Page Not Found',
      description: 'The requested page could not be found.',
      icon: Icons.error_outline,
    ),
  );
}

/// Temporary page used until the corresponding feature is implemented.
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          tooltip: 'Go back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.splash);
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: const Color(0xFFA78BFA)),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
