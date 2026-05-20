part of 'app_assistant_cubit.dart';

enum AppAssistantStatus { idle, responding, error }

class AppAssistantState {
  final List<ChatMessage> messages;
  final AppAssistantStatus status;

  /// Follow-up question chips to show after the latest assistant reply.
  final List<String> followUpSuggestions;

  const AppAssistantState({
    this.messages = const [],
    this.status = AppAssistantStatus.idle,
    this.followUpSuggestions = const [],
  });

  bool get showWelcome => messages.isEmpty;
  bool get isResponding => status == AppAssistantStatus.responding;

  AppAssistantState copyWith({
    List<ChatMessage>? messages,
    AppAssistantStatus? status,
    List<String>? followUpSuggestions,
  }) {
    return AppAssistantState(
      messages: messages ?? this.messages,
      status: status ?? this.status,
      followUpSuggestions: followUpSuggestions ?? this.followUpSuggestions,
    );
  }
}
