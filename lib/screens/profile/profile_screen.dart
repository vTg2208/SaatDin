import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/tab_router.dart';
import '../../theme/app_colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static final ApiService _apiService = ApiService();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<User>(
      future: _apiService.getProfile('me'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.scaffoldBackground,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return const Scaffold(
            backgroundColor: AppColors.scaffoldBackground,
            body: Center(
              child: Text(
                'Failed to load profile. Please retry.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        }

        final user = snapshot.data!;
        final email =
            '${user.name.toLowerCase().replaceAll(' ', '')}@saatdin.app';

        return Scaffold(
          backgroundColor: AppColors.scaffoldBackground,
          body: Stack(
            children: [
              _buildGlassTopBackground(),
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopBar(context, user),
                      const SizedBox(height: 20),
                      const Text(
                        'Account',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildAccountCard(user, email),
                      const SizedBox(height: 24),
                      const Text(
                        'Team',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildOptionTile(
                        icon: Icons.settings_outlined,
                        title: 'Settings',
                        onTap: () => _showSimpleInfo(context, 'Settings panel opened.'),
                      ),
                      _buildOptionTile(
                        icon: Icons.dark_mode_outlined,
                        title: 'Theme',
                        onTap: () => _showSimpleInfo(context, 'Theme controls opened.'),
                      ),
                      _buildOptionTile(
                        icon: Icons.info_outline,
                        title: 'Help and resources',
                        onTap: () => _showSimpleInfo(context, 'Help center opened.'),
                      ),
                      _buildOptionTile(
                        icon: Icons.grid_view_rounded,
                        title: 'Advanced tools',
                        badge: 'Beta',
                        onTap: () => _showSimpleInfo(context, 'Advanced tools coming soon.'),
                      ),
                      _buildOptionTile(
                        icon: Icons.work_outline,
                        title: 'Plans and pricing',
                        onTap: () => _switchToTab(context, 2),
                      ),
                      _buildOptionTile(
                        icon: Icons.history,
                        title: 'Claims history',
                        onTap: () => _switchToTab(context, 1),
                      ),
                      _buildOptionTile(
                        icon: Icons.payments_outlined,
                        title: 'Payouts',
                        onTap: () => _switchToTab(context, 3),
                      ),
                      _buildOptionTile(
                        icon: Icons.logout,
                        title: 'Log out',
                        onTap: () => _confirmLogout(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context, User user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _headerIconButton(
          icon: Icons.arrow_back,
          tooltip: 'Back to Home',
          onTap: () {
            _switchToTab(context, 0);
          },
        ),
        Row(
          children: [
            _headerIconButton(
              icon: Icons.notifications_none,
              tooltip: 'Notifications',
              onTap: () {
                _showNotificationsSheet(context);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _headerIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          ),
          child: Icon(icon, size: 21, color: AppColors.textPrimary),
        ),
      ),
    );
  }

  Widget _buildAccountCard(User user, String email) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    user.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.52),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  Icons.keyboard_arrow_down,
                  size: 24,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassTopBackground() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SizedBox(
        height: 230,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryLight.withValues(alpha: 0.22),
                      AppColors.accent.withValues(alpha: 0.13),
                      AppColors.background,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -28,
              right: -34,
              child: _glassOrb(size: 146, opacity: 0.22),
            ),
            Positioned(
              top: 36,
              left: -22,
              child: _glassOrb(size: 96, opacity: 0.20),
            ),
            Positioned(
              top: 128,
              left: 80,
              right: 80,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.38),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassOrb({required double size, required double opacity}) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? badge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Icon(icon, size: 27, color: AppColors.textPrimary),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
            const Spacer(),
            const Icon(
              Icons.chevron_right,
              size: 28,
              color: AppColors.textPrimary,
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          children: const [
            ListTile(
              leading: Icon(Icons.verified_outlined),
              title: Text('Profile verification completed'),
              subtitle: Text('Your account details are fully up to date'),
            ),
            ListTile(
              leading: Icon(Icons.shield_outlined),
              title: Text('Security reminder'),
              subtitle: Text('Review device activity once every week'),
            ),
          ],
        );
      },
    );
  }

  void _showSimpleInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _switchToTab(BuildContext context, int index) {
    TabRouter.switchTo(index);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _confirmLogout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Log out'),
          content: const Text('Are you sure you want to log out of this account?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.welcome,
                  (route) => false,
                );
              },
              child: const Text('Log out'),
            ),
          ],
        );
      },
    );
  }
}
