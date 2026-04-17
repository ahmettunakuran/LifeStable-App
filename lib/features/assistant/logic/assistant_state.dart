part of 'assistant_cubit.dart';

enum AssistantStatus { initial, responding, idle, error, navigate }

class AssistantState {
  final List<ChatMessage> messages;
  final AssistantStatus status;
  final bool isListening;
  final String? errorMessage;
  final String? redirectTo;
  final Object? redirectArgs;

  const AssistantState({
    this.messages = const [],
    this.status = AssistantStatus.initial,
    this.isListening = false,
    this.errorMessage,
    this.redirectTo,
    this.redirectArgs,
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
  }) {
    return AssistantState(
      messages: messages ?? this.messages,
      status: status ?? this.status,
      isListening: isListening ?? this.isListening,
      errorMessage: errorMessage ?? this.errorMessage,
      redirectTo: redirectTo ?? this.redirectTo,
      redirectArgs: redirectArgs ?? this.redirectArgs,
    );
  }
}