import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
import 'offline_task_cache.dart';
import '../domain/entities/task_entity.dart';
import '../domain/repositories/task_repository.dart';
import 'dart:async';

class TaskRepositoryImpl implements TaskRepository {
  TaskRepositoryImpl(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Future<OfflineTaskCache> _offlineCache = OfflineTaskCache.create();

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _personalTaskCollection {
    final uid = _userId;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('tasks');
  }

  CollectionReference<Map<String, dynamic>> _teamTaskCollection(String teamId) {
    return _firestore.collection('teams').doc(teamId).collection('tasks');
  }

  @override
  Future<List<TaskEntity>> fetchTasks() async {
    final cache = await _offlineCache;
    // For simplicity, we mostly rely on watchTasks for real-time sync.
    // fetchTasks can return cached data or personal tasks.
    final collection = _personalTaskCollection;
    if (collection == null) return cache.getAllTasks();

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
    final uid = _userId;
    final taskToPersist = (task.teamId != null && uid != null)
        ? task.copyWith(lastUpdatedBy: uid)
        : task;

    final cache = await _offlineCache;
    await cache.upsertTask(taskToPersist);

    if (uid == null) return;

    if (taskToPersist.teamId != null) {
      await _teamTaskCollection(taskToPersist.teamId!).doc(taskToPersist.id).set(taskToPersist.toFirestore());
    } else {
      final collection = _personalTaskCollection;
      if (collection != null) {
        await collection.doc(taskToPersist.id).set(taskToPersist.toFirestore());
      }
    }
    await cache.markTaskSynced(taskToPersist.id, DateTime.now().toUtc());
  }

  @override
  Future<void> deleteTask(String taskId) async {
    final cache = await _offlineCache;
    final task = await cache.getTask(taskId);
    await cache.removeTask(taskId);

    if (_userId == null) return;

    if (task?.teamId != null) {
      await _teamTaskCollection(task!.teamId!).doc(taskId).delete();
    } else {
      final collection = _personalTaskCollection;
      if (collection != null) {
        await collection.doc(taskId).delete();
      }
    }
  }

  @override
  Stream<List<TaskEntity>> watchTasks() {
    final uid = _userId;
    if (uid == null) {
      return Stream.fromFuture(_offlineCache.then((cache) => cache.getAllTasks()));
    }

    // 1. Watch personal tasks
    final personalStream = _personalTaskCollection?.snapshots().map((snapshot) {
          return snapshot.docs
              .map((doc) => TaskEntity.fromFirestore(doc.id, doc.data()))
              .toList();
        }) ??
        Stream.value(<TaskEntity>[]);

    // 2. Watch team tasks by first watching the user's team memberships
    final teamsTasksStream = _firestore
        .collection('team_members')
        .where('user_id', isEqualTo: uid)
        .snapshots()
        .switchMap((membershipSnapshot) {
      final teamIds = membershipSnapshot.docs.map((doc) => doc.data()['team_id'] as String).toList();
      
      if (teamIds.isEmpty) return Stream.value(<List<TaskEntity>>[]);

      final teamTaskStreams = teamIds.map((teamId) {
        return _teamTaskCollection(teamId).snapshots().map((snapshot) {
          return snapshot.docs
              .map((doc) => TaskEntity.fromFirestore(doc.id, doc.data()))
              .toList();
        });
      });

      return CombineLatestStream.list<List<TaskEntity>>(teamTaskStreams);
    });

    return CombineLatestStream.combine2<List<TaskEntity>, List<List<TaskEntity>>, List<TaskEntity>>(
      personalStream,
      teamsTasksStream,
      (personal, allTeamsTasks) {
        final List<TaskEntity> combined = [...personal];
        for (final teamTasks in allTeamsTasks) {
          combined.addAll(teamTasks);
        }
        
        // Background cache update
        _offlineCache.then((cache) async {
          for (final task in combined) {
            await cache.upsertTask(task);
          }
        });
        
        return combined;
      },
    );
  }
}
