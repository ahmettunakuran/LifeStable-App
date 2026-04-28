import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/entities/note_entity.dart';
import '../domain/repositories/note_repository.dart';

class NoteRepositoryImpl implements NoteRepository {
  NoteRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _col(String userId) =>
      _firestore.collection('users').doc(userId).collection('notes');

  @override
  Stream<List<NoteEntity>> watchNotes(String userId) {
    return _col(userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => NoteEntity.fromFirestore(d.id, d.data()))
            .toList());
  }

  @override
  Future<NoteEntity> createNote({
    required String userId,
    required String domainId,
    required String title,
    required String content,
  }) async {
    final now = DateTime.now();
    final docRef = _col(userId).doc();
    final note = NoteEntity(
      id: docRef.id,
      userId: userId,
      domainId: domainId,
      title: title,
      content: content,
      createdAt: now,
      updatedAt: now,
    );
    await docRef.set({
      ...note.toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return note;
  }

  @override
  Future<void> updateNote(NoteEntity note) async {
    await _col(note.userId).doc(note.id).update({
      'domainId': note.domainId,
      'title': note.title,
      'content': note.content,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteNote(String userId, String noteId) async {
    await _col(userId).doc(noteId).delete();
  }
}
