import 'package:flutter/material.dart';
import 'package:clerk_flutter/clerk_flutter.dart';

class ClerkAuthScreen extends StatelessWidget {
  const ClerkAuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Authenticate')),
      body: const ClerkAuthentication(),
    );
  }
}
