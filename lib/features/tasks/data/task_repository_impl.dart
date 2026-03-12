import '../domain/entities/task_entity.dart';
import '../domain/repositories/task_repository.dart';
import 'offline_task_cache.dart';

/// Task repository with offline-first behavior using a local LRU cache.
///
/// This implementation:
/// - Serves reads from the local [OfflineTaskCache] so the UI works offline.
/// - Writes into the cache and marks tasks as "dirty" for later synchronization.
/// - Exposes hooks (via [OfflineTaskCache]) that a future sync layer can use
///   to push local changes to Firestore and merge remote snapshots using
///   a "last-write-wins" conflict resolution strategy.
class TaskRepositoryImpl implements TaskRepository {
  TaskRepositoryImpl(this._offlineCache);

  final OfflineTaskCache _offlineCache;

  /// Convenience factory that constructs the repository with a default
  /// offline cache configuration.
  static Future<TaskRepositoryImpl> create() async {
    final cache = await OfflineTaskCache.create();
    return TaskRepositoryImpl(cache);
  }

  @override
  Future<List<TaskEntity>> fetchTasks() async {
    // Offline-first: return whatever is currently cached locally. A future
    // enhancement can trigger a background sync with Firestore and merge
    // the remote snapshot back into the cache via OfflineTaskCache.
    return _offlineCache.getAllTasks();
  }

  @override
  Future<void> createOrUpdateTask(TaskEntity task) async {
    // Offline-first: write into the local cache and mark the entry as dirty.
    // A future sync layer will push dirty entries to Firestore and then
    // call markTaskSynced / mergeRemoteSnapshot accordingly.
    await _offlineCache.upsertTask(task);
  }
}

