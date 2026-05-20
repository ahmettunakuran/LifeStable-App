import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../features/assistant/domain/entities/chat_message.dart';
import '../../../services/help_bot_service.dart';

part 'app_assistant_state.dart';

/// Cubit for the App Assistant feature.
/// Communicates exclusively with [HelpBotService].
/// Passes conversation history to the service for context-aware replies.
class AppAssistantCubit extends Cubit<AppAssistantState> {
  final HelpBotService _helpBot = HelpBotService();

  AppAssistantCubit() : super(const AppAssistantState());

  Future<void> ask(String question) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty) return;

    final userMsg = ChatMessage(
      content: trimmed,
      sender: MessageSender.user,
    );
    final loadingMsg = ChatMessage(
      content: '',
      sender: MessageSender.assistant,
      isLoading: true,
    );

    emit(state.copyWith(
      messages: [...state.messages, userMsg, loadingMsg],
      status: AppAssistantStatus.responding,
      followUpSuggestions: const [],
    ));

    try {
      // Build conversation history (last 2 completed Q&A pairs)
      final history = _buildHistory(state.messages);

      final response = await _helpBot.ask(trimmed, history: history);

      final answered = [
        ...state.messages.where((m) => !m.isLoading),
        ChatMessage(
          content: response.answer,
          sender: MessageSender.assistant,
        ),
      ];

      emit(state.copyWith(
        messages: answered,
        status: AppAssistantStatus.idle,
        followUpSuggestions: response.followUpSuggestions,
      ));
    } catch (_) {
      final fallback = [
        ...state.messages.where((m) => !m.isLoading),
        ChatMessage(
          content: 'Something went wrong. Please try again.\n'
              'Bir şeyler ters gitti. Lütfen tekrar deneyin.',
          sender: MessageSender.assistant,
        ),
      ];
      emit(state.copyWith(
        messages: fallback,
        status: AppAssistantStatus.error,
        followUpSuggestions: const [],
      ));
    }
  }

  /// Builds a history list from completed user+assistant message pairs.
  List<ConversationTurn> _buildHistory(List<ChatMessage> messages) {
    final completed = messages.where((m) => !m.isLoading).toList();
    final turns = <ConversationTurn>[];

    for (int i = 0; i + 1 < completed.length; i++) {
      final a = completed[i];
      final b = completed[i + 1];
      if (a.sender == MessageSender.user &&
          b.sender == MessageSender.assistant) {
        turns.add(ConversationTurn(question: a.content, answer: b.content));
        i++; // advance past the assistant message
      }
    }

    // Return only the last 2 turns to keep the prompt compact
    return turns.length > 2 ? turns.sublist(turns.length - 2) : turns;
  }

  void clearError() => emit(state.copyWith(status: AppAssistantStatus.idle));
}
