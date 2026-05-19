// ignore_for_file: lines_longer_than_80_chars

/// Notes Extended Tests — TC76 through TC85
///
/// Additional pure-Dart tests for NoteEntity: copyWith field updates,
/// filtering, grouping, and Firestore map shape.
/// Timestamp is a value class; no live Firebase connection required.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_lifestable/features/notes/domain/entities/note_entity.dart';

import '../../helpers/fixtures.dart';

void main() {
  // TC76 ────────────────────────────────────────────────────────────────────
  group('TC76: NoteEntity copyWith updates title', () {
    test('new title is reflected; all other fields remain unchanged', () {
      final original = Fixtures.note(title: 'Original Title');
      final updated = original.copyWith(title: 'Revised Title');

      expect(updated.title, 'Revised Title');
      expect(updated.id, original.id);
      expect(updated.userId, original.userId);
      expect(updated.content, original.content);
      expect(updated.createdAt, original.createdAt);
    });
  });

  // TC77 ────────────────────────────────────────────────────────────────────
  group('TC77: NoteEntity copyWith updates domainId', () {
    test('note can be moved to a different domain via copyWith', () {
      final original = Fixtures.note(domainId: 'domain-work');
      final moved = original.copyWith(domainId: 'domain-personal');

      expect(moved.domainId, 'domain-personal');
      expect(moved.id, original.id,
          reason: 'id must not change when only domainId changes.');
    });
  });

  // TC78 ────────────────────────────────────────────────────────────────────
  group('TC78: filter notes by domainId', () {
    test('only notes belonging to the requested domain are returned', () {
      final notes = [
        Fixtures.note(id: '1', domainId: 'domain-health'),
        Fixtures.note(id: '2', domainId: 'domain-work'),
        Fixtures.note(id: '3', domainId: 'domain-health'),
        Fixtures.note(id: '4', domainId: 'domain-personal'),
      ];

      const target = 'domain-health';
      final filtered = notes.where((n) => n.domainId == target).toList();

      expect(filtered.length, 2);
      expect(filtered.every((n) => n.domainId == target), isTrue);
      expect(filtered.map((n) => n.id), containsAll(['1', '3']));
    });

    test('filter for domain with no notes returns empty list', () {
      final notes = [Fixtures.note(domainId: 'domain-work')];
      final filtered =
          notes.where((n) => n.domainId == 'domain-empty').toList();
      expect(filtered, isEmpty);
    });
  });

  // TC79 ────────────────────────────────────────────────────────────────────
  group('TC79: combined title OR content search', () {
    test('search matches note whose title matches even if content does not', () {
      final notes = [
        Fixtures.note(id: '1', title: 'Quarterly review', content: 'Nothing here'),
        Fixtures.note(id: '2', title: 'Meeting notes', content: 'Discussed quarterly goals'),
        Fixtures.note(id: '3', title: 'Daily standup', content: 'Routine update'),
      ];

      const query = 'quarterly';
      final results = notes
          .where((n) =>
              n.title.toLowerCase().contains(query) ||
              n.content.toLowerCase().contains(query))
          .toList();

      expect(results.length, 2);
      expect(results.map((n) => n.id), containsAll(['1', '2']));
    });

    test('query matching neither title nor content returns empty list', () {
      final notes = [Fixtures.note(title: 'Alpha', content: 'Beta')];
      final results = notes
          .where((n) =>
              n.title.toLowerCase().contains('xyz') ||
              n.content.toLowerCase().contains('xyz'))
          .toList();
      expect(results, isEmpty);
    });
  });

  // TC80 ────────────────────────────────────────────────────────────────────
  group('TC80: note with empty content is valid', () {
    test('NoteEntity accepts an empty string as content', () {
      final note = NoteEntity(
        id: 'empty-content',
        userId: 'user-1',
        domainId: 'dom-1',
        title: 'Placeholder note',
        content: '',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );

      expect(note.content, isEmpty,
          reason: 'Empty content is valid for a draft-style note.');
      expect(note.title, isNotEmpty);
    });
  });

  // TC81 ────────────────────────────────────────────────────────────────────
  group('TC81: NoteEntity toFirestore includes userId field', () {
    test('userId is present in the serialized Firestore map', () {
      final note = Fixtures.note(userId: 'user-owner-42');
      final map = note.toFirestore();

      expect(map.containsKey('userId'), isTrue,
          reason: 'userId is required for Firestore security rules.');
      expect(map['userId'], 'user-owner-42');
    });
  });

  // TC82 ────────────────────────────────────────────────────────────────────
  group('TC82: NoteEntity toFirestore contains all required fields', () {
    test('map includes userId, domainId, title, content, createdAt, updatedAt', () {
      final note = Fixtures.note();
      final map = note.toFirestore();

      expect(map.containsKey('userId'), isTrue);
      expect(map.containsKey('domainId'), isTrue);
      expect(map.containsKey('title'), isTrue);
      expect(map.containsKey('content'), isTrue);
      expect(map.containsKey('createdAt'), isTrue);
      expect(map.containsKey('updatedAt'), isTrue);
    });
  });

  // TC83 ────────────────────────────────────────────────────────────────────
  group('TC83: multiple notes under same domain can coexist', () {
    test('three notes sharing the same domainId are all accessible', () {
      final notes = [
        Fixtures.note(id: 'n1', domainId: 'shared-domain'),
        Fixtures.note(id: 'n2', domainId: 'shared-domain'),
        Fixtures.note(id: 'n3', domainId: 'shared-domain'),
      ];

      final filtered =
          notes.where((n) => n.domainId == 'shared-domain').toList();

      expect(filtered.length, 3,
          reason: 'All three notes must be accessible within the same domain.');
      expect(filtered.map((n) => n.id), containsAll(['n1', 'n2', 'n3']));
    });
  });

  // TC84 ────────────────────────────────────────────────────────────────────
  group('TC84: note with very long content round-trips correctly', () {
    test('content of 10000 chars is preserved through toFirestore/fromFirestore', () {
      final longContent = 'x' * 10000;
      final note = NoteEntity(
        id: 'long-note',
        userId: 'user-1',
        domainId: 'dom-1',
        title: 'Long note',
        content: longContent,
        createdAt: DateTime(2024, 6, 1),
        updatedAt: DateTime(2024, 6, 1),
      );

      final map = note.toFirestore();
      final restored = NoteEntity.fromFirestore(note.id, map);

      expect(restored.content.length, 10000,
          reason: 'Full content must be preserved regardless of length.');
    });
  });

  // TC85 ────────────────────────────────────────────────────────────────────
  group('TC85: notes sorted by updatedAt for edit-time ordering', () {
    test('most recently edited note appears first when sorted by updatedAt', () {
      final early = Fixtures.note(
        id: 'early',
        updatedAt: DateTime(2024, 1, 1),
      );
      final recent = Fixtures.note(
        id: 'recent',
        updatedAt: DateTime(2024, 9, 1),
      );
      final middle = Fixtures.note(
        id: 'middle',
        updatedAt: DateTime(2024, 5, 1),
      );

      final sorted = [early, recent, middle]
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      expect(sorted.first.id, 'recent',
          reason: 'Most recently edited note must appear first.');
      expect(sorted.last.id, 'early',
          reason: 'Oldest edited note must appear last.');
    });

    test('single note list is unchanged after updatedAt sort', () {
      final notes = [Fixtures.note()];
      final sorted = notes..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      expect(sorted.length, 1);
    });
  });
}
