import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:http/http.dart' as http;
import '../core/models/help_bot_response.dart';
import '../core/models/rag_result.dart';
import '../data/knowledge_base/faq_chunks.dart';
import 'embedding_service.dart';
import 'faq_seeder.dart';

/// Conversation turn passed to [HelpBotService.ask] for context-aware answers.
class ConversationTurn {
  final String question;
  final String answer;
  const ConversationTurn({required this.question, required this.answer});
}

class HelpBotService {
  static final HelpBotService _instance = HelpBotService._internal();
  factory HelpBotService() => _instance;
  HelpBotService._internal() {
    // Kick off FAQ seeding in the background whenever this service is first used.
    unawaited(FaqSeeder().seedIfNeeded());
  }

  final EmbeddingService _embedding = EmbeddingService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const double _confidenceThreshold = 0.72;

  // ── Comprehensive app knowledge (injected into every Gemini call) ─────────

  static const _appKnowledge = '''
LifeStable is a life-management app for students and professionals.

DASHBOARD (Home screen):
- Shows all your Domains as tappable cards.
- Tap the + button at the TOP of the Dashboard to create a new Domain.
- Tap any domain card to open its Kanban task board.
- Top section shows today's task summary and close deadlines (within 72 h).

DOMAINS (personal workspaces):
- Group tasks and notes (e.g. "University", "Work", "Personal").
- Create: tap + at the top of the Dashboard, OR long-press a card → New Domain.
- Edit: long-press a domain card → Edit (change name, icon, color, description).
- Delete: long-press → Delete (removes all tasks inside).
- Team mirror domain: auto-created when you join/create a team.

TASKS:
- Open a domain → tap + inside → fill title, priority (Low/Medium/High), due date → Save.
- Kanban columns: To Do / In Progress / Done. Drag cards to change status.
- Assign to team member: open task → Assign → pick member.
- Edit/delete: tap task card → Edit icon or trash icon.
- AI shortcut: tell LifeStable AI "Add task [title] by [date]".

HABIT TRACKER (Habit tab in bottom navigation):
- Add habit: tap + → enter name, frequency, optional reminder → Save.
- Mark complete: tap the circle next to the habit name each day.
- Streak: consecutive days marked complete. Missing ONE day resets to 0.
- Longer streaks = more XP per day. XP fills your level bar on Profile.
- Pause habit: swipe left on habit card → Pause (streak protected during pause).
- Health guardrail: app suggests fewer habits if you add too many.

TEAMS (Team tab):
- Create: tap Create Team → enter name, objective, color → become Owner.
- Join: tap "Join with Code" → enter the 6-character invite code → Join.
- Invite code: Team Detail → copy icon next to code → share via messaging app.
- Roles: Owner (full control), Admin (manage members), Member (create tasks).
- Leave: Team Detail → scroll down → Leave Team (transfer ownership first if sole owner).
- Team Kanban: shared board visible to all members; changes sync in real time.

CALENDAR (Calendar tab):
- Create event manually: tap date → + → fill title, start/end time → Save.
- Sync Google Calendar: Settings (Sidebar bottom) → Calendar Sync → Connect → authorize.
- Import class schedule: send a timetable photo to LifeStable AI → OCR reads it → preview → confirm.
- Team task due dates automatically appear as calendar events for all members.

LIFESTABLE AI (AI tab — the action bot):
- Natural language in English and Turkish.
- Create/edit/delete tasks and events.
- Voice input: tap microphone icon.
- Image upload: tap image icon → choose timetable photo for OCR import.
- Find free time: "Find me a free slot this week for 2 hours".
- Summarize day: "Summarize my day".

APP ASSISTANT (this bot):
- Answers questions about how LifeStable works.
- Works offline (local knowledge base).
- Responds in the same language as your question (English or Turkish).

LOCATION ALERTS (Sidebar → Alerts):
- Set geofence reminders triggered on Arrival, Departure, or both.
- Set "Do not remind after [time]" to avoid late-night alerts.
- Requires "Always On" location permission (iOS: Settings → LifeStable → Location → Always; Android: Allow all the time).

SETTINGS (bottom of Sidebar):
- Change display name, profile picture, language.
- Connect Google Calendar.
- Manage notification preferences and quiet hours.

OFFLINE MODE:
- Tasks and domains are cached locally — viewable and creatable without internet.
- Syncs automatically when internet returns.
- Calendar, team data, and AI features require internet.

XP & LEVELS:
- Earn XP by completing tasks and maintaining habit streaks.
- Streak multiplier: longer streak = more XP per completion.
- Accumulate XP to level up. Level shown on your profile.
''';

