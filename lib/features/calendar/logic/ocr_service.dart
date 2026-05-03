import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import '../domain/entities/calendar_event_entity.dart';

class OcrService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  Future<String> _getApiKeyFromRemoteConfig() async {
    try {
      print("--- Remote Config Başlatılıyor ---");
      await _remoteConfig.setDefaults(<String, dynamic>{
        'gemini_api_key': '',
      });
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 30),
        minimumFetchInterval: const Duration(seconds: 1),
      ));
      
      print("--- Veriler Çekiliyor (Fetch) ---");
      await _remoteConfig.fetchAndActivate();
      
      final String apiKey = _remoteConfig.getString('gemini_api_key');
      
      if (apiKey.isNotEmpty) {
        print("API Key Başarıyla Alındı: ${apiKey.substring(0, 5)}...");
        return apiKey;
      } else {
        print("Uyarı: 'gemini_api_key' Remote Config'de boş görünüyor.");
      }
    } catch (e) {
      print("Remote Config Hatası: $e");
    }
    // Fallback as a last resort if remote config fails (not recommended for production)
    return _remoteConfig.getString('gemini_api_key');
  }

  Future<List<CalendarEventEntity>> processScheduleFree(String userId, XFile pickedFile) async {
    try {
      final apiKey = await _getApiKeyFromRemoteConfig();
      if (apiKey.isEmpty) {
        print("Hata: API Key bulunamadı.");
        return [];
      }

      print("--- Gemini 2.5 Flash Analizi Başlıyor ---");
      final bytes = await pickedFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      const modelName = "gemini-2.5-flash"; 
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey');

      final prompt = """Bu bir üniversite ders programı görselidir. Görseli analiz et ve tüm dersleri JSON formatında çıkar. 
      SADECE JSON döndür. Markdown (```json) kullanma.
      Format: {"events": [{"course": "Ders Adı", "day": "Monday", "start": "08:40", "end": "10:30", "location": "Oda"}]}""";

      final body = {
        "contents": [
          {
            "parts": [
              {"text": prompt},
              {
                "inline_data": {
                  "mime_type": "image/png",
                  "data": base64Image
                }
              }
            ]
          }
        ],
        "generationConfig": {
          "response_mime_type": "application/json",
          "temperature": 0.1
        }
      };

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String content = data['candidates'][0]['content']['parts'][0]['text'];
        print("Gemini Yanıtı Alındı.");
        return _parseAiResponse(content, userId);
      } else {
        print("Gemini Hatası (${response.statusCode}): ${response.body}");
      }
    } catch (e) {
      print("Kritik Hata: $e");
    }
    return [];
  }

  List<CalendarEventEntity> _parseAiResponse(String jsonText, String userId) {
    try {
      String cleanedJson = jsonText.trim();
      if (cleanedJson.startsWith("```")) {
        cleanedJson = cleanedJson.replaceAll("```json", "").replaceAll("```", "").trim();
      }

      final decoded = jsonDecode(cleanedJson);
      List<dynamic> events = [];

      if (decoded is Map) {
        events = decoded['events'] ?? [];
      } else if (decoded is List) {
        events = decoded;
      }

      return events.map((item) {
        final now = DateTime.now();
        final eventDate = _getNearestDayOfWeek(now, item['day'] ?? 'Monday');
        
        return CalendarEventEntity(
          id: const Uuid().v4(),
          userId: userId,
          title: "${item['course'] ?? 'Ders'} ${item['location'] != null ? '(${item['location']})' : ''}",
          startAt: _parseDateTime(eventDate, item['start'] ?? '08:00'),
          endAt: _parseDateTime(eventDate, item['end'] ?? '09:00'),
          eventType: CalendarEventType.classSchedule,
        );
      }).toList();
    } catch (e) {
      print("JSON Ayrıştırma Hatası: $e");
      print("Ham Metin: $jsonText");
      return [];
    }
  }

  DateTime _parseDateTime(DateTime date, String timeStr) {
    try {
      final parts = timeStr.trim().split(':');
      return DateTime(date.year, date.month, date.day, int.parse(parts[0]), int.parse(parts[1]));
    } catch (e) {
      return date;
    }
  }

  DateTime _getNearestDayOfWeek(DateTime relativeTo, String dayName) {
    final days = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"];
    int target = days.indexOf(dayName.toLowerCase());
    if (target == -1) return relativeTo;
    int diff = (target + 1) - relativeTo.weekday;
    return relativeTo.add(Duration(days: diff < 0 ? diff + 7 : diff));
  }

  Future<void> saveScheduleEvents(List<CalendarEventEntity> events, String userId) async {
    if (events.isEmpty) return;
    final batch = _firestore.batch();
    for (var event in events) {
      final docRef = _firestore.collection('users').doc(userId).collection('calendar_events').doc();
      batch.set(docRef, event.toFirestore());
    }
    await batch.commit();
  }
}
