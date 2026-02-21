import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
  final _nameController = TextEditingController();
  String? _selectedDistrict;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _completeProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }
    if (_selectedDistrict == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your district')),
      );
      return;
    }

    final phone = ModalRoute.of(context)!.settings.arguments as String;
    final auth = Provider.of<AuthProvider>(context, listen: false);

    final result = await auth.verifyOtp(phone, 'verified', name: name, district: _selectedDistrict!);

    if (result != null && result['token'] != null && mounted) {
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 50),

                // Header
                Center(
                  child: Container(
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
                    child: const Icon(Icons.person_add, size: 36, color: AppColors.black),
                  ).animate().fadeIn(duration: 500.ms),
                ),

                const SizedBox(height: 24),

                Center(
                  child: Text(
                    'Complete Your Profile',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ).animate().fadeIn(delay: 200.ms),
                ),

                const SizedBox(height: 8),

                Center(
                  child: Text(
                    'Tell us a little about yourself',
                    style: GoogleFonts.outfit(fontSize: 14, color: AppColors.lightGray),
                  ).animate().fadeIn(delay: 300.ms),
                ),

                const SizedBox(height: 40),

                // Full Name
                Text(
                  'Full Name',
                  style: GoogleFonts.outfit(
                    color: AppColors.lightGray,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  style: GoogleFonts.outfit(color: AppColors.white, fontSize: 15),
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Enter your full name',
                    hintStyle: GoogleFonts.outfit(color: AppColors.lightGray.withOpacity(0.5)),
                    prefixIcon: const Icon(Icons.person_outline, color: AppColors.primary, size: 22),
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
                ).animate().fadeIn(delay: 400.ms, duration: 500.ms),

                const SizedBox(height: 28),

                // District Dropdown
                Text(
                  'Select Your District',
                  style: GoogleFonts.outfit(
                    color: AppColors.lightGray,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.white.withOpacity(0.1)),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedDistrict,
                    dropdownColor: const Color(0xFF333333),
                    icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
                    style: GoogleFonts.outfit(color: AppColors.white, fontSize: 15),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 22),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      hintText: 'Choose your district',
                      hintStyle: GoogleFonts.outfit(color: AppColors.lightGray.withOpacity(0.5)),
                    ),
                    selectedItemBuilder: (context) {
                      return DistrictData.dropdownItems.map((item) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            item['label']!,
                            style: GoogleFonts.outfit(color: AppColors.white, fontSize: 15),
                          ),
                        );
                      }).toList();
                    },
                    items: DistrictData.dropdownItems.map((item) {
                      return DropdownMenuItem<String>(
                        value: item['district'],
                        child: Text(
                          item['label']!,
                          style: GoogleFonts.outfit(color: AppColors.white, fontSize: 15),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedDistrict = value);
                    },
                  ),
                ).animate().fadeIn(delay: 500.ms, duration: 500.ms),

                // Error
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    if (auth.error != null) {
                      return Container(
                        margin: const EdgeInsets.only(top: 20),
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
                            Expanded(
                              child: Text(auth.error!, style: GoogleFonts.outfit(color: AppColors.error, fontSize: 13)),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                const SizedBox(height: 36),

                // Get Started button
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    return SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: auth.isLoading ? null : _completeProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: auth.isLoading
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.black))
                            : Text(
                                'Get Started 🥚',
                                style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w700),
                              ),
                      ),
                    );
                  },
                ).animate().fadeIn(delay: 600.ms, duration: 500.ms),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