  // ── Follow-up suggestions by topic ────────────────────────────────────────

  static const _followUps = <String, List<String>>{
    'domain_management': [
      'How do I edit a domain?',
      'How do I delete a domain?',
      'What is a team mirror domain?',
      'Alanı nasıl düzenlerim?',
    ],
    'task_creation': [
      'How do I set task priority?',
      'How do I assign a task to a team member?',
      'How do I edit or delete a task?',
      'Görev önceliği nasıl ayarlanır?',
    ],
    'habit_tracker': [
      'How does the habit streak work?',
      'How do I pause a habit?',
      'How do I earn XP from habits?',
      'Alışkanlık serisi nasıl çalışır?',
    ],
    'habit_tracker_streak': [
      'How do I create a habit?',
      'How do I pause a habit to protect my streak?',
      'How do XP points and levels work?',
      'Alışkanlık nasıl oluşturulur?',
    ],
    'team_management': [
      'How do I share the team invite code?',
      'What are team roles?',
      'How do I leave a team?',
      'Takım davet kodunu nasıl paylaşırım?',
    ],
    'calendar': [
      'How do I sync Google Calendar?',
      'How do I import a class schedule?',
      'How do team deadlines appear in my calendar?',
      'Google Takvim nasıl senkronize edilir?',
    ],
    'ai_assistant': [
      'How do I use voice input with the AI?',
      'How do I create a task with the AI?',
      'How do I find free time in my schedule?',
      'Yapay zeka ile görev oluşturabilir miyim?',
    ],
    'location_alerts': [
      'What is the difference between arrival and departure?',
      'Why does the app need "Always On" location?',
      'Can I limit when reminders fire?',
      'Konum iznini neden vermem gerekiyor?',
    ],
    'offline_mode': [
      'Which features require internet?',
      'Does offline mode affect teams?',
      'İnternetsiz görev oluşturabilir miyim?',
    ],
    'dashboard': [
      'How do I create a domain?',
      'What is the Close Deadlines card?',
      'How do I navigate the app?',
      'Alan nasıl oluşturulur?',
    ],
    'settings': [
      'How do I change the app language?',
      'How do I connect Google Calendar?',
      'How do I manage notifications?',
      'Uygulama dili nasıl değiştirilir?',
    ],
    'onboarding': [
      'How do I create a domain?',
      'How do I add tasks?',
      'What are XP and levels?',
      'Alan nasıl oluşturulur?',
    ],
    'notifications': [
      'How do I set quiet hours?',
      'Can I turn off habit reminders?',
      'Why am I not getting notifications?',
      'Sessiz saatler nasıl ayarlanır?',
    ],
  };

  // ── Language detection ────────────────────────────────────────────────────

  /// Returns true if the query appears to be Turkish.
  bool _isTurkish(String text) {
    if (RegExp(r'[ğüşıöçĞÜŞİÖÇ]').hasMatch(text)) return true;
    final trWords = RegExp(
        r'\b(nasıl|nedir|neden|nereye|hangi|oluştur|görev|alan|takım|uygulama|'
        r'çalış|çevrimdışı|katıl|seri|alışkanlık|takvim|bildir|ayar|'
        r'bilgi|özellik|özetle|bul|ekle|sil|düzenle)\b',
        caseSensitive: false);
    return trWords.hasMatch(text);
  }

  // ── Local keyword search ──────────────────────────────────────────────────

  /// Returns the best matching FAQ chunk (or null) based on keyword overlap.
  /// Only considers keywords ≥ 3 chars. Requires ≥ 2 keyword hits.
  Map<String, dynamic>? _localKeywordChunk(String query) {
    final lower = query.toLowerCase();
    Map<String, dynamic>? bestChunk;
    int bestScore = 1;

    for (final chunk in kFaqChunks) {
      final indexes = (chunk['indexes'] as List).cast<String>();
      int score = 0;
      for (final kw in indexes) {
        if (kw.length >= 3 && lower.contains(kw.toLowerCase())) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        bestChunk = chunk;
      }
    }
    return bestChunk;
  }

  // ── Follow-up suggestions ────────────────────────────────────────────────

