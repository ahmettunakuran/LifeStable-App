import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/router/app_routes.dart';
import '../logic/home_dashboard_cubit.dart';

class HomeDashboardPage extends StatelessWidget {
  const HomeDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeDashboardCubit()..loadOverview(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Home Dashboard'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            BlocBuilder<HomeDashboardCubit, HomeDashboardState>(
              builder: (context, state) {
                return switch (state) {
                  HomeDashboardLoading() => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  HomeDashboardLoaded(summary: final summary) => Text(summary),
                  _ => const Text('Welcome to LifeStable'),
                };
              },
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _NavChip(
                  label: 'Domains',
                  routeName: AppRoutes.domainDashboard,
                ),
                _NavChip(
                  label: 'Tasks / Kanban',
                  routeName: AppRoutes.tasksKanban,
                ),
                _NavChip(
                  label: 'Habits',
                  routeName: AppRoutes.habitTracker,
                ),
                _NavChip(
                  label: 'Teams',
                  routeName: AppRoutes.teamDashboard,
                ),
                _NavChip(
                  label: 'Alerts',
                  routeName: AppRoutes.alerts,
                ),
                _NavChip(
                  label: 'Map',
                  routeName: AppRoutes.map,
                ),
                _NavChip(
                  label: 'Calendar',
                  routeName: AppRoutes.calendar,
                ),
                _NavChip(
                  label: 'AI Assistant',
                  routeName: AppRoutes.aiAssistant,
                ),
                _NavChip(
                  label: 'Settings',
                  routeName: AppRoutes.settings,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NavChip extends StatelessWidget {
  const _NavChip({
    required this.label,
    required this.routeName,
  });

  final String label;
  final String routeName;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: () => Navigator.of(context).pushNamed(routeName),
    );
  }
}

