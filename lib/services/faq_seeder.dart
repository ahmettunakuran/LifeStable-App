import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/knowledge_base/faq_chunks.dart';
import 'embedding_service.dart';

/// Seeds [kFaqChunks] into the Firestore `doc_embeddings` collection.
///
/// Each chunk becomes one document whose ID is [title_type].
/// Already-existing documents are skipped, so seeding is idempotent.
/// Call [seedIfNeeded] once on app start — it runs fully in the background.
class FaqSeeder {
  static final FaqSeeder _instance = FaqSeeder._internal();
  factory FaqSeeder() => _instance;
  FaqSeeder._internal();

  static bool _seeding = false;
  static bool _done = false;

  final EmbeddingService _embedding = EmbeddingService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const _collection = 'doc_embeddings';

  /// Checks if seeding is needed and seeds any missing chunks in the background.
  /// Safe to call multiple times — it's a no-op after the first run.
  Future<void> seedIfNeeded() async {
    if (_done || _seeding) return;
    _seeding = true;
    unawaited(_runSeeding());
  }

  Future<void> _runSeeding() async {
    try {
      // Collect which title_types already exist in Firestore
      final snap = await _db
          .collection(_collection)
          .where('doc_type', isEqualTo: 'faq')
          .get();
      final existing = snap.docs.map((d) => d.id).toSet();

      final missing = kFaqChunks
          .where((c) => !existing.contains(c['title_type'] as String))
          .toList();

      if (missing.isEmpty) {
        _done = true;
        _seeding = false;
        return;
      }

      // Seed each missing chunk sequentially to stay within API rate limits
      for (final chunk in missing) {
        await _seedChunk(chunk);
        // Small pause between API calls to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 300));
      }

      _done = true;
    } catch (_) {
      // Seeding is best-effort — the local keyword fallback works without it
    } finally {
      _seeding = false;
    }
  }

  Future<void> _seedChunk(Map<String, dynamic> chunk) async {
    try {
      final content = chunk['content'] as String;
      final titleType = chunk['title_type'] as String;

      final vector = await _embedding.generateEmbedding(content);

      await _db.collection(_collection).doc(titleType).set({
        'title_type': titleType,
        'doc_type': chunk['doc_type'],
        'source_key': chunk['source_key'],
        'content': content,
        'indexes': chunk['indexes'],
        'embedding_vector': vector,
        'seeded_at': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Skip this chunk — it will be retried on the next app launch
    }
  }
}
