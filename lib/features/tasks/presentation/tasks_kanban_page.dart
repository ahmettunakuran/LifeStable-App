import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../app/router/app_routes.dart';
import '../domain/entities/task_entity.dart';
import 'bloc/tasks_bloc.dart';
import 'bloc/tasks_event.dart';
import 'bloc/tasks_state.dart';

class TasksKanbanPage extends StatelessWidget {
  const TasksKanbanPage({super.key});

  static const Color goldColor = Color(0xFFD4AF37);
  static const Color lightGrey = Color(0xFFF8F9FA);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        title: Text(
          'BOARD',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            fontSize: 22,
            color: isDark ? goldColor : Colors.black87,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: BlocBuilder<TasksBloc, TasksState>(
        builder: (context, state) {
          if (state is TasksLoading) {
            return const Center(child: CircularProgressIndicator(color: goldColor));
          } else if (state is TasksLoaded) {
            return _buildKanbanBoard(context, state.tasks);
          } else if (state is TasksError) {
            return Center(child: Text(state.message));
          }
          return const Center(child: Text('No tasks found.'));
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).pushNamed(AppRoutes.taskEdit),
        backgroundColor: goldColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Task', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildKanbanBoard(BuildContext context, List<TaskEntity> tasks) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildKanbanColumn(context, 'TO DO', TaskStatus.todo, tasks),
          _buildKanbanColumn(context, 'DOING', TaskStatus.inProgress, tasks),
          _buildKanbanColumn(context, 'DONE', TaskStatus.done, tasks),
        ],
      ),
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

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : lightGrey,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
              child: Column(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 0.8,
                      color: isDark ? goldColor : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: goldColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${columnTasks.length}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: goldColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1.5),
            Expanded(
              child: DragTarget<TaskEntity>(
                onWillAcceptWithDetails: (details) => details.data.status != status,
                onAcceptWithDetails: (details) {
                  context.read<TasksBloc>().add(UpdateTaskStatus(details.data.id, status));
                },
                builder: (context, candidateData, rejectedData) {
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                    itemCount: columnTasks.length,
                    itemBuilder: (context, index) {
                      final task = columnTasks[index];
                      return Draggable<TaskEntity>(
                        data: task,
                        feedback: Material(
                          elevation: 15,
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.transparent,
                          child: ConstrainedBox(
                            constraints: BoxConstraints.tightFor(
                              width: (MediaQuery.of(context).size.width - 24) / 3,
                            ),
                            child: _TaskCard(task: task),
                          ),
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
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    this.onStatusChanged,
    this.onDelete,
  });

  final TaskEntity task;
  final ValueChanged<TaskStatus>? onStatusChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 100, // BURASI KONTROL EDER: Kartın boylamasına yüksekliği
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 5, color: TasksKanbanPage.goldColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                task.title,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  height: 1.2,
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
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : Colors.black54,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PriorityBadge(priority: task.priority),
                        if (task.dueDate != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 12,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat('d MMM yyyy').format(task.dueDate!),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
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
        color = TasksKanbanPage.goldColor;
        break;
      case TaskPriority.low:
        color = const Color(0xFF388E3C);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        priority.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
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
    return SizedBox(
      width: 24,
      height: 24,
      child: PopupMenuButton<dynamic>(
        padding: EdgeInsets.zero,
        onSelected: (value) {
          if (value is TaskStatus) {
            onStatusChanged(value);
          } else if (value == 'delete') {
            onDelete?.call();
          }
        },
        icon: Icon(
          Icons.more_vert,
          size: 20,
          color: isDark ? Colors.white38 : Colors.black38,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        itemBuilder: (context) => [
          _buildMenuItem(TaskStatus.todo, 'To-Do', Icons.radio_button_unchecked),
          _buildMenuItem(TaskStatus.inProgress, 'Doing', Icons.sync),
          _buildMenuItem(TaskStatus.done, 'Done', Icons.check_circle_outline),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: const [
                Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                SizedBox(width: 8),
                Text('Delete', style: TextStyle(color: Colors.redAccent, fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
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
            size: 20,
            color: isSelected ? TasksKanbanPage.goldColor : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 15,
              color: isSelected ? TasksKanbanPage.goldColor : null,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
