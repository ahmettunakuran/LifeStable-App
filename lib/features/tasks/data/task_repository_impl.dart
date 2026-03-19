import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'offline_task_cache.dart';
import '../domain/entities/task_entity.dart';
import '../domain/repositories/task_repository.dart';

class TaskRepositoryImpl implements TaskRepository {
  TaskRepositoryImpl(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Future<OfflineTaskCache> _offlineCache = OfflineTaskCache.create();

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _taskCollection {
    final uid = _userId;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('tasks');
  }

  @override
  Future<List<TaskEntity>> fetchTasks() async {
    final collection = _taskCollection;
    final cache = await _offlineCache;
    if (collection == null) {
      return cache.getAllTasks();
    }

    try {
      final snapshot = await collection.get();
      final remoteTasks = snapshot.docs
          .map((doc) => TaskEntity.fromFirestore(doc.id, doc.data()))
          .toList();

      for (final task in remoteTasks) {
        await cache.upsertTask(task);
        await cache.markTaskSynced(task.id, DateTime.now().toUtc());
      }
      return remoteTasks;
    } catch (_) {
      return cache.getAllTasks();
    }
  }

  @override
  Future<void> createOrUpdateTask(TaskEntity task) async {
    final collection = _taskCollection;
    final cache = await _offlineCache;
    await cache.upsertTask(task);
    if (collection == null) return;

    await collection.doc(task.id).set(task.toFirestore());
    await cache.markTaskSynced(task.id, DateTime.now().toUtc());
  }

  @override
  Future<void> deleteTask(String taskId) async {
    final collection = _taskCollection;
    final cache = await _offlineCache;
    await cache.removeTask(taskId);
    if (collection == null) return;
    await collection.doc(taskId).delete();
  }

  @override
  Stream<List<TaskEntity>> watchTasks() {
    final collection = _taskCollection;
    if (collection == null) {
      return Stream.fromFuture(_offlineCache.then((cache) => cache.getAllTasks()));
    }

    return collection.snapshots().map((snapshot) {
      final tasks = snapshot.docs
          .map((doc) => TaskEntity.fromFirestore(doc.id, doc.data()))
          .toList();
      _offlineCache.then((cache) async {
        for (final task in tasks) {
          await cache.upsertTask(task);
          await cache.markTaskSynced(task.id, DateTime.now().toUtc());
        }
      });
      return tasks;
    });
  }
}
