import 'package:flutter/material.dart';

class TaskDetailPage extends StatelessWidget {
  const TaskDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Detail'),
      ),
      body: const Center(
        child: Text('Task Detail Placeholder'),
      ),
    );
  }
}