  List<String> _getFollowUps(String? sourceKey, bool isTurkish) {
    final list = _followUps[sourceKey] ?? [];
    if (list.isEmpty) return [];

    // Return 3 suggestions: pick language-appropriate ones
    if (isTurkish) {
      // Prefer TR suggestions (last item in each list), then EN
      final tr = list.where(_isTurkish).take(2).toList();
      final en = list.where((s) => !_isTurkish(s)).take(3 - tr.length).toList();
      return [...tr, ...en].take(3).toList();
    } else {
      // Prefer EN suggestions, skip TR ones
      return list.where((s) => !_isTurkish(s)).take(3).toList();
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Answers a help question with full RAG pipeline + language-aware Gemini.
  ///
  /// [history] — last 2-3 conversation turns for context-aware follow-ups.
  Future<HelpBotResponse> ask(
    String userQuestion, {
    List<ConversationTurn> history = const [],
  }) async {
    final query = userQuestion.trim();
    final turkish = _isTurkish(query);

    // 0. Local keyword match (instant, offline-safe)
    final localChunk = _localKeywordChunk(query);
    final localContent = localChunk?['content'] as String?;
    final localSourceKey = localChunk?['source_key'] as String?;

    // 1. Firestore cache check
    final cached = await _embedding.checkQueryCache(query);
    if (cached != null && cached.isNotEmpty) {
      final followUps = _getFollowUps(cached.first.sourceKey, turkish);
      return HelpBotResponse(
        answer: cached.first.content,
        sourceDocId: cached.first.docId,
        confidenceScore: cached.first.similarity,
        usedCache: true,
        usedFallback: false,
        queryId: _embedding.hashForQuery(query),
        followUpSuggestions: followUps,
      );
    }

    // 2. Generate embedding + semantic search
    List<double> queryEmbedding;
    List<RagResult> results;
    try {
      queryEmbedding = await _embedding.generateEmbedding(query);
      results = await _embedding.semanticSearch(
        query,
        topK: 3,
        docType: 'faq',
        precomputedEmbedding: queryEmbedding,
      );
    } catch (_) {
      // Embedding/search failed → go straight to Gemini with local context
      return await _geminiFormat(
        query: query,
        isTurkish: turkish,
        contextContent: localContent,
        sourceKey: localSourceKey,
        history: history,
      );
    }

    // 3. Save to cache (non-blocking)
    if (results.isNotEmpty) {
      unawaited(_embedding.saveQueryCache(query, queryEmbedding, results));
    }

    final top = results.isEmpty ? null : results.first;

    // 4. High-confidence RAG hit → still format through Gemini for clean output
    if (top != null && top.similarity >= _confidenceThreshold) {
      return await _geminiFormat(
        query: query,
        isTurkish: turkish,
        contextContent: top.content,
        sourceKey: top.sourceKey,
        history: history,
        docId: top.docId,
        confidence: top.similarity,
      );
    }

    // 5. Low-confidence → Gemini with best available context
    final bestContext = top?.content ?? localContent;
    final bestSourceKey = top?.sourceKey ?? localSourceKey;
    return await _geminiFormat(
      query: query,
      isTurkish: turkish,
      contextContent: bestContext,
      sourceKey: bestSourceKey,
      history: history,
    );
  }

  // ── Gemini formatting ─────────────────────────────────────────────────────

  Future<HelpBotResponse> _geminiFormat({
    required String query,
    required bool isTurkish,
    String? contextContent,
    String? sourceKey,
    List<ConversationTurn> history = const [],
    String? docId,
    double confidence = 0.0,
  }) async {
    final followUps = _getFollowUps(sourceKey, isTurkish);

    try {
      final rc = FirebaseRemoteConfig.instance;
      final apiKey = rc.getString('rag_gemini_api_key').isNotEmpty
          ? rc.getString('rag_gemini_api_key')
          : rc.getString('gemini_api_key');

      if (apiKey.isEmpty) {
        return _localFallback(contextContent, sourceKey, isTurkish, followUps);
      }

      final lang = isTurkish ? 'Turkish' : 'English';
      final otherLang = isTurkish ? 'English' : 'Turkish';

      // Build conversation history block
      final historyBlock = history.isNotEmpty
          ? 'Previous conversation context:\n' +
              history
                  .map((t) => 'User: ${t.question}\nAssistant: ${t.answer}')
                  .join('\n')
          : '';

      // Build context block from FAQ knowledge
      final contextBlock = contextContent != null && contextContent.isNotEmpty
          ? 'Relevant FAQ content:\n"$contextContent"\n'
          : '';

      final prompt = '''You are the App Assistant for LifeStable — a friendly, precise help bot.

CRITICAL LANGUAGE RULE: Respond EXCLUSIVELY in $lang.
Do NOT write any $otherLang text in your response — not even a single word.

$historyBlock

$contextBlock
APP KNOWLEDGE:
$_appKnowledge

USER QUESTION (in $lang): "$query"

Instructions:
- Answer in $lang ONLY.
- Be specific and actionable — tell the user exactly where to tap.
- Use numbered steps when navigation is involved (1. Go to... 2. Tap...).
- Keep it concise: 2-5 sentences or up to 5 short steps.
- Do NOT translate your answer. Do NOT add any $otherLang text.''';

      final response = await http
          .post(
            Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/'
              'gemini-2.5-flash:generateContent?key=$apiKey',
            ),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': prompt}
                  ],
                }
              ],
              'generationConfig': {
                'temperature': 0.3,
                'maxOutputTokens': 768,
              },
            }),
          )
          .timeout(const Duration(seconds: 18));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final parts = candidates[0]['content']['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            final answer = (parts[0]['text'] as String).trim();
            if (answer.isNotEmpty) {
              return HelpBotResponse(
                answer: answer,
                sourceDocId: docId ?? sourceKey ?? '',
                confidenceScore: confidence,
                usedCache: false,
                usedFallback: true,
                followUpSuggestions: followUps,
              );
            }
          }
        }
      }
    } catch (_) {
      // Gemini unavailable → use local content
    }

    return _localFallback(contextContent, sourceKey, isTurkish, followUps);
  }

  // ── Local fallback (never shows generic error for known topics) ───────────

  HelpBotResponse _localFallback(
    String? localContent,
    String? sourceKey,
    bool isTurkish,
    List<String> followUps,
  ) {
    if (localContent != null && localContent.isNotEmpty) {
      // The local content is bilingual. Extract the relevant language half.
      final answer = _extractLanguage(localContent, isTurkish);
      return HelpBotResponse(
        answer: answer,
        sourceDocId: sourceKey ?? 'local',
        confidenceScore: 0.6,
        usedCache: false,
        usedFallback: false,
        followUpSuggestions: followUps,
      );
    }

    // Truly unknown topic
    return HelpBotResponse(
      answer: isTurkish
          ? 'Bu konuda şu an net bir bilgim yok. Dashboard\'dan uygulamayı '
              'keşfedebilir ya da LifeStable AI\'ya sorabilirsiniz.'
          : "I don't have a specific answer for that yet. You can explore "
              'the app from the Dashboard or ask LifeStable AI directly.',
      sourceDocId: '',
      confidenceScore: 0.0,
      usedCache: false,
      usedFallback: true,
      followUpSuggestions: isTurkish
          ? ['Alan nasıl oluşturulur?', 'Alışkanlık serisi nasıl çalışır?', 'Google Takvim nasıl bağlanır?']
          : ['How do I create a domain?', 'How does the habit streak work?', 'How do I sync Google Calendar?'],
    );
  }

  /// Extracts the language-appropriate half from bilingual FAQ content.
  ///
  /// English content comes first; Turkish content follows. The split heuristic
  /// looks for sentences that contain Turkish-specific characters or words.
  String _extractLanguage(String content, bool wantTurkish) {
    // Split into sentences on period + space / newline boundaries
    final sentences = content
        .replaceAll(RegExp(r'\.(\s)', caseSensitive: false), '.\n')
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final trSentences = <String>[];
    final enSentences = <String>[];

    for (final s in sentences) {
      if (_isTurkish(s)) {
        trSentences.add(s);
      } else {
        enSentences.add(s);
      }
    }

    final target = wantTurkish ? trSentences : enSentences;
    final fallback = wantTurkish ? enSentences : trSentences;

    if (target.isNotEmpty) return target.join(' ');
    if (fallback.isNotEmpty) return fallback.join(' ');
    return content; // last resort
  }

  // ── Feedback ──────────────────────────────────────────────────────────────

  Future<void> logFeedback(String queryId, bool wasHelpful) async {
    try {
      await _db.collection('query_cache').doc(queryId).update({
        'feedback': wasHelpful ? 'helpful' : 'not_helpful',
        'feedback_at': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
