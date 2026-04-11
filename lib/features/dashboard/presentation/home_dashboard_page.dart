import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/router/app_routes.dart';
import '../../../shared/constants/app_colors.dart';
import '../../habits/presentation/habit.dart';
import '../../tasks/domain/entities/task_entity.dart';
import '../../tasks/domain/repositories/task_repository.dart';
import '../../calendar/domain/repositories/calendar_repository.dart';
import '../../calendar/domain/entities/calendar_event_entity.dart';
import '../domain/entities/domain_entity.dart';
import '../domain/repositories/domain_repository.dart';
import '../logic/home_dashboard_cubit.dart';

class HomeDashboardPage extends StatelessWidget {
  const HomeDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

    return BlocProvider(
      create: (context) => HomeDashboardCubit(
        context.read<TaskRepository>(),
        context.read<CalendarRepository>(),
        context.read<DomainRepository>(),
      )..loadOverview(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: AppColors.black,
        drawer: _buildDrawer(context),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D0D0D), Color(0xFF1A1200), Color(0xFF0D0D0D)],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: BlocBuilder<HomeDashboardCubit, HomeDashboardState>(
              builder: (context, state) {
                if (state is HomeDashboardLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  );
                }

                if (state is HomeDashboardError) {
                  return Center(
                    child: Text(
                      state.message,
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (state is HomeDashboardLoaded) {
                  return Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.menu, color: AppColors.gold),
                                    onPressed: () => scaffoldKey.currentState?.openDrawer(),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'LifeStable',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.gold,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const Spacer(),
                                  _buildHabitStreakTrigger(state.habits),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // 1. Domain List Access (At the top)
                              _buildSlidableDomainAccess(context, state.domains),
                              const SizedBox(height: 16),
                              
                              if (state.deadlineCount > 0) ...[
                                _buildDeadlineAlert(state.deadlineCount),
                                const SizedBox(height: 16),
                              ],

                              // 2. Main Grid Section (Summary, Focus, Deadlines)
                              Expanded(
                                flex: 4,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildSummaryCard(state.tasks, state.finishedEvents),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        children: [
                                          Expanded(child: _buildFocusCard(context, state.todayEvents)),
                                          const SizedBox(height: 12),
                                          Expanded(child: _buildCloseDeadlinesSection(context, state.tasks, state.domains)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),

                              // 3. AI Recommendations
                              Expanded(
                                flex: 1,
                                child: _buildAIRecommendations(),
                              ),

                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                      
                      _buildAIFloatingButton(context),
                      _buildBottomNav(context),
                    ],
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.cardBg,
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Icon(Icons.home_outlined, color: Colors.blueAccent, size: 28),
              ),
            ),
            const SizedBox(height: 10),
            _buildDrawerButton(context, 'Calendar', AppRoutes.calendar),
            _buildDrawerButton(context, 'To-Do List', AppRoutes.tasksKanban),
            _buildDrawerButton(context, 'Team', AppRoutes.teamDashboard),
            _buildDrawerButton(context, 'AI Bot', AppRoutes.aiAssistant),
            _buildDrawerButton(context, 'Habits', AppRoutes.habitTracker),
            _buildDrawerButton(context, 'Add Location', AppRoutes.map),
            const Spacer(),
            _buildDrawerButton(context, 'Settings', AppRoutes.settings),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
                    icon: const Icon(Icons.logout, color: Colors.white70, size: 18),
                    label: const Text('Log Out', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  ),
                  const Icon(Icons.help_outline, color: Colors.white70, size: 28),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerButton(BuildContext context, String title, String route) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, route);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold.withValues(alpha: 0.8),
            foregroundColor: AppColors.black,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildHabitStreakTrigger(List<Habit> habits) {
    return PopupMenuButton(
      icon: const Icon(Icons.local_fire_department, color: AppColors.gold, size: 24),
      offset: const Offset(0, 40),
      color: AppColors.goldLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            children: habits.map((h) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(h.name, style: const TextStyle(color: AppColors.black, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 20),
                  Row(
                    children: [
                      Text('${h.streak} Days', style: const TextStyle(color: AppColors.black, fontSize: 11)),
                      const Icon(Icons.local_fire_department, color: AppColors.goldDark, size: 14),
                    ],
                  ),
                ],
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildAIFloatingButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: () => Navigator.pushNamed(context, AppRoutes.aiAssistant),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.blueAccent,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeadlineAlert(int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'You Have ${count == 2 ? "Two" : count} Deadlines Today.',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.black,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    List<TaskEntity> tasks,
    List<CalendarEventEntity> finishedEvents,
  ) {
    final doneTasks = tasks.where((t) => t.status == TaskStatus.done).toList();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCompactHeader('Fast Summary'),
          const SizedBox(height: 12),
          if (doneTasks.isEmpty && finishedEvents.isEmpty)
            const Expanded(child: Center(child: Text('No recent activity', style: TextStyle(color: Colors.white24, fontSize: 12))))
          else
            Expanded(
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  ...doneTasks.take(2).map((t) => _buildListItem(t.title, Icons.check_circle_outline, Colors.greenAccent)),
                  ...finishedEvents.take(2).map((e) => _buildListItem(e.title, Icons.event_available, AppColors.gold)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildListItem(String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloseDeadlinesSection(BuildContext context, List<TaskEntity> tasks, List<DomainEntity> domains) {
    final now = DateTime.now();
    final closeTasks = tasks.where((t) {
      if (t.dueDate == null || t.status == TaskStatus.done) return false;
      return t.dueDate!.difference(now).inDays <= 3;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCompactHeader('Close Deadlines'),
          const SizedBox(height: 12),
          if (closeTasks.isEmpty)
            const Expanded(child: Center(child: Text('All clear!', style: TextStyle(color: Colors.white24, fontSize: 12))))
          else
            Expanded(
              child: ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: closeTasks.length.clamp(0, 3),
                itemBuilder: (context, index) {
                  final task = closeTasks[index];
                  final domainIndex = domains.indexWhere((d) => d.id == task.domainId);
                  return GestureDetector(
                    onTap: () {
                      if (domainIndex != -1) {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.domainDashboard,
                          arguments: domainIndex,
                        );
                      } else {
                        Navigator.pushNamed(context, AppRoutes.domainDashboard);
                      }
                    },
                    child: _buildListItem(task.title, Icons.timer_outlined, Colors.redAccent),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompactHeader(String title, {double? height}) {
    return Container(
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: title.isEmpty ? null : Text(
        title.toUpperCase(),
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.black, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1),
      ),
    );
  }

  Widget _buildFocusCard(BuildContext context, List<CalendarEventEntity> events) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          _buildCompactHeader("Today's Focus"),
          const SizedBox(height: 12),
          if (events.isEmpty)
            const Expanded(child: Center(child: Text('No events today', style: TextStyle(color: Colors.white24, fontSize: 12))))
          else
            Expanded(
              child: ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: events.length.clamp(0, 3),
                itemBuilder: (context, index) {
                  final event = events[index];
                  return GestureDetector(
                    onTap: () => Navigator.pushNamed(context, AppRoutes.calendar),
                    child: _buildListItem(event.title, Icons.calendar_today, Colors.blueAccent),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAIRecommendations() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          _buildCompactHeader("RECOMMENDATIONS (AI)"),
          const SizedBox(height: 12),
          const Expanded(
            child: Center(
              child: Text(
                'AI Recommendations to be added soon.',
                style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlidableDomainAccess(BuildContext context, List<DomainEntity> domains) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(27),
      ),
      child: Row(
        children: [
          // New Domain Button
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRoutes.domainEdit),
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.black.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: AppColors.black, size: 28),
            ),
          ),
          const VerticalDivider(width: 1, color: AppColors.black, indent: 14, endIndent: 14),
          // Domain List
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: domains.length,
              itemBuilder: (context, index) {
                final domain = domains[index];
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 24),
                    child: GestureDetector(
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.domainDashboard,
                        arguments: index,
                      ),
                      child: Text(
                        domain.name.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 18),
            child: Icon(Icons.arrow_forward_ios, color: AppColors.black, size: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 20, top: 10),
      color: Colors.transparent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavButton(context, 'Team', AppRoutes.teamDashboard),
          _buildNavButton(context, 'Calendar', AppRoutes.calendar),
          _buildNavButton(context, 'Dashboard', AppRoutes.homeDashboard),
          _buildNavButton(context, 'Habit', AppRoutes.habitTracker),
        ],
      ),
    );
  }

  Widget _buildNavButton(BuildContext context, String label, String route) {
    final bool isActive = ModalRoute.of(context)?.settings.name == route;
    return GestureDetector(
      onTap: () {
        if (!isActive) {
          Navigator.pushNamed(context, route);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.blueAccent.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
