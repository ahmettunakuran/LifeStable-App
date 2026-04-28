import '../entities/note_entity.dart';

abstract class NoteRepository {
  Stream<List<NoteEntity>> watchNotes(String userId);

  Future<NoteEntity> createNote({
    required String userId,
    required String domainId,
    required String title,
    required String content,
  });

  Future<void> updateNote(NoteEntity note);

  Future<void> deleteNote(String userId, String noteId);
}
