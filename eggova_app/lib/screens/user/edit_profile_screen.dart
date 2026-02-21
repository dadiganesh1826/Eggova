import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/district_data.dart';
import '../../providers/auth_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _pincodeController = TextEditingController();
  String? _selectedDistrict;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) {
      _nameController.text = user.name;
      _emailController.text = user.email;
      _addressController.text = user.address ?? '';
      _pincodeController.text = user.pincode ?? '';
      _selectedDistrict = user.district;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.updateProfile(
      name: name,
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      district: _selectedDistrict,
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      pincode: _pincodeController.text.trim().isEmpty ? null : _pincodeController.text.trim(),
    );

    setState(() => _isSaving = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile updated! ✅', style: GoogleFonts.outfit()),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          'Edit Profile',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : '?',
                    style: GoogleFonts.outfit(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: AppColors.black,
                    ),
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 400.ms),

            const SizedBox(height: 8),

            // Phone (read-only)
            Center(
              child: Text(
                '+91 ${user?.phone ?? ''}',
                style: GoogleFonts.outfit(
                  color: AppColors.lightGray,
                  fontSize: 14,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Name
            _buildLabel('Full Name'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _nameController,
              hint: 'Your name',
              icon: Icons.person_outline,
            ),

            const SizedBox(height: 20),

            // Email (optional)
            _buildLabel('Email (Optional)'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _emailController,
              hint: 'your@email.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),

            const SizedBox(height: 20),

            // District
            _buildLabel('District'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.white.withOpacity(0.1)),
              ),
              child: DropdownButtonFormField<String>(
                value: DistrictData.allDistricts.contains(_selectedDistrict)
                    ? _selectedDistrict
                    : null,
                dropdownColor: const Color(0xFF333333),
                icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
                style: GoogleFonts.outfit(color: AppColors.white, fontSize: 15),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 22),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  hintText: 'Select district',
                  hintStyle: GoogleFonts.outfit(color: AppColors.lightGray.withOpacity(0.5)),
                ),
                items: DistrictData.dropdownItems.map((item) {
                  return DropdownMenuItem<String>(
                    value: item['district'],
                    child: Text(item['label']!, style: GoogleFonts.outfit(color: AppColors.white, fontSize: 15)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedDistrict = value);
                },
              ),
            ),

            const SizedBox(height: 20),

            // Address (optional)
            _buildLabel('Address (Optional)'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _addressController,
              hint: 'Your full address',
              icon: Icons.home_outlined,
              maxLines: 2,
            ),

            const SizedBox(height: 20),

            // Pincode (optional)
            _buildLabel('Pincode (Optional)'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _pincodeController,
              hint: 'Pincode',
              icon: Icons.pin_drop_outlined,
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 36),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.black))
                    : Text('Save Changes', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        color: AppColors.lightGray,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.outfit(color: AppColors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.outfit(color: AppColors.lightGray.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 22),
        filled: true,
        fillColor: AppColors.white.withOpacity(0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }
}
