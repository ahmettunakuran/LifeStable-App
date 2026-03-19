import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/cache/lru_cache.dart';
import '../domain/entities/task_entity.dart';

const String _offlineTasksStorageKey = 'offline_tasks_v1';

class CachedTask {
  CachedTask({
    required this.task,
    required this.updatedAt,
    required this.isDirty,
  });

  final TaskEntity task;
  final DateTime updatedAt;
  final bool isDirty;

  CachedTask copyWith({
    TaskEntity? task,
    DateTime? updatedAt,
    bool? isDirty,
  }) {
    return CachedTask(
      task: task ?? this.task,
      updatedAt: updatedAt ?? this.updatedAt,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': task.id,
      'domainId': task.domainId,
      'title': task.title,
      'description': task.description,
      'status': task.status.name,
      'priority': task.priority.name,
      'dueDate': task.dueDate?.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isDirty': isDirty,
    };
  }

  static CachedTask fromJson(Map<String, dynamic> json) {
    return CachedTask(
      task: TaskEntity(
        id: json['id'] as String,
        domainId: json['domainId'] as String? ?? '',
        title: json['title'] as String,
        description: json['description'] as String?,
        status: TaskStatus.values.firstWhere(
          (e) => e.name == (json['status'] as String? ?? TaskStatus.todo.name),
          orElse: () => TaskStatus.todo,
        ),
        priority: TaskPriority.values.firstWhere(
          (e) => e.name == (json['priority'] as String? ?? TaskPriority.medium.name),
          orElse: () => TaskPriority.medium,
        ),
        dueDate: json['dueDate'] != null
            ? DateTime.tryParse(json['dueDate'] as String)
            : null,
      ),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      isDirty: json['isDirty'] as bool? ?? false,
    );
  }
}

/// Offline-first task cache backed by local storage with an in-memory LRU layer.
///
/// - Uses [LruCache] in-memory to keep only the most recently used tasks.
/// - Persists the complete cached set into `SharedPreferences` for offline usage.
/// - Applies a "last-write-wins" strategy when merging local and remote changes.
class OfflineTaskCache {
  OfflineTaskCache._(this._prefs, this._lruCache);

  final SharedPreferences _prefs;
  final LruCache<String, CachedTask> _lruCache;

  /// Factory for async initialization (loads from disk into the LRU cache).
  static Future<OfflineTaskCache> create({int maxEntries = 100}) async {
    final prefs = await SharedPreferences.getInstance();
    final lruCache = LruCache<String, CachedTask>(capacity: maxEntries);

    final raw = prefs.getString(_offlineTasksStorageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        for (final item in decoded) {
          final cached = CachedTask.fromJson(item as Map<String, dynamic>);
          lruCache.put(cached.task.id, cached);
        }
      } catch (_) {
        // If anything goes wrong during decode, start with an empty cache.
      }
    }

    return OfflineTaskCache._(prefs, lruCache);
  }

  /// Returns all tasks currently held in the cache (ordered from least
  /// recently used to most recently used).
  List<TaskEntity> getAllTasks() {
    return _lruCache.values().map((cached) => cached.task).toList();
  }

  /// Upserts a task locally and marks it as "dirty" so it will be pushed to
  /// the backend on next sync. Uses "last-write-wins" semantics locally by
  /// always overwriting existing entries with the latest write timestamp.
  Future<void> upsertTask(TaskEntity task) async {
    final now = DateTime.now().toUtc();
    final cached = CachedTask(
      task: task,
      updatedAt: now,
      isDirty: true,
    );

    _lruCache.put(task.id, cached);
    await _persist();
  }

  /// Returns all locally modified tasks that have not been successfully
  /// synchronized with the backend yet.
  List<CachedTask> getDirtyTasks() {
    return _lruCache
        .values()
        .where((cached) => cached.isDirty)
        .toList(growable: false);
  }

  /// Marks the given task as successfully synchronized at [syncedAt] and
  /// persists the updated state.
  Future<void> markTaskSynced(String taskId, DateTime syncedAt) async {
    final existing = _lruCache.get(taskId);
    if (existing == null) {
      return;
    }

    final updated = existing.copyWith(
      isDirty: false,
      updatedAt: syncedAt.toUtc(),
    );
    _lruCache.put(taskId, updated);
    await _persist();
  }

  Future<void> removeTask(String taskId) async {
    _lruCache.remove(taskId);
    await _persist();
  }

  /// Applies a remote snapshot into the local cache using "last-write-wins".
  ///
  /// For each [remote] task:
  /// - If no local version exists, the remote is stored.
  /// - If a local version exists, the one with the newer [updatedAt] wins.
  /// - When the remote wins, the entry is marked as not dirty.
  ///
  /// This method is designed to be called after fetching a fresh list of tasks
  /// from the backend.
  Future<void> mergeRemoteSnapshot(List<CachedTask> remoteTasks) async {
    for (final remote in remoteTasks) {
      final local = _lruCache.get(remote.task.id);
      if (local == null) {
        _lruCache.put(
          remote.task.id,
          remote.copyWith(isDirty: false),
        );
        continue;
      }

      // Last-write-wins: prefer the task with the newer updatedAt timestamp.
      if (remote.updatedAt.isAfter(local.updatedAt)) {
        _lruCache.put(
          remote.task.id,
          remote.copyWith(isDirty: false),
        );
      } else {
        // Keep local version; it stays dirty so the sync layer knows to
        // push it up to the backend.
        _lruCache.put(local.task.id, local);
      }
    }

    await _persist();
  }

  Future<void> _persist() async {
    final list = _lruCache.values().map((cached) => cached.toJson()).toList();
    final raw = jsonEncode(list);
    await _prefs.setString(_offlineTasksStorageKey, raw);
  }
}

