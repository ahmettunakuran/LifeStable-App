import 'dart:convert';
import 'dart:io' as io;
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:http/http.dart' as http;

enum AppDomain { tasks, calendar, habits, summary, sports, education, domains, unknown }

class AiResult {
  final AppDomain domain;
  final String action;
  final Map<String, dynamic> payload;
  final String responseText;

  AiResult({
    required this.domain,
    required this.action,
    required this.payload,
    required this.responseText,
  });
}

class AiPipelineService {
  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  Future<AiResult> dispatch(
    String prompt,
    List<Map<String, dynamic>> history, {
    String? appData,
    String configKey = 'groq_api_key',
  }) async {
    try {
      final apiKey = _remoteConfig.getString(configKey);
      
      if (apiKey.isEmpty) {
        print("KRİTİK HATA: groq_api_key Remote Config'de bulunamadı!");
        return AiResult(domain: AppDomain.unknown, action: 'none', payload: {}, responseText: "Sistem yapılandırması eksik (API Key bulunamadı).");
      }
          
      final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

      final now = DateTime.now();
      
      final systemInstruction = """
      Sen LifeStable asistanısın. 24 saatlik (23:00, 21:00) dijital saat sistemini kullan.
      GÜNCEL ZAMAN (ISO): ${now.toIso8601String()}
      BUGÜN: ${_getWeekday(now.weekday)}
      
      UYGULAMA VERİLERİ (CONTEXT):
      $appData

      KURALLAR:
      1. İşlem Tipleri (Action):
         - 'create' / 'add_event': Yeni öğe oluştur. Zaman belirtilmişse ISO8601 formatında TAM zamanı (YYYY-MM-DDTHH:mm:ss) döndür.
         - 'delete': Mevcut öğeyi sil. (Tekil için 'id', toplu silme için 'ids' listesi gönder).
         - 'update': Mevcut öğeyi güncelle. ('id' ve değişen alanlar).
         - 'find_gap': Boş zaman/uygun slot bulma. Kullanıcı "Boş vaktim var mı?", "2 saatlik yer bul", "Ne zaman müsaitim?" gibi sorgularında kullanılır.
         - 'read': Mevcut verileri sorgulama veya listeleme.

      2. Zaman Tanımları (Göreceli):
         - 'Bu sabah': 08:00 - 12:00
         - 'Bu öğlen': 12:00 - 17:00
         - 'Bu akşam': 17:00 - 22:00
         - 'Gece': 22:00 - 00:00
         - 'Haftaya': Mevcut tarihten 7 gün sonrası ve o hafta içi.
         - '3-4 gün sonra': Mevcut tarihe 3 veya 4 gün ekle.

      3. 'find_gap' için Özel Kurallar:
         - MEVCUT TAKVİM ETKİNLİKLERİ ve MEVCUT GÖREVLER (eğer zamanı varsa) verilerini incele.
         - Çakışmayan, kullanıcının istediği süreye (örn: 2 saat) uygun boşlukları tespit et.
         - 'payload' içinde 'suggestedSlots' listesi döndür. Her slot {'startTime': '...', 'endTime': '...'} içermeli.
         - 'responseText' içinde sadece bulunan boşlukları listele. Örn: "Bugün 14:00-16:00 ve 18:00-20:00 arası uygunsunuz."
         - Gereksiz "işlem başlatıldı" gibi ara mesajlar verme, doğrudan sonucu söyle.

      4. CRUD İşlemleri:
         - Kullanıcı "Bugünkü tüm etkinlikleri sil" veya "Hepsini temizle" derse, Context içindeki uygun ID'leri bul ve 'ids' listesi olarak döndür.
         - Başlık (title) içine saati ekleme.
         - Zaman Dilimi: Yerel saati kullan, sonuna 'Z' koyma. Kullanıcı "16:00" diyorsa, ISO string'in saati tam 16:00 olmalıdır.

      GÖREV ÖNCELİĞİ (Priority):
      - 'low', 'medium', 'high' değerlerini kullan.
      - Kullanıcı belirtmezse varsayılan 'low' kullan.

      JSON FORMATI:
      {
        "domain": "tasks" | "calendar" | "summary" | "habits",
        "action": "create" | "add_event" | "delete" | "update" | "read" | "find_gap",
        "payload": { 
           "domain": "Kullanıcının belirttiği alan adı (Örn: Gym, School, İş)",
           "domainId": "Eğer Context içinde varsa alanın ID'si",
           "title": "...", 
           "dueDate": "ISO8601",
           "startTime": "ISO8601",
           "endTime": "ISO8601",
           "priority": "low" | "medium" | "high",
           "durationMinutes": 120,
           "suggestedSlots": [
              {"startTime": "ISO8601", "endTime": "ISO8601"}
           ]
        },
        "responseText": "Kullanıcıya yapılan işlem veya bulunan boşluklar hakkında bilgi ver."
      }
      """;

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $apiKey"
        },
        body: jsonEncode({
          "model": "llama-3.3-70b-versatile",
          "messages": [
            {"role": "system", "content": systemInstruction},
            ...history.map((m) => {
              "role": m['role'] == 'model' ? 'assistant' : 'user',
              "content": m['text']
            }),
            {"role": "user", "content": prompt}
          ],
          "response_format": {"type": "json_object"},
          "temperature": 0.1
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        print("RAW AI CONTENT: $content");
        
        final decoded = jsonDecode(content);
        Map<String, dynamic> result;
        
        if (decoded is List && decoded.isNotEmpty) {
          result = decoded[0] as Map<String, dynamic>;
        } else if (decoded is Map) {
          result = decoded as Map<String, dynamic>;
        } else {
          result = {};
        }

        return AiResult(
          domain: _parseDomain(result['domain']),
          action: result['action'] ?? 'none',
          payload: result['payload'] ?? {},
          responseText: result['responseText'] ?? "İşlem tamam.",
        );
      }
    } catch (e) {
      print("Pipeline Error: $e");
    }
    return AiResult(domain: AppDomain.unknown, action: 'none', payload: {}, responseText: "Bir hata oluştu.");
  }

