import 'package:flutter/material.dart';

import '../../../app/router/app_routes.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Register Screen Placeholder'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pushReplacementNamed(AppRoutes.homeDashboard),
              child: const Text('Mock Register'),
            ),
          ],
        ),
      ),
    );
  }
}

