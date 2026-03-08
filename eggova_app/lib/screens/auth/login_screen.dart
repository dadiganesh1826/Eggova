import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/district_data.dart';
import '../../providers/auth_provider.dart';

// The stages of the user login flow
enum _AuthStage { initial }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  bool _isAdminMode = false;
  _AuthStage _stage = _AuthStage.initial;

  // ── Admin mode ───────────────────────────────────────────────────────────
  final _emailController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  bool _adminObscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────
  // Helpers
  // ────────────────────────────────────────────────────
  void _showSnack(String msg, {bool error = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
      backgroundColor: error ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _navigate(AuthProvider auth) {
    if (!mounted) return;
    if (auth.isAdmin) {
      Navigator.pushReplacementNamed(context, '/admin-dashboard');
    } else {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  // ────────────────────────────────────────────────────
  // Google Sign-In
  // ────────────────────────────────────────────────────
  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final success = await auth.signInWithGoogle();

      if (!mounted) return;

      if (success) {
        if (auth.requiresDetails) {
          Navigator.pushNamed(context, '/complete-profile');
        } else if (auth.isPendingApproval) {
          Navigator.pushNamed(context, '/pending-approval');
        } else {
          _navigate(auth);
        }
      } else {
        if (auth.error != null) {
          _showSnack(auth.error!);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ────────────────────────────────────────────────────
  // Admin login
  // ────────────────────────────────────────────────────
  Future<void> _adminLogin() async {
    if (_isLoading) return;
    final email = _emailController.text.trim();
    final password = _adminPasswordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showSnack('Please enter email and password');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final success = await auth.login(email, password);
      if (!mounted) return;
      if (success) {
        _navigate(auth);
      } else {
        _showSnack(auth.error ?? 'Admin login failed');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ────────────────────────────────────────────────────
  // Build
  // ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo + title
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8))],
                      ),
                      child: const Icon(Icons.egg_rounded, color: AppColors.black, size: 44),
                    ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.8, 0.8)),
                    const SizedBox(height: 20),
                    Text('Eggova', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.black))
                        .animate().fadeIn(delay: 200.ms),
                    Text('Fresh Eggs, Fair Prices', style: GoogleFonts.outfit(fontSize: 14, color: AppColors.gray))
                        .animate().fadeIn(delay: 300.ms),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // ── Card ──────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: AppColors.black.withValues(alpha: 0.07), blurRadius: 24, offset: const Offset(0, 8))],
                ),
                child: _isAdminMode ? _buildAdminForm() : _buildUserFlow(),
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.08, end: 0),

              const SizedBox(height: 20),

              // ── Toggle admin mode ─────────────────────────────────────
              Center(
                child: TextButton(
                  onPressed: () => setState(() {
                    _isAdminMode = !_isAdminMode;
                  }),
                  child: Text(
                    _isAdminMode ? 'Login as Customer' : 'Admin Login',
                    style: GoogleFonts.outfit(fontSize: 13, color: AppColors.gray),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────
  // User flow (Google Only)
  // ────────────────────────────
  Widget _buildUserFlow() {
    return Column(
      key: const ValueKey('google_auth'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Welcome!', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.black)),
        const SizedBox(height: 4),
        Text('Sign in to continue to Eggova', style: GoogleFonts.outfit(fontSize: 14, color: AppColors.gray)),
        const SizedBox(height: 32),
        
        // Google Button
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton(
            onPressed: _isLoading ? null : _handleGoogleSignIn,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.gray.withOpacity(0.2)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading)
                  const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                else ...[
                   Image.network(
                    'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_\"G\"_logo.svg/1024px-Google_\"G\"_logo.svg.png',
                    height: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Sign in with Google',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.darkGray),
                  ),
                ],
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        Text(
          'By continuing, you agree to our Terms of Service.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(fontSize: 12, color: AppColors.gray),
        ),
      ],
    );
  }

  // ────────────────────────────
  // Admin form
  // ────────────────────────────
  Widget _buildAdminForm() {
    return Column(
      key: const ValueKey('admin'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Admin Login', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.black)),
        const SizedBox(height: 4),
        Text('Authorised personnel only', style: GoogleFonts.outfit(fontSize: 14, color: AppColors.gray)),
        const SizedBox(height: 24),
        _textField('Email', _emailController, icon: Icons.email_outlined, keyboard: TextInputType.emailAddress),
        const SizedBox(height: 14),
        _passwordField('Password', _adminPasswordController, _adminObscure, () => setState(() => _adminObscure = !_adminObscure)),
        const SizedBox(height: 20),
        _primaryButton('Login as Admin', _adminLogin),
      ],
    );
  }

  // ────────────────────────────
  // Reusable widgets
  // ────────────────────────────
  Widget _textField(String label, TextEditingController controller, {IconData? icon, TextInputType? keyboard}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      style: GoogleFonts.outfit(fontSize: 15, color: AppColors.darkGray),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.outfit(color: AppColors.gray),
        prefixIcon: icon != null ? Icon(icon, color: AppColors.gray) : null,
        filled: true,
        fillColor: AppColors.offWhite,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _passwordField(String label, TextEditingController controller, bool obscure, VoidCallback toggle) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: GoogleFonts.outfit(fontSize: 15, color: AppColors.darkGray),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.outfit(color: AppColors.gray),
        prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.gray),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.gray),
          onPressed: toggle,
        ),
        filled: true,
        fillColor: AppColors.offWhite,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _primaryButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.black,
          disabledBackgroundColor: AppColors.lightGray.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.black))
            : Text(label, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
