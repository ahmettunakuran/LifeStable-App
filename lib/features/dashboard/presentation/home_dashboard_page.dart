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
            _OverviewCard(),
            const SizedBox(height: 16),
            Text(
              'Quick Access',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: const [
                _NavChip(
                  label: 'Domains',
                  icon: Icons.dashboard_outlined,
                  routeName: AppRoutes.domainDashboard,
                ),
                _NavChip(
                  label: 'Tasks / Kanban',
                  icon: Icons.view_kanban_outlined,
                  routeName: AppRoutes.tasksKanban,
                ),
                _NavChip(
                  label: 'Habits',
                  icon: Icons.local_fire_department_outlined,
                  routeName: AppRoutes.habitTracker,
                ),
                _NavChip(
                  label: 'Notes',
                  icon: Icons.notes_outlined,
                  routeName: AppRoutes.notes,
                ),
                _NavChip(
                  label: 'Teams',
                  icon: Icons.groups_outlined,
                  routeName: AppRoutes.teamDashboard,
                ),
                _NavChip(
                  label: 'Alerts',
                  icon: Icons.notifications_none_outlined,
                  routeName: AppRoutes.alerts,
                ),
                _NavChip(
                  label: 'Map',
                  icon: Icons.map_outlined,
                  routeName: AppRoutes.map,
                ),
                _NavChip(
                  label: 'Calendar',
                  icon: Icons.calendar_month_outlined,
                  routeName: AppRoutes.calendar,
                ),
                _NavChip(
                  label: 'AI Assistant',
                  icon: Icons.smart_toy_outlined,
                  routeName: AppRoutes.aiAssistant,
                ),
                _NavChip(
                  label: 'Settings',
                  icon: Icons.settings_outlined,
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
    required this.icon,
    required this.routeName,
  });

  final String label;
  final IconData icon;
  final String routeName;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ActionChip(
      avatar: Icon(
        icon,
        size: 18,
        color: isDark ? Colors.white70 : Colors.black54,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      side: BorderSide(
        color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
      ),
      onPressed: () => Navigator.of(context).pushNamed(routeName),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1D1D1F) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: BlocBuilder<HomeDashboardCubit, HomeDashboardState>(
        builder: (context, state) {
          return switch (state) {
            HomeDashboardLoading() => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(),
                ),
              ),
            HomeDashboardLoaded(summary: final summary) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Today',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    summary,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            _ => Text(
                'Welcome to LifeStable',
                style: theme.textTheme.bodyMedium,
              ),
          };
        },
      ),
    );
  }
}

