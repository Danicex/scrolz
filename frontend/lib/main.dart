import 'package:flutter/material.dart';
import 'package:clerk_flutter/clerk_flutter.dart';
import 'core/theme/app_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/auth/home_page.dart'; // Create this file in step 2

void main() {
  runApp(
    ClerkAuth(
      config: ClerkAuthConfig(
        publishableKey: 'pk_test_c3F1YXJlLXNuYWtlLTkxNjIuY2xlcmsuYWNjb3VudHMuZGV2J',
      ),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scrolz',
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      // ClerkAuthBuilder automatically listens for login/logout changes
      home: ClerkAuthBuilder(
        signedInBuilder: (context, authState) {
          return const DashboardScreen();
        },
        signedOutBuilder: (context, authState) {
          return const HomePage();
        },
      ),
    );
  }
}
