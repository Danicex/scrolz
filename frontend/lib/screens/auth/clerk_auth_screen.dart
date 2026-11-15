import 'package:flutter/material.dart';
import 'package:clerk_flutter/clerk_flutter.dart';

class ClerkAuthScreen extends StatelessWidget {
  const ClerkAuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign In'),
      ),
      body: ClerkAuthBuilder(
        signedOutBuilder: (context, authState) {
          return const ClerkAuthentication();
        },
        signedInBuilder: (context, authState) {
          // Close this pushed route once authenticated so DashboardScreen is visible
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          });
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
