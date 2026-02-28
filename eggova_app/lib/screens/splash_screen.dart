import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);

    // Wait for the AuthProvider to finish loading from SharedPreferences
    while (!auth.isInitialized) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
    }

    if (auth.isAuthenticated) {
      if (auth.isAdmin) {
        Navigator.pushReplacementNamed(context, '/admin-dashboard');
      } else {
        Navigator.pushReplacementNamed(context, '/user-dashboard');
      }
    } else {
      Navigator.pushReplacementNamed(context, '/login');
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
            colors: [
              AppColors.black,
              Color(0xFF2A2A2A),
              AppColors.black,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Egg icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.egg,
                size: 64,
                color: AppColors.black,
              ),
            ).animate().fadeIn(duration: 800.ms).scale(
                begin: const Offset(0.5, 0.5),
                end: const Offset(1, 1),
                duration: 800.ms,
                curve: Curves.elasticOut),

            const SizedBox(height: 32),

            // App name
            Text(
              'EGGOVA',
              style: GoogleFonts.outfit(
                fontSize: 42,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
                letterSpacing: 8,
              ),
            )
                .animate()
                .fadeIn(delay: 400.ms, duration: 600.ms)
                .slideY(begin: 0.3, end: 0, duration: 600.ms),

            const SizedBox(height: 8),

            Text(
              'Fresh Eggs, Fair Prices',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: AppColors.primaryLight,
                letterSpacing: 2,
              ),
            ).animate().fadeIn(delay: 800.ms, duration: 600.ms),

            const SizedBox(height: 60),

            // Loading indicator
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                strokeWidth: 3,
              ),
            ).animate().fadeIn(delay: 1200.ms, duration: 400.ms),
          ],
        ),
      ),
    );
  }
}
