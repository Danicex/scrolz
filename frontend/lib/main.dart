import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:clerk_flutter/clerk_flutter.dart';
import 'core/theme/app_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/auth/home_page.dart';
import '../core/auth/session_gate.dart';




const clerkKey = String.fromEnvironment('CLERK_PUBLISHABLE_KEY');

void main() {
  debugPrint('Clerk key length: ${clerkKey.length}, starts: ${clerkKey.isEmpty ? "EMPTY" : clerkKey.substring(0, 8)}, ends: ${clerkKey.isEmpty ? "" : clerkKey.substring(clerkKey.length - 4)}');

  if (clerkKey.isEmpty) {
    runApp(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'CLERK_PUBLISHABLE_KEY is missing.\nRun with --dart-define-from-file=env.json',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ));
    return;
  }

  runApp(
    ClerkAuth(
      config: ClerkAuthConfig(publishableKey: clerkKey),
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
      home: ClerkErrorListener(
        child: ClerkAuthBuilder(
          signedInBuilder: (context, authState) => const SessionGate(child: DashboardScreen()),
          signedOutBuilder: (context, authState) => const HomePage(),
        ),
      ),
    );
  }
}