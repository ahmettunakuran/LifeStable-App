import '../domain/entities/note_entity.dart';

sealed class NotesState {}

class NotesLoading extends NotesState {}

class NotesLoaded extends NotesState {
  NotesLoaded(this.notes);
  final List<NoteEntity> notes;
}

class NotesError extends NotesState {
  NotesError(this.message);
  final String message;
}
