import 'package:flutter/material.dart';

import '../../../app/router/app_routes.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Onboarding'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Onboarding Placeholder'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pushReplacementNamed(AppRoutes.login),
              child: const Text('Continue to Login'),
            ),
          ],
        ),
      ),
    );
  }
}

