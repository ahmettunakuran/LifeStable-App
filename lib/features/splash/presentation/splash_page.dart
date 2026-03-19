import 'package:flutter/material.dart';

import '../../../app/router/app_routes.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    Future.microtask(
      () => Navigator.of(context).pushReplacementNamed(AppRoutes.onboarding),
    );

    return const Scaffold(
      body: Center(
        child: Text('LifeStable • Splash'),
      ),
    );
  }
}

