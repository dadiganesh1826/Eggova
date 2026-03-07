import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/district_data.dart';
import '../../providers/auth_provider.dart';

// The stages of the user login flow
enum _AuthStage { phoneEntry, login, register, forgotPassword }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ── Shared ──────────────────────────────────────────────────────────────
  final _phoneController = TextEditingController();
  _AuthStage _stage = _AuthStage.phoneEntry;
  bool _isLoading = false;
  bool _isAdminMode = false;

  // ── Login stage ──────────────────────────────────────────────────────────
  final _loginPasswordController = TextEditingController();
  bool _loginObscure = true;

  // ── Register stage ───────────────────────────────────────────────────────
  final _nameController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _selectedDistrict;
  bool _regObscure = true;
  bool _confirmObscure = true;

  // ── Forgot Password stage ────────────────────────────────────────────────
  final _forgotPasswordController = TextEditingController();
  final _forgotConfirmController = TextEditingController();
  bool _forgotObscure = true;
  bool _forgotConfirmObscure = true;

  // ── Admin mode ───────────────────────────────────────────────────────────
  final _emailController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  bool _adminObscure = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _loginPasswordController.dispose();
    _nameController.dispose();
    _regPasswordController.dispose();
    _confirmPasswordController.dispose();
    _emailController.dispose();
    _adminPasswordController.dispose();
    _forgotPasswordController.dispose();
    _forgotConfirmController.dispose();
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
      Navigator.pushReplacementNamed(context, '/user-dashboard');
    }
  }

  // ────────────────────────────────────────────────────
  // Step 1 — Check phone
  // ────────────────────────────────────────────────────
  Future<void> _checkPhone() async {
    if (_isLoading) return;
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      _showSnack('Please enter a valid 10-digit mobile number');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final isExisting = await auth.checkPhone(phone);
      if (!mounted) return;
      if (isExisting == null) {
        _showSnack(auth.error ?? 'Something went wrong');
        return;
      }
      setState(() => _stage = isExisting ? _AuthStage.login : _AuthStage.register);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ────────────────────────────────────────────────────
  // Step 2a — Login
  // ────────────────────────────────────────────────────
  Future<void> _login() async {
    if (_isLoading) return;
    final phone = _phoneController.text.trim();
    final password = _loginPasswordController.text;
    if (password.isEmpty) {
      _showSnack('Please enter your password');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final success = await auth.loginWithPassword(phone, password);
      if (!mounted) return;
      if (success) {
        _navigate(auth);
      } else {
        _showSnack(auth.error ?? 'Login failed');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ────────────────────────────────────────────────────
  // Step 2b — Register
  // ────────────────────────────────────────────────────
  Future<void> _register() async {
    if (_isLoading) return;
    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();
    final password = _regPasswordController.text;
    final confirm = _confirmPasswordController.text;

    if (name.isEmpty) { _showSnack('Please enter your name'); return; }
    if (_selectedDistrict == null) { _showSnack('Please select your district'); return; }
    if (password.length < 6) { _showSnack('Password must be at least 6 characters'); return; }
    if (password != confirm) { _showSnack('Passwords do not match'); return; }

    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final success = await auth.registerUser(phone, password, name, _selectedDistrict!);
      if (!mounted) return;
      if (success) {
        _navigate(auth);
      } else {
        _showSnack(auth.error ?? 'Registration failed');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ────────────────────────────────────────────────────
  // Step 2c — Forgot Password
  // ────────────────────────────────────────────────────
  Future<void> _resetPassword() async {
    if (_isLoading) return;
    final phone = _phoneController.text.trim();
    final password = _forgotPasswordController.text;
    final confirm = _forgotConfirmController.text;

    if (password.length < 6) { _showSnack('Password must be at least 6 characters'); return; }
    if (password != confirm) { _showSnack('Passwords do not match'); return; }

    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final success = await auth.forgotPassword(phone, password);
      if (!mounted) return;
      if (success) {
        _showSnack('Password reset successfully! Please login.', error: false);
        _forgotPasswordController.clear();
        _forgotConfirmController.clear();
        setState(() => _stage = _AuthStage.login);
      } else {
        _showSnack(auth.error ?? 'Failed to reset password');
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
                    _stage = _AuthStage.phoneEntry;
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
  // User flow (all 3 stages)
  // ────────────────────────────
  Widget _buildUserFlow() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
      child: switch (_stage) {
        _AuthStage.phoneEntry     => _buildPhoneEntry(),
        _AuthStage.login          => _buildLoginForm(),
        _AuthStage.register       => _buildRegisterForm(),
        _AuthStage.forgotPassword => _buildForgotPasswordForm(),
      },
    );
  }

  Widget _buildPhoneEntry() {
    return Column(
      key: const ValueKey('phone'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Welcome!', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.black)),
        const SizedBox(height: 4),
        Text('Enter your mobile number to continue', style: GoogleFonts.outfit(fontSize: 14, color: AppColors.gray)),
        const SizedBox(height: 24),
        _phoneField(),
        const SizedBox(height: 20),
        _primaryButton('Continue', _checkPhone),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Column(
      key: const ValueKey('login'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          GestureDetector(
            onTap: () => setState(() => _stage = _AuthStage.phoneEntry),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.darkGray),
          ),
          const SizedBox(width: 10),
          Text('Login', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.black)),
        ]),
        const SizedBox(height: 4),
        Text('Welcome back! 👋', style: GoogleFonts.outfit(fontSize: 14, color: AppColors.gray)),
        const SizedBox(height: 24),
        _phoneField(readOnly: true),
        const SizedBox(height: 14),
        _passwordField('Password', _loginPasswordController, _loginObscure, () => setState(() => _loginObscure = !_loginObscure)),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => setState(() => _stage = _AuthStage.forgotPassword),
            child: Text(
              'Forgot Password?',
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _primaryButton('Login', _login),
      ],
    );
  }

  Widget _buildRegisterForm() {
    final districts = DistrictData.allDistricts;
    return Column(
      key: const ValueKey('register'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          GestureDetector(
            onTap: () => setState(() => _stage = _AuthStage.phoneEntry),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.darkGray),
          ),
          const SizedBox(width: 10),
          Text('Create Account', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.black)),
        ]),
        const SizedBox(height: 4),
        Text('Set up your Eggova account', style: GoogleFonts.outfit(fontSize: 14, color: AppColors.gray)),
        const SizedBox(height: 24),
        _phoneField(readOnly: true),
        const SizedBox(height: 14),
        _textField('Full Name', _nameController, icon: Icons.person_outline_rounded),
        const SizedBox(height: 14),
        // District dropdown
        DropdownButtonFormField<String>(
          value: _selectedDistrict,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'District',
            labelStyle: GoogleFonts.outfit(color: AppColors.gray),
            prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.gray),
            filled: true,
            fillColor: AppColors.offWhite,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          style: GoogleFonts.outfit(color: AppColors.darkGray, fontSize: 15),
          items: districts.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
          onChanged: (v) => setState(() => _selectedDistrict = v),
        ),
        const SizedBox(height: 14),
        _passwordField('Password (min 6 chars)', _regPasswordController, _regObscure, () => setState(() => _regObscure = !_regObscure)),
        const SizedBox(height: 14),
        _passwordField('Confirm Password', _confirmPasswordController, _confirmObscure, () => setState(() => _confirmObscure = !_confirmObscure)),
        const SizedBox(height: 20),
        _primaryButton('Create Account', _register),
      ],
    );
  }

  Widget _buildForgotPasswordForm() {
    return Column(
      key: const ValueKey('forgot_password'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          GestureDetector(
            onTap: () => setState(() => _stage = _AuthStage.login),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.darkGray),
          ),
          const SizedBox(width: 10),
          Text('Reset Password', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.black)),
        ]),
        const SizedBox(height: 4),
        Text('Create a new password for your account', style: GoogleFonts.outfit(fontSize: 14, color: AppColors.gray)),
        const SizedBox(height: 24),
        _phoneField(readOnly: true),
        const SizedBox(height: 14),
        _passwordField('New Password (min 6 chars)', _forgotPasswordController, _forgotObscure, () => setState(() => _forgotObscure = !_forgotObscure)),
        const SizedBox(height: 14),
        _passwordField('Confirm Password', _forgotConfirmController, _forgotConfirmObscure, () => setState(() => _forgotConfirmObscure = !_forgotConfirmObscure)),
        const SizedBox(height: 20),
        _primaryButton('Reset Password', _resetPassword),
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
  Widget _phoneField({bool readOnly = false}) {
    return TextFormField(
      controller: _phoneController,
      readOnly: readOnly,
      keyboardType: TextInputType.phone,
      maxLength: 10,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: GoogleFonts.outfit(fontSize: 15, color: readOnly ? AppColors.gray : AppColors.darkGray),
      decoration: InputDecoration(
        labelText: 'Mobile Number',
        labelStyle: GoogleFonts.outfit(color: AppColors.gray),
        prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.gray),
        counterText: '',
        filled: true,
        fillColor: readOnly ? AppColors.lightGray.withOpacity(0.2) : AppColors.offWhite,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

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
