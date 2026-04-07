import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../domain/entities/calendar_event_entity.dart';

class OcrService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Groq API Anahtarınız (Güvenlik için push edilmemelidir)
  static const String _groqApiKey = "YOUR_GROQ_API_KEY_HERE";

  Future<List<CalendarEventEntity>> processScheduleWithGemini(String userId, XFile pickedFile) async {
    try {
      print("--- ADIM 1: ML KIT METİN OKUMA ---");
      final inputImage = InputImage.fromFilePath(pickedFile.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      if (recognizedText.text.trim().isEmpty) {
        print("Hata: Metin okunamadı.");
        return [];
      }

      print("--- ADIM 2: GROQ (LLAMA 3.3) İLE METİN İŞLEME ---");
      return await _processWithGroq(userId, recognizedText.text);

    } catch (e) {
      print("OCR SERVİS HATASI: $e");
      return [];
    }
  }

  Future<List<CalendarEventEntity>> _processWithGroq(String userId, String rawText) async {
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    
    try {
      final body = jsonEncode({
        "model": "llama-3.3-70b-versatile",
        "messages": [
          {
            "role": "system",
            "content": "Sen bir ders programı asistanısın. OCR çıktısındaki hataları düzelterek temiz bir ders programı çıkar. "
                       "Görevin SADECE bir JSON array döndürmek. Başka hiçbir açıklama ekleme. "
                       "Günleri Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday olarak eşle."
          },
          {
            "role": "user",
            "content": "Aşağıdaki metni JSON array'e dönüştür: \n$rawText \n\n"
                       "Format: [{\"day\": \"Monday\", \"start_time\": \"09:00\", \"end_time\": \"10:00\", \"course_name\": \"Ders Adı\"}]"
          }
        ],
        "temperature": 0.1,
        "response_format": {"type": "json_object"}
      });

      final client = HttpClient();
      final request = await client.postUrl(url);
      request.headers.set('Authorization', 'Bearer $_groqApiKey');
      request.headers.set('Content-Type', 'application/json');
      request.add(utf8.encode(body));
      
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        final String? aiResponse = data['choices']?[0]['message']?[ 'content'];
        if (aiResponse != null) {
          print("Groq yanıtı alındı.");
          return _parseAiResponse(aiResponse, userId);
        }
      } else {
        print("Groq Hatası (${response.statusCode}): $responseBody");
      }
    } catch (e) {
      print("Bağlantı Hatası: $e");
    }
    return [];
  }

  List<CalendarEventEntity> _parseAiResponse(String jsonText, String userId) {
    try {
      String cleanJson = jsonText.trim();
      // JSON bloğunu ayıkla (eğer markdown içindeyse)
      if (cleanJson.contains('```')) {
        final regExp = RegExp(r'\[.*\]', dotAll: true);
        final match = regExp.stringMatch(cleanJson);
        if (match != null) cleanJson = match;
      }
          
      final dynamic decoded = jsonDecode(cleanJson);
      List<dynamic> list = [];
      
      if (decoded is List) {
        list = decoded;
      } else if (decoded is Map) {
        // Eğer AI bir obje içinde listeyi döndürdüyse bulalım
        final possibleList = decoded.values.firstWhere((v) => v is List, orElse: () => []);
        list = possibleList is List ? possibleList : [];
      }

      return list.map((item) {
        final now = DateTime.now();
        final eventDate = _getNearestDayOfWeek(now, item['day']?.toString() ?? "Monday");
        
        return CalendarEventEntity(
          id: const Uuid().v4(),
          userId: userId,
          title: item['course_name']?.toString() ?? "Ders",
          startAt: _parseDateTime(eventDate, item['start_time']?.toString() ?? "09:00"),
          endAt: _parseDateTime(eventDate, item['end_time']?.toString() ?? "10:00"),
          eventType: CalendarEventType.classSchedule,
        );
      }).toList();
    } catch (e) {
      print("Parsing Hatası: $e \nRaw JSON: $jsonText");
      return [];
    }
  }

  DateTime _parseDateTime(DateTime date, String timeStr) {
    try {
      final parts = timeStr.split(':');
      int hour = int.parse(parts[0]);
      int minute = parts.length > 1 ? int.parse(parts[1]) : 0;
      return DateTime(date.year, date.month, date.day, hour, minute);
    } catch (e) {
      return date;
    }
  }

  DateTime _getNearestDayOfWeek(DateTime relativeTo, String dayName) {
    final dayNames = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    int targetDay = dayNames.indexOf(dayName.toLowerCase());
    if (targetDay == -1) return relativeTo;
    int currentDay = relativeTo.weekday - 1; 
    return relativeTo.add(Duration(days: targetDay - currentDay));
  }

  Future<void> saveScheduleEvents(List<CalendarEventEntity> events, String userId) async {
    if (events.isEmpty) return;
    final batch = _firestore.batch();
    for (var event in events) {
      final docRef = _firestore.collection('users').doc(userId).collection('calendar_events').doc();
      batch.set(docRef, event.toFirestore());
    }
    await batch.commit();
    print("Firebase: ${events.length} etkinlik başarıyla kaydedildi.");
  }
}
