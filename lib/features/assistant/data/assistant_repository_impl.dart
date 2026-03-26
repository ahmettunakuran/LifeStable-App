import '../domain/entities/chat_message.dart';
import '../domain/repositories/assistant_repository.dart';

class AssistantRepositoryImpl implements AssistantRepository {
  @override
  Future<String> sendMessage(
      String message,
      List<ChatMessage> history,
      ) async {
    // TODO: Task 5.2 — Firebase Cloud Functions → OpenAI GPT bağlantısı
    await Future.delayed(const Duration(milliseconds: 1400));
    return 'Hello! Full AI responses will be active in Task 5.2. '
        'You asked: "$message"';
  }

  @override
  Future<String> transcribeAudio(String audioPath) async {
    // TODO: Task 5.2 — Whisper API bağlantısı
    await Future.delayed(const Duration(milliseconds: 500));
    return '';
  }
}