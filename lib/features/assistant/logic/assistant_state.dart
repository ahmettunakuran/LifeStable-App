part of 'assistant_cubit.dart';

enum AssistantStatus { initial, responding, idle, error, navigate }

enum UndoableKind { task, calendarEvent, habit, domain }

class UndoableAction {
  final String token;
  final UndoableKind kind;
  final String entityId;
  final String label;

  const UndoableAction({
    required this.token,
    required this.kind,
    required this.entityId,
    required this.label,
  });
}

class AssistantState {
  final List<ChatMessage> messages;
  final AssistantStatus status;
  final bool isListening;
  final String? errorMessage;
  final String? redirectTo;
  final Object? redirectArgs;
  final UndoableAction? undoable;

  const AssistantState({
    this.messages = const [],
    this.status = AssistantStatus.initial,
    this.isListening = false,
    this.errorMessage,
    this.redirectTo,
    this.redirectArgs,
    this.undoable,
  });

  bool get showWelcome =>
      messages.isEmpty && status == AssistantStatus.initial;

  AssistantState copyWith({
    List<ChatMessage>? messages,
    AssistantStatus? status,
    bool? isListening,
    String? errorMessage,
    String? redirectTo,
    Object? redirectArgs,
    UndoableAction? undoable,
    bool clearUndoable = false,
  }) {
    return AssistantState(
      messages: messages ?? this.messages,
      status: status ?? this.status,
      isListening: isListening ?? this.isListening,
      errorMessage: errorMessage ?? this.errorMessage,
      redirectTo: redirectTo ?? this.redirectTo,
      redirectArgs: redirectArgs ?? this.redirectArgs,
      undoable: clearUndoable ? null : (undoable ?? this.undoable),
    );
  }
}