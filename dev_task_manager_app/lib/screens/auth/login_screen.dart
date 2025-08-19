import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../utils/constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _rememberMe = false;

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
      curve: const Interval(0.0, 0.8, curve: Curves.easeInOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));

    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppConstants.whiteColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.message,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                backgroundColor: AppConstants.errorColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                ),
                margin: const EdgeInsets.all(AppConstants.defaultPadding),
              ),
            );
          }
          if (state is AuthSuccess) {
            context.go('/home');
          }
        },
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppConstants.backgroundGradient,
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.largePadding),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      _buildHeader(),
                      const SizedBox(height: 50),
                      _buildLoginCard(),
                      const SizedBox(height: 24),
                      _buildFooter(),
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

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: AppConstants.primaryGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppConstants.glowShadow,
          ),
          child: const Icon(
            Icons.code,
            size: 45,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 30),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFE2E8F0), Color(0xFF94A3B8)],
          ).createShader(bounds),
          child: Text(
            'DevTask Manager',
            style: AppConstants.headerStyle.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Code. Track. Ship.',
          style: AppConstants.bodyStyle.copyWith(
            fontSize: 18,
            color: AppConstants.textSecondaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor.withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppConstants.borderColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: AppConstants.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.largePadding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back',
                style: AppConstants.subHeaderStyle.copyWith(
                  color: AppConstants.textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to continue your development journey',
                style: AppConstants.bodyStyle.copyWith(
                  color: AppConstants.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 32),
              _buildEmailField(),
              const SizedBox(height: 20),
              _buildPasswordField(),
              const SizedBox(height: 20),
              _buildRememberMeRow(),
              const SizedBox(height: 32),
              _buildLoginButton(),
              const SizedBox(height: 24),
              _buildDivider(),
              const SizedBox(height: 24),
              _buildSocialButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Email',
          style: AppConstants.bodyStyle.copyWith(
            color: AppConstants.textColor,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: AppConstants.textColor),
          decoration: InputDecoration(
            hintText: 'developer@example.com',
            prefixIcon: Icon(
              Icons.alternate_email,
              color: AppConstants.textSecondaryColor,
              size: 20,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Email is required';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Enter a valid email';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Password',
          style: AppConstants.bodyStyle.copyWith(
            color: AppConstants.textColor,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(color: AppConstants.textColor),
          decoration: InputDecoration(
            hintText: 'Enter your password',
            prefixIcon: Icon(
              Icons.lock_outline,
              color: AppConstants.textSecondaryColor,
              size: 20,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: AppConstants.textSecondaryColor,
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Password is required';
            }
            if (value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildRememberMeRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Theme(
              data: Theme.of(context).copyWith(
                checkboxTheme: CheckboxThemeData(
                  fillColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppConstants.primaryColor;
                    }
                    return Colors.transparent;
                  }),
                  side: const BorderSide(
                    color: AppConstants.borderColor,
                    width: 2,
                  ),
                ),
              ),
              child: Checkbox(
                value: _rememberMe,
                onChanged: (value) {
                  setState(() {
                    _rememberMe = value ?? false;
                  });
                },
              ),
            ),
            Text(
              'Remember me',
              style: AppConstants.bodyStyle.copyWith(
                color: AppConstants.textColor,
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: () {
            // TODO: Implement forgot password
          },
          child: Text(
            'Forgot password?',
            style: AppConstants.bodyStyle.copyWith(
              color: AppConstants.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        return Container(
          width: double.infinity,
          height: AppConstants.buttonHeight,
          decoration: BoxDecoration(
            gradient: state is AuthLoading 
                ? null 
                : const LinearGradient(colors: AppConstants.primaryGradient),
            borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
            color: state is AuthLoading ? AppConstants.borderColor : null,
          ),
          child: ElevatedButton(
            onPressed: state is AuthLoading
                ? null
                : () {
                    if (_formKey.currentState!.validate()) {
                      context.read<AuthBloc>().add(
                            LoginRequested(
                              email: _emailController.text.trim(),
                              password: _passwordController.text,
                            ),
                          );
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
              ),
            ),
            child: state is AuthLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppConstants.textSecondaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Signing in...',
                        style: AppConstants.buttonStyle.copyWith(
                          color: AppConstants.textSecondaryColor,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.login, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Sign In',
                        style: AppConstants.buttonStyle,
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Divider(color: AppConstants.borderColor.withOpacity(0.5)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or continue with',
            style: AppConstants.bodyStyle.copyWith(
              color: AppConstants.textSecondaryColor,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: AppConstants.borderColor.withOpacity(0.5)),
        ),
      ],
    );
  }

  Widget _buildSocialButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildSocialButton(
            icon: Icons.g_mobiledata,
            label: 'Google',
            color: Colors.red,
            onPressed: () {
              // TODO: Implement Google sign in
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSocialButton(
            icon: Icons.facebook,
            label: 'Facebook',
            color: Colors.blue,
            onPressed: () {
              // TODO: Implement Facebook sign in
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: AppConstants.inputFillColor,
        borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
        border: Border.all(
          color: AppConstants.borderColor.withOpacity(0.3),
        ),
      ),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: color, size: 20),
        label: Text(
          label,
          style: AppConstants.bodyStyle.copyWith(
            color: AppConstants.textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Don't have an account? ",
              style: AppConstants.bodyStyle.copyWith(
                color: AppConstants.textSecondaryColor,
              ),
            ),
            TextButton(
              onPressed: () => context.go('/register'),
              child: Text(
                'Sign Up',
                style: AppConstants.bodyStyle.copyWith(
                  color: AppConstants.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '© 2024 DevTask Manager. Built for developers.',
          style: AppConstants.captionStyle.copyWith(
            color: AppConstants.textSecondaryColor.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}