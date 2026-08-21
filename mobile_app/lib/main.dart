import 'package:flutter/material.dart';
import 'widgets/auth_wrapper.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const AiFileAssistantApp());
}

class AiFileAssistantApp extends StatelessWidget {
  const AiFileAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI File Assistant',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthWrapper(),
    );
  }
}
