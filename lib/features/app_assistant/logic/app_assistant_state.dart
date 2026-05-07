part of 'app_assistant_cubit.dart';

enum AppAssistantStatus { idle, responding, error }

class AppAssistantState {
  final List<ChatMessage> messages;
  final AppAssistantStatus status;

  const AppAssistantState({
    this.messages = const [],
    this.status = AppAssistantStatus.idle,
  });

  bool get showWelcome => messages.isEmpty;
  bool get isResponding => status == AppAssistantStatus.responding;

  AppAssistantState copyWith({
    List<ChatMessage>? messages,
    AppAssistantStatus? status,
  }) {
    return AppAssistantState(
      messages: messages ?? this.messages,
      status: status ?? this.status,
    );
  }
}
