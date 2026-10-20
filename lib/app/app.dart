import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../features/navigation/presentation/main_navigation.dart';
import 'theme/app_theme.dart';

/// Root application widget configuring dark theme, titles, and routing.
class ShadowPlayerApp extends StatelessWidget {
  const ShadowPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainNavigation(),
    );
  }
}
