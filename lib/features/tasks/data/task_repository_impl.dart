import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/entities/task_entity.dart';
import '../domain/repositories/task_repository.dart';

class TaskRepositoryImpl implements TaskRepository {
  TaskRepositoryImpl(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  // Geçici olarak test kullanıcısı kimliği kullanılıyor.
  String? get _userId => 'test_kullanicisi_tuna';

  CollectionReference<Map<String, dynamic>>? get _taskCollection {
    final uid = _userId;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('tasks');
  }

  @override
  Future<List<TaskEntity>> fetchTasks() async {
    final collection = _taskCollection;
    if (collection == null) return [];
    
    final snapshot = await collection.get();
    return snapshot.docs
        .map((doc) => TaskEntity.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  @override
  Future<void> createOrUpdateTask(TaskEntity task) async {
    final collection = _taskCollection;
    if (collection == null) return;
    
    await collection.doc(task.id).set(task.toFirestore());
  }

  @override
  Future<void> deleteTask(String taskId) async {
    final collection = _taskCollection;
    if (collection == null) return;
    
    await collection.doc(taskId).delete();
  }

  @override
  Stream<List<TaskEntity>> watchTasks() {
    final collection = _taskCollection;
    if (collection == null) return Stream.value([]);

    return collection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => TaskEntity.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }
}
