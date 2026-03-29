import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/localization/app_localizations.dart';
import '../../tasks/domain/entities/task_entity.dart';
import '../../tasks/domain/task_sort.dart';
import '../../tasks/presentation/bloc/tasks_bloc.dart';
import '../../tasks/presentation/bloc/tasks_event.dart';
import '../../tasks/presentation/bloc/tasks_state.dart';
import '../domain/entities/domain_entity.dart';
import 'package:intl/intl.dart';

class DomainKanbanView extends StatelessWidget {
  const DomainKanbanView({super.key, required this.domain});

  final DomainEntity domain;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    
    return BlocBuilder<TasksBloc, TasksState>(
      builder: (context, state) {
        if (state is TasksLoading) {
          return const Center(child: CircularProgressIndicator(color: AppColors.gold));
        } else if (state is TasksLoaded) {
          var domainTasks = state.tasks.where((t) => t.domainId == domain.id).toList();
          
          // If this is a team mirror domain, filter to show only tasks assigned to the current user
          if (domain.isTeamMirror && currentUser != null) {
            domainTasks = domainTasks.where((t) => t.assignedTo == currentUser.uid).toList();
          }
          
          return _buildKanbanBoard(context, domainTasks);
        } else if (state is TasksError) {
          return Center(child: Text(state.message, style: TextStyle(color: Colors.white.withValues(alpha: 0.5))));
        }
        return Center(child: Text('No tasks found for this domain.', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))));
      },
    );
  }

  Widget _buildKanbanBoard(BuildContext context, List<TaskEntity> tasks) {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        _buildKanbanColumn(context, 'TO DO', TaskStatus.todo, tasks),
        _buildKanbanColumn(context, 'IN PROGRESS', TaskStatus.inProgress, tasks),
        _buildKanbanColumn(context, 'DONE', TaskStatus.done, tasks),
      ],
    );
  }

  Widget _buildKanbanColumn(BuildContext context, String title, TaskStatus status, List<TaskEntity> tasks) {
    final columnTasks = tasks.where((t) => t.status == status).toList();
    sortTasksByPriorityHighFirst(columnTasks);

    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1.2, color: Colors.white.withValues(alpha: 0.5))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text('${columnTasks.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gold)),
                ),
              ],
            ),
          ),
          Expanded(
            child: DragTarget<TaskEntity>(
              onWillAcceptWithDetails: (details) => details.data.status != status,
              onAcceptWithDetails: (details) {
                context.read<TasksBloc>().add(UpdateTaskStatus(details.data.id, status));
              },
              builder: (context, candidateData, rejectedData) {
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: columnTasks.length,
                  itemBuilder: (context, index) {
                    final task = columnTasks[index];
                    return Draggable<TaskEntity>(
                      data: task,
                      feedback: Material(
                        elevation: 10,
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.transparent,
                        child: _TaskCard(task: task, width: 276),
                      ),
                      childWhenDragging: Opacity(opacity: 0.3, child: _TaskCard(task: task)),
                      child: _TaskCard(
                        task: task,
                        onStatusChanged: (newStatus) {
                          context.read<TasksBloc>().add(UpdateTaskStatus(task.id, newStatus));
                        },
                        onDelete: () {
                          context.read<TasksBloc>().add(DeleteTask(task.id));
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, this.width, this.onStatusChanged, this.onDelete});
  final TaskEntity task;
  final double? width;
  final ValueChanged<TaskStatus>? onStatusChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 3, decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.goldLight.withValues(alpha: 0.6), AppColors.gold.withValues(alpha: 0.3)]))),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(task.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white))),
                      _TaskActions(currentStatus: task.status, onStatusChanged: onStatusChanged ?? (_) {}, onDelete: onDelete),
                    ],
                  ),
                  if (task.description != null && task.description!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(task.description!, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12, height: 1.4)),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _PriorityBadge(priority: task.priority),
                      if (task.dueDate != null)
                        Row(children: [
                          Icon(Icons.calendar_today, size: 11, color: Colors.white.withValues(alpha: 0.3)),
                          const SizedBox(width: 4),
                          Text(DateFormat('MMM d').format(task.dueDate!),
                              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.3), fontWeight: FontWeight.w600)),
                        ]),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});
  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (priority) {
      case TaskPriority.high: color = const Color(0xFFD32F2F);
      case TaskPriority.medium: color = AppColors.gold;
      case TaskPriority.low: color = const Color(0xFF388E3C);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(priority.name.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
    );
  }
}

class _TaskActions extends StatelessWidget {
  const _TaskActions({required this.currentStatus, required this.onStatusChanged, this.onDelete});
  final TaskStatus currentStatus;
  final ValueChanged<TaskStatus> onStatusChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<dynamic>(
      padding: EdgeInsets.zero,
      onSelected: (value) {
        if (value is TaskStatus) {
          onStatusChanged(value);
        } else if (value == 'delete') {
          onDelete?.call();
        }
      },
      icon: Icon(Icons.more_horiz, size: 18, color: Colors.white.withValues(alpha: 0.3)),
      color: AppColors.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => [
        PopupMenuItem(enabled: false, child: Text('MOVE TO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white.withValues(alpha: 0.3)))),
        _buildMenuItem(TaskStatus.todo, 'To-Do', Icons.radio_button_unchecked),
        _buildMenuItem(TaskStatus.inProgress, 'In-Progress', Icons.sync),
        _buildMenuItem(TaskStatus.done, 'Done', Icons.check_circle_outline),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Delete', style: TextStyle(color: Colors.redAccent, fontSize: 14)),
          ]),
        ),
      ],
    );
  }

  PopupMenuItem _buildMenuItem(TaskStatus status, String text, IconData icon) {
    final isSelected = currentStatus == status;
    return PopupMenuItem(
      value: status,
      child: Row(children: [
        Icon(icon, size: 18, color: isSelected ? AppColors.gold : Colors.white38),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(fontSize: 14, color: isSelected ? AppColors.gold : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      ]),
    );
  }
}
