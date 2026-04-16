import 'dart:convert';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../domain/entities/task_entity.dart';
import '../../calendar/domain/entities/calendar_event_entity.dart';

enum AiActionType { createTask, updateTask, createEvent, unknown }

class AiActionResult {
  final AiActionType type;
  final dynamic entity;
  final String? targetId; // Güncelleme durumunda hedef task ID
  final Map<String, dynamic>? updates; // Güncellenecek alanlar

  AiActionResult({required this.type, this.entity, this.targetId, this.updates});
}

class PromptToActionService {
  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  Future<String> _getApiKey() async {
    return _remoteConfig.getString('gemini_api_key');
  }

  Future<AiActionResult> processPrompt(String prompt, String userId, {List<TaskEntity>? existingTasks}) async {
    try {
      final apiKey = await _getApiKey();
      if (apiKey.isEmpty) throw Exception("API Key bulunamadı");

      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey');

      // Mevcut görevleri bağlam olarak ekleyelim (Güncelleme için)
      String contextTasks = "";
      if (existingTasks != null && existingTasks.isNotEmpty) {
        contextTasks = "MEVCUT GÖREVLER (ID: Başlık):\n" + 
            existingTasks.map((t) => "- ${t.id}: ${t.title}").join("\n");
      }

      final systemPrompt = """Sen bir asistanasın. Kullanıcı metnini analiz et ve uygun aksiyonu JSON olarak dönüştür.
      
      AKSİYONLAR:
      1. CREATE_TASK: Yeni bir görev eklenmek istendiğinde.
      2. UPDATE_TASK: Mevcut bir görevin durumu (done/todo), önceliği veya tarihi değiştirilmek istendiğinde.
      3. CREATE_EVENT: Takvime bir etkinlik eklenmek istendiğinde.

      $contextTasks

      FORMAT (SADECE JSON):
      {
        "action": "CREATE_TASK" | "UPDATE_TASK" | "CREATE_EVENT",
        "target_id": "güncellenecek task ID'si (varsa)",
        "data": {
          "title": "başlık",
          "status": "todo" | "inProgress" | "done",
          "priority": "low" | "medium" | "high",
          "due_date": "ISO8601",
          "description": "açıklama"
        }
      }""";

      final body = {
        "contents": [
          {
            "parts": [{"text": "$systemPrompt\n\nKullanıcı: $prompt"}]
          }
        ],
        "generationConfig": {
          "response_mime_type": "application/json",
          "temperature": 0.1
        }
      };

      final response = await http.post(url, headers: {"Content-Type": "application/json"}, body: jsonEncode(body));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final String textResult = jsonResponse['candidates'][0]['content']['parts'][0]['text'];
        final Map<String, dynamic> actionData = jsonDecode(textResult);

        return _mapJsonToAction(actionData, userId);
      }
    } catch (e) {
      print("Prompt-to-Action Hatası: $e");
    }
    return AiActionResult(type: AiActionType.unknown);
  }

  AiActionResult _mapJsonToAction(Map<String, dynamic> json, String userId) {
    final action = json['action'];
    final data = json['data'] ?? {};
    final targetId = json['target_id'];

    if (action == "CREATE_TASK") {
      final task = TaskEntity(
        id: const Uuid().v4(),
        domainId: userId,
        title: data['title'] ?? "Adsız Görev",
        description: data['description'],
        status: _mapStatus(data['status']),
        priority: _mapPriority(data['priority']),
        dueDate: DateTime.tryParse(data['due_date'] ?? ""),
      );
      return AiActionResult(type: AiActionType.createTask, entity: task);
    } 
    
    if (action == "UPDATE_TASK" && targetId != null) {
      return AiActionResult(
        type: AiActionType.updateTask,
        targetId: targetId,
        updates: data,
      );
    }

    if (action == "CREATE_EVENT") {
      final event = CalendarEventEntity(
        id: const Uuid().v4(),
        userId: userId,
        title: data['title'] ?? "Etkinlik",
        startAt: DateTime.tryParse(data['due_date'] ?? "") ?? DateTime.now(),
        endAt: DateTime.tryParse(data['due_date'] ?? "")?.add(const Duration(hours: 1)) ?? DateTime.now().add(const Duration(hours: 1)),
        eventType: CalendarEventType.personal,
      );
      return AiActionResult(type: AiActionType.createEvent, entity: event);
    }

    return AiActionResult(type: AiActionType.unknown);
  }

  TaskStatus _mapStatus(String? status) {
    return TaskStatus.values.firstWhere((e) => e.name == status, orElse: () => TaskStatus.todo);
  }

  TaskPriority _mapPriority(String? priority) {
    return TaskPriority.values.firstWhere((e) => e.name == priority, orElse: () => TaskPriority.medium);
  }
}
