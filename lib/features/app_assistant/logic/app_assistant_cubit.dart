import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../features/assistant/domain/entities/chat_message.dart';
import '../../../services/help_bot_service.dart';

part 'app_assistant_state.dart';

/// Cubit for the dedicated App Assistant feature.
/// Communicates exclusively with [HelpBotService] and the Firestore
/// knowledge base — never touches the Groq action pipeline.
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
    ));

    try {
      final response = await _helpBot.ask(trimmed);

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
      ));
    }
  }

  void clearError() => emit(state.copyWith(status: AppAssistantStatus.idle));
}