  AppDomain _parseDomain(String? domain) {
    return AppDomain.values.firstWhere((e) => e.name == domain, orElse: () => AppDomain.unknown);
  }

  String _getWeekday(int day) {
    const days = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
    return days[day - 1];
  }

  Future<String?> fetchDailyInsights(
    String data, {
    String configKey = 'groq_api_key',
    String languageCode = 'tr',
  }) async {
    try {
      final apiKey = _remoteConfig.getString(configKey);
      if (apiKey.isEmpty) return null;

      final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
      
      final systemPrompt = languageCode == 'tr' 
          ? "Sen bir verimlilik asistanısın. Kullanıcının bugünkü görevlerine ve alışkanlıklarına bakarak kısa, motive edici ve aksiyon odaklı bir günlük özet çıkar. Maksimum 2-3 cümle olsun."
          : "You are a productivity assistant. Based on the user's tasks and habits for today, provide a short, motivating, and action-oriented daily insight. Maximum 2-3 sentences.";

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $apiKey"
        },
        body: jsonEncode({
          "model": "llama-3.3-70b-versatile",
          "messages": [
            {"role": "system", "content": systemPrompt},
            {"role": "user", "content": data}
          ],
          "temperature": 0.7
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['choices'][0]['message']['content'];
      }
    } catch (e) {
      print("Insight Error: $e");
    }
    return null;
  }

  /// Vision fallback for non-structured schedule images
  Future<List<Map<String, dynamic>>?> extractScheduleFromImage(String imagePath) async {
    // This is often a fallback for when ML Kit layout analysis fails.
    // We send the image directly to Gemini to find a schedule.
    try {
      final apiKey = _remoteConfig.getString('gemini_api_key');
      if (apiKey.isEmpty) return null;

      final bytes = await http.ByteStream(Stream.value(List<int>.from(await http.readBytes(Uri.file(imagePath))))).toBytes();
      final base64Image = base64Encode(await _readImageBytes(imagePath));

      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey');

      final prompt = """Analyze this image. If it contains a class schedule or weekly calendar, 
      extract all entries into a JSON list.
      Format: {"events": [{"title": "...", "dayOfWeek": 1-7, "startHour": 0-23, "startMinute": 0-59, "endHour": 0-23, "endMinute": 0-59}]}""";

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [{
            "parts": [
              {"text": prompt},
              {"inline_data": {"mime_type": "image/jpeg", "data": base64Image}}
            ]
          }],
          "generationConfig": {"response_mime_type": "application/json"}
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['candidates'][0]['content']['parts'][0]['text'];
        final decoded = jsonDecode(content);
        final list = decoded['events'] as List?;
        return list?.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print("Vision Schedule Error: $e");
    }
    return null;
  }

  Future<String?> extractTextFromImage(String imagePath) async {
    try {
      final apiKey = _remoteConfig.getString('gemini_api_key');
      if (apiKey.isEmpty) return null;

      final base64Image = base64Encode(await _readImageBytes(imagePath));
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey');

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [{
            "parts": [
              {"text": "Extract all readable text from this image as plain text."},
              {"inline_data": {"mime_type": "image/jpeg", "data": base64Image}}
            ]
          }]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'];
      }
    } catch (e) {
      print("Vision OCR Error: $e");
    }
    return null;
  }

  Future<List<Map<String, dynamic>>?> parseSchedulePerDay(Map<int, String> perDayText) async {
    try {
      final apiKey = _remoteConfig.getString('gemini_api_key');
      if (apiKey.isEmpty) return null;

      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey');

      final prompt = """I have text extracted from a schedule image, organized by day of week.
      Map these into a JSON list of entries.
      Input: $perDayText
      Output Format: {"events": [{"title": "...", "dayOfWeek": 1-7, "startHour": 0-23, "startMinute": 0-59, "endHour": 0-23, "endMinute": 0-59, "description": "..."}]}""";

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [{"parts": [{"text": prompt}]}],
          "generationConfig": {"response_mime_type": "application/json"}
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['candidates'][0]['content']['parts'][0]['text'];
        final decoded = jsonDecode(content);
        final list = decoded['events'] as List?;
        return list?.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print("Per-Day Parse Error: $e");
    }
    return null;
  }

  Future<List<int>> _readImageBytes(String path) async {
    return io.File(path).readAsBytes();
  }
}
