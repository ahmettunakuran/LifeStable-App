import '../domain/entities/task_entity.dart';
import '../domain/repositories/task_repository.dart';

/// Placeholder implementation that will be wired to Firestore in later WPs.
class TaskRepositoryImpl implements TaskRepository {
  @override
  Future<List<TaskEntity>> fetchTasks() async {
    // TODO(WP2+): Implement using Firestore / Cloud Functions.
    return [];
  }

  @override
  Future<void> createOrUpdateTask(TaskEntity task) async {
    // TODO(WP2+): Implement using Firestore / Cloud Functions.
  }
}

