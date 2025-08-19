import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../utils/constants.dart';
import '../../models/user.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppConstants.backgroundGradient,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    children: [
                      _buildTopBar(context),
                      const SizedBox(height: 32),
                      BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, state) {
                          if (state is AuthSuccess) {
                            return _buildProfileContent(context, state.user);
                          }
                          return _buildNoUserData();
                        },
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

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppConstants.surfaceColor.withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppConstants.borderColor.withOpacity(0.3),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.go('/home'),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  Icons.arrow_back_ios,
                  color: AppConstants.textColor,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile Settings',
                style: AppConstants.headerStyle.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Manage your account',
                style: AppConstants.bodyStyle.copyWith(
                  color: AppConstants.textSecondaryColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppConstants.surfaceColor.withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppConstants.borderColor.withOpacity(0.3),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showModernLogoutDialog(context),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  Icons.logout_outlined,
                  color: AppConstants.errorColor,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoUserData() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppConstants.borderColor.withOpacity(0.3),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off_outlined,
              color: AppConstants.textSecondaryColor,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'No user data available',
              style: AppConstants.subHeaderStyle.copyWith(
                color: AppConstants.textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, User user) {
    return Column(
      children: [
        _buildProfileHeader(user),
        const SizedBox(height: 24),
        _buildQuickActions(context),
        const SizedBox(height: 24),
        _buildAccountSettings(context),
        const SizedBox(height: 24),
        _buildAppSettings(context),
      ],
    );
  }

  Widget _buildProfileHeader(User user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppConstants.borderColor.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppConstants.primaryGradient,
                  ),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: AppConstants.primaryColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppConstants.successColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppConstants.surfaceColor,
                      width: 3,
                    ),
                  ),
                  child: const Icon(
                    Icons.verified,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: AppConstants.primaryGradient,
            ).createShader(bounds),
            child: Text(
              user.name,
              style: AppConstants.headerStyle.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            user.email,
            style: AppConstants.bodyStyle.copyWith(
              color: AppConstants.textSecondaryColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: AppConstants.primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppConstants.primaryColor.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.code,
                  color: AppConstants.primaryColor,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  user.role.toUpperCase(),
                  style: TextStyle(
                    color: AppConstants.primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.assignment_turned_in,
                  label: 'Tasks Completed',
                  value: '24',
                  color: AppConstants.successColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.schedule,
                  label: 'Active Tasks',
                  value: '8',
                  color: AppConstants.warningColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.cardColor.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppConstants.subHeaderStyle.copyWith(
              fontSize: 18,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppConstants.captionStyle.copyWith(
              color: AppConstants.textSecondaryColor,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return _buildModernCard(
      title: 'Quick Actions',
      icon: Icons.rocket_launch,
      children: [
        _buildModernActionTile(
          icon: Icons.edit_outlined,
          title: 'Edit Profile',
          subtitle: 'Update personal information',
          gradient: AppConstants.primaryGradient,
          onTap: () {
            _showComingSoon(context, 'Edit profile');
          },
        ),
        const SizedBox(height: 12),
        _buildModernActionTile(
          icon: Icons.lock_outline,
          title: 'Change Password',
          subtitle: 'Update account security',
          gradient: const [Color(0xFF06B6D4), Color(0xFF8B5CF6)],
          onTap: () {
            _showComingSoon(context, 'Change password');
          },
        ),
        const SizedBox(height: 12),
        _buildModernActionTile(
          icon: Icons.assignment_outlined,
          title: 'My Tasks',
          subtitle: 'View and manage tasks',
          gradient: const [Color(0xFF10B981), Color(0xFF06B6D4)],
          onTap: () => context.go('/tasks'),
        ),
      ],
    );
  }

  Widget _buildAccountSettings(BuildContext context) {
    return _buildModernCard(
      title: 'Account Settings',
      icon: Icons.settings_outlined,
      children: [
        _buildModernActionTile(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          subtitle: 'Manage preferences',
          gradient: const [Color(0xFFF59E0B), Color(0xFFEF4444)],
          onTap: () {
            _showComingSoon(context, 'Notifications');
          },
        ),
        const SizedBox(height: 12),
        _buildModernActionTile(
          icon: Icons.security_outlined,
          title: 'Privacy & Security',
          subtitle: 'Manage privacy settings',
          gradient: const [Color(0xFF8B5CF6), Color(0xFFEC4899)],
          onTap: () {
            _showComingSoon(context, 'Privacy settings');
          },
        ),
        const SizedBox(height: 12),
        _buildModernActionTile(
          icon: Icons.download_outlined,
          title: 'Export Data',
          subtitle: 'Download task data',
          gradient: const [Color(0xFF06B6D4), Color(0xFF3B82F6)],
          onTap: () {
            _showComingSoon(context, 'Export data');
          },
        ),
      ],
    );
  }

  Widget _buildAppSettings(BuildContext context) {
    return _buildModernCard(
      title: 'App Settings',
      icon: Icons.apps_outlined,
      children: [
        _buildModernActionTile(
          icon: Icons.help_outline,
          title: 'Help & Support',
          subtitle: 'Get help and contact support',
          gradient: const [Color(0xFF10B981), Color(0xFF059669)],
          onTap: () {
            _showComingSoon(context, 'Help & Support');
          },
        ),
        const SizedBox(height: 12),
        _buildModernActionTile(
          icon: Icons.info_outline,
          title: 'About',
          subtitle: 'App version and info',
          gradient: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          onTap: () => _showModernAboutDialog(context),
        ),
        const SizedBox(height: 12),
        _buildModernActionTile(
          icon: Icons.logout_outlined,
          title: 'Sign Out',
          subtitle: 'Log out of your account',
          gradient: const [Color(0xFFEF4444), Color(0xFFDC2626)],
          onTap: () => _showModernLogoutDialog(context),
        ),
      ],
    );
  }

  Widget _buildModernCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppConstants.borderColor.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppConstants.primaryGradient,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: AppConstants.subHeaderStyle.copyWith(
                  color: AppConstants.textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildModernActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppConstants.cardColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppConstants.borderColor.withOpacity(0.2),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppConstants.bodyStyle.copyWith(
                          color: AppConstants.textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppConstants.captionStyle.copyWith(
                          color: AppConstants.textSecondaryColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: AppConstants.textSecondaryColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: AppConstants.whiteColor),
            const SizedBox(width: 8),
            Text(
              '$feature - Coming soon!',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        backgroundColor: AppConstants.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showModernAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppConstants.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppConstants.primaryGradient,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.code,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'DevTask Manager',
                style: AppConstants.subHeaderStyle.copyWith(
                  color: AppConstants.textColor,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Version 1.0.0',
                style: AppConstants.bodyStyle.copyWith(
                  color: AppConstants.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'A modern task management app designed specifically for software developers.',
                style: AppConstants.bodyStyle.copyWith(
                  color: AppConstants.textSecondaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppConstants.cardColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Built with Flutter & ❤️',
                  style: AppConstants.captionStyle.copyWith(
                    color: AppConstants.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Got it!',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showModernLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppConstants.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppConstants.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.logout_outlined,
                  color: AppConstants.errorColor,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Sign Out',
                style: AppConstants.subHeaderStyle.copyWith(
                  color: AppConstants.textColor,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to sign out of your account?',
                style: AppConstants.bodyStyle.copyWith(
                  color: AppConstants.textSecondaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: AppConstants.textSecondaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.read<AuthBloc>().add(LogoutRequested());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.errorColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Sign Out',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}