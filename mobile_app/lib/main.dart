import 'package:flutter/material.dart';
import 'widgets/auth_wrapper.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppTheme.initTheme();
  runApp(const AiFileAssistantApp());
}

class AiFileAssistantApp extends StatelessWidget {
  const AiFileAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, currentThemeMode, _) {
        return MaterialApp(
          title: 'AI File Assistant',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentThemeMode,
          home: const AuthWrapper(),
        );
      },
    );
  }
}
