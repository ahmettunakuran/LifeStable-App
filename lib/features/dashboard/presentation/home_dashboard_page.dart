import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
      )..loadOverview(),
      child: ValueListenableBuilder<Locale>(
        valueListenable: localeNotifier,
        builder: (context, locale, _) {
          return Scaffold(
            key: scaffoldKey,
            backgroundColor: AppColors.black,
            drawer: _buildDrawer(context),
            body: Container(
              decoration: BoxDecoration(
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
                              _buildHeaderBar(context, scaffoldKey),
                              const SizedBox(height: 16),
                              _buildSkeletonBox(context, height: 110, radius: 27),
                              const SizedBox(height: 16),
                              Expanded(
                                flex: 4,
                                child: Row(
                                  children: [
                                    Expanded(child: _buildSkeletonBox(context, )),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        children: [
                                          Expanded(child: _buildSkeletonBox(context, )),
                                          const SizedBox(height: 12),
                                          Expanded(child: _buildSkeletonBox(context, )),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Expanded(flex: 1, child: _buildSkeletonBox(context, )),
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
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeaderBar(
                                context,
                                scaffoldKey,
                                trailing: _buildHabitStreakTrigger(context, state.habits),
                              ),
                              const SizedBox(height: 20),
                              _buildDomainsSection(context, state.domains, state.tasks),
                              const SizedBox(height: 20),
                              _buildTodayBrief(context, state),
                              const SizedBox(height: 20),
                              SizedBox(
                                height: 260,
                                child: Row(
                                  children: [
                                    Expanded(child: _buildFocusCard(context, state.todayEvents)),
                                    const SizedBox(width: 12),
                                    Expanded(child: _buildCloseDeadlinesSection(context, state.tasks, state.domains)),
                                  ],
                                ),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
              child: Row(
                children: [
                  _brandTitle(),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRoutes.homeDashboard,
                        (route) => false,
                      );
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.gold.withOpacity(0.18)),
                      ),
                      child: Icon(Icons.home_rounded, color: AppColors.gold, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: AppColors.gold.withOpacity(0.12), height: 1),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  _buildDrawerItem(context, Icons.calendar_month_outlined,
                      S.of('calendar'), AppRoutes.calendar),
                  _buildDrawerItem(context, Icons.checklist_rounded,
                      S.of('tasks'), AppRoutes.tasksKanban),
                  _buildDrawerItem(context, Icons.groups_outlined,
                      S.of('team'), AppRoutes.teamDashboard),
                  _buildDrawerItem(context, Icons.auto_awesome,
                      S.of('ai_bot'), AppRoutes.aiAssistant),
                  _buildDrawerItem(context, Icons.local_fire_department_outlined,
                      S.of('habits'), AppRoutes.habitTracker),
                  _buildDrawerItem(context, Icons.location_on_outlined,
                      S.of('add_location'), AppRoutes.map),
                  _buildDrawerItem(context, Icons.support_agent_rounded,
                      S.of('app_assistant'), AppRoutes.appAssistant),
                ],
              ),
            ),
            Divider(color: AppColors.gold.withOpacity(0.12), height: 1),
            const SizedBox(height: 8),
            _buildDrawerItem(context, Icons.settings_outlined,
                S.of('settings'), AppRoutes.settings),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 12, 26, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, AppRoutes.login),
                    icon: Icon(Icons.logout_rounded,
                        color: Colors.white.withValues(alpha: 0.70), size: 18),
                    label: Text(S.of('logout'),
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.70),
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  ),
                  Icon(Icons.help_outline_rounded,
                      color: Colors.white.withValues(alpha: 0.50), size: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
      BuildContext context, IconData icon, String title, String route) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, route);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.gold.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.gold, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: Colors.white.withOpacity(0.25), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHabitStreakTrigger(BuildContext context, List<Habit> habits) {
    final maxStreak = habits.fold<int>(0, (best, h) => h.streak > best ? h.streak : best);
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
                  '$maxStreak ${S.of('days')}',
                  style: TextStyle(
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
                    style: TextStyle(
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
                final done = last7.map((d) => h.completedDates.contains(d)).toList();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          h.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: h.isPaused ? Colors.white.withValues(alpha: 0.38) : Colors.white,
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
                        style: TextStyle(
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
            child: Icon(Icons.auto_awesome, color: Colors.blueAccent, size: 24),
          ),
        ),
      ),
    );
  }

  Widget _buildDomainsSection(BuildContext context, List<DomainEntity> domains, List<TaskEntity> tasks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of('domains_title').toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 104,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: domains.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) return _buildNewDomainCard(context);
              final domain = domains[index - 1];
              final uid = FirebaseAuth.instance.currentUser?.uid;
              var domainTasks = tasks.where((t) => t.domainId == domain.id);
              // Team domains only surface tasks assigned to the current user,
              // matching the kanban board (DomainKanbanView).
              if (domain.isTeamMirror && uid != null) {
                domainTasks = domainTasks.where((t) => t.assignedTo == uid);
              }
              final count =
                  domainTasks.where((t) => t.status != TaskStatus.done).length;
              return _buildDomainCard(context, domain, count, index - 1);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNewDomainCard(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.domainEdit),
      child: Container(
        width: 96,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: AppColors.gold.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: AppColors.gold, size: 28),
            const SizedBox(height: 6),
            Text(
              S.of('new_short').toUpperCase(),
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDomainCard(BuildContext context, DomainEntity domain, int taskCount, int index) {
    Color domainColor;
    try {
      domainColor = Color(int.parse(domain.colorHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      domainColor = AppColors.gold;
    }

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.domainDashboard, arguments: index),
      child: Container(
        width: 132,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: domainColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    domain.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              '$taskCount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              S.of('summary_tasks').toLowerCase(),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayBrief(BuildContext context, HomeDashboardLoaded state) {
    final taskCount = state.deadlineCount;
    final headline = taskCount == 0
        ? S.of('all_clear_today')
        : S.of('you_have_tasks_today').replaceAll('{n}', '$taskCount');

    Widget insight;
    if (state.isInsightLoading) {
      insight = Row(
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            '...',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.38), fontSize: 13),
          ),
        ],
      );
    } else {
      final text = (state.aiInsight != null && state.aiInsight!.isNotEmpty)
          ? state.aiInsight!
          : S.of('no_summary');
      insight = _ExpandableInsight(text: text);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.auto_awesome, color: AppColors.gold, size: 16),
              ),
              const SizedBox(width: 8),
              _goldGradientText(S.of('todays_brief').toUpperCase(),
                  fontSize: 11, letterSpacing: 1.4),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            headline,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          insight,
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildBriefStat(context, S.of('due_today_short'), '$taskCount')),
              const SizedBox(width: 10),
              Expanded(child: _buildBriefStat(context, S.of('summary_events'), '${state.todayEvents.length}')),
              const SizedBox(width: 10),
              Expanded(
                child: _buildBriefStat(
                  context,
                  S.of('summary_habits'),
                  '${state.completedHabitsCount}/${state.habits.length}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBriefStat(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(BuildContext context, String text, IconData icon, Color color) {
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
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
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
          _buildCompactHeader(context, S.of('close_deadlines')),
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
            Expanded(
                child: Center(
                    child: Text(S.of('all_clear'),
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.24), fontSize: 12))))
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
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                                ),
                                if (task.dueDate != null)
                                  Text(
                                    DateFormat('MMM d').format(task.dueDate!),
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.38), fontSize: 9),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          _buildPriorityBadge(context, task.priority),
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

  Widget _buildPriorityBadge(BuildContext context, TaskPriority priority) {
    final Color color;
    final String label;
    switch (priority) {
      case TaskPriority.high:
        color = Colors.redAccent;
        label = 'HIGH';
      case TaskPriority.medium:
        color = AppColors.gold;
        label = 'MED';
      case TaskPriority.low:
        color = Colors.greenAccent;
        label = 'LOW';
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

  Widget _buildCompactHeader(BuildContext context, String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 13,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.goldLight, AppColors.goldDark],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: _goldGradientText(title.toUpperCase(), fontSize: 11, letterSpacing: 1.5)),
      ],
    );
  }

  /// Gradient-gold text, matching the calendar screen's luxury treatment.
  Widget _goldGradientText(String text, {double fontSize = 11, double letterSpacing = 1.2}) {
    return ShaderMask(
      shaderCallback: (b) => const LinearGradient(
        colors: [AppColors.goldLight, AppColors.gold, AppColors.goldDark],
      ).createShader(b),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: fontSize,
          letterSpacing: letterSpacing,
        ),
      ),
    );
  }

  Widget _brandTitle() {
    return ShaderMask(
      shaderCallback: (b) => const LinearGradient(
        colors: [AppColors.goldLight, AppColors.gold, AppColors.goldDark],
      ).createShader(b),
      child: const Text(
        'LifeStable',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  Widget _buildHeaderBar(
    BuildContext context,
    GlobalKey<ScaffoldState> scaffoldKey, {
    Widget? trailing,
  }) {
    final dateLine =
        DateFormat('EEE · MMM d').format(DateTime.now()).toUpperCase();
    final user = FirebaseAuth.instance.currentUser;
    final rawName = user?.displayName?.trim() ?? '';
    final firstName = rawName.isNotEmpty
        ? rawName.split(' ').first
        : (user?.email?.split('@').first ?? '');

    return Row(
      children: [
        GestureDetector(
          onTap: () => scaffoldKey.currentState?.openDrawer(),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.gold.withOpacity(0.18)),
            ),
            child: Icon(Icons.menu_rounded, color: AppColors.gold, size: 22),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dateLine,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                firstName.isEmpty
                    ? S.of('greeting_hey')
                    : '${S.of('greeting_hey')}, $firstName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing],
      ],
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
          _buildCompactHeader(context, S.of('todays_schedule')),
          const SizedBox(height: 12),
          if (events.isEmpty)
            Expanded(
                child: Center(
                    child: Text(S.of('no_events_today'),
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.24), fontSize: 12))))
          else
            Expanded(
              child: ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: events.length.clamp(0, 3),
                itemBuilder: (context, index) {
                  final event = events[index];
                  return GestureDetector(
                    onTap: () => Navigator.pushNamed(context, AppRoutes.calendar),
                    child: _buildListItem(context, event.title, Icons.calendar_today, Colors.blueAccent),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSkeletonBox(context, {double? height, double radius = 16}) {
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
            _buildNavButton(context, Icons.group_outlined, S.of('nav_team'), AppRoutes.teamDashboard),
            _buildNavButton(context, Icons.calendar_month_outlined, S.of('nav_calendar'), AppRoutes.calendar),
            _buildNavButton(context, Icons.dashboard_outlined, S.of('nav_dashboard'), AppRoutes.homeDashboard, active: true),
            _buildNavButton(context, Icons.local_fire_department_outlined, S.of('nav_habit'), AppRoutes.habitTracker),
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

/// AI insight text that shows a 3-line preview and expands on tap.
/// The "show more / show less" toggle only appears when the text
/// actually overflows the 3-line preview.
class _ExpandableInsight extends StatefulWidget {
  const _ExpandableInsight({required this.text});

  final String text;

  @override
  State<_ExpandableInsight> createState() => _ExpandableInsightState();
}

class _ExpandableInsightState extends State<_ExpandableInsight> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: Colors.white.withValues(alpha: 0.70),
      fontSize: 13,
      height: 1.4,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 3,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;

        final textWidget = Text(
          widget.text,
          maxLines: _expanded ? null : 3,
          overflow: _expanded ? TextOverflow.clip : TextOverflow.ellipsis,
          style: style,
        );

        if (!overflows) return textWidget;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _expanded = !_expanded),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              textWidget,
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _expanded ? S.of('show_less') : S.of('show_more'),
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.gold,
                    size: 16,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}