import 'package:flutter/material.dart';

import '../../../app/router/app_routes.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Login Screen Placeholder'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.forgotPassword),
              child: const Text('Forgot Password'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pushReplacementNamed(AppRoutes.homeDashboard),
              child: const Text('Mock Login'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.register),
              child: const Text('Create Account'),
            ),
          ],
        ),
      ),
    );
  }
}

