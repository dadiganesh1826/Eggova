import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/district_data.dart';
import '../../providers/auth_provider.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  String? _selectedDistrict;
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool error = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.outfit()),
        backgroundColor: error ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submit() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      _showSnack('Please enter a valid 10-digit mobile number');
      return;
    }
    if (_selectedDistrict == null) {
      _showSnack('Please select your district');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final success = await auth.submitDetails(phone, _selectedDistrict!);
      
      if (!mounted) return;

      if (success) {
        if (auth.isPendingApproval) {
          Navigator.pushNamedAndRemoveUntil(context, '/pending-approval', (route) => false);
        } else {
          Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
        }
      } else {
        _showSnack(auth.error ?? 'Something went wrong');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final districts = DistrictData.allDistricts;

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                'Almost there! 👋',
                style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.black),
              ),
              const SizedBox(height: 8),
              Text(
                'Complete your profile to continue with Eggova.',
                style: GoogleFonts.outfit(fontSize: 16, color: AppColors.gray),
              ),
              const SizedBox(height: 40),
              
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: AppColors.black.withOpacity(0.05), blurRadius: 40, offset: const Offset(0, 10))
                  ],
                ),
                child: Column(
                  children: [
                    _textField('Full Name', _nameController, icon: Icons.person_outline_rounded),
                    const SizedBox(height: 16),
                    _phoneField(),
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 32),
                    _primaryButton('Complete Profile', _submit),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _phoneField() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      maxLength: 10,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: GoogleFonts.outfit(fontSize: 15, color: AppColors.darkGray),
      decoration: InputDecoration(
        labelText: 'Mobile Number',
        labelStyle: GoogleFonts.outfit(color: AppColors.gray),
        prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.gray),
        counterText: '',
        filled: true,
        fillColor: AppColors.offWhite,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _textField(String label, TextEditingController controller, {IconData? icon}) {
    return TextFormField(
      controller: controller,
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

  Widget _primaryButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.black,
          disabledBackgroundColor: AppColors.lightGray.withOpacity(0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.black))
            : Text(label, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
