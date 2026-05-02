import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';

class TaskDetailPage extends StatelessWidget {
  const TaskDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of('task_detail')),
      ),
      body: Center(
        child: Text(S.of('task_detail_placeholder')),
      ),
    );
  }
}

