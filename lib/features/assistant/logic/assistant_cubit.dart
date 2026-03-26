import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/entities/chat_message.dart';
import '../domain/repositories/assistant_repository.dart';

part 'assistant_state.dart';

class AssistantCubit extends Cubit<AssistantState> {
  final AssistantRepository _repository;

  AssistantCubit({required AssistantRepository repository})
      : _repository = repository,
        super(const AssistantState());

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    final userMessage = ChatMessage(
      content: content.trim(),
      sender: MessageSender.user,
    );

    final withLoading = [
      ...state.messages,
      userMessage,
      ChatMessage(
        content: '',
        sender: MessageSender.assistant,
        isLoading: true,
      ),
    ];

    emit(state.copyWith(
      messages: withLoading,
      status: AssistantStatus.responding,
    ));

    try {
      final response = await _repository.sendMessage(
        content.trim(),
        state.messages,
      );

      final finalMessages = [
        ...withLoading.where((m) => !m.isLoading),
        ChatMessage(
          content: response,
          sender: MessageSender.assistant,
        ),
      ];

      emit(state.copyWith(
        messages: finalMessages,
        status: AssistantStatus.idle,
      ));
    } catch (_) {
      emit(state.copyWith(
        messages: withLoading.where((m) => !m.isLoading).toList(),
        status: AssistantStatus.error,
        errorMessage: 'Yanıt alınamadı. Lütfen tekrar dene.',
      ));
    }
  }

  void setListening(bool value) =>
      emit(state.copyWith(isListening: value));

  void clearError() => emit(state.copyWith(
    status: AssistantStatus.idle,
    errorMessage: null,
  ));
}