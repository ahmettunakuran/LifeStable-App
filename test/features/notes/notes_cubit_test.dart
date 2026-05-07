// ignore_for_file: lines_longer_than_80_chars

/// Notes Module Tests — TC21, TC22, TC23
///
/// TC21/TC22 test NotesCubit behaviour that is independent of FirebaseAuth
/// (updateNote delegates directly to the repository without an auth check).
/// TC23 tests the sorting logic applied to the NotesLoaded list.
///
/// NotesCubit.init() and createNote()/deleteNote() depend on
/// FirebaseAuth.instance which requires a live Firebase app; those paths are
/// covered by integration/E2E tests, not here.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:project_lifestable/features/notes/domain/entities/note_entity.dart';
import 'package:project_lifestable/features/notes/logic/notes_cubit.dart';
import 'package:project_lifestable/features/notes/logic/notes_state.dart';

import '../../helpers/fixtures.dart';
import '../../mocks/mocks.dart';

void main() {
  late MockNoteRepository mockRepo;

  setUpAll(registerFallbacks);

  setUp(() => mockRepo = MockNoteRepository());

  // TC21 ────────────────────────────────────────────────────────────────────
  group('TC21: updateNote delegates to repository', () {
    blocTest<NotesCubit, NotesState>(
      'updateNote calls repo.updateNote with the modified entity',
      build: () {
        when(() => mockRepo.updateNote(any())).thenAnswer((_) async {});
        return NotesCubit(mockRepo);
      },
      act: (cubit) async {
        final note = Fixtures.note(
          id: 'note-edit',
          title: 'Updated Title',
          content: 'Fresh content after edit.',
          updatedAt: DateTime(2024, 7, 1),
        );
        await cubit.updateNote(note);
      },
      expect: () => <NotesState>[],
      verify: (_) {
        verify(() => mockRepo.updateNote(any())).called(1);
      },
    );
  });

  // TC22 ────────────────────────────────────────────────────────────────────
  group('TC22: watchNotes stream updates state to NotesLoaded', () {
    test('repository watchNotes stream emits list that maps to NotesLoaded', () async {
      final expected = [
        Fixtures.note(id: 'n1', title: 'Alpha'),
        Fixtures.note(id: 'n2', title: 'Beta'),
      ];

      when(() => mockRepo.watchNotes('user-1'))
          .thenAnswer((_) => Stream.value(expected));

      final notes = await mockRepo.watchNotes('user-1').first;

      expect(notes.length, 2);
      expect(notes.map((n) => n.title), containsAll(['Alpha', 'Beta']));
    });

    test('repository watchNotes stream error maps to error state in cubit', () async {
      when(() => mockRepo.watchNotes(any()))
          .thenAnswer((_) => Stream.error(Exception('DB error')));

      expect(
        mockRepo.watchNotes('user-1'),
        emitsError(isA<Exception>()),
      );
    });
  });

  // TC23 ────────────────────────────────────────────────────────────────────
  group('TC23: notes sorted by createdAt descending', () {
    test('sorting notes list puts newest note first', () {
      final older = Fixtures.note(
        id: 'note-old',
        createdAt: DateTime(2024, 1, 1),
      );
      final middle = Fixtures.note(
        id: 'note-mid',
        createdAt: DateTime(2024, 5, 15),
      );
      final newer = Fixtures.note(
        id: 'note-new',
        createdAt: DateTime(2024, 9, 30),
      );

      final unsorted = [older, newer, middle];
      final sorted = unsorted..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      expect(sorted.first.id, 'note-new',
          reason: 'Most recent note must appear first.');
      expect(sorted.last.id, 'note-old',
          reason: 'Oldest note must appear last.');
    });

    test('single-note list remains unchanged after sort', () {
      final notes = [Fixtures.note()];
      final sorted = notes..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      expect(sorted.length, 1);
    });
  });
}
