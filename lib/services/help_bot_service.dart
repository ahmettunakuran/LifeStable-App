import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:http/http.dart' as http;
import '../core/models/help_bot_response.dart';
import '../core/models/rag_result.dart';
import '../data/knowledge_base/faq_chunks.dart';
import 'embedding_service.dart';

class HelpBotService {
  static final HelpBotService _instance = HelpBotService._internal();
  factory HelpBotService() => _instance;
  HelpBotService._internal();

  final EmbeddingService _embedding = EmbeddingService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const double _confidenceThreshold = 0.75;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Flow:
  ///   0. Local keyword search → reliable offline answer, used as safety net
  ///   1. Check query cache → fast return on hit
  ///   2. Generate embedding + semantic search
  ///   3. If top similarity ≥ threshold → return FAQ answer
  ///   4. Otherwise → Gemini fallback (with local content as backup context)
  ///   5. If Gemini also fails → return local keyword match (never show generic error)
  Future<HelpBotResponse> ask(String userQuestion) async {
    final normalised = userQuestion.trim();

    // 0. Local keyword search — always runs, used as backup if APIs fail
    final localContent = _localKeywordSearch(normalised);

    // 1. Cache hit (hash-based, no embedding needed)
    final cached = await _embedding.checkQueryCache(normalised);
    if (cached != null && cached.isNotEmpty) {
      return HelpBotResponse(
        answer: cached.first.content,
        sourceDocId: cached.first.docId,
        confidenceScore: cached.first.similarity,
        usedCache: true,
        usedFallback: false,
        queryId: _embedding.hashForQuery(normalised),
      );
    }

    // 2. Generate embedding once, reuse for semantic search
    List<double> queryEmbedding;
    List<RagResult> results;
    try {
      queryEmbedding = await _embedding.generateEmbedding(normalised);
      results = await _embedding.semanticSearch(
        normalised,
        topK: 3,
        docType: 'faq',
        precomputedEmbedding: queryEmbedding,
      );
    } catch (e) {
      return await _fallbackResponse(normalised, null,
          localFallback: localContent);
    }

    // 3. Persist to cache without blocking the UI
    if (results.isNotEmpty) {
      unawaited(
        _embedding.saveQueryCache(normalised, queryEmbedding, results),
      );
    }

    if (results.isEmpty) {
      return await _fallbackResponse(normalised, null,
          localFallback: localContent);
    }

    final top = results.first;

    // 4. Confidence gate
    if (top.similarity >= _confidenceThreshold) {
      return HelpBotResponse(
        answer: top.content,
        sourceDocId: top.docId,
        confidenceScore: top.similarity,
        usedCache: false,
        usedFallback: false,
        queryId: _embedding.hashForQuery(normalised),
      );
    }

    return await _fallbackResponse(normalised, top,
        localFallback: localContent);
  }

