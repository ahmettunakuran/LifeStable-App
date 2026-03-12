import 'package:flutter/material.dart';

import '../../../app/router/app_routes.dart';

class TasksKanbanPage extends StatelessWidget {
  const TasksKanbanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks / Kanban'),
      ),
      body: const Center(
        child: Text('Tasks Kanban Placeholder'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            Navigator.of(context).pushNamed(AppRoutes.taskEdit),
        child: const Icon(Icons.add),
      ),
    );
  }
}

