import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/entities/note_entity.dart';
import '../domain/repositories/note_repository.dart';
import 'notes_state.dart';

class NotesCubit extends Cubit<NotesState> {
  NotesCubit(this._repo) : super(NotesLoading());

  final NoteRepository _repo;
  StreamSubscription<List<NoteEntity>>? _sub;

  void init() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      emit(NotesError('Not signed in.'));
      return;
    }
    _sub = _repo.watchNotes(uid).listen(
      (notes) => emit(NotesLoaded(notes)),
      onError: (Object e) => emit(NotesError(e.toString())),
    );
  }

  Future<void> createNote({
    required String domainId,
    required String title,
    required String content,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _repo.createNote(
      userId: uid,
      domainId: domainId,
      title: title,
      content: content,
    );
  }

  Future<void> updateNote(NoteEntity note) => _repo.updateNote(note);

  Future<void> deleteNote(String noteId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _repo.deleteNote(uid, noteId);
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
