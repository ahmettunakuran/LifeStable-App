import 'package:flutter/material.dart';

class TaskEditPage extends StatelessWidget {
  const TaskEditPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create / Edit Task'),
      ),
      body: const Center(
        child: Text('Task Create/Edit Placeholder'),
      ),
    );
  }
}

