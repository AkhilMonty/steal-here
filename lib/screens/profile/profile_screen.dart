import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routes/app_routes.dart';
import '../../core/services/auth_service.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_spacing.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/themes/app_decorations.dart';
import 'my_review_reports_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _background = AppColors.background;
  static const Color _surface = AppColors.surface;
  static const Color _primary = AppColors.primary;
  static const Color _gold = AppColors.gold;
  static const Color _muted = AppColors.textMuted;

  Future<void> _openEditProfile(BuildContext context) async {
    final updated = await context.push<bool>(AppRoutes.editProfile);

    if (updated == true && mounted) {
      setState(() {});
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));

    if (parts.isEmpty || parts.first.isEmpty) {
      return 'U';
    }

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Future<void> _logout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
            side: BorderSide(color: _primary.withValues(alpha: 0.25)),
          ),
          title: const Text('Logout', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Are you sure you want to logout from your account?',
            style: TextStyle(color: _muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true || !context.mounted) {
      return;
    }

    try {
      await AuthService.logout();

      if (!context.mounted) return;

      context.go(AppRoutes.login);
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;

    final metadata = user?.userMetadata ?? {};

    final fullName = (metadata['full_name'] as String?)?.trim();

    final name = fullName == null || fullName.isEmpty
        ? 'Steal Here User'
        : fullName;

    final email = user?.email ?? 'No email available';

    final phone = (metadata['phone'] as String?)?.trim();

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Text(
          'My Profile',
          style: AppTextStyles.headingSmall.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          tooltip: 'Go back',
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Home',
            onPressed: () => context.go(AppRoutes.home),
            icon: const Icon(Icons.home_outlined, color: Colors.white),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            AppSpacing.md,
            AppSpacing.pageHorizontal,
            AppSpacing.xxxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header
              // Profile Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: AppDecorations.premiumCard,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _gold.withValues(alpha: 0.6),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 43,
                        backgroundColor: _primary,
                        child: Text(
                          _getInitials(name),
                          style: AppTextStyles.headingMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headingMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      email,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusCircular,
                        ),
                        border: Border.all(
                          color: _gold.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified_user_outlined,
                            color: _gold,
                            size: 16,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'Steal Here Member',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: _gold,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // Edit Profile
              _buildMenuCard(
                icon: Icons.edit_outlined,
                title: 'Edit Profile',
                subtitle: 'Update your name and phone number',
                iconColor: _primary,
                onTap: () => _openEditProfile(context),
              ),

              const SizedBox(height: 15),

              // Shopping Section
              _buildSectionTitle('MY SHOPPING'),

              const SizedBox(height: 12),

              _buildMenuCard(
                icon: Icons.shopping_bag_outlined,
                title: 'My Orders',
                subtitle: 'Track and manage your orders',
                onTap: () => context.push(AppRoutes.orders),
              ),

              _buildMenuCard(
                icon: Icons.favorite_border,
                title: 'My Wishlist',
                subtitle: 'Your saved favorite products',
                onTap: () => context.push(AppRoutes.wishlist),
              ),

              _buildMenuCard(
                icon: Icons.shopping_cart_outlined,
                title: 'My Cart',
                subtitle: 'View your shopping cart',
                onTap: () => context.push(AppRoutes.cart),
              ),

              _buildMenuCard(
                icon: Icons.location_on_outlined,
                title: 'My Addresses',
                subtitle: 'Manage your delivery addresses',
                iconColor: _primary,
                onTap: () => context.push(AppRoutes.addresses),
              ),

              const SizedBox(height: 26),

              // Account Section
              _buildSectionTitle('ACCOUNT INFORMATION'),

              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: AppDecorations.card,
                child: Column(
                  children: [
                    _buildInformationRow(
                      icon: Icons.person_outline,
                      title: 'Full Name',
                      value: name,
                    ),
                    Divider(
                      color: AppColors.textMuted.withValues(alpha: 0.15),
                      height: AppSpacing.xxl,
                    ),
                    _buildInformationRow(
                      icon: Icons.email_outlined,
                      title: 'Email Address',
                      value: email,
                    ),
                    if (phone != null && phone.isNotEmpty) ...[
                      Divider(
                        color: AppColors.textMuted.withValues(alpha: 0.15),
                        height: AppSpacing.xxl,
                      ),
                      _buildInformationRow(
                        icon: Icons.phone_outlined,
                        title: 'Phone Number',
                        value: phone,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 26),

              // Account Actions
              _buildSectionTitle('ACCOUNT SETTINGS'),

              const SizedBox(height: 12),

              _buildMenuCard(
                icon: Icons.mark_email_read_outlined,
                title: 'Change Email Address',
                subtitle: 'Update your account email securely',
                iconColor: _gold,
                onTap: () => context.push(AppRoutes.changeEmail),
              ),

              _buildMenuCard(
                icon: Icons.lock_reset_outlined,
                title: 'Change Password',
                subtitle: 'Update your account password securely',
                iconColor: _primary,
                onTap: () => context.push(AppRoutes.changePassword),
              ),

              _buildMenuCard(
                icon: Icons.history,
                title: 'Recent Account Activity',
                subtitle: 'Review your profile changes and security events',
                iconColor: _gold,
                onTap: () => context.push(AppRoutes.accountActivity),
              ),

              _buildMenuCard(
                icon: Icons.flag_outlined,
                title: 'My Review Reports',
                subtitle: 'Track reports you have submitted',
                iconColor: _gold,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MyReviewReportsScreen(),
                    ),
                  );
                },
              ),

              _buildMenuCard(
                icon: Icons.logout,
                title: 'Logout',
                subtitle: 'Sign out from your account',
                iconColor: Colors.redAccent,
                onTap: () => _logout(context),
                showArrow: false,
              ),

              const SizedBox(height: 30),

              Center(
                child: Column(
                  children: [
                    Text(
                      'STEAL HERE',
                      style: AppTextStyles.headingSmall.copyWith(
                        color: _primary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Luxury Deals. Powerful Experience.',
                      style: AppTextStyles.bodySmall.copyWith(color: _muted),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Version 1.0.0',
                      style: AppTextStyles.labelSmall.copyWith(color: _muted),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 17,
            decoration: BoxDecoration(
              color: _gold,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCircular),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            title,
            style: AppTextStyles.labelMedium.copyWith(
              color: _gold,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color iconColor = _primary,
    bool showArrow = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: AppDecorations.card,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusMedium,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: AppSpacing.iconMedium,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showArrow)
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AppColors.textMuted,
                    size: 15,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInformationRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          ),
          child: Icon(icon, color: _primary, size: AppSpacing.iconMedium),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
