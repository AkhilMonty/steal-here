import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/themes/themes.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.pagePadding,
              ),
              child: Column(
                  children: [
                  const Spacer(flex: 2),
                  // Brand icon
          // Premium shopping logo
          Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 35,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(
          Icons.shopping_bag_rounded,
          size: 58,
          color: Colors.white,
        ),
      ),

      const SizedBox(height: 28),

      // App name
      Text(
        'STEAL HERE',
        textAlign: TextAlign.center,
        style: AppTextStyles.displayMedium.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: 3,
        ),
      ),

      const SizedBox(height: 12),

      // App tagline
      Text(
        'Luxury Deals. Powerful Experience.',
        textAlign: TextAlign.center,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
      ),

      const Spacer(),

      // Welcome heading
      Text(
        'Shop Smarter.\nSpend Better.',
        textAlign: TextAlign.center,
        style: AppTextStyles.displaySmall.copyWith(
          fontWeight: FontWeight.bold,
          height: 1.2,
        ),
      ),

      const SizedBox(height: 16),

      // Welcome description
      Text(
        'Discover amazing deals, make smarter buying '
            'decisions, and stay in control of your budget.',
        textAlign: TextAlign.center,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary,
          height: 1.6,
        ),
      ),

      const SizedBox(height: 36),

      // Get Started button
      SizedBox(
        width: double.infinity,
        height: 56,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(
              AppConstants.buttonRadius,
            ),
          ),
          child: ElevatedButton(
            onPressed: () {
              context.go(AppRoutes.register);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  AppConstants.buttonRadius,
                ),
              ),
            ),
            child: Text(
              'Get Started',
              style: AppTextStyles.buttonLarge.copyWith(
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),

      const SizedBox(height: 16),

      // Login button
      SizedBox(
        width: double.infinity,
        height: 56,
        child: OutlinedButton(
          onPressed: () {
            context.go(AppRoutes.login);
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            backgroundColor: AppColors.surface.withValues(alpha: 0.55),
            side: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.65),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                AppConstants.buttonRadius,
              ),
            ),
          ),
          child: Text(
            'I Already Have an Account',
            style: AppTextStyles.buttonMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),

      const SizedBox(height: 24),

      // Smart shopping message
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Smarter choices. Better spending.',
              textAlign: TextAlign.center,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),

      const Spacer(),

      // Footer
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          'YOUR SMART SHOPPING JOURNEY STARTS HERE',
          textAlign: TextAlign.center,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
      ),
      ],
    ),
    ),
    ),
    ),
    );
  }
}
