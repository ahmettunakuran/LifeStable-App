import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';
import '../../tasks/domain/entities/task_entity.dart';
import '../../tasks/presentation/bloc/tasks_bloc.dart';
import '../../tasks/presentation/bloc/tasks_event.dart';
import '../../tasks/presentation/bloc/tasks_state.dart';

class TeamKanbanView extends StatelessWidget {
  const TeamKanbanView({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TasksBloc, TasksState>(
      builder: (context, state) {
        if (state is TasksLoading) {
          return const Center(child: CircularProgressIndicator(color: AppColors.gold));
        } else if (state is TasksLoaded) {
          final teamTasks = state.tasks.where((t) => t.teamId == teamId).toList();
          return _buildKanbanBoard(context, teamTasks);
        } else if (state is TasksError) {
          return Center(child: Text(state.message, style: TextStyle(color: Colors.white.withValues(alpha: 0.5))));
        }
        return Center(child: Text('No tasks found for this team.', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))));
      },
    );
  }

  Widget _buildKanbanBoard(BuildContext context, List<TaskEntity> tasks) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 0),
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

  Widget _buildKanbanColumn(BuildContext context, String title, TaskStatus status, List<TaskEntity> tasks) {
    final columnTasks = tasks.where((t) => t.status == status).toList();

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Column(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900, 
                      fontSize: 8, 
                      letterSpacing: 0.5, 
                      color: Colors.white38
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${columnTasks.length}', 
                    style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white24)
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 0.5, color: Colors.white10),
            Expanded(
              child: DragTarget<TaskEntity>(
                onWillAcceptWithDetails: (details) => details.data.status != status,
                onAcceptWithDetails: (details) {
                  context.read<TasksBloc>().add(UpdateTaskStatus(details.data.id, status));
                },
                builder: (context, candidateData, rejectedData) {
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                    itemCount: columnTasks.length,
                    itemBuilder: (context, index) {
                      final task = columnTasks[index];
                      return Draggable<TaskEntity>(
                        data: task,
                        feedback: Material(
                          elevation: 10,
                          borderRadius: BorderRadius.circular(6),
                          color: Colors.transparent,
                          child: ConstrainedBox(
                            constraints: BoxConstraints.tightFor(
                              width: (MediaQuery.of(context).size.width - 12) / 3,
                            ),
                            child: _TaskCard(task: task, teamId: teamId),
                          ),
                        ),
                        childWhenDragging: Opacity(opacity: 0.3, child: _TaskCard(task: task, teamId: teamId)),
                        child: _TaskCard(
                          task: task,
                          teamId: teamId,
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
  const _TaskCard({required this.task, required this.teamId, this.onStatusChanged, this.onDelete});
  final TaskEntity task;
  final String teamId;
  final ValueChanged<TaskStatus>? onStatusChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 1.5, decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.goldLight.withValues(alpha: 0.6), AppColors.gold.withValues(alpha: 0.3)]))),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
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
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, height: 1.2, color: Colors.white)
                        ),
                      ),
                      _TaskActions(currentStatus: task.status, onStatusChanged: onStatusChanged ?? (_) {}, onDelete: onDelete),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (task.description != null && task.description!.isNotEmpty) ...[
                    Text(
                      task.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 9, color: Colors.white38, height: 1.2),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _PriorityBadge(priority: task.priority),
                      if (task.dueDate != null)
                        Text(
                          DateFormat('d MMM').format(task.dueDate!),
                          style: const TextStyle(fontSize: 8, color: Colors.white24, fontWeight: FontWeight.w600)
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _AssigneeChip(userId: task.assignedTo),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssigneeChip extends StatelessWidget {
  const _AssigneeChip({this.userId});
  final String? userId;

  Future<String> _getUsername(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return doc.data()?['displayName'] ?? uid.substring(0, 4);
  }

  @override
  Widget build(BuildContext context) {
    if (userId == null) return const SizedBox.shrink();
    return FutureBuilder<String>(
      future: _getUsername(userId!),
      builder: (context, snapshot) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(2)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person, size: 7, color: Colors.white24),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  snapshot.data ?? '...', 
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white24, fontSize: 7)
                ),
              ),
            ],
          ),
        );
      },
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
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(priority.name.toUpperCase(), style: TextStyle(color: color, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 0.2)),
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
    return SizedBox(
      width: 16,
      height: 16,
      child: PopupMenuButton<dynamic>(
        padding: EdgeInsets.zero,
        onSelected: (value) {
          if (value is TaskStatus) {
            onStatusChanged(value);
          } else if (value == 'delete') {
            onDelete?.call();
          }
        },
        icon: const Icon(Icons.more_vert, size: 14, color: Colors.white24),
        color: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        itemBuilder: (context) => [
          _buildMenuItem(TaskStatus.todo, 'To-Do', Icons.radio_button_unchecked),
          _buildMenuItem(TaskStatus.inProgress, 'Doing', Icons.sync),
          _buildMenuItem(TaskStatus.done, 'Done', Icons.check_circle_outline),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: Colors.redAccent, fontSize: 14)),
            ]),
          ),
        ],
      ),
    );
  }

  PopupMenuItem _buildMenuItem(TaskStatus status, String text, IconData icon) {
    final isSelected = currentStatus == status;
    return PopupMenuItem(
      value: status,
      child: Row(children: [
        Icon(icon, size: 16, color: isSelected ? AppColors.gold : Colors.white38),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(fontSize: 14, color: isSelected ? AppColors.gold : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      ]),
    );
  }
}
