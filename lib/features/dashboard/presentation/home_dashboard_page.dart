import '../../notes/domain/repositories/note_repository.dart';
import '../../../core/logic/ai_pipeline_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/router/app_routes.dart';
import '../../../shared/constants/app_colors.dart';
import '../../habits/domain/habit_model.dart';
import '../../tasks/domain/entities/task_entity.dart';
import '../../tasks/domain/repositories/task_repository.dart';
import '../../calendar/domain/repositories/calendar_repository.dart';
import '../../calendar/domain/entities/calendar_event_entity.dart';
import '../domain/entities/domain_entity.dart';
import '../domain/repositories/domain_repository.dart';
import '../logic/home_dashboard_cubit.dart';
import '../../../core/localization/app_localizations.dart';

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
        context.read<NoteRepository>(),
        context.read<AiPipelineService>(),
      )..loadOverview(),
      child: ValueListenableBuilder<Locale>(
        valueListenable: localeNotifier,
        builder: (context, locale, _) {
          return Scaffold(
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
                    if (state is HomeDashboardLoading || state is HomeDashboardError) {
                      return Column(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
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
                                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.gold, letterSpacing: -0.5),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _buildSkeletonBox(height: 110, radius: 27),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    flex: 4,
                                    child: Row(
                                      children: [
                                        Expanded(child: _buildSkeletonBox()),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            children: [
                                              Expanded(child: _buildSkeletonBox()),
                                              const SizedBox(height: 12),
                                              Expanded(child: _buildSkeletonBox()),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Expanded(flex: 1, child: _buildSkeletonBox()),
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

                    if (state is HomeDashboardLoaded) {
                      return Column(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
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
                                      _buildHabitStreakTrigger(context, state.habits),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _buildSlidableDomainAccess(context, state.domains, state.tasks, state.habits),
                                  const SizedBox(height: 16),
                                  if (state.deadlineCount > 0) ...[
                                    _buildDeadlineAlert(state.deadlineCount),
                                    const SizedBox(height: 16),
                                  ],
                                  Expanded(
                                    flex: 4,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            children: [
                                              Expanded(child: _buildSummaryCard(state.todayTasks)),
                                              const SizedBox(height: 12),
                                              Expanded(child: _buildAIRecommendations(state.dailySummary)),
                                            ],
                                          ),
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
                                  _buildProactiveRecommendationsCard(state.aiProactiveSuggestions),
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
          );
        },
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
            _buildDrawerButton(context, S.of('calendar'), AppRoutes.calendar),
            _buildDrawerButton(context, S.of('todo_list'), AppRoutes.tasksKanban),
            _buildDrawerButton(context, S.of('team'), AppRoutes.teamDashboard),
            _buildDrawerButton(context, S.of('ai_bot'), AppRoutes.aiAssistant),
            _buildDrawerButton(context, S.of('habits'), AppRoutes.habitTracker),
            _buildDrawerButton(context, S.of('add_location'), AppRoutes.map),
            const Spacer(),
            _buildDrawerButton(context, S.of('settings'), AppRoutes.settings),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
                    icon: const Icon(Icons.logout, color: Colors.white70, size: 18),
                    label: Text(S.of('logout'), style: const TextStyle(color: Colors.white70, fontSize: 14)),
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
            backgroundColor: AppColors.gold.withOpacity(0.8),
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

  Widget _buildHabitStreakTrigger(BuildContext context, List<Habit> habits) {
    final totalStreak = habits.fold<int>(0, (s, h) => s + h.streak);
    final activeCount = habits.where((h) => !h.isPaused).length;

    return GestureDetector(
      onTap: () => _showStreakSheet(context, habits),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.gold.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.gold.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔥', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$totalStreak ${S.of('days')}',
                  style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w900),
                ),
                Text(
                  '$activeCount ${S.of('active')}',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 9),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showStreakSheet(BuildContext context, List<Habit> habits) {
    final now = DateTime.now();
    final last7 = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    });
    final dayLabels = ['6d', '5d', '4d', '3d', '2d', 'Yest', 'Today'];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(S.of('streak_tracker'),
                    style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 16,
                        fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: dayLabels
                  .map((l) => SizedBox(
                width: 32,
                child: Text(l,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 9)),
              ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            if (habits.isEmpty)
              Center(
                child: Text(S.of('no_habits_yet'),
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 13)),
              )
            else
              ...habits.map((h) {
                final done = last7.map((d) => h.completionDates.any((date) => DateFormat('yyyy-MM-dd').format(date) == d)).toList();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          h.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: h.isPaused ? Colors.white38 : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: List.generate(7, (i) {
                          final filled = done[i];
                          return Container(
                            width: 28,
                            height: 28,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: filled
                                  ? AppColors.gold.withOpacity(0.85)
                                  : Colors.white.withOpacity(0.07),
                              border: Border.all(
                                color: filled ? AppColors.gold : Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: Center(
                              child: filled
                                  ? const Text('🔥', style: TextStyle(fontSize: 12))
                                  : Text(
                                '${i == 6 ? 'T' : (6 - i).toString()}',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.2),
                                    fontSize: 9),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${h.streak}🔥',
                        style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
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
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.blueAccent, size: 24),
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
        color: AppColors.gold.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        S.of('deadlines_today', args: {'count': count == 2 ? (S.of('two', args: {}) == 'two' ? 'Two' : 'İki') : count.toString()}),
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.black, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _buildSummaryCard(List<TaskEntity> todayTasks) {
    final count = todayTasks.length;
    final nextTask = todayTasks.isNotEmpty ? todayTasks.first : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCompactHeader(S.of('fast_summary')),
          const SizedBox(height: 12),
          if (count == 0)
            Expanded(
              child: Center(
                child: Text(S.of('all_clear_today'), style: const TextStyle(color: Colors.white24, fontSize: 12)),
              ),
            )
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    S.of('tasks_today', args: {'count': count.toString()}),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  if (nextTask != null) ...[
                    const SizedBox(height: 10),
                    Text(S.of('next_up'), style: const TextStyle(color: Colors.white38, fontSize: 10)),
                    const SizedBox(height: 4),
                    Text(
                      nextTask.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ],
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
    final todayStart = DateTime(now.year, now.month, now.day);
    final threeDaysLater = todayStart.add(const Duration(days: 3));

    final allClose = tasks.where((t) {
      if (t.dueDate == null) return false;
      return !t.dueDate!.isBefore(todayStart) && t.dueDate!.isBefore(threeDaysLater);
    }).toList();

    final doneCount = allClose.where((t) => t.status == TaskStatus.done).length;
    final progress = allClose.isEmpty ? 0.0 : doneCount / allClose.length;

    final incomplete = allClose.where((t) => t.status != TaskStatus.done).toList();
    const priorityOrder = {TaskPriority.high: 0, TaskPriority.medium: 1, TaskPriority.low: 2};
    incomplete.sort((a, b) => (priorityOrder[a.priority] ?? 1).compareTo(priorityOrder[b.priority] ?? 1));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCompactHeader(S.of('close_deadlines')),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withOpacity(0.1),
            color: AppColors.gold,
            minHeight: 3,
            borderRadius: BorderRadius.circular(2),
          ),
          const SizedBox(height: 8),
          if (incomplete.isEmpty)
            Expanded(child: Center(child: Text(S.of('all_clear'), style: const TextStyle(color: Colors.white24, fontSize: 12))))
          else
            Expanded(
              child: ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: incomplete.length.clamp(0, 3),
                itemBuilder: (context, index) {
                  final task = incomplete[index];
                  final domainIndex = domains.indexWhere((d) => d.id == task.domainId);
                  return GestureDetector(
                    onTap: () {
                      if (domainIndex != -1) {
                        Navigator.pushNamed(context, AppRoutes.domainDashboard, arguments: domainIndex);
                      } else {
                        Navigator.pushNamed(context, AppRoutes.domainDashboard);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.timer_outlined, size: 13, color: Colors.redAccent),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                                ),
                                if (task.dueDate != null)
                                  Text(
                                    DateFormat('MMM d').format(task.dueDate!),
                                    style: const TextStyle(color: Colors.white38, fontSize: 9),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          _buildPriorityBadge(task.priority),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPriorityBadge(TaskPriority priority) {
    final Color color;
    final String label;
    switch (priority) {
      case TaskPriority.high:
        color = Colors.redAccent;
        label = S.of('high');
      case TaskPriority.medium:
        color = AppColors.gold;
        label = S.of('med');
      case TaskPriority.low:
        color = Colors.greenAccent;
        label = S.of('low');
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildCompactHeader(String title, {double? height}) {
    return Container(
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: title.isEmpty
          ? null
          : Text(
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
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          _buildCompactHeader(S.of('todays_focus')),
          const SizedBox(height: 12),
          if (events.isEmpty)
            Expanded(child: Center(child: Text(S.of('no_events_today'), style: const TextStyle(color: Colors.white24, fontSize: 12))))
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

  Widget _buildAIRecommendations(String? summary) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          _buildCompactHeader(S.of('daily_insights')),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: Text(
                  summary ?? S.of('ai_summarizing'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      height: 1.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProactiveRecommendationsCard(List<String>? suggestions) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.gold.withOpacity(0.15), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              Text(
                S.of('proactive_recommendations'),
                style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (suggestions == null)
            Row(
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                ),
                const SizedBox(width: 12),
                Text(S.of('ai_recommending'), style: const TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic)),
              ],
            )
          else if (suggestions.isEmpty)
            Text(S.of('proactive_empty'), style: const TextStyle(color: Colors.white38, fontSize: 12))
          else
            Column(
              children: suggestions.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(Icons.auto_awesome, color: AppColors.gold, size: 14),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s,
                        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSlidableDomainAccess(BuildContext context, List<DomainEntity> domains, List<TaskEntity> tasks, List<Habit> habits) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.8),
        borderRadius: BorderRadius.circular(27),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRoutes.domainEdit),
            child: Container(
              width: 54,
              height: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.black.withOpacity(0.1),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(27), bottomLeft: Radius.circular(27)),
              ),
              child: const Icon(Icons.add, color: AppColors.black, size: 28),
            ),
          ),
          const VerticalDivider(width: 1, color: AppColors.black, indent: 14, endIndent: 14),
          Expanded(
            child: domains.isEmpty
                ? Center(child: Text(S.of('no_domains_yet'), style: const TextStyle(color: AppColors.black, fontSize: 12, fontWeight: FontWeight.w600)))
                : ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: domains.length,
              itemBuilder: (context, index) {
                final domain = domains[index];
                final incompleteTasks = tasks.where((t) => t.domainId == domain.id && t.status != TaskStatus.done).length;
                final domainHabits = habits.where((h) => h.domainId == domain.id).toList();
                final maxStreak = domainHabits.fold<int>(0, (best, h) => h.streak > best ? h.streak : best);

                return Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () => Navigator.pushNamed(context, AppRoutes.domainDashboard, arguments: index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(color: AppColors.black.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(domain.name.toUpperCase(), style: const TextStyle(color: AppColors.black, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
                            const SizedBox(height: 4),
                            Text(S.of(incompleteTasks == 1 ? 'task_count' : 'tasks_count', args: {'count': incompleteTasks.toString()}), style: const TextStyle(color: AppColors.black, fontSize: 10, fontWeight: FontWeight.w600)),
                            if (maxStreak > 0) ...[
                              const SizedBox(height: 4),
                              Row(children: [
                                const Icon(Icons.local_fire_department, color: AppColors.goldDark, size: 12),
                                const SizedBox(width: 2),
                                Text(S.of(maxStreak == 1 ? 'day_count' : 'days_count', args: {'count': maxStreak.toString()}), style: const TextStyle(color: AppColors.black, fontSize: 10)),
                              ]),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Padding(padding: EdgeInsets.only(right: 18), child: Icon(Icons.arrow_forward_ios, color: AppColors.black, size: 14)),
        ],
      ),
    );
  }

  Widget _buildSkeletonBox({double? height, double radius = 16}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.gold.withOpacity(0.1)),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(color: AppColors.cardBg, border: Border(top: BorderSide(color: AppColors.gold.withOpacity(0.1)))),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavButton(context, Icons.group_outlined, S.of('team'), AppRoutes.teamDashboard),
            _buildNavButton(context, Icons.calendar_month_outlined, S.of('calendar'), AppRoutes.calendar),
            _buildNavButton(context, Icons.dashboard_outlined, S.of('dashboard'), AppRoutes.homeDashboard, active: true),
            _buildNavButton(context, Icons.local_fire_department_outlined, S.of('habit'), AppRoutes.habitTracker),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton(BuildContext context, IconData icon, String label, String route, {bool active = false}) {
    return GestureDetector(
      onTap: () => Navigator.pushReplacementNamed(context, route),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: active ? AppColors.gold : AppColors.gold.withOpacity(0.45), size: 22),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: active ? AppColors.gold : Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}