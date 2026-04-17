import 'dart:convert';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:http/http.dart' as http;

enum AppDomain { tasks, calendar, habits, summary, sports, education, unknown }

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

  Future<AiResult> dispatch(String prompt, List<Map<String, dynamic>> history, {String? appData}) async {
    try {
      final apiKey = _remoteConfig.getString('groq_api_key');
      
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
      1. CRUD İşlemleri:
         - 'create' / 'add_event': Yeni öğe oluştur. Zaman belirtilmişse ISO8601 formatında TAM zamanı (YYYY-MM-DDTHH:mm:ss) döndür.
         - 'delete': Mevcut öğeyi sil. (Tekil için 'id', toplu silme için 'ids' listesi gönder).
         - 'update': Mevcut öğeyi güncelle. ('id' ve değişen alanlar).
      2. Kullanıcı "Bugünkü tüm etkinlikleri sil" veya "Hepsini temizle" derse, Context içindeki uygun ID'leri bul ve 'ids' listesi olarak döndür.
      3. Başlık (title) içine saati ekleme.
      4. Zaman Dilimi: Yerel saati kullan, sonuna 'Z' koyma. Kullanıcı "16:00" diyorsa, ISO string'in saati tam 16:00 olmalıdır.

      GÖREV ÖNCELİĞİ (Priority):
      - 'low', 'medium', 'high' değerlerini kullan.
      - Kullanıcı belirtmezse varsayılan 'low' kullan.

      JSON FORMATI:
      {
        "domain": "tasks" | "calendar" | "summary" | "habits",
        "action": "create" | "add_event" | "delete" | "update" | "read",
        "payload": { 
           "domain": "Kullanıcının belirttiği alan adı (Örn: Gym, School, İş)",
           "domainId": "Eğer Context içinde varsa alanın ID'si",
           "title": "...", 
           "dueDate": "ISO8601",
           "startTime": "ISO8601",
           "endTime": "ISO8601",
           "priority": "low" | "medium" | "high"
        },
        "responseText": "Kullanıcıya yapılan işlem hakkında bilgi ver (örn: 'Bugünkü 3 etkinlik silindi.')."
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
}
