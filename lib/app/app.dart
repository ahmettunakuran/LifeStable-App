import 'package:flutter/material.dart';

import '../shared/theme/app_theme.dart';
import 'router/app_router.dart';
import 'router/app_routes.dart';

class LifeStableApp extends StatelessWidget {
  const LifeStableApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LifeStable',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}

