import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import './screens/dashboard_screen.dart';
import 'package:clerk_flutter/clerk_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scrolz',
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
    );
  }
}