  /// Records user feedback on a cached query result.
  Future<void> logFeedback(String queryId, bool wasHelpful) async {
    try {
      await _db.collection('query_cache').doc(queryId).update({
        'feedback': wasHelpful ? 'helpful' : 'not_helpful',
        'feedback_at': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Best-effort
    }
  }

  // ── Local keyword search ──────────────────────────────────────────────────

  /// Scans kFaqChunks for the best keyword overlap match.
  /// Only considers keywords ≥ 3 characters to avoid false positives from
  /// common short words (e.g. "a", "do", "i").
  /// Requires at least 2 matching tokens to return a result.
  String? _localKeywordSearch(String query) {
    final lower = query.toLowerCase();

    Map<String, dynamic>? bestChunk;
    int bestScore = 1; // must beat 1, so effectively need ≥ 2 matches

    for (final chunk in kFaqChunks) {
      final indexes = (chunk['indexes'] as List).cast<String>();
      int score = 0;
      for (final keyword in indexes) {
        final kw = keyword.toLowerCase();
        if (kw.length >= 3 && lower.contains(kw)) {
          score++;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        bestChunk = chunk;
      }
    }

    return bestChunk?['content'] as String?;
  }

  // ── Fallback: Gemini generative response ──────────────────────────────────

  Future<HelpBotResponse> _fallbackResponse(
    String question,
    RagResult? contextDoc, {
    String? localFallback,
  }) async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      final apiKey = rc.getString('rag_gemini_api_key').isNotEmpty
          ? rc.getString('rag_gemini_api_key')
          : rc.getString('gemini_api_key');

      if (apiKey.isEmpty) return _localOrError(localFallback, contextDoc);

      // Prefer RAG context, fall back to local keyword content as context
      final contextContent =
          contextDoc?.content ?? localFallback ?? '';
      final contextClause = contextContent.isNotEmpty
          ? 'Use this related information as context:\n"$contextContent"\n\n'
          : '';

      const appKnowledge = '''
LifeStable is a life-management app for students and professionals. Key features:

DASHBOARD (Home): Shows all domains as cards. Tap the + button at the TOP of the Dashboard to create a new domain. Tap any domain card to open its Kanban board.

DOMAINS: Personal workspaces grouping tasks and notes (e.g. "University", "Work", "Personal"). Create with + at top of Dashboard or long-press a card. Edit by long-pressing → Edit. Delete by long-pressing → Delete.

TASKS: Inside each domain, tap + to create a task with title, priority (Low/Medium/High), and due date. Kanban board has columns: To Do / In Progress / Done. Drag cards to change status. Assign to team members by opening the task → Assign.

HABIT TRACKER (Habit tab): Tap + to add a habit. Mark complete daily by tapping the circle next to it. Streak = consecutive days marked complete. Missing a day resets streak to 0. Streaks earn XP points. Long streaks = more XP per day. Pause a habit (swipe left → Pause) to avoid streak breaks during holidays.

TEAMS (Team tab): Create a team or join with a 6-character invite code. Roles: Owner (full control), Admin (manage members), Member (create/update tasks). Each team creates a mirror domain in your workspace. Share invite code from Team Detail → copy icon. Leave via Team Detail → Leave Team.

CALENDAR (Calendar tab): Create events manually (tap date → +). Sync Google Calendar via Settings → Calendar Sync → Connect Google Calendar. Import class schedules by sending a timetable photo to LifeStable AI (OCR). Team task due dates auto-appear as calendar events for all members.

LIFESTABLE AI (AI tab): Understands natural language in English and Turkish. Can create/edit/delete tasks and events. Voice input via microphone icon. Image upload for OCR import. Commands: "Add task X by Friday", "Summarize my day", "Find a free slot this week".

LOCATION ALERTS: Set geofence reminders from Sidebar → Alerts. Trigger on Arrival, Departure, or both. Set "Do not remind after" time to avoid late-night alerts.

SETTINGS (bottom of Sidebar): Change profile, language, notification preferences, connect Google Calendar.

OFFLINE MODE: Tasks and domains cached locally — work without internet. Syncs when connection returns. Calendar, team data, and AI require internet.

XP & LEVELS: Earn XP by completing tasks and maintaining habit streaks. Accumulate XP to level up. Shown on profile.
''';

      final prompt =
          '${contextClause}You are the App Assistant for LifeStable. '
          'Use the app knowledge below to answer the user question accurately. '
          'Detect the language of the question and respond in the SAME language '
          '(Turkish if Turkish, English if English). '
          'Give a clear, specific, step-by-step answer in 2-5 sentences. '
          'If the answer involves navigation, describe exactly where to tap.\n\n'
          'APP KNOWLEDGE:\n$appKnowledge\n\n'
          'USER QUESTION: "$question"';

      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/'
        'gemini-2.5-flash:generateContent?key=$apiKey',
      );

      final response = await http
          .post(
            uri,
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
                'temperature': 0.4,
                'maxOutputTokens': 512,
              },
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final answer =
            data['candidates'][0]['content']['parts'][0]['text'] as String;
        return HelpBotResponse(
          answer: answer,
          sourceDocId: contextDoc?.docId ?? '',
          confidenceScore: contextDoc?.similarity ?? 0.0,
          usedCache: false,
          usedFallback: true,
        );
      }
    } catch (_) {
      // Gemini unavailable → fall through to local content
    }
    return _localOrError(localFallback, contextDoc);
  }

  /// Returns local FAQ content if available, otherwise the generic error.
  HelpBotResponse _localOrError(
      String? localContent, RagResult? contextDoc) {
    if (localContent != null && localContent.isNotEmpty) {
      return HelpBotResponse(
        answer: localContent,
        sourceDocId: 'local_keyword',
        confidenceScore: 0.6,
        usedCache: false,
        usedFallback: false,
      );
    }
    return HelpBotResponse(
      answer:
          "I couldn't find a specific answer. You can explore the app's "
          'features from the Dashboard or ask the AI assistant directly.\n\n'
          'Türkçe: Belirli bir cevap bulunamadı. Uygulamanın özelliklerini '
          'Ana Ekran\'dan keşfedebilir ya da yapay zeka asistanına sorabilirsiniz.',
      sourceDocId: contextDoc?.docId ?? '',
      confidenceScore: 0.0,
      usedCache: false,
      usedFallback: true,
    );
  }
}
