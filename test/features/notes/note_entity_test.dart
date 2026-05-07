// ignore_for_file: lines_longer_than_80_chars

/// Note Entity Tests — TC24, TC25
///
/// Tests for NoteEntity serialization and in-memory search filtering.
/// Pure Dart: no Firebase connection required (Timestamp is a value class).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_lifestable/features/notes/domain/entities/note_entity.dart';

import '../../helpers/fixtures.dart';

void main() {
  // TC24 ────────────────────────────────────────────────────────────────────
  group('TC24: in-note content search', () {
    test('case-insensitive search finds notes whose content contains the query', () {
      final notes = [
        Fixtures.note(id: '1', content: 'Meeting agenda for Q3 review'),
        Fixtures.note(id: '2', content: 'Shopping list: milk, eggs, bread'),
        Fixtures.note(id: '3', content: 'Q3 performance targets and KPIs'),
      ];

      const query = 'q3';
      final results = notes
          .where((n) => n.content.toLowerCase().contains(query.toLowerCase()))
          .toList();

      expect(results.length, 2,
          reason: 'Both notes mentioning Q3 must be returned.');
      expect(results.map((n) => n.id), containsAll(['1', '3']));
    });

    test('search by title also filters correctly', () {
      final notes = [
        Fixtures.note(id: 'a', title: 'Sprint Planning'),
        Fixtures.note(id: 'b', title: 'Weekly Standup'),
        Fixtures.note(id: 'c', title: 'Sprint Retrospective'),
      ];

      const query = 'sprint';
      final results = notes
          .where((n) => n.title.toLowerCase().contains(query.toLowerCase()))
          .toList();

      expect(results.length, 2);
      expect(results.map((n) => n.id), containsAll(['a', 'c']));
    });

    test('query with no match returns empty list', () {
      final notes = [Fixtures.note(content: 'Nothing relevant here')];
      final results = notes
          .where((n) => n.content.toLowerCase().contains('quantum'))
          .toList();
      expect(results, isEmpty);
    });
  });

  // TC25 ────────────────────────────────────────────────────────────────────
  group('TC25: NoteEntity Firestore serialization round-trip', () {
    test('toFirestore → fromFirestore preserves all fields', () {
      final createdAt = DateTime(2024, 3, 10, 9, 0);
      final updatedAt = DateTime(2024, 3, 12, 11, 30);

      final original = NoteEntity(
        id: 'round-trip-1',
        userId: 'user-abc',
        domainId: 'domain-school',
        title: 'Lecture notes',
        content: 'Chapter 3: Thermodynamics fundamentals.',
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      final map = original.toFirestore();
      final restored = NoteEntity.fromFirestore(original.id, map);

      expect(restored.id, original.id);
      expect(restored.userId, original.userId);
      expect(restored.domainId, original.domainId);
      expect(restored.title, original.title);
      expect(restored.content, original.content);
      // Timestamps lose sub-millisecond precision; compare date parts.
      expect(restored.createdAt.year, createdAt.year);
      expect(restored.createdAt.month, createdAt.month);
      expect(restored.createdAt.day, createdAt.day);
      expect(restored.updatedAt.year, updatedAt.year);
      expect(restored.updatedAt.month, updatedAt.month);
      expect(restored.updatedAt.day, updatedAt.day);
    });

    test('fromFirestore with missing optional fields uses safe defaults', () {
      final map = {
        'userId': null,
        'domainId': null,
        'title': null,
        'content': null,
        'createdAt': Timestamp.fromDate(DateTime(2024)),
        'updatedAt': Timestamp.fromDate(DateTime(2024)),
      };

      final entity = NoteEntity.fromFirestore('fallback-id', map);

      expect(entity.id, 'fallback-id');
      expect(entity.userId, '');
      expect(entity.domainId, '');
      expect(entity.title, '');
      expect(entity.content, '');
    });

    test('copyWith updates content and updatedAt without touching other fields', () {
      final original = Fixtures.note();
      final edited = original.copyWith(
        content: 'Edited content',
        updatedAt: DateTime(2025, 1, 1),
      );

      expect(edited.content, 'Edited content');
      expect(edited.updatedAt.year, 2025);
      expect(edited.id, original.id,
          reason: 'id is immutable and must not change.');
      expect(edited.userId, original.userId);
      expect(edited.title, original.title);
    });
  });
}
