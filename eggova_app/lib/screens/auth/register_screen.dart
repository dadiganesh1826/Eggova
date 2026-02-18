import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _addressController = TextEditingController();
  final _districtController = TextEditingController();
  final _pincodeController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _addressController.dispose();
    _districtController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
      district: _districtController.text.trim(),
      address: _addressController.text.trim(),
      pincode: _pincodeController.text.trim(),
    );

    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/user-dashboard');
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
                const SizedBox(height: 40),

                // Logo
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.egg, size: 38, color: AppColors.black),
                ).animate().fadeIn(duration: 500.ms),

                const SizedBox(height: 20),

                Text(
                  'Create Account',
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ).animate().fadeIn(delay: 200.ms),

                const SizedBox(height: 6),

                Text(
                  'Join Eggova to order fresh eggs',
                  style: GoogleFonts.outfit(fontSize: 14, color: AppColors.lightGray),
                ).animate().fadeIn(delay: 300.ms),

                const SizedBox(height: 32),

                // Form
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildField(_nameController, 'Full Name', Icons.person_outline,
                          validator: (v) => v!.isEmpty ? 'Name is required' : null),
                      const SizedBox(height: 16),
                      _buildField(_emailController, 'Email', Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v!.isEmpty) return 'Email is required';
                            if (!v.contains('@')) return 'Invalid email';
                            return null;
                          }),
                      const SizedBox(height: 16),
                      _buildField(_phoneController, 'Mobile Number', Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: (v) {
                            if (v!.isEmpty) return 'Phone is required';
                            if (v.length < 10) return 'Invalid phone number';
                            return null;
                          }),
                      const SizedBox(height: 16),
                      _buildField(_passwordController, 'Password', Icons.lock_outline,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: AppColors.lightGray,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          validator: (v) {
                            if (v!.isEmpty) return 'Password is required';
                            if (v.length < 6) return 'Min 6 characters';
                            return null;
                          }),
                      const SizedBox(height: 16),
                      _buildField(_districtController, 'District', Icons.location_on_outlined,
                          validator: (v) => v!.isEmpty ? 'District is required' : null),
                      const SizedBox(height: 16),
                      _buildField(_addressController, 'Full Address', Icons.home_outlined,
                          maxLines: 2),
                      const SizedBox(height: 16),
                      _buildField(_pincodeController, 'Pincode', Icons.pin_drop_outlined,
                          keyboardType: TextInputType.number),
                    ],
                  ),
                ).animate().fadeIn(delay: 400.ms, duration: 600.ms),

                // Error
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    if (auth.error != null) {
                      return Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.error.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(auth.error!, style: GoogleFonts.outfit(color: AppColors.error, fontSize: 13))),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                const SizedBox(height: 28),

                // Register button
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    return SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: auth.isLoading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: auth.isLoading
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.black))
                            : Text('Create Account', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w700)),
                      ),
                    );
                  },
                ).animate().fadeIn(delay: 600.ms),

                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Already have an account?  ', style: GoogleFonts.outfit(color: AppColors.lightGray, fontSize: 14)),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                      child: Text('Sign In', style: GoogleFonts.outfit(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ).animate().fadeIn(delay: 700.ms),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, {
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      style: GoogleFonts.outfit(color: AppColors.white, fontSize: 15),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.outfit(color: AppColors.lightGray),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 22),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.white.withOpacity(0.08),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.white.withOpacity(0.1))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.white.withOpacity(0.1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.error)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }
}
