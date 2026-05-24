import 'package:flutter/material.dart';

import '../../../app/router/app_routes.dart';
import '../../../shared/constants/app_colors.dart';

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: const Text(
          'Alerts',
          style: TextStyle(color: AppColors.gold),
        ),
        iconTheme: const IconThemeData(color: AppColors.gold),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              tileColor: AppColors.cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.battery_saver_outlined, color: AppColors.gold),
              title: const Text(
                'Battery & Efficiency Report',
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
              subtitle: const Text(
                'Geofence trigger stats and battery usage',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right, color: AppColors.gold),
              onTap: () => Navigator.pushNamed(context, AppRoutes.batteryReport),
            ),
          ],
        ),
      ),
    );
  }
}

