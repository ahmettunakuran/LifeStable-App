import 'dart:convert';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:http/http.dart' as http;
import '../localization/app_localizations.dart';

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

  Future<AiResult> dispatch(String prompt, List<Map<String, dynamic>> history, {String? appData, bool useSecondaryKey = false}) async {
    try {
      final key1 = _remoteConfig.getString('groq_api_key');
      final key2 = _remoteConfig.getString('groq_api_key2');
      
      String apiKey = key1;
      if (useSecondaryKey && key2.isNotEmpty) {
        apiKey = key2;
      } else if (key1.isEmpty && key2.isNotEmpty) {
        apiKey = key2;
      }
      
      if (apiKey.isEmpty) {
        return AiResult(
          domain: AppDomain.unknown,
          action: 'none',
          payload: {},
          responseText: S.of('ai_config_error'),
        );
      }
          
      final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

      final now = DateTime.now();
      
      final systemInstruction = """
      Sen LifeStable asistanısın. 24 saatlik (23:00, 21:00) dijital saat sistemini kullan.
      GÜNCEL ZAMAN (ISO): ${now.toIso8601String()}
      BUGÜN: ${_getWeekday(now.weekday)}
      DİL: ${localeNotifier.value.languageCode}

      ÖNEMLİ: Kullanıcıya yanıt verirken ${localeNotifier.value.languageCode == 'tr' ? 'TÜRKÇE' : 'İNGİLİZCE'} konuş.

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
          "model": "llama-3.1-8b-instant",
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
          responseText: (result['responseText'] is List)
              ? (result['responseText'] as List).join('\n')
              : (result['responseText']?.toString() ?? S.of('ai_default_response')),
        );
      } else {
        print("API ERROR: " + response.statusCode.toString() + " - " + response.body);
      }
    } catch (e) {
      print("Pipeline Error: $e");
    }
    return AiResult(
      domain: AppDomain.unknown,
      action: 'none',
      payload: {},
      responseText: S.of('ai_error_generic'),
    );
  }

  AppDomain _parseDomain(String? domain) {
    return AppDomain.values.firstWhere((e) => e.name == domain, orElse: () => AppDomain.unknown);
  }

  String _getWeekday(int day) {
    const days = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
    return days[day - 1];
  }
}
