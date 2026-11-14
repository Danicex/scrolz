import 'package:flutter/material.dart';
import 'clerk_auth_screen.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clerk Auth Demo')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const ClerkAuthScreen(),
              ),
            );
          },
          child: const Text('Sign In / Sign Up'),
        ),
      ),
    );
  }
}
