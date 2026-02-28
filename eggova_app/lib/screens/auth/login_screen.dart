import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpControllers = List.generate(4, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(4, (_) => FocusNode());

  // Admin login
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isAdminMode = false;
  bool _obscurePassword = true;

  bool _otpSent = false;
  bool _isExistingUser = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _adminLogin() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final success = await auth.login(email, password);

      if (success && mounted) {
        if (auth.isAdmin) {
          Navigator.pushReplacementNamed(context, '/admin-dashboard');
        } else {
          Navigator.pushReplacementNamed(context, '/user-dashboard');
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendOtp() async {
    if (_isLoading) return;

    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a valid 10-digit mobile number')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final result = await auth.sendOtp(phone);

      if (result != null && mounted) {
        setState(() {
          _otpSent = true;
          _isExistingUser = result['isExistingUser'] ?? false;
        });
        // Focus first OTP field
        _otpFocusNodes[0].requestFocus();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_isLoading) return;

    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 4) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the complete 4-digit OTP')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final phone = _phoneController.text.trim();
      final result = await auth.verifyOtp(phone, otp);

      if (result != null && mounted) {
        if (result['isNewUser'] == true && result['token'] == null) {
          // New user — needs to complete profile
          Navigator.pushReplacementNamed(context, '/complete-profile',
              arguments: phone);
        } else if (auth.isAdmin) {
          Navigator.pushReplacementNamed(context, '/admin-dashboard');
        } else {
          Navigator.pushReplacementNamed(context, '/user-dashboard');
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onOtpChanged(String value, int index) {
    if (value.isNotEmpty && index < 3) {
      _otpFocusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
    // Auto-verify when all 4 digits entered
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length == 4) {
      _verifyOtp();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.black, Color(0xFF2A2A2A)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                SizedBox(height: _isAdminMode ? 40 : 70),

                // Logo
                Container(
                  width: _isAdminMode ? 70 : 90,
                  height: _isAdminMode ? 70 : 90,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child:
                      const Icon(Icons.egg, size: 48, color: AppColors.black),
                ).animate().fadeIn(duration: 600.ms).scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1, 1),
                    duration: 600.ms),

                const SizedBox(height: 28),

                Text(
                  'Eggova',
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 500.ms),

                const SizedBox(height: 8),

                Text(
                  _isAdminMode
                      ? 'Sign in with your admin credentials'
                      : _otpSent
                          ? 'Enter the OTP sent to your phone'
                          : 'Fresh eggs, delivered to your door',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    color: AppColors.lightGray,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 300.ms, duration: 500.ms),

                SizedBox(height: _isAdminMode ? 30 : 50),

                if (!_isAdminMode) ...[
                  // Phone Number Input
                  _buildPhoneField(),

                  if (_otpSent) ...[
                    const SizedBox(height: 32),
                    _buildOtpFields(),
                  ],

                  // Error message
                  Consumer<AuthProvider>(
                    builder: (context, auth, _) {
                      if (auth.error != null) {
                        return Container(
                          margin: const EdgeInsets.only(top: 20),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.error.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: AppColors.error, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(auth.error!,
                                    style: GoogleFonts.outfit(
                                        color: AppColors.error, fontSize: 13)),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                  const SizedBox(height: 32),

                  // Action button
                  Consumer<AuthProvider>(
                    builder: (context, auth, _) {
                      return SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: auth.isLoading
                              ? null
                              : (_otpSent ? _verifyOtp : _sendOtp),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: auth.isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppColors.black,
                                  ),
                                )
                              : Text(
                                  _otpSent ? 'Verify OTP' : 'Send OTP',
                                  style: GoogleFonts.outfit(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      );
                    },
                  ).animate().fadeIn(delay: 500.ms, duration: 500.ms),

                  if (_otpSent) ...[
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _otpSent = false;
                          for (final c in _otpControllers) {
                            c.clear();
                          }
                        });
                        Provider.of<AuthProvider>(context, listen: false)
                            .clearError();
                      },
                      child: Text(
                        'Change Number',
                        style: GoogleFonts.outfit(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 40),

                // Admin mode toggle
                if (!_isAdminMode && !_otpSent)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isAdminMode = true;
                      });
                      Provider.of<AuthProvider>(context, listen: false)
                          .clearError();
                    },
                    child: Text(
                      'Admin? Login here',
                      style: GoogleFonts.outfit(
                        color: AppColors.lightGray.withOpacity(0.6),
                        fontSize: 13,
                      ),
                    ),
                  ),

                // Admin login form
                if (_isAdminMode) ...[
                  _buildAdminForm(),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isAdminMode = false;
                      });
                      Provider.of<AuthProvider>(context, listen: false)
                          .clearError();
                    },
                    child: Text(
                      'Back to Phone Login',
                      style: GoogleFonts.outfit(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: AppColors.white.withOpacity(0.1)),
              ),
            ),
            child: Text(
              '+91',
              style: GoogleFonts.outfit(
                color: AppColors.primary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: _phoneController,
              enabled: !_otpSent,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.outfit(
                color: _otpSent ? AppColors.lightGray : AppColors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.5,
              ),
              decoration: InputDecoration(
                hintText: 'Mobile Number',
                hintStyle: GoogleFonts.outfit(
                    color: AppColors.lightGray.withOpacity(0.5)),
                counterText: '',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms, duration: 600.ms);
  }

  Widget _buildOtpFields() {
    return Column(
      children: [
        Text(
          'Enter OTP',
          style: GoogleFonts.outfit(
            color: AppColors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            return Container(
              width: 64,
              height: 64,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _otpControllers[index].text.isNotEmpty
                      ? AppColors.primary
                      : AppColors.white.withOpacity(0.15),
                  width: 2,
                ),
              ),
              child: Center(
                child: TextFormField(
                  controller: _otpControllers[index],
                  focusNode: _otpFocusNodes[index],
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  textAlign: TextAlign.center,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: GoogleFonts.outfit(
                    color: AppColors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    filled: false,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  onChanged: (value) => _onOtpChanged(value, index),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        Text(
          'OTP is 1234 (Dev Mode)',
          style: GoogleFonts.outfit(
            color: AppColors.lightGray.withOpacity(0.5),
            fontSize: 12,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildAdminForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Admin Login',
          style: GoogleFonts.outfit(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),

        // Email
        Container(
          decoration: BoxDecoration(
            color: AppColors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.white.withOpacity(0.1)),
          ),
          child: TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: GoogleFonts.outfit(color: AppColors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Email',
              hintStyle: GoogleFonts.outfit(
                  color: AppColors.lightGray.withOpacity(0.5)),
              prefixIcon: const Icon(Icons.email_outlined,
                  color: AppColors.primary, size: 22),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Password
        Container(
          decoration: BoxDecoration(
            color: AppColors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.white.withOpacity(0.1)),
          ),
          child: TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: GoogleFonts.outfit(color: AppColors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Password',
              hintStyle: GoogleFonts.outfit(
                  color: AppColors.lightGray.withOpacity(0.5)),
              prefixIcon: const Icon(Icons.lock_outline,
                  color: AppColors.primary, size: 22),
              suffixIcon: GestureDetector(
                onTap: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                child: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.lightGray,
                  size: 22,
                ),
              ),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Login button
        Consumer<AuthProvider>(
          builder: (context, auth, _) {
            return SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: auth.isLoading ? null : _adminLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: auth.isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: AppColors.black))
                    : Text('Login as Admin',
                        style: GoogleFonts.outfit(
                            fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            );
          },
        ),

        // Error
        Consumer<AuthProvider>(
          builder: (context, auth, _) {
            if (auth.error != null) {
              return Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Text(auth.error!,
                    style: GoogleFonts.outfit(
                        color: AppColors.error, fontSize: 13)),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }
}
