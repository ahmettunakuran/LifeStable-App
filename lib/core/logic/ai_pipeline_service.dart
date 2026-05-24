import 'dart:async';
import 'dart:convert';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:http/http.dart' as http;

import '../../features/billing/data/usage_tracker.dart';
import '../../features/billing/domain/plan_catalog.dart';

enum AppDomain { tasks, calendar, habits, domains, summary, sports, education, unknown }

enum AiProvider { groq, gemini, none }

class AiResult {
  final AppDomain domain;
  final String action;
  final Map<String, dynamic> payload;
  final String responseText;
  final AiProvider provider;
  final bool degraded;

  AiResult({
    required this.domain,
    required this.action,
    required this.payload,
    required this.responseText,
    this.provider = AiProvider.groq,
    this.degraded = false,
  });
}

class AiPipelineService {
  static const _requestTimeout = Duration(seconds: 12);

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  Future<AiResult> dispatch(String prompt, List<Map<String, dynamic>> history, {String? appData}) async {
    try {
      await UsageTracker.instance.consume(BillableFeature.aiAssistantPrompt);
    } catch (e) {
      print('UsageTracker error: $e');
    }

    final systemInstruction = _buildSystemInstruction(appData);

    // Prioritize Gemini: try gemini_api_key first
    final geminiKey = _remoteConfig.getString('gemini_api_key');
    if (geminiKey.isNotEmpty) {
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          final result = await _callGemini(geminiKey, systemInstruction, history, prompt);
          if (result != null) return result;
        } catch (e) {
          print("Gemini attempt $attempt failed: $e");
        }
      }
    } else {
      print("gemini_api_key Remote Config'de bulunamadı; Groq fallback'e geçiliyor.");
    }

    // Fallback to Groq keys
    final groqKeys = [
      _remoteConfig.getString('groq_api_key'),
      _remoteConfig.getString('groq_api_key2'),
      _remoteConfig.getString('groq_api_key3'),
    ].where((key) => key.isNotEmpty).toList();

    for (final groqKey in groqKeys) {
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          final result = await _callGroq(groqKey, systemInstruction, history, prompt);
          if (result != null) return result;
        } catch (e) {
          print("Groq attempt $attempt failed with key: ${groqKey.substring(0, 10.clamp(0, groqKey.length))}...: $e");
        }
      }
    }

    return AiResult(
      domain: AppDomain.unknown,
      action: 'none',
      payload: const {},
      responseText:
          'AI servislerine şu an ulaşılamıyor. Görev veya etkinliğini elle ekleyebilirsin; bağlantı düzelince tekrar deneyelim.',
      provider: AiProvider.none,
      degraded: true,
    );
  }


  Future<AiResult?> _callGroq(
    String apiKey,
    String systemInstruction,
    List<Map<String, dynamic>> history,
    String prompt,
  ) async {
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    final response = await http
        .post(
          url,
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $apiKey",
          },
          body: jsonEncode({
            "model": "llama-3.3-70b-versatile",
            "messages": [
              {"role": "system", "content": systemInstruction},
              ...history.map((m) => {
                    "role": m['role'] == 'model' ? 'assistant' : 'user',
                    "content": m['text'],
                  }),
              {"role": "user", "content": prompt},
            ],
            "response_format": {"type": "json_object"},
            "temperature": 0.1,
          }),
        )
        .timeout(_requestTimeout);

    if (response.statusCode >= 500 || response.statusCode == 408 || response.statusCode == 429) {
      throw http.ClientException('Groq HTTP ${response.statusCode}');
    }
    if (response.statusCode != 200) {
      print("Groq non-retryable status ${response.statusCode}: ${response.body}");
      return null;
    }

    final data = jsonDecode(response.body);
    final content = data['choices'][0]['message']['content'];
    return _parseJsonContent(content, AiProvider.groq);
  }

  Future<AiResult?> _callGemini(
    String apiKey,
    String systemInstruction,
    List<Map<String, dynamic>> history,
    String prompt,
  ) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
    );

    final contents = [
      ...history.map((m) => {
            "role": m['role'] == 'model' ? 'model' : 'user',
            "parts": [
              {"text": m['text']}
            ]
          }),
      {
        "role": "user",
        "parts": [
          {"text": prompt}
        ]
      }
    ];

    final response = await http
        .post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "systemInstruction": {
              "parts": [
                {"text": systemInstruction}
              ]
            },
            "contents": contents,
            "generationConfig": {
              "temperature": 0.1,
              "responseMimeType": "application/json",
            }
          }),
        )
        .timeout(_requestTimeout);

    if (response.statusCode != 200) {
      print("Gemini status ${response.statusCode}: ${response.body}");
      return null;
    }

    final data = jsonDecode(response.body);
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return null;
    final parts = candidates.first['content']?['parts'] as List?;
    if (parts == null || parts.isEmpty) return null;
    final content = parts.first['text']?.toString() ?? '';
    if (content.isEmpty) return null;
    return _parseJsonContent(content, AiProvider.gemini);
  }


  AiResult? _parseJsonContent(String content, AiProvider provider) {
    try {
      final decoded = jsonDecode(content);
      Map<String, dynamic> result;
      if (decoded is List && decoded.isNotEmpty) {
        result = decoded.first as Map<String, dynamic>;
      } else if (decoded is Map) {
        result = decoded as Map<String, dynamic>;
      } else {
        return null;
      }
      return AiResult(
        domain: _parseDomain(result['domain']),
        action: result['action'] ?? 'none',
        payload: (result['payload'] as Map?)?.cast<String, dynamic>() ?? {},
        responseText: result['responseText'] ?? 'İşlem tamam.',
        provider: provider,
        degraded: provider != AiProvider.gemini,
      );
    } catch (e) {
      print('JSON parse failed for $provider: $e — raw: $content');
      return null;
    }
  }

  String _buildSystemInstruction(String? appData) {
    final now = DateTime.now();
    return """
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
         - KULLANICI TERCİHLERİNE UYU: Sadece çalışma saatleri içinde slot öner, uyku saatlerini ASLA önerme.
         - Geçmişte kabul edilen popüler saatlere yakın slotları üste sırala (kullanıcı bu saatlerde daha verimli demektir).
         - En fazla 3 slot öner; çok fazla seçenek karar yorgunluğu yaratır.

      4. CRUD İşlemleri:
         - Kullanıcı "Bugünkü tüm etkinlikleri sil" veya "Hepsini temizle" derse, Context içindeki uygun ID'leri bul ve 'ids' listesi olarak döndür.
         - Başlık (title) içine saati ekleme.
         - Zaman Dilimi: Yerel saati kullan, sonuna 'Z' koyma. Kullanıcı "16:00" diyorsa, ISO string'in saati tam 16:00 olmalıdır.

      5. Alışkanlıklar (Habits):
         - Kullanıcı "her gün X yapayım", "X alışkanlığı ekle", "günlük X" gibi tekrarlayan rutinler için domain='habits' ve action='create' kullan.
         - Tek seferlik görevler ile karıştırma: tek seferlik ise 'tasks' alanına git.
         - 'payload' içinde 'title' (alışkanlık adı) ve 'domain' (örn: Health, School) belirt. Saat/tarih GEREKMEZ.
         - Silme için domain='habits', action='delete', 'id' veya 'title' (kısmi eşleşme yeterli) gönder.

      6.5 Haftalık Tekrarlayan Program (Recurring Schedule Import):
         - Kullanıcı bir ders programı / haftalık ders saatleri / 3+ tekrarlayan etkinlik içeren bir resim yüklediğinde, BU dersleri DOĞRUDAN takvime EKLEME (tarih belirsiz olabilir, geçmiş hafta olabilir).
         - Bunun yerine domain='calendar' ve action='ask_schedule_scope' kullan.
         - 'payload.entries' alanında HER tekrarlayan ders için bir nesne döndür:
            {"title": "Ders adı (kod ve sınıf bilgisi dahil)",
             "description": "(opsiyonel)",
             "dayOfWeek": 1-7 (1=Pazartesi, 7=Pazar, ISO),
             "startHour": 0-23, "startMinute": 0-59,
             "endHour": 0-23, "endMinute": 0-59}
         - Sadece günü ve saati belirt — TARIH koyma. Tarih kullanıcı seçimine göre cubit tarafından hesaplanacak.
         - 'responseText' kısa olsun: "5 tekrarlayan ders buldum. Hangi haftalara ekleyim?"
         - Bu kural SADECE 3+ tekrarlayan etkinlik için. Tek seferlik etkinlikler için normal 'create' kullan.
         - Eğer kullanıcının notunda açık bir scope varsa ("haftaya ekle", "sadece bu hafta", "tüm dönem") yine de ask_schedule_scope kullan; cubit kullanıcı tercihini kullanacak.

      7. Yaşam Alanları (Life Domains / Areas):
         - Kullanıcı "X domain ekle", "X alanı oluştur", "create X domain", "yeni kategori X" gibi YENİ BİR ALAN/KATEGORİ oluşturmak istediğinde domain='domains' ve action='create' kullan.
         - ÖNEMLİ: "domain" sözcüğü TEK BAŞINA bir alışkanlık (habit) DEĞİLDİR. "X domain" denirse bu yeni bir yaşam alanı (life area) oluşturmaktır.
         - Örnekler: "create school domain", "yeni Health alanı ekle", "Spor domaini oluştur" → domain='domains', action='create', payload.title='School' / 'Health' / 'Spor'
         - Habits'ten farkı: Habits tekrarlayan eylemdir ("her gün spor yap"). Domains organizasyon kategorisidir ("Spor alanı oluştur").
         - 'payload' içinde sadece 'title' (alan adı) belirt. Saat/tarih GEREKMEZ.
         - DUPLİKAT KONTROLÜ: KULLANICI ALANLARI (DOMAINS) listesini KESINLIKLE incele. Aynı isimli (büyük/küçük harf duyarsız) bir alan zaten varsa create ETME. Bunun yerine action='read' döndür ve responseText içinde "{X} alanı zaten mevcut, yeni bir tane oluşturmadım." diye bilgi ver.

      GÖREV ÖNCELİĞİ (Priority):
      - 'low', 'medium', 'high' değerlerini kullan.
      - Kullanıcı belirtmezse varsayılan 'low' kullan.

      JSON FORMATI:
      {
        "domain": "tasks" | "calendar" | "summary" | "habits" | "domains",
        "action": "create" | "add_event" | "delete" | "update" | "read" | "find_gap" | "create_batch" | "ask_schedule_scope",
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
    final List<String> keys = [
      _remoteConfig.getString(configKey),
      _remoteConfig.getString('groq_api_key'),
      _remoteConfig.getString('groq_api_key2'),
      _remoteConfig.getString('groq_api_key3'),
    ].where((k) => k.isNotEmpty).toSet().toList();

    for (final apiKey in keys) {
      try {
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
        } else if (response.statusCode == 429) {
          print("[fetchDailyInsights] Groq API 429 (Rate Limit) on key ${apiKey.substring(0, 10.clamp(0, apiKey.length))}..., trying next...");
          continue;
        } else {
          print("[fetchDailyInsights] Groq API HATA: ${response.statusCode} | body=${response.body}");
        }
      } catch (e) {
        print("[fetchDailyInsights] Error: $e");
      }
    }
    return null;
  }
}
