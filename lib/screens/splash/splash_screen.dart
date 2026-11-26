import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/supabase_config.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/supabase_service.dart';
import '../../core/themes/themes.dart';

/// Initial screen displayed when Steal Here launches.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: AppConstants.animationSlow,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();

    _navigateAfterSplash();
  }

  /// Shows a longer splash for signed-out users and a shorter
  /// splash for users who already have an authenticated session.
  void _navigateAfterSplash() {
    final isConfigured = SupabaseConfig.isConfigured;

    final isAuthenticated = isConfigured && SupabaseService.currentUser != null;

    final duration = isAuthenticated
        ? const Duration(seconds: 6)
        : const Duration(seconds: 10);

    _navigationTimer = Timer(duration, () {
      if (!mounted) return;

      _completeNavigation(isConfigured);
    });
  }

  void _completeNavigation(bool isConfigured) {
    // Preserve the demonstration flow when Supabase is not configured.
    if (!isConfigured) {
      context.go(AppRoutes.onboarding);
      return;
    }

    try {
      // Check the session again in case authentication changed
      // while the splash screen was visible.
      final user = SupabaseService.currentUser;

      if (!mounted) return;

      if (user != null) {
        context.go(AppRoutes.home);
      } else {
        context.go(AppRoutes.onboarding);
      }
    } catch (error, stackTrace) {
      debugPrint('Could not restore authentication session: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      context.go(AppRoutes.onboarding);
    }
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.pagePadding),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Brand icon
                      Container(
                        width: 108,
                        height: 108,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                            width: 1,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.purpleGlow,
                              blurRadius: 36,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.shopping_bag_rounded,
                          size: 56,
                          color: AppColors.white,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Brand name
                      Text(
                        AppConstants.appName,
                        style: AppTextStyles.displayMedium.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 12),

                      // Tagline
                      Text(
                        AppConstants.appTagline,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.gold,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 44),

                      // Loading indicator
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.primaryLight,
                        ),
                      ),

                      const SizedBox(height: 20),

                      Text(
                        'A smarter way to shop.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
