import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/localization/app_localizations.dart';
import '../logic/home_dashboard_cubit.dart';

class HomeDashboardPage extends StatelessWidget {
  const HomeDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeDashboardCubit()..loadOverview(),
      child: Scaffold(
        backgroundColor: AppColors.black,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D0D0D), Color(0xFF1A1200), Color(0xFF0D0D0D)],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: -80, right: -80,
                  child: Container(width: 280, height: 280, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.gold.withOpacity(0.06))),
                ),
                Positioned(
                  bottom: -100, left: -60,
                  child: Container(width: 320, height: 320, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.gold.withOpacity(0.04))),
                ),
                ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [AppColors.goldLight, AppColors.gold],
                          ).createShader(bounds),
                          child: const Text(
                            'LifeStable',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, AppRoutes.settings),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.05),
                              border: Border.all(color: AppColors.gold.withOpacity(0.2)),
                            ),
                            child: Icon(Icons.settings_outlined, color: AppColors.gold.withOpacity(0.7), size: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _OverviewCard(),
                    const SizedBox(height: 28),
                    Text('Quick Access',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1),
                    ),
                    const SizedBox(height: 14),
                    _buildGrid(context),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    final items = <(String, IconData, String)>[
      ('Domains', Icons.dashboard_outlined, AppRoutes.domainDashboard),
      ('Tasks', Icons.view_kanban_outlined, AppRoutes.tasksKanban),
      ('Habits', Icons.local_fire_department_outlined, AppRoutes.habitTracker),
      ('Notes', Icons.notes_outlined, AppRoutes.notes),
      ('Teams', Icons.groups_outlined, AppRoutes.teamDashboard),
      ('Calendar', Icons.calendar_month_outlined, AppRoutes.calendar),
      ('AI Bot', Icons.smart_toy_outlined, AppRoutes.aiAssistant),
      ('Alerts', Icons.notifications_none_outlined, AppRoutes.alerts),
      ('Map', Icons.map_outlined, AppRoutes.map),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.05,
      children: items.map((item) {
        return GestureDetector(
          onTap: () => Navigator.pushNamed(context, item.$3),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withOpacity(0.04),
              border: Border.all(color: AppColors.gold.withOpacity(0.12)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.gold.withOpacity(0.08)),
                  child: Icon(item.$2, color: AppColors.gold, size: 22),
                ),
                const SizedBox(height: 8),
                Text(item.$1, style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: AppColors.gold.withOpacity(0.15)),
      ),
      child: BlocBuilder<HomeDashboardCubit, HomeDashboardState>(
        builder: (context, state) {
          return switch (state) {
            HomeDashboardLoading() => const Center(
                child: Padding(padding: EdgeInsets.symmetric(vertical: 12), child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2))),
            HomeDashboardLoaded(summary: final s) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), gradient: const LinearGradient(colors: [AppColors.goldLight, AppColors.goldDark])),
                    child: const Icon(Icons.wb_sunny_outlined, color: Colors.black, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Text('Today', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 14),
                Text(s, style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 14, height: 1.5)),
              ],
            ),
            _ => Text('Welcome to LifeStable', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          };
        },
      ),
    );
  }
}