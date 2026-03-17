import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../tasks/domain/entities/task_entity.dart';
import '../../tasks/presentation/bloc/tasks_bloc.dart';
import '../../tasks/presentation/bloc/tasks_event.dart';
import '../../tasks/presentation/bloc/tasks_state.dart';
import '../domain/entities/domain_entity.dart';
import 'package:intl/intl.dart';

class DomainKanbanView extends StatelessWidget {
  const DomainKanbanView({super.key, required this.domain});

  final DomainEntity domain;

  static const Color goldColor = Color(0xFFD4AF37);
  static const Color lightGrey = Color(0xFFF8F9FA);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocBuilder<TasksBloc, TasksState>(
      builder: (context, state) {
        if (state is TasksLoading) {
          return const Center(child: CircularProgressIndicator(color: goldColor));
        } else if (state is TasksLoaded) {
          final domainTasks = state.tasks.where((t) => t.domainId == domain.id).toList();
          return _buildKanbanBoard(context, domainTasks);
        } else if (state is TasksError) {
          return Center(child: Text(state.message));
        }
        return const Center(child: Text('No tasks found for this domain.'));
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

  Widget _buildKanbanColumn(
    BuildContext context,
    String title,
    TaskStatus status,
    List<TaskEntity> tasks,
  ) {
    final columnTasks = tasks.where((t) => t.status == status).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : lightGrey,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 1,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: goldColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${columnTasks.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: goldColor,
                    ),
                  ),
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
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.transparent,
                        child: _TaskCard(task: task, width: 276),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.4,
                        child: _TaskCard(task: task),
                      ),
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
  const _TaskCard({
    required this.task,
    this.width,
    this.onStatusChanged,
    this.onDelete,
  });

  final TaskEntity task;
  final double? width;
  final ValueChanged<TaskStatus>? onStatusChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: width,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 4,
              color: DomainKanbanView.goldColor,
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      _TaskActions(
                        currentStatus: task.status,
                        onStatusChanged: onStatusChanged ?? (s) {},
                        onDelete: onDelete,
                      ),
                    ],
                  ),
                  if (task.description != null && task.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      task.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _PriorityBadge(priority: task.priority),
                      if (task.dueDate != null)
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 12,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('MMM d').format(task.dueDate!),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white38 : Colors.black38,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
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
      case TaskPriority.high:
        color = const Color(0xFFD32F2F);
        break;
      case TaskPriority.medium:
        color = DomainKanbanView.goldColor;
        break;
      case TaskPriority.low:
        color = const Color(0xFF388E3C);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        priority.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _TaskActions extends StatelessWidget {
  const _TaskActions({
    required this.currentStatus,
    required this.onStatusChanged,
    this.onDelete,
  });

  final TaskStatus currentStatus;
  final ValueChanged<TaskStatus> onStatusChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopupMenuButton<dynamic>(
      padding: EdgeInsets.zero,
      onSelected: (value) {
        if (value is TaskStatus) {
          onStatusChanged(value);
        } else if (value == 'delete') {
          onDelete?.call();
        }
      },
      icon: Icon(
        Icons.more_horiz,
        size: 18,
        color: isDark ? Colors.white38 : Colors.black26,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => [
        const PopupMenuItem(
          enabled: false,
          child: Text(
            'MOVE TO',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey),
          ),
        ),
        _buildMenuItem(TaskStatus.todo, 'To-Do', Icons.radio_button_unchecked),
        _buildMenuItem(TaskStatus.inProgress, 'In-Progress', Icons.sync),
        _buildMenuItem(TaskStatus.done, 'Done', Icons.check_circle_outline),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: const [
              Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: Colors.redAccent, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  PopupMenuItem _buildMenuItem(TaskStatus status, String text, IconData icon) {
    final isSelected = currentStatus == status;
    return PopupMenuItem(
      value: status,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected ? DomainKanbanView.goldColor : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: isSelected ? DomainKanbanView.goldColor : null,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
