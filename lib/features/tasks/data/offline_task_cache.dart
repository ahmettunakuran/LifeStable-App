import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/cache/lru_cache.dart';
import '../domain/entities/task_entity.dart';

const String _offlineTasksStorageKey = 'offline_tasks_v2';

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
      'teamId': task.teamId,
      'assignedTo': task.assignedTo,
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
        dueDate: json['dueDate'] != null ? DateTime.tryParse(json['dueDate'] as String) : null,
        teamId: json['teamId'] as String?,
        assignedTo: json['assignedTo'] as String?,
      ),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      isDirty: json['isDirty'] as bool? ?? false,
    );
  }
}

class OfflineTaskCache {
  OfflineTaskCache._(this._prefs, this._lruCache);

  final SharedPreferences _prefs;
  final LruCache<String, CachedTask> _lruCache;

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
      } catch (_) {}
    }

    return OfflineTaskCache._(prefs, lruCache);
  }

  List<TaskEntity> getAllTasks() {
    return _lruCache.values().map((cached) => cached.task).toList();
  }

  Future<TaskEntity?> getTask(String id) async {
    return _lruCache.get(id)?.task;
  }

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

  Future<void> markTaskSynced(String taskId, DateTime syncedAt) async {
    final existing = _lruCache.get(taskId);
    if (existing == null) return;

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

  Future<void> _persist() async {
    final list = _lruCache.values().map((cached) => cached.toJson()).toList();
    final raw = jsonEncode(list);
    await _prefs.setString(_offlineTasksStorageKey, raw);
  }
}
