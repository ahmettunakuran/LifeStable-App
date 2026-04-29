import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:http/http.dart' as http;
import '../core/models/help_bot_response.dart';
import '../core/models/rag_result.dart';
import 'embedding_service.dart';

class HelpBotService {
  static final HelpBotService _instance = HelpBotService._internal();
  factory HelpBotService() => _instance;
  HelpBotService._internal();

  final EmbeddingService _embedding = EmbeddingService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Minimum cosine similarity to return an FAQ answer without falling back.
  static const double _confidenceThreshold = 0.75;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Answers a user help question using semantic FAQ retrieval.
  ///
  /// Flow:
  ///   1. Check query cache → fast return on hit
  ///   2. Generate embedding → semantic search against doc_embeddings
  ///   3. If top result similarity ≥ threshold → return FAQ answer
  ///   4. Otherwise → fall back to generative Gemini response
  Future<HelpBotResponse> ask(String userQuestion) async {
    final normalised = userQuestion.trim();

    // 1. Cache hit
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

    // 2. Semantic search
    List<RagResult> results;
    List<double> queryEmbedding;
    try {
      queryEmbedding = await _embedding.generateEmbedding(normalised);
      results = await _embedding.semanticSearch(
        normalised,
        topK: 3,
        docType: 'faq',
      );
    } catch (e) {
      return await _fallbackResponse(normalised, null);
    }

    // 3. Save to cache (non-blocking)
    if (results.isNotEmpty) {
      _embedding
          .saveQueryCache(normalised, queryEmbedding, results)
          .catchError((_) => null);
    }

    if (results.isEmpty) {
      return await _fallbackResponse(normalised, null);
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

    return await _fallbackResponse(normalised, top);
  }

  /// Records user feedback on a cached query result.
  Future<void> logFeedback(String queryId, bool wasHelpful) async {
    try {
      await _db.collection('query_cache').doc(queryId).update({
        'feedback': wasHelpful ? 'helpful' : 'not_helpful',
        'feedback_at': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Feedback logging is best-effort
    }
  }

  // ── Fallback: generative Gemini response ──────────────────────────────────

  Future<HelpBotResponse> _fallbackResponse(
    String question,
    RagResult? contextDoc,
  ) async {
    try {
      final apiKey =
          FirebaseRemoteConfig.instance.getString('gemini_api_key');
      if (apiKey.isEmpty) {
        return _errorResponse(contextDoc);
      }

      final contextClause = contextDoc != null
          ? 'Use this related information as context:\n"${contextDoc.content}"\n\n'
          : '';

      final prompt = '${contextClause}You are the help assistant for '
          'LifeStable, a life-management app for students. Answer the '
          'following user question concisely in 2-4 sentences:\n\n'
          '"$question"';

      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/'
        'gemini-2.5-flash:generateContent?key=$apiKey',
      );

      final response = await http.post(
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
      );

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
      // Fall through to error response
    }
    return _errorResponse(contextDoc);
  }

  HelpBotResponse _errorResponse(RagResult? contextDoc) {
    return HelpBotResponse(
      answer:
          "I couldn't find a specific answer, but you can explore the app's "
          'features from the Dashboard or ask the AI assistant directly.',
      sourceDocId: contextDoc?.docId ?? '',
      confidenceScore: 0.0,
      usedCache: false,
      usedFallback: true,
    );
  }
}
