import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/order_provider.dart';
import 'providers/admin_provider.dart';
import 'services/notification_service.dart';

import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/user/user_dashboard.dart';
import 'screens/user/edit_profile_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/auth/complete_profile_screen.dart';
import 'screens/auth/pending_approval_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Init Firebase first
  await Firebase.initializeApp();
  // Init push notifications
  await NotificationService.initialize();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const EggovaApp());
}

class EggovaApp extends StatelessWidget {
  const EggovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
      ],
      child: MaterialApp(
        title: 'Eggova',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/dashboard': (context) => const UserDashboard(),
          '/complete-profile': (context) => const CompleteProfileScreen(),
          '/pending-approval': (context) => const PendingApprovalScreen(),
          '/edit-profile': (context) => const EditProfileScreen(),
          '/admin-dashboard': (context) => const AdminDashboard(),
        },
      ),
    );
  }
}